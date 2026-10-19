-- Минимальная реализация сигнала (как RBXScriptSignal, но на Luau).
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handlers = self._handlers
	local entry = { fn = fn, connected = true }
	table.insert(handlers, entry)
	return {
		Disconnect = function()
			entry.connected = false
			local i = table.find(handlers, entry)
			if i then
				table.remove(handlers, i)
			end
		end,
	}
end

function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn.Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Fire(...)
	for _, entry in table.clone(self._handlers) do
		if entry.connected then
			local ok, err = pcall(entry.fn, ...)
			if not ok then
				warn("[PS5] Signal handler error:", err)
			end
		end
	end
end

function Signal:DisconnectAll()
	table.clear(self._handlers)
end

return Signal
