-- Шаблон приложения. Скопируйте папку _Template, переименуйте и уберите hidden = true.
return {
	id = "my_game", -- уникальный: латиница, цифры, _ и -
	title = "My Game",
	category = "game", -- game | media | app
	genre = "Genre",
	developer = "Your Name",
	version = "0.1",
	description = "Short description for the home screen and the store.",
	icon = "🎮",
	cover = "", -- модуль-картинка cover.luau в папке игры или "rbxassetid://..."
	art = "", -- фон главного экрана 16:9 (art.luau), рисует blender/game_art.py
	colors = { "#3A86FF", "#14213D" },
	hidden = true, -- шаблон не показывается в системе; удалите эту строку в своей игре
	controls = {
		{ "✕", "Action" },
		{ "○", "Exit" },
	},
	trophies = {
		{ id = "hello", name = "Hello, PS5", description = "Press ✕ for the first time", grade = "bronze" },
	},
}
