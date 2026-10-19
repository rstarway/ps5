-- Меню параметров приложения (кнопка OPTIONS или «•••»).
local PS5 = script.Parent.Parent
local Util = require(PS5.Util)
local Theme = require(PS5.Theme)
local Data = require(PS5.Data)
local Runtime = require(PS5.Runtime)
local Trophies = require(PS5.Trophies)

return function(Shell, manifest)
	local running = Runtime.Current()
	local items = {
		{ label = running and running.id == manifest.id and "Resume" or "Start", action = function()
			Shell.Launch(manifest.id)
		end },
		{ label = "Information", action = function()
			Shell.Modal.Open(function(panel, close)
				Util.text(manifest.title, { Size = UDim2.new(1, 0, 0, 36), TextSize = 30, Font = Theme.FontBold, Parent = panel })
				local got, total = Trophies.Progress(manifest)
				local lines = {
					`Developer: {manifest.developer}`,
					`Version: {manifest.version}`,
					`Genre: {manifest.genre or "—"}`,
					`Trophies: {got} of {total}`,
					`Last played: {Util.formatTime(Data.LastPlayed(manifest.id))}`,
					"",
					manifest.description,
				}
				if manifest.controls then
					table.insert(lines, "")
					table.insert(lines, "Controls:")
					for _, c in manifest.controls do
						table.insert(lines, `  {c[1]} — {c[2]}`)
					end
				end
				Util.text(table.concat(lines, "\n"), {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					TextWrapped = true,
					TextSize = 19,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextColor3 = Theme.Colors.SubText,
					LayoutOrder = 1,
					Parent = panel,
				})
				require(script.Parent.Components).Button("Close", { order = 2, parent = panel, onActivate = close })
			end, { width = 640 })
		end },
		{ label = "Trophies", action = function()
			Shell.GoHome()
			Shell.Go("trophies", { app = manifest.id })
		end },
		{ label = "Delete saved data", variant = "danger", action = function()
			Shell.Modal.Confirm("Delete data?", `Saves and trophies for “{manifest.title}” will be deleted for this user.`, function()
				Data.ClearAppData(manifest.id)
				Shell.Toast("Data deleted", manifest.title)
			end, "Delete")
		end },
	}
	if running and running.id == manifest.id then
		table.insert(items, 2, { label = "Close Game", action = function()
			Runtime.Close()
		end })
	end
	Shell.Modal.Menu(manifest.title, items)
end
