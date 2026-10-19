-- Библиотека игр: сетка всех установленных приложений.
local PS5 = script.Parent.Parent
local Util = require(PS5.Util)
local Theme = require(PS5.Theme)
local Nav = require(PS5.Nav)
local Registry = require(PS5.Registry)
local Runtime = require(PS5.Runtime)
local C = require(script.Parent.Components)
local AppMenu = require(script.Parent.AppMenu)

return function(Shell)
	local frame = Util.new("Frame", { Name = "Library", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local screen = { frame = frame }
	local layer
	C.Header("Game Library", frame)
	local count = Util.text("", { Size = UDim2.fromOffset(600, 26), Position = UDim2.fromOffset(82, 104), TextSize = 20, TextColor3 = Theme.Colors.SubText, Parent = frame })
	local grid = Util.new("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -120, 1, -240),
		Position = UDim2.fromOffset(60, 150),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = frame,
	})

	local function build()
		grid:ClearAllChildren()
		Util.new("UIGridLayout", { CellSize = UDim2.fromOffset(200, 250), CellPadding = UDim2.fromOffset(28, 20), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		Util.padding(20).Parent = grid
		local apps = Registry.List()
		count.Text = `Installed: {#apps}`
		local running = Runtime.Current()
		for i, manifest in apps do
			local holder = Util.new("Frame", { BackgroundTransparency = 1, LayoutOrder = i, Parent = grid })
			C.Tile(manifest, {
				size = UDim2.fromOffset(200, 200),
				caption = true,
				parent = holder,
				onActivate = function()
					Shell.Launch(manifest.id)
				end,
				onButton = function(btn, event)
					if event == "press" and (btn == "options" or btn == "triangle") then
						AppMenu(Shell, manifest)
						return true
					end
					return false
				end,
			})
			if running and running.id == manifest.id then
				Util.text("● Running", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -18), TextSize = 15, TextColor3 = Theme.Colors.Success, Parent = holder })
			end
		end
		if #apps == 0 then
			Util.text("Nothing here yet. Add a game to src/apps (see README).", { Size = UDim2.fromOffset(800, 30), TextColor3 = Theme.Colors.SubText, Parent = grid })
		end
	end

	function screen.Enter()
		Shell.SetHints({ { "cross", "Start" }, { "options", "Options" }, { "circle", "Back" } })
		build()
		layer = Nav.Push({ root = frame, name = "library", onBack = Shell.Back })
	end

	function screen.Leave()
		Nav.Pop(layer)
	end

	return screen
end
