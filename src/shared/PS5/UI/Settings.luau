-- Настройки: категории слева, параметры справа.
-- Типы строк: toggle, slider, choice, action, info.
local PS5 = script.Parent.Parent
local Util = require(PS5.Util)
local Theme = require(PS5.Theme)
local Nav = require(PS5.Nav)
local Input = require(PS5.Input)
local Data = require(PS5.Data)
local Registry = require(PS5.Registry)
local Runtime = require(PS5.Runtime)
local Version = require(PS5.Version)
local C = require(script.Parent.Components)

return function(Shell)
	local frame = Util.new("Frame", { Name = "Settings", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local screen = { frame = frame }
	local layer, currentCategory, categoryButtons = nil, nil, {}
	C.Header("Settings", frame)

	local function scrolling(name, position, size)
		return Util.new("ScrollingFrame", {
			Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, Position = position, Size = size,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
			ScrollingDirection = Enum.ScrollingDirection.Y, Parent = frame,
		})
	end
	local categoriesList = scrolling("Categories", UDim2.fromOffset(70, 150), UDim2.new(0, 480, 1, -240))
	local content = scrolling("Content", UDim2.fromOffset(600, 150), UDim2.new(1, -680, 1, -240))

	local function setting(key)
		return {
			get = function()
				return Data.Setting(key)
			end,
			set = function(v)
				Data.SetSetting(key, v)
			end,
		}
	end

	local CATEGORIES
	local function showCategory(id) end -- объявлено ниже

	CATEGORIES = {
		{ id = "users", icon = "👤", name = "Users", rows = function()
			local user = Data.CurrentUser() or Data.Users()[1]
			return {
				{ type = "info", label = "Current user", value = user.name },
				{ type = "action", label = "Change name", run = function()
					Shell.Modal.Prompt("New name", user.name, function(name)
						Data.RenameUser(user.id, string.sub(name, 1, 24))
						showCategory("users")
					end)
				end },
				{ type = "action", label = "Add User", run = function()
					local added = Data.AddUser()
					Shell.Toast("User added", added.name)
					showCategory("users")
				end },
				{ type = "action", label = "Switch User", run = function()
					Runtime.Close()
					Shell.Go("users")
				end },
				{ type = "info", label = "Total users", value = tostring(#Data.Users()) },
			}
		end },
		{ id = "sound", icon = "🔊", name = "Sound", rows = function()
			return {
				{ type = "slider", label = "Master volume", min = 0, max = 1, step = 0.1, percent = true, binding = setting("volume") },
				{ type = "toggle", label = "Interface sounds", binding = setting("uiSounds") },
				{ type = "toggle", label = "Menu music", binding = setting("menuMusic") },
				{ type = "toggle", label = "Controller vibration", binding = setting("vibration") },
			}
		end },
		{ id = "display", icon = "🖥", name = "Screen and Theme", rows = function()
			local options = {}
			for _, b in Theme.Backgrounds do
				table.insert(options, { b.id, b.name })
			end
			return {
				{ type = "choice", label = "Home background", options = options, binding = setting("background") },
				{ type = "toggle", label = "Reduce motion", binding = setting("reduceMotion") },
				{ type = "toggle", label = "24-hour clock", binding = setting("clock24") },
				{ type = "toggle", label = "Boot animation", binding = setting("bootAnimation") },
			}
		end },
		{ id = "storage", icon = "💾", name = "Storage", rows = function()
			local rows = {}
			for _, manifest in Registry.List() do
				local keys = 0
				for _ in Data.AppSaves(manifest.id) do
					keys += 1
				end
				table.insert(rows, { type = "action", label = manifest.title, value = `entries: {keys} · delete`, run = function()
					Shell.Modal.Confirm("Delete data?", `Saves and trophies for “{manifest.title}” will be deleted.`, function()
						Data.ClearAppData(manifest.id)
						showCategory("storage")
					end, "Delete")
				end })
			end
			if #rows == 0 then
				table.insert(rows, { type = "info", label = "No apps installed", value = "" })
			end
			return rows
		end },
		{ id = "system", icon = "⚙", name = "System", rows = function()
			return {
				{ type = "info", label = "System version", value = Version },
				{ type = "info", label = "Installed apps", value = tostring(#Registry.List()) },
				{ type = "info", label = "Input device", value = Input.LastDevice },
				{ type = "action", label = "Restart", run = function()
					Shell.Power("restart")
				end },
				{ type = "action", label = "Reset to Factory Settings", danger = true, run = function()
					Shell.Modal.Confirm("Reset everything?", "Users, saves, trophies and settings will be deleted.", function()
						Data.FactoryReset()
						Shell.Power("restart")
					end, "Reset")
				end },
			}
		end },
		{ id = "dev", icon = "🛠", name = "Developer", rows = function()
			local rows = {
				{ type = "toggle", label = "Show FPS", binding = setting("showFps") },
				{ type = "action", label = "Reload app registry", run = function()
					local count = #Registry.Load()
					Shell.Toast("Registry reloaded", `Apps: {count}`)
					showCategory("dev")
				end },
			}
			for _, manifest in Registry.List() do
				table.insert(rows, { type = "info", label = manifest.title, value = `{manifest.id} · v{manifest.version} · {manifest.category}` })
			end
			return rows
		end },
	}

	local function valueText(row)
		if row.type == "toggle" then
			return row.binding.get() and "On" or "Off"
		elseif row.type == "slider" then
			local v = row.binding.get()
			return row.percent and `◀ {math.floor(v * 100 + 0.5)}% ▶` or `◀ {v} ▶`
		elseif row.type == "choice" then
			local v = row.binding.get()
			for _, o in row.options do
				if o[1] == v then
					return `◀ {o[2]} ▶`
				end
			end
			return `◀ {tostring(v)} ▶`
		end
		return row.value or ""
	end

	local function cycleChoice(row, dir)
		local v = row.binding.get()
		local index = 1
		for i, o in row.options do
			if o[1] == v then
				index = i
			end
		end
		index = (index - 1 + dir) % #row.options + 1
		row.binding.set(row.options[index][1])
	end

	function showCategory(id)
		currentCategory = id
		content:ClearAllChildren()
		Util.list(Enum.FillDirection.Vertical, 10).Parent = content
		Util.padding(10).Parent = content
		for cid, b in categoryButtons do
			b.BackgroundTransparency = cid == id and 0.1 or 0.7
		end
		local category
		for _, c in CATEGORIES do
			if c.id == id then
				category = c
			end
		end
		if not category then
			return
		end
		for i, row in category.rows() do
			local button = Util.new("TextButton", {
				Text = "",
				BackgroundColor3 = Theme.Colors.Card,
				BackgroundTransparency = row.type == "info" and 0.6 or 0.2,
				Size = UDim2.new(1, -10, 0, 66),
				LayoutOrder = i,
				Parent = content,
			}, { Util.corner(14), Util.padding(0, 22) })
			Util.text(row.label, { Size = UDim2.new(0.6, 0, 1, 0), TextSize = 21, TextColor3 = row.danger and Theme.Colors.Danger or Theme.Colors.Text, TextTruncate = Enum.TextTruncate.AtEnd, Parent = button })
			local value = Util.text(valueText(row), {
				Name = "Value", Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromScale(0.6, 0), TextSize = 19,
				TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Theme.Colors.SubText, TextTruncate = Enum.TextTruncate.AtEnd, Parent = button,
			})
			local function refresh()
				value.Text = valueText(row)
			end
			Nav.Register(button, {
				scale = 1.02,
				onActivate = function()
					if row.type == "toggle" then
						row.binding.set(not row.binding.get())
					elseif row.type == "choice" then
						cycleChoice(row, 1)
					elseif row.type == "action" then
						row.run()
					end
					refresh()
				end,
				onButton = function(btn)
					if btn ~= "left" and btn ~= "right" then
						return false
					end
					local dir = btn == "right" and 1 or -1
					if row.type == "slider" then
						local v = math.clamp(row.binding.get() + dir * row.step, row.min, row.max)
						row.binding.set(math.floor(v / row.step + 0.5) * row.step)
						refresh()
						return true
					elseif row.type == "choice" then
						cycleChoice(row, dir)
						refresh()
						return true
					end
					return false
				end,
			})
		end
	end

	local function buildCategories()
		categoriesList:ClearAllChildren()
		table.clear(categoryButtons)
		Util.list(Enum.FillDirection.Vertical, 10).Parent = categoriesList
		Util.padding(10).Parent = categoriesList
		for i, category in CATEGORIES do
			local button = Util.new("TextButton", {
				Name = category.id,
				Text = "",
				BackgroundColor3 = Theme.Colors.CardLight,
				BackgroundTransparency = 0.7,
				Size = UDim2.new(1, -10, 0, 70),
				LayoutOrder = i,
				Parent = categoriesList,
			}, { Util.corner(14) })
			Util.text(category.icon, { Size = UDim2.fromOffset(60, 70), TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Parent = button })
			Util.text(category.name, { Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(66, 0), TextSize = 22, Font = Theme.FontBold, Parent = button })
			Nav.Register(button, {
				scale = 1.03,
				onFocus = function()
					if currentCategory ~= category.id then
						showCategory(category.id)
					end
				end,
				onActivate = function()
					local first = content:FindFirstChildWhichIsA("TextButton")
					if first then
						Nav.Focus(first)
					end
				end,
			})
			categoryButtons[category.id] = button
		end
	end

	function screen.Enter(args)
		Shell.SetHints({ { "cross", "Select" }, { "circle", "Back" } })
		buildCategories()
		local startId = args and args.category or "users"
		showCategory(startId)
		layer = Nav.Push({
			root = frame,
			name = "settings",
			default = categoryButtons[startId],
			onBack = function()
				local focused = Nav.Focused()
				if focused and focused:IsDescendantOf(content) then
					Nav.Focus(categoryButtons[currentCategory])
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
