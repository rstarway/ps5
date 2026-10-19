-- Визуал, встроенный в код (см. blender/export_luau.py): картинки собираются в EditableImage,
-- модели в EditableMesh → MeshPart. Ничего не нужно загружать в Roblox вручную.
-- Если движок не даёт создать Editable-объект, функции возвращают nil, и система рисует запасной вариант.
local AssetService = game:GetService("AssetService")

local Embedded = {}

local imageCache = {}
local warned = false

local function report(err)
	if not warned then
		warned = true
		warn("[PS5] Embedded visuals unavailable, using fallback:", err)
	end
end

local B64 = {}
do
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #alphabet do
		B64[string.byte(alphabet, i)] = i - 1
	end
end

-- base64 RGB → буфер RGBA для EditableImage
local function decodeToRgba(data, pixels)
	local out = buffer.create(pixels * 4)
	local byte = string.byte
	local o, channel = 0, 0
	local function push(value)
		buffer.writeu8(out, o, value)
		o += 1
		channel += 1
		if channel == 3 then
			buffer.writeu8(out, o, 255)
			o += 1
			channel = 0
		end
	end
	for i = 1, #data, 4 do
		local a, b, c, d = byte(data, i, i + 3)
		local n = B64[a] * 262144 + B64[b] * 4096 + (B64[c] or 0) * 64 + (B64[d] or 0)
		if o < pixels * 4 then
			push(bit32.rshift(n, 16))
		end
		if c ~= 61 and o < pixels * 4 then
			push(bit32.band(bit32.rshift(n, 8), 255))
		end
		if d ~= 61 and o < pixels * 4 then
			push(bit32.band(n, 255))
		end
	end
	return out
end

-- Content картинки из модуля { width, height, rgb } или nil.
function Embedded.Image(module)
	if not module then
		return nil
	end
	if imageCache[module] ~= nil then
		return imageCache[module] or nil
	end
	local ok, result = pcall(function()
		local data = require(module)
		local size = Vector2.new(data.width, data.height)
		local image = AssetService:CreateEditableImage({ Size = size })
		image:WritePixelsBuffer(Vector2.zero, size, decodeToRgba(data.rgb, data.width * data.height))
		return Content.fromObject(image)
	end)
	if not ok then
		report(result)
	end
	imageCache[module] = ok and result or false
	return ok and result or nil
end

-- Ставит картинку в ImageLabel: ref — "rbxassetid://..." или имя модуля-картинки внутри owner.
function Embedded.ApplyImage(label, ref, owner)
	if type(ref) ~= "string" or ref == "" then
		return false
	end
	if string.find(ref, "rbxasset") then
		label.Image = ref
		return true
	end
	local content = Embedded.Image(owner and owner:FindFirstChild(ref))
	if content then
		label.ImageContent = content
		return true
	end
	return false
end

local KIND = {
	White = { color = Color3.fromRGB(238, 240, 245), material = Enum.Material.SmoothPlastic },
	Black = { color = Color3.fromRGB(16, 16, 20), material = Enum.Material.SmoothPlastic },
	Light = { color = Color3.fromRGB(0, 120, 255), material = Enum.Material.Neon },
}

local function meshPartFrom(mesh)
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(mesh), { CollisionFidelity = Enum.CollisionFidelity.Box })
	end)
	if ok then
		return part
	end
	return AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
end

-- Модель из модуля сетки ({ {kind, v, n, t[, uv, color, material, transparency]}, ... }) или nil.
-- yieldEvery: пауза после каждых N деталей, чтобы большая сцена не подвешивала кадр.
function Embedded.Model(module, name, yieldEvery)
	if not module then
		return nil
	end
	local ok, result = pcall(function()
		local model = Instance.new("Model")
		model.Name = name
		for index, part in require(module) do
			local mesh = AssetService:CreateEditableMesh()
			local verts, normals, uvs = {}, {}, {}
			for i = 1, #part.v, 3 do
				table.insert(verts, mesh:AddVertex(Vector3.new(part.v[i], part.v[i + 1], part.v[i + 2])))
			end
			for i = 1, #part.n, 3 do
				table.insert(normals, mesh:AddNormal(Vector3.new(part.n[i], part.n[i + 1], part.n[i + 2])))
			end
			local t = part.t
			if part.uv then
				for i = 1, #part.uv, 2 do
					table.insert(uvs, mesh:AddUV(Vector2.new(part.uv[i], part.uv[i + 1])))
				end
				for i = 1, #t, 9 do
					local face = mesh:AddTriangle(verts[t[i]], verts[t[i + 3]], verts[t[i + 6]])
					mesh:SetFaceNormals(face, { normals[t[i + 1]], normals[t[i + 4]], normals[t[i + 7]] })
					mesh:SetFaceUVs(face, { uvs[t[i + 2]], uvs[t[i + 5]], uvs[t[i + 8]] })
				end
			else
				for i = 1, #t, 6 do
					local face = mesh:AddTriangle(verts[t[i]], verts[t[i + 2]], verts[t[i + 4]])
					mesh:SetFaceNormals(face, { normals[t[i + 1]], normals[t[i + 3]], normals[t[i + 5]] })
				end
			end
			local meshPart = meshPartFrom(mesh)
			meshPart.Name = part.kind
			meshPart.Anchored = true
			meshPart.CanCollide = false
			meshPart.CanQuery = false
			meshPart.CanTouch = false
			if part.color then
				meshPart.Color = Color3.fromRGB(part.color[1], part.color[2], part.color[3])
				meshPart.Material = Enum.Material[part.material]
				meshPart.Transparency = part.transparency or 0
				meshPart.CastShadow = part.material ~= "Neon" and part.material ~= "Glass"
			else
				local style = KIND[part.kind] or KIND.Black
				meshPart.Color = style.color
				meshPart.Material = style.material
			end
			-- вершины EditableMesh остаются в координатах сцены Blender относительно начала детали
			meshPart.CFrame = CFrame.new()
			meshPart.Parent = model
			if yieldEvery and index % yieldEvery == 0 then
				task.wait()
			end
		end
		-- точка опоры = начало координат сцены Blender (основание модели)
		model.WorldPivot = CFrame.new()
		return model
	end)
	if not ok then
		report(result)
		return nil
	end
	return result
end

return Embedded
