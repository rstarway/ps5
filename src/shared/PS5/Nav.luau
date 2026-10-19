-- Навигация фокусом в стиле PS5: стрелки/стик двигают фокус по геометрии элементов,
-- ✕ активирует, ○ — назад. Слои складываются в стек (экран, меню, модальное окно).
local Signal = require(script.Parent.Signal)
local Util = require(script.Parent.Util)
local Theme = require(script.Parent.Theme)
local Audio = require(script.Parent.Audio)

local Nav = {}
Nav.FocusChanged = Signal.new()

local layers = {}
local meta = setmetatable({}, { __mode = "k" })

local function topLayer()
	return layers[#layers]
end
Nav.Top = topLayer

local function inLayer(el, layer)
	return layer and (el == layer.root or el:IsDescendantOf(layer.root))
end

local function isVisible(el, root)
	local node = el
	while node and node ~= root.Parent do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("LayerCollector") and not node.Enabled then
			return false
		end
		node = node.Parent
	end
	return node ~= nil
end

-- Блик, который бежит по рамке выделенного элемента
local SHIMMER = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Theme.Colors.Focus),
	ColorSequenceKeypoint.new(0.45, Theme.Colors.Focus),
	ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.55, Theme.Colors.Focus),
	ColorSequenceKeypoint.new(1, Theme.Colors.Focus),
})
local shimmer -- градиент на рамке текущего элемента
game:GetService("RunService").Heartbeat:Connect(function(dt)
	if shimmer and shimmer.Parent then
		shimmer.Rotation = (shimmer.Rotation + dt * 90) % 360
	end
end)

local function setVisual(el, focused)
	local m = meta[el]
	if not m then
		return
	end
	local ring = el:FindFirstChild("FocusRing")
	if ring then
		Util.tween(ring, 0.15, { Transparency = focused and 0 or 1 })
		local gradient = ring:FindFirstChild("Shimmer")
		if focused then
			gradient = gradient or Util.new("UIGradient", { Name = "Shimmer", Color = SHIMMER, Rotation = 0, Parent = ring })
			gradient.Enabled = true
			shimmer = gradient
		elseif gradient then
			gradient.Enabled = false
		end
	end
	local scale = el:FindFirstChild("FocusScale")
	if scale then
		-- пружинка: чуть больше и обратно
		if focused then
			Util.tween(scale, 0.32, { Scale = m.scale or 1.05 }, Enum.EasingStyle.Back)
		else
			Util.tween(scale, 0.2, { Scale = 1 })
		end
	end
	if focused and m.onFocus then
		m.onFocus(el)
	elseif not focused and m.onBlur then
		m.onBlur(el)
	end
end

-- Делает элемент фокусируемым.
-- opts: onActivate, onFocus, onBlur, onButton(btn, event) -> bool, scale, noRing, ringInset
function Nav.Register(el, opts)
	opts = opts or {}
	meta[el] = opts
	el:SetAttribute("Focusable", true)
	if not opts.noRing and not el:FindFirstChild("FocusRing") then
		Util.new("UIStroke", {
			Name = "FocusRing",
			Color = Theme.Colors.Focus,
			Thickness = opts.ringThickness or 3,
			Transparency = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = el,
		})
	end
	if opts.scale ~= 1 and not el:FindFirstChild("FocusScale") then
		Util.new("UIScale", { Name = "FocusScale", Parent = el })
	end
	if el:IsA("GuiButton") then
		el.AutoButtonColor = false
		el.Activated:Connect(function()
			local layer = topLayer()
			if inLayer(el, layer) then
				Nav.Focus(el, true)
				Nav.Activate(el)
			end
		end)
		el.MouseEnter:Connect(function()
			local layer = topLayer()
			if inLayer(el, layer) and layer.focused ~= el then
				Nav.Focus(el, true)
			end
		end)
	end
	return el
end

function Nav.Unregister(el)
	meta[el] = nil
	el:SetAttribute("Focusable", nil)
end

local function candidates(layer)
	local list = {}
	for _, d in layer.root:GetDescendants() do
		if meta[d] and d:GetAttribute("Focusable") and isVisible(d, layer.root) then
			table.insert(list, d)
		end
	end
	return list
end
Nav.Candidates = function()
	local layer = topLayer()
	return layer and candidates(layer) or {}
end

-- Прокрутка ScrollingFrame, чтобы фокус был виден.
local function ensureVisible(el, layer)
	local sf = el:FindFirstAncestorWhichIsA("ScrollingFrame")
	if not sf or not inLayer(sf, layer) then
		return
	end
	local pad = 40
	local canvas = sf.CanvasPosition
	local relX = el.AbsolutePosition.X - sf.AbsolutePosition.X + canvas.X
	local relY = el.AbsolutePosition.Y - sf.AbsolutePosition.Y + canvas.Y
	local x, y = canvas.X, canvas.Y
	if relY < y + pad then
		y = relY - pad
	elseif relY + el.AbsoluteSize.Y > y + sf.AbsoluteSize.Y - pad then
		y = relY + el.AbsoluteSize.Y - sf.AbsoluteSize.Y + pad
	end
	if relX < x + pad then
		x = relX - pad
	elseif relX + el.AbsoluteSize.X > x + sf.AbsoluteSize.X - pad then
		x = relX + el.AbsoluteSize.X - sf.AbsoluteSize.X + pad
	end
	local maxY = math.max(0, sf.AbsoluteCanvasSize.Y - sf.AbsoluteWindowSize.Y)
	local maxX = math.max(0, sf.AbsoluteCanvasSize.X - sf.AbsoluteWindowSize.X)
	Util.tween(sf, 0.25, { CanvasPosition = Vector2.new(math.clamp(x, 0, maxX), math.clamp(y, 0, maxY)) })
end

function Nav.Focus(el, silent)
	local layer = topLayer()
	if not layer or not el or not meta[el] then
		return
	end
	if layer.focused == el then
		return
	end
	if layer.focused then
		setVisual(layer.focused, false)
	end
	layer.focused = el
	setVisual(el, true)
	ensureVisible(el, layer)
	if not silent then
		Audio.Ui("move")
	end
	Nav.FocusChanged:Fire(el)
end

function Nav.Focused()
	local layer = topLayer()
	return layer and layer.focused
end

function Nav.Activate(el)
	local m = meta[el]
	if m and m.onActivate then
		if not m.silent then
			Audio.Ui("confirm")
		end
		m.onActivate(el)
	end
end

local function overlap(a1, a2, b1, b2)
	if b2 < a1 then
		return a1 - b2
	elseif b1 > a2 then
		return b1 - a2
	end
	return 0
end

function Nav.Move(dir)
	local layer = topLayer()
	if not layer then
		return
	end
	if layer.onMove and layer.onMove(dir, layer.focused) then
		return
	end
	local list = candidates(layer)
	local cur = layer.focused
	if not cur or not table.find(list, cur) then
		if list[1] then
			Nav.Focus(list[1])
		end
		return
	end
	local p, s = cur.AbsolutePosition, cur.AbsoluteSize
	local cx, cy = p.X + s.X / 2, p.Y + s.Y / 2
	local best, bestScore = nil, math.huge
	for _, c in list do
		if c ~= cur then
			local q, t = c.AbsolutePosition, c.AbsoluteSize
			local x, y = q.X + t.X / 2, q.Y + t.Y / 2
			local main, cross = nil, nil
			if dir == "right" and x > cx + 1 then
				main, cross = x - cx, overlap(p.Y, p.Y + s.Y, q.Y, q.Y + t.Y)
			elseif dir == "left" and x < cx - 1 then
				main, cross = cx - x, overlap(p.Y, p.Y + s.Y, q.Y, q.Y + t.Y)
			elseif dir == "down" and y > cy + 1 then
				main, cross = y - cy, overlap(p.X, p.X + s.X, q.X, q.X + t.X)
			elseif dir == "up" and y < cy - 1 then
				main, cross = cy - y, overlap(p.X, p.X + s.X, q.X, q.X + t.X)
			end
			if main then
				local score = main + cross * 3
				if score < bestScore then
					best, bestScore = c, score
				end
			end
		end
	end
	if best then
		Nav.Focus(best)
	end
end

-- Обработка ввода интерфейсом (вызывается из приёмника Input).
function Nav.Handle(event, btn)
	local layer = topLayer()
	if not layer or event == "release" then
		return
	end
	local focused = layer.focused
	local m = focused and meta[focused]
	if m and m.onButton and m.onButton(btn, event) then
		return
	end
	if layer.onButton and layer.onButton(btn, event, focused) then
		return
	end
	if btn == "up" or btn == "down" or btn == "left" or btn == "right" then
		Nav.Move(btn)
	elseif event == "press" and btn == "cross" and focused then
		Nav.Activate(focused)
	elseif event == "press" and btn == "circle" and layer.onBack then
		Audio.Ui("back")
		layer.onBack()
	end
end

-- layer = { root, default = el | fn, onBack, onButton, onMove, name }
function Nav.Push(layer)
	local prev = topLayer()
	if prev and prev.focused then
		setVisual(prev.focused, false)
	end
	table.insert(layers, layer)
	task.defer(function()
		if topLayer() ~= layer then
			return
		end
		local target = layer.focused
		if not target and layer.default then
			target = type(layer.default) == "function" and layer.default() or layer.default
		end
		if not target then
			target = candidates(layer)[1]
		end
		if target then
			layer.focused = nil
			Nav.Focus(target, true)
		end
	end)
	return layer
end

function Nav.Pop(layer)
	local i = table.find(layers, layer)
	if not i then
		return
	end
	local wasTop = i == #layers
	if layer.focused then
		setVisual(layer.focused, false)
	end
	table.remove(layers, i)
	local top = topLayer()
	if wasTop and top and top.focused then
		if meta[top.focused] and top.focused.Parent then
			setVisual(top.focused, true)
		else
			top.focused = nil
			local first = candidates(top)[1]
			if first then
				Nav.Focus(first, true)
			end
		end
	end
end

function Nav.Refocus(layer)
	-- перевыбор фокуса после перестроения содержимого слоя
	layer = layer or topLayer()
	if not layer then
		return
	end
	if layer.focused and (not layer.focused.Parent or not meta[layer.focused]) then
		layer.focused = nil
	end
	if not layer.focused and layer == topLayer() then
		local first = layer.default and (type(layer.default) == "function" and layer.default() or layer.default)
		first = first or candidates(layer)[1]
		if first then
			Nav.Focus(first, true)
		end
	end
end

-- Снять все слои (выход из интерфейса PS5)
function Nav.Clear()
	for i = #layers, 1, -1 do
		local layer = layers[i]
		if layer.focused then
			setVisual(layer.focused, false)
		end
		layers[i] = nil
	end
end

function Nav.Depth()
	return #layers
end

return Nav
