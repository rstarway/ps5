-- Без неона и свечения: неоновый материал вместе с Bloom пересвечивал мир и игры.
-- Страховка на клиенте: любая деталь с Neon становится обычным пластиком, а Bloom/SunRays
-- из Lighting удаляются. Так неон не вернётся, даже если новая игра его создаст.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local NoGlow = {}

local BANNED_EFFECTS = { BloomEffect = true, SunRaysEffect = true }

local function fixPart(p)
	if p.Material == Enum.Material.Neon then
		p.Material = Enum.Material.SmoothPlastic
	end
end

local function watchPart(p)
	fixPart(p)
	-- материал иногда задают сразу после того, как деталь попала в мир
	task.defer(fixPart, p)
end

local function fixEffect(e)
	if BANNED_EFFECTS[e.ClassName] then
		e:Destroy()
	end
end

function NoGlow.Start()
	for _, d in Workspace:GetDescendants() do
		if d:IsA("BasePart") then
			watchPart(d)
		end
	end
	Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			watchPart(d)
		end
	end)
	for _, e in Lighting:GetChildren() do
		fixEffect(e)
	end
	Lighting.ChildAdded:Connect(function(e)
		task.defer(fixEffect, e)
	end)
end

return NoGlow
