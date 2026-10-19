-- Шаблон: 2D-интерфейс в ctx.gui + 3D-объект в ctx.world, счётчик в сохранениях и трофей.
local Template = {}

function Template.launch(ctx)
	local ui = ctx.ui

	-- 3D: вращающийся куб перед камерой
	local cube = Instance.new("Part")
	cube.Anchored = true
	cube.Size = Vector3.new(4, 4, 4)
	cube.Color = Color3.fromRGB(58, 134, 255)
	cube.Material = Enum.Material.Neon
	cube.Position = Vector3.new(0, 105, 0)
	cube.Parent = ctx.world
	ctx.camera.CameraType = Enum.CameraType.Scriptable
	ctx.camera.CFrame = CFrame.lookAt(Vector3.new(0, 107, 14), cube.Position)

	-- 2D: прозрачный фон, чтобы был виден 3D-мир
	ctx.gui.BackgroundTransparency = 1
	local canvas = ui.canvas(ctx.gui)
	local label = ui.text("", {
		Size = UDim2.fromOffset(1920, 200),
		Position = UDim2.fromOffset(0, 760),
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = canvas,
	})

	local count = ctx.save:Get("count", 0)
	local function render()
		label.Text = `Hello, {ctx.user.name}!\n✕ pressed: {count}   ({ctx.input:Glyph("circle")} — quit)`
	end
	render()

	ctx.input:On("press", function(btn)
		if btn == "cross" then
			count += 1
			ctx.save:Set("count", count)
			ctx.trophies:Unlock("hello")
			ctx.audio:Play("confirm")
			render()
		elseif btn == "circle" then
			ctx:Exit()
		end
	end)

	ctx:Loop(function(dt)
		cube.CFrame = cube.CFrame * CFrame.Angles(dt, dt * 0.7, 0)
	end)

	ctx:On("exit", function()
		-- ctx.world, ctx.gui, подписки и звуки очищаются системой; здесь — своё
	end)
end

return Template
