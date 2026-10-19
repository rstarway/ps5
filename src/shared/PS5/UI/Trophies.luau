-- Экран трофеев: уровень пользователя, список игр слева, трофеи выбранной игры справа.
local PS5 = script.Parent.Parent
local Util = require(PS5.Util)
local Theme = require(PS5.Theme)
local Nav = require(PS5.Nav)
local Data = require(PS5.Data)
local Registry = require(PS5.Registry)
local Trophies = require(PS5.Trophies)
local C = require(script.Parent.Components)

local POINTS = { bronze = 15, silver = 30, gold = 90, platinum = 300 }

return function(Shell)
	local frame = Util.new("Frame", { Name = "Trophies", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local screen = { frame = frame }
	local layer, lastGameRow
	C.Header("Trophies", frame)
	local summary = Util.text("", { Size = UDim2.fromOffset(1200, 28), Position = UDim2.fromOffset(82, 104), TextSize = 22, TextColor3 = Theme.Colors.SubText, Parent = frame })

	local function scrolling(name, position, size)
		return Util.new("ScrollingFrame", {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = position,
			Size = size,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Parent = frame,
		})
	end
	local gamesList = scrolling("Games", UDim2.fromOffset(70, 160), UDim2.new(0, 520, 1, -250))
	local trophyList = scrolling("List", UDim2.fromOffset(640, 160), UDim2.new(1, -720, 1, -250))

	local function resetList(list)
		list:ClearAllChildren()
		Util.list(Enum.FillDirection.Vertical, 12).Parent = list
		Util.padding(10).Parent = list
	end

	local function showTrophies(manifest)
		resetList(trophyList)
		if not manifest then
			Util.text("Trophies will appear here once games define manifest.trophies.", { Size = UDim2.new(1, 0, 0, 30), TextColor3 = Theme.Colors.SubText, Parent = trophyList })
			return
		end
		for i, t in Trophies.List(manifest) do
			local row = Util.new("TextButton", {
				Text = "",
				BackgroundColor3 = Theme.Colors.Card,
				BackgroundTransparency = t.unlocked and 0.1 or 0.5,
				Size = UDim2.new(1, -10, 0, 92),
				LayoutOrder = i,
				Parent = trophyList,
			}, { Util.corner(16) })
			local medal = Util.new("Frame", {
				BackgroundColor3 = Theme.TrophyColors[t.grade] or Theme.Colors.Bronze,
				BackgroundTransparency = t.unlocked and 0 or 0.75,
				Size = UDim2.fromOffset(60, 60),
				Position = UDim2.fromOffset(16, 16),
				Parent = row,
			}, { Util.corner(UDim.new(0.5, 0)) })
			Util.text(t.unlocked and "🏆" or "🔒", { Size = UDim2.fromScale(1, 1), TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Parent = medal })
			local hidden = t.hidden and not t.unlocked
			Util.text(hidden and "Hidden trophy" or t.name, { Size = UDim2.new(1, -260, 0, 28), Position = UDim2.fromOffset(94, 14), TextSize = 22, Font = Theme.FontBold, Parent = row })
			Util.text(hidden and "Keep playing to find out." or (t.description or ""), {
				Size = UDim2.new(1, -260, 0, 40), Position = UDim2.fromOffset(94, 44), TextSize = 17, TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Theme.Colors.SubText, Parent = row,
			})
			Util.text(`{Theme.TrophyNames[t.grade] or ""}\n{t.unlocked and os.date("%d.%m.%Y", t.unlockedAt) or ""}`, {
				Size = UDim2.fromOffset(150, 50), Position = UDim2.new(1, -166, 0, 20), TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Theme.TrophyColors[t.grade] or Theme.Colors.SubText, Parent = row,
			})
			Nav.Register(row, { scale = 1.02 })
		end
	end

	local function build(selectId)
		resetList(gamesList)
		local points, counts = 0, { bronze = 0, silver = 0, gold = 0, platinum = 0 }
		local first, selectEl
		local withTrophies = {}
		for _, manifest in Registry.List() do
			if #manifest.trophies > 0 then
				table.insert(withTrophies, manifest)
			end
			for _, t in Trophies.List(manifest) do
				if t.unlocked then
					points += POINTS[t.grade] or 0
					counts[t.grade] = (counts[t.grade] or 0) + 1
				end
			end
		end
		local level = 1 + math.floor(points / 100)
		local user = Data.CurrentUser()
		summary.Text = `{user and user.name or ""} · level {level}   ·   🥉 {counts.bronze}   🥈 {counts.silver}   🥇 {counts.gold}   💎 {counts.platinum}`

		for i, manifest in withTrophies do
			local got, total, pct = Trophies.Progress(manifest)
			local row = Util.new("TextButton", {
				Name = manifest.id,
				Text = "",
				BackgroundColor3 = Theme.Colors.Card,
				BackgroundTransparency = 0.2,
				Size = UDim2.new(1, -10, 0, 100),
				LayoutOrder = i,
				Parent = gamesList,
			}, { Util.corner(16) })
			local icon = Util.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(72, 72), Position = UDim2.fromOffset(14, 14), Parent = row })
			C.Cover(manifest, icon)
			Util.text(manifest.title, { Size = UDim2.new(1, -120, 0, 28), Position = UDim2.fromOffset(102, 16), TextSize = 22, Font = Theme.FontBold, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
			Util.text(`{got}/{total} · {pct}%`, { Size = UDim2.new(1, -120, 0, 22), Position = UDim2.fromOffset(102, 46), TextSize = 17, TextColor3 = Theme.Colors.SubText, Parent = row })
			C.Progress(total > 0 and got / total or 0, { parent = row, position = UDim2.fromOffset(102, 78), size = UDim2.new(1, -130, 0, 6) })
			Nav.Register(row, {
				scale = 1.02,
				onFocus = function(el)
					lastGameRow = el
					showTrophies(manifest)
				end,
			})
			first = first or row
			if manifest.id == selectId then
				selectEl = row
			end
		end
		if #withTrophies == 0 then
			showTrophies(nil)
		end
		return selectEl or first
	end

	function screen.Enter(args)
		Shell.SetHints({ { "cross", "Select" }, { "circle", "Back" } })
		local focusEl = build(args and args.app)
		layer = Nav.Push({
			root = frame,
			name = "trophies",
			default = focusEl,
			onBack = function()
				local focused = Nav.Focused()
				if focused and focused:IsDescendantOf(trophyList) then
					Nav.Focus(lastGameRow or gamesList:FindFirstChildWhichIsA("TextButton"))
				else
					Shell.Back()
				end
			end,
		})
	end

	function screen.Leave()
		Nav.Pop(layer)
	end

	return screen
end
