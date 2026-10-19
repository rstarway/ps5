-- Модели из Creator Store, которые сервер собирает в чиллзоне через AssetService:CreateMeshPartAsync.
-- Детали записаны относительно опоры модели (pivot); при неудаче остаются запасные детали из Blender (fallback).
-- Скриптов в моделях нет: берутся только меши, текстуры и сиденья.
return {
	{
		name = "Sofa",
		assetId = 11652583496, -- "Beige Modern Sofa" by Vyhtx21 (free)
		pivot = { 0, 3.52, 6.3 },
		fallback = "SofaFallback",
		parts = {
			{ class = "MeshPart", name = "Base", mesh = "rbxassetid://11651993548", texture = "rbxassetid://11652116316", cf = { 0, 0.249, 0.514 }, size = { 12.627, 3.994, 6.035 }, solid = true },
			{ class = "MeshPart", name = "Legs", mesh = "rbxassetid://11651993148", texture = "", cf = { -0.008, -2.095, 0.507 }, size = { 12.145, 0.774, 4.828 }, color = { 27, 42, 53 } },
			{ class = "MeshPart", name = "Sheet", mesh = "rbxassetid://11651993526", texture = "rbxassetid://11652122706", cf = { 1.897, 0.006, -0.642 }, size = { 4.246, 4.977, 5.783 } },
			{ class = "MeshPart", name = "Pillow", mesh = "rbxassetid://11651993549", texture = "rbxassetid://11652116316", cf = { 3.642, 1.04, 0.987 }, size = { 2.731, 2.227, 1.273 } },
			{ class = "MeshPart", name = "Pillow", mesh = "rbxassetid://11651993532", texture = "rbxassetid://11652116316", cf = { -2.151, 1.05, 0.972 }, size = { 2.731, 2.227, 1.273 } },
			{ class = "MeshPart", name = "Pillow", mesh = "rbxassetid://11651993499", texture = "rbxassetid://11652116316", cf = { 0.144, 0.431, -0.444 }, size = { 3.361, 0.949, 3.46 } },
			{ class = "MeshPart", name = "Pillow", mesh = "rbxassetid://11651993556", texture = "rbxassetid://11652116316", cf = { 5.372, 0.944, -0.469 }, size = { 1.668, 1.908, 2.718 } },
			{ class = "MeshPart", name = "Pillow", mesh = "rbxassetid://11651993574", texture = "rbxassetid://11652116316", cf = { -4.847, 1.018, 0.71 }, size = { 2.745, 2.132, 2.084 } },
			{ class = "Seat", name = "Seat", cf = { -4.075, -0.669, -0.78 }, size = { 1.971, 1, 2 } },
			{ class = "Seat", name = "Seat", cf = { -1.725, -0.669, -0.78 }, size = { 1.971, 1, 2 } },
			{ class = "Seat", name = "Seat", cf = { 3.485, -0.669, -0.78 }, yaw = 10, size = { 1.971, 1, 2 } },
		},
	},
}
