-- Профили игроков в чиллзоне: навёл мышь на игрока — подсветка и карточка с уровнем, клик (или тап) — профиль
-- с трофеями и наградами по играм и кнопкой «Visit Chill Zone». В гостях сверху плашка с кнопкой домой.
-- Когда своя чиллзона получает новый уровень, показывается баннер с тем, что появилось.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Util = require(script.Parent.Util)
local Theme = require(script.Parent.Theme)
local Registry = require(script.Parent.Registry)
local Embedded = require(script.Parent.Embedded)
local Audio = require(script.Parent.Audio)
local Progress = require(script.Parent.Progress)

local Profiles = {}

local player = Players.LocalPlayer
local shell, chill
local gui, root, panel, visitBar, banner
local hovered, highlight, hoverTag
local pendingTier

local GRADES = { { "bronze", "🥉" }, { "silver", "🥈" }, { "gold", "🥇" }, { "platinum", "💎" } }

local function remote(name)
	local folder = ReplicatedStorage:FindFirstChild("PS5Remotes")
	return folder and folder:FindFirstChild(name)
end

local function inWorld()
	return shell and shell.state == "standby" and not (chill and chill.IsActive())
end

local function characterOwner(part)
	local model = part and part:FindFirstAncestorWhichIsA("Model")
	while model do
		local owner = Players:GetPlayerFromCharacter(model)
		if owner then
			return owner
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

-- viewport = true для координат мыши (GetMouseLocation), false для касаний (без полосы сверху)
local function playerAt(pos, viewport)
	local camera = Workspace.CurrentCamera
	if not (camera and camera.ViewportPointToRay) then
		return nil
	end
	local ray = viewport and camera:ViewportPointToRay(pos.X, pos.Y) or camera:ScreenPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 250, params)
	local owner = hit and characterOwner(hit.Instance)
	return owner ~= player and owner or nil
end

-- ---------------------------------------------------------------- подсветка при наведении
local function clearHover()
	hovered = nil
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	if hoverTag then
		hoverTag:Destroy()
		hoverTag = nil
	end
end

local function setHover(target)
	if target == hovered then
		return
	end
	clearHover()
	local character = target and target.Character
	if not character then
		return
	end
	hovered = target
	highlight = Util.new("Highlight", {
		FillColor = Theme.Colors.AccentLight,
		FillTransparency = 0.88,
		OutlineColor = Color3.new(1, 1, 1),
		OutlineTransparency = 0.1,
		DepthMode = Enum.HighlightDepthMode.Occluded,
		Adornee = character,
		Parent = gui,
	})
	local head = character:FindFirstChild("Head") or character.PrimaryPart
	hoverTag = Util.new("BillboardGui", {
		Size = UDim2.fromOffset(250, 74),
		StudsOffset = Vector3.new(0, 3.2, 0),
		AlwaysOnTop = true,
		Adornee = head,
		Parent = gui,
	})
	local card = Util.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Colors.Panel, BackgroundTransparency = 0.12, Parent = hoverTag }, {
		Util.corner(16),
		Util.stroke(Theme.Colors.AccentLight, 1.5, 0.4),
	})
	Util.text(target.DisplayName, { Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 6), TextSize = 22, Font = Theme.FontBold, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
	local level = target:GetAttribute("PS5Tier") or 1
	Util.text(`LV {level}  ·  🏆 {target:GetAttribute("PS5Trophies") or 0}  ·  🎮 {target:GetAttribute("PS5Games") or 0}`, {
		Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 32), TextSize = 17, TextColor3 = Theme.Colors.AccentLight, TextXAlignment = Enum.TextXAlignment.Center, Parent = card,
	})
	Util.text("Click to view profile", { Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(10, 53), TextSize = 13, TextColor3 = Theme.Colors.Muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
end

-- ---------------------------------------------------------------- окно профиля
function Profiles.Close()
	if panel then
		panel:Destroy()
		panel = nil
	end
end

local function chip(text, parent, color)
	return Util.new("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), BackgroundColor3 = color or Theme.Colors.CardLight, BackgroundTransparency = 0.1, Parent = parent }, {
		Util.corner(UDim.new(0.5, 0)),
		Util.padding(0, 18),
		Util.text(text, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextSize = 20, Font = Theme.FontBold }),
	})
end

local function button(text, primary, parent, onClick)
	local b = Util.new("TextButton", {
		Text = text,
		Font = Theme.FontBold,
		TextSize = 24,
		AutoButtonColor = true,
		TextColor3 = primary and Color3.new(0, 0, 0) or Theme.Colors.Text,
		BackgroundColor3 = primary and Color3.new(1, 1, 1) or Theme.Colors.CardLight,
		Size = UDim2.fromOffset(primary and 300 or 180, 60),
		Parent = parent,
	}, { Util.corner(UDim.new(0.5, 0)) })
	b.Activated:Connect(onClick)
	return b
end

local function statTile(icon, value, label, parent, order)
	local tile = Util.new("Frame", { Size = UDim2.fromOffset(176, 104), BackgroundColor3 = Theme.Colors.Card, LayoutOrder = order, Parent = parent }, { Util.corner(18) })
	Util.text(icon .. " " .. value, { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 16), TextSize = 34, Font = Theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, Parent = tile })
	Util.text(label, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 66), TextSize = 18, TextColor3 = Theme.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Center, Parent = tile })
	return tile
end

local function gameRow(g, parent, order)
	local manifest = Registry.Get(g.id)
	local row = Util.new("Frame", { Size = UDim2.new(1, -12, 0, 76), BackgroundColor3 = Theme.Colors.Card, LayoutOrder = order, Parent = parent }, { Util.corner(16) })
	local colors = Util.appColors(manifest)
	local cover = Util.new("Frame", { Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = row }, {
		Util.corner(12),
		Util.gradient({ colors[1], colors[2] or colors[1] }, 135),
	})
	local image = Util.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop, Parent = cover })
	if not (manifest and Embedded.ApplyImage(image, manifest.cover, manifest.module)) then
		image:Destroy()
		if manifest then
			Util.appIcon(manifest, UDim2.fromScale(0.7, 0.7)).Parent = cover
			cover:FindFirstChildWhichIsA("GuiObject").Position = UDim2.fromScale(0.15, 0.15)
		end
	end
	Util.text(g.title or g.id, { Size = UDim2.new(1, -330, 0, 30), Position = UDim2.fromOffset(84, 10), TextSize = 24, Font = Theme.FontBold, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	local info = `🏆 {g.got}/{g.total}`
	if g.best then
		info ..= `   ·   Best {g.best}`
	end
	if not g.installed then
		info ..= "   ·   not installed"
	end
	Util.text(info, { Size = UDim2.new(1, -330, 0, 22), Position = UDim2.fromOffset(84, 42), TextSize = 18, TextColor3 = Theme.Colors.SubText, Parent = row })
	-- награды игры: значки полученных трофеев по рангам
	local medals = {}
	if manifest then
		for _, t in manifest.trophies do
			if g.unlocked[t.id] then
				local grade = t.grade or "bronze"
				medals[grade] = (medals[grade] or 0) + 1
			end
		end
	end
	local medalText = {}
	for _, grade in GRADES do
		if medals[grade[1]] then
			table.insert(medalText, grade[2] .. (medals[grade[1]] > 1 and "×" .. medals[grade[1]] or ""))
		end
	end
	Util.text(#medalText > 0 and table.concat(medalText, "  ") or "No trophies yet", {
		Size = UDim2.fromOffset(230, 30), Position = UDim2.new(1, -244, 0, 12), TextSize = 22,
		TextColor3 = #medalText > 0 and Theme.Colors.Text or Theme.Colors.Muted, TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
	})
	local fill = g.total > 0 and g.got / g.total or 0
	local bar = Util.new("Frame", { Size = UDim2.fromOffset(230, 8), Position = UDim2.new(1, -244, 0, 52), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, Parent = row }, { Util.corner(UDim.new(0.5, 0)) })
	Util.new("Frame", { Size = UDim2.fromScale(fill, 1), BackgroundColor3 = g.platinum and Theme.Colors.Platinum or Theme.Colors.AccentLight, Parent = bar }, { Util.corner(UDim.new(0.5, 0)) })
	return row
end

function Profiles.Open(userId)
	Profiles.Close()
	clearHover()
	local summary = chill and (userId == player.UserId and chill.OwnSummary() or chill.FetchProfile(userId))
	if not summary then
		return nil
	end
	local target = Players:GetPlayerByUserId(userId)
	panel = Util.new("TextButton", { Name = "Profile", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Parent = gui })
	panel.Activated:Connect(Profiles.Close)
	local canvas = Util.canvas(panel)
	local card = Util.new("TextButton", {
		Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(860, 820), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Theme.Colors.Panel, ClipsDescendants = true, Parent = canvas,
	}, { Util.corner(30), Util.stroke(Color3.new(1, 1, 1), 1, 0.85) })
	local tierColors = { Theme.Colors.CardLight, Color3.fromRGB(60, 120, 90), Color3.fromRGB(70, 140, 200), Color3.fromRGB(120, 70, 220), Theme.Colors.Gold, Theme.Colors.Platinum }
	local header = Util.new("Frame", { Size = UDim2.new(1, 0, 0, 230), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card }, {
		Util.gradient({ tierColors[summary.tier] or Theme.Colors.Accent, Theme.Colors.Panel }, 90),
	})
	-- аватар
	local avatar = Util.new("ImageLabel", { Size = UDim2.fromOffset(150, 150), Position = UDim2.fromOffset(40, 44), BackgroundColor3 = Theme.Colors.Card, Parent = header }, {
		Util.corner(UDim.new(0.5, 0)),
		Util.stroke(Color3.new(1, 1, 1), 3, 0.2),
	})
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and avatar.Parent then
			avatar.Image = image
		end
	end)
	Util.text(summary.displayName or "Player", { Size = UDim2.new(1, -260, 0, 56), Position = UDim2.fromOffset(220, 52), TextSize = 50, Font = Theme.FontHeavy, TextTruncate = Enum.TextTruncate.AtEnd, Parent = header })
	Util.text("@" .. (summary.name or ""), { Size = UDim2.new(1, -260, 0, 26), Position = UDim2.fromOffset(222, 108), TextSize = 22, TextColor3 = Theme.Colors.SubText, Parent = header })
	local chips = Util.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -260, 0, 40), Position = UDim2.fromOffset(220, 146), Parent = header }, { Util.list(Enum.FillDirection.Horizontal, 10) })
	chip(`🏡 Chill Zone LV {summary.tier} · {summary.tierName}`, chips, Color3.fromRGB(20, 26, 46))
	chip(`⭐ {summary.points} pts`, chips, Color3.fromRGB(20, 26, 46))
	-- до следующего уровня
	local nextText
	if summary.nextAt then
		local nextTier = Progress.TIERS[summary.tier + 1]
		nextText = `{summary.points} / {summary.nextAt} pts to LV {summary.tier + 1} · {nextTier.name}`
	else
		nextText = "Max level · Legend chill zone"
	end
	Util.text(nextText, { Size = UDim2.new(1, -80, 0, 24), Position = UDim2.fromOffset(40, 246), TextSize = 19, TextColor3 = Theme.Colors.SubText, Parent = card })
	local span = summary.nextAt and (summary.nextAt - summary.tierAt) or 1
	local value = summary.nextAt and (summary.points - summary.tierAt) / span or 1
	local bar = Util.new("Frame", { Size = UDim2.new(1, -80, 0, 10), Position = UDim2.fromOffset(40, 276), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.85, Parent = card }, { Util.corner(UDim.new(0.5, 0)) })
	Util.new("Frame", { Size = UDim2.fromScale(math.clamp(value, 0, 1), 1), BackgroundColor3 = Theme.Colors.AccentLight, Parent = bar }, { Util.corner(UDim.new(0.5, 0)) })
	-- общие цифры
	local t = summary.trophies
	local stats = Util.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -80, 0, 104), Position = UDim2.fromOffset(40, 306), Parent = card }, { Util.list(Enum.FillDirection.Horizontal, 16) })
	statTile("🏆", `{t.got}/{t.total}`, "Trophies", stats, 1)
	statTile("💎", t.platinum, "Platinum", stats, 2)
	statTile("🎮", summary.gamesOwned, "Games", stats, 3)
	statTile("🕹", summary.gamesPlayed, "Played", stats, 4)
	Util.text(`🥉 {t.bronze}     🥈 {t.silver}     🥇 {t.gold}     💎 {t.platinum}`, { Size = UDim2.new(1, -80, 0, 30), Position = UDim2.fromOffset(40, 422), TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
	-- награды по играм
	Util.text("Games and awards", { Size = UDim2.new(1, -80, 0, 28), Position = UDim2.fromOffset(40, 464), TextSize = 24, Font = Theme.FontBold, Parent = card })
	local list = Util.new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -80, 0, 220), Position = UDim2.fromOffset(40, 500),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, Parent = card,
	}, { Util.list(Enum.FillDirection.Vertical, 8) })
	for i, g in summary.games do
		gameRow(g, list, i)
	end
	if #summary.games == 0 then
		Util.text("No games yet", { TextColor3 = Theme.Colors.Muted, Parent = list })
	end
	-- кнопки
	local buttons = Util.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -80, 0, 60), Position = UDim2.new(0, 40, 1, -84), Parent = card }, {
		Util.list(Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Right),
	})
	local visiting = player:GetAttribute("VisitingZone")
	if userId ~= player.UserId and target then
		if visiting == userId then
			button("🏠 Go home", true, buttons, function()
				Profiles.Visit(nil)
			end).LayoutOrder = 1
		else
			button("🏡 Visit Chill Zone", true, buttons, function()
				Profiles.Visit(userId)
			end).LayoutOrder = 1
		end
	end
	button("Close", false, buttons, Profiles.Close).LayoutOrder = 2
	Audio.Ui("open")
	return panel
end

function Profiles.Visit(userId)
	Profiles.Close()
	local r = remote("VisitZone")
	if r then
		Audio.Ui("confirm")
		r:FireServer(userId)
	end
end

-- ---------------------------------------------------------------- плашка «в гостях»
local function updateVisitBar()
	if visitBar then
		visitBar:Destroy()
		visitBar = nil
	end
	local hostId = player:GetAttribute("VisitingZone")
	if not hostId then
		return
	end
	local host = Players:GetPlayerByUserId(hostId)
	visitBar = Util.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(0, 52), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Colors.Panel, BackgroundTransparency = 0.1, Parent = gui,
	}, { Util.corner(UDim.new(0.5, 0)), Util.padding(6, 8), Util.list(Enum.FillDirection.Horizontal, 12), Util.stroke(Color3.new(1, 1, 1), 1, 0.8) })
	local label = Util.text(`Visiting {host and host.DisplayName or "a friend"}'s Chill Zone`, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextSize = 20, Font = Theme.FontBold, LayoutOrder = 1, Parent = visitBar })
	Util.new("UIPadding", { PaddingLeft = UDim.new(0, 14), Parent = label })
	local home = Util.new("TextButton", { Text = "🏠 Go home", Font = Theme.FontBold, TextSize = 20, TextColor3 = Color3.new(0, 0, 0), BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(150, 40), LayoutOrder = 2, Parent = visitBar }, {
		Util.corner(UDim.new(0.5, 0)),
	})
	home.Activated:Connect(function()
		Profiles.Visit(nil)
	end)
end

-- ---------------------------------------------------------------- баннер нового уровня чиллзоны
function Profiles.ShowUpgrade(level)
	if banner then
		banner:Destroy()
	end
	local info = Progress.TIERS[level]
	if not info then
		return
	end
	banner = Util.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -160), Size = UDim2.fromOffset(620, 128),
		BackgroundColor3 = Theme.Colors.Panel, BackgroundTransparency = 0.05, Parent = gui,
	}, { Util.corner(26), Util.stroke(Theme.Colors.Gold, 2, 0.2) })
	Util.text("✨ CHILL ZONE UPGRADED", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 14), TextSize = 22, Font = Theme.FontHeavy, TextColor3 = Theme.Colors.Gold, TextXAlignment = Enum.TextXAlignment.Center, Parent = banner })
	Util.text(`Level {level} · {info.name}`, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 44), TextSize = 36, Font = Theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, Parent = banner })
	Util.text(info.unlocks, { Size = UDim2.new(1, -40, 0, 24), Position = UDim2.fromOffset(20, 90), TextSize = 19, TextColor3 = Theme.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Center, Parent = banner })
	Audio.Ui("trophy")
	local shown = banner
	Util.tween(shown, 0.6, { Position = UDim2.new(0.5, 0, 0, 24) }, Enum.EasingStyle.Back)
	task.delay(6, function()
		if shown.Parent then
			Util.tween(shown, 0.5, { Position = UDim2.new(0.5, 0, 0, -160) }).Completed:Connect(function()
				shown:Destroy()
			end)
		end
	end)
end

function Profiles.Start(ui, chillZone)
	shell, chill = ui, chillZone
	gui = Util.new("ScreenGui", { Name = "PlayerProfiles", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30, Parent = player:WaitForChild("PlayerGui") })

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			Profiles.Close()
			return
		end
		if processed or panel or not inWorld() then
			return
		end
		local mouse = input.UserInputType == Enum.UserInputType.MouseButton1
		local touch = input.UserInputType == Enum.UserInputType.Touch
		if mouse or touch then
			local target = mouse and hovered or playerAt(input.Position, false)
			if target then
				Profiles.Open(target.UserId)
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		if panel or not inWorld() or not UserInputService.MouseEnabled then
			if hovered then
				clearHover()
			end
		else
			setHover(playerAt(UserInputService:GetMouseLocation(), true))
		end
		if pendingTier and inWorld() then
			local level = pendingTier
			pendingTier = nil
			Profiles.ShowUpgrade(level)
		end
	end)

	player:GetAttributeChangedSignal("VisitingZone"):Connect(updateVisitBar)
	updateVisitBar()

	local lastTier = player:GetAttribute("PS5Tier")
	player:GetAttributeChangedSignal("PS5Tier"):Connect(function()
		local level = player:GetAttribute("PS5Tier")
		if lastTier and level and level > lastTier then
			pendingTier = level -- покажем, когда игрок выйдет из PS5 в чиллзону
		end
		lastTier = level
	end)
end

return Profiles
