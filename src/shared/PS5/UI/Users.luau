-- Выбор пользователя: «Кто будет играть?»
local PS5 = script.Parent.Parent
local Util = require(PS5.Util)
local Theme = require(PS5.Theme)
local Nav = require(PS5.Nav)
local Data = require(PS5.Data)
local C = require(script.Parent.Components)

return function(Shell)
	local frame = Util.new("Frame", { Name = "Users", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local screen = { frame = frame }
	local layer
	local row

	Util.text("Who's playing?", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromOffset(800, 60),
		TextSize = 46,
		Font = Theme.FontBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	row = Util.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(1, -160, 0, 240),
		BackgroundTransparency = 1,
		Parent = frame,
	})

	local function userButton(user, order)
		local button = Util.new("TextButton", {
			Name = user and user.id or "add",
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(170, 170),
			LayoutOrder = order,
			Parent = row,
		}, { Util.corner(UDim.new(0.5, 0)) })
		if user then
			C.Avatar(user, 170, button)
		else
			local plus = Util.new("Frame", {
				BackgroundColor3 = Theme.Colors.CardLight,
				BackgroundTransparency = 0.3,
				Size = UDim2.fromScale(1, 1),
				Parent = button,
			}, { Util.corner(UDim.new(0.5, 0)) })
			Util.text("+", { Size = UDim2.fromScale(1, 1), TextSize = 80, TextXAlignment = Enum.TextXAlignment.Center, Parent = plus })
		end
		Util.text(user and user.name or "Add", {
			Size = UDim2.new(1, 40, 0, 30),
			Position = UDim2.new(0, -20, 1, 16),
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = button,
		})
		return button
	end

	local function rebuild(focusId)
		row:ClearAllChildren()
		Util.list(Enum.FillDirection.Horizontal, 48, Enum.HorizontalAlignment.Center).Parent = row
		local focusEl
		for i, user in Data.Users() do
			local button = userButton(user, i)
			Nav.Register(button, {
				scale = 1.1,
				ringThickness = 5,
				onActivate = function()
					Data.SetCurrentUser(user.id)
					Shell.Toast(`Welcome, {user.name}!`, "Signed in", { icon = "👋" })
					Shell.Go("home")
				end,
				onButton = function(btn, event)
					if event == "press" and (btn == "triangle" or btn == "options") then
						Shell.Modal.Menu(user.name, {
							{ label = "Rename", action = function()
								Shell.Modal.Prompt("New name", user.name, function(name)
									Data.RenameUser(user.id, string.sub(name, 1, 24))
									rebuild(user.id)
								end)
							end },
							{ label = "Delete User", variant = "danger", action = function()
								Shell.Modal.Confirm("Delete user?", `All saves and trophies for “{user.name}” will be deleted.`, function()
									if Data.RemoveUser(user.id) then
										rebuild()
									else
										Shell.Toast("Can't delete", "At least one user must remain")
									end
								end, "Delete")
							end },
						})
						return true
					end
					return false
				end,
			})
			if user.id == focusId then
				focusEl = button
			end
		end
		if #Data.Users() < 8 then
			local add = userButton(nil, 100)
			Nav.Register(add, {
				scale = 1.1,
				ringThickness = 5,
				onActivate = function()
					local user = Data.AddUser()
					rebuild(user.id)
				end,
			})
		end
		if layer then
			layer.focused = nil
			task.defer(function()
				Nav.Focus(focusEl or row:FindFirstChildWhichIsA("TextButton"), true)
			end)
		end
	end

	function screen.Enter()
		Shell.SetHints({ { "cross", "Sign In" }, { "triangle", "Options" } })
		layer = nil
		rebuild()
		layer = Nav.Push({ root = frame, name = "users" })
	end

	function screen.Leave()
		Nav.Pop(layer)
		layer = nil
	end

	return screen
end
