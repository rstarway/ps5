-- Шахматный движок: доска 0x88, все правила (рокировка, взятие на проходе, превращение, шах, мат, пат,
-- правило 50 ходов, троекратное повторение, недостаток материала) и компьютер (альфа-бета + quiescence).
-- Ход — число: from + to*128 + promo*16384 + flag*131072 (flag: 1 на проходе, 2 рокировка, 3 ход пешки на 2).
local Engine = {}

local band, bxor = bit32.band, bit32.bxor
local floor, abs = math.floor, math.abs

local PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING = 1, 2, 3, 4, 5, 6
Engine.PAWN, Engine.KNIGHT, Engine.BISHOP, Engine.ROOK, Engine.QUEEN, Engine.KING = PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING
Engine.START = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

local VALUE = { 100, 320, 330, 500, 900, 20000 }
local KNIGHT_D = { 33, 31, 18, 14, -33, -31, -18, -14 }
local KING_D = { 1, -1, 16, -16, 15, 17, -15, -17 }
local ROOK_D = { 1, -1, 16, -16 }
local BISHOP_D = { 15, 17, -15, -17 }
local LETTER = { "p", "n", "b", "r", "q", "k" }
local FROM_LETTER = { p = PAWN, n = KNIGHT, b = BISHOP, r = ROOK, q = QUEEN, k = KING }

-- права рокировки: 1 белые O-O, 2 белые O-O-O, 4 чёрные O-O, 8 чёрные O-O-O
local CASTLE_MASK = table.create(128, 15)
CASTLE_MASK[0] = 15
CASTLE_MASK[4], CASTLE_MASK[0], CASTLE_MASK[7] = 12, 13, 14
CASTLE_MASK[116], CASTLE_MASK[112], CASTLE_MASK[119] = 3, 7, 11

-- Зобрист-ключи для повторений (детерминированный генератор, 32 бита)
local seed = 20261019
local function rand16()
	seed = (seed * 16807) % 2147483647
	return seed % 65536
end
local function rand32()
	return rand16() * 65536 + rand16()
end
local ZP = {}
for p = -6, 6 do
	ZP[p] = {}
	for sq = 0, 127 do
		ZP[p][sq] = p == 0 and 0 or rand32()
	end
end
local ZSIDE = rand32()
local ZCASTLE, ZEP = {}, {}
for i = 0, 15 do
	ZCASTLE[i] = rand32()
end
for sq = -1, 127 do
	ZEP[sq] = sq < 0 and 0 or rand32()
end

-- оценки клеток (с точки зрения белых, строка 8 сверху)
local PST = {
	[PAWN] = {
		0, 0, 0, 0, 0, 0, 0, 0,
		50, 50, 50, 50, 50, 50, 50, 50,
		10, 10, 20, 30, 30, 20, 10, 10,
		5, 5, 10, 25, 25, 10, 5, 5,
		0, 0, 0, 20, 20, 0, 0, 0,
		5, -5, -10, 0, 0, -10, -5, 5,
		5, 10, 10, -20, -20, 10, 10, 5,
		0, 0, 0, 0, 0, 0, 0, 0,
	},
	[KNIGHT] = {
		-50, -40, -30, -30, -30, -30, -40, -50,
		-40, -20, 0, 0, 0, 0, -20, -40,
		-30, 0, 10, 15, 15, 10, 0, -30,
		-30, 5, 15, 20, 20, 15, 5, -30,
		-30, 0, 15, 20, 20, 15, 0, -30,
		-30, 5, 10, 15, 15, 10, 5, -30,
		-40, -20, 0, 5, 5, 0, -20, -40,
		-50, -40, -30, -30, -30, -30, -40, -50,
	},
	[BISHOP] = {
		-20, -10, -10, -10, -10, -10, -10, -20,
		-10, 0, 0, 0, 0, 0, 0, -10,
		-10, 0, 5, 10, 10, 5, 0, -10,
		-10, 5, 5, 10, 10, 5, 5, -10,
		-10, 0, 10, 10, 10, 10, 0, -10,
		-10, 10, 10, 10, 10, 10, 10, -10,
		-10, 5, 0, 0, 0, 0, 5, -10,
		-20, -10, -10, -10, -10, -10, -10, -20,
	},
	[ROOK] = {
		0, 0, 0, 0, 0, 0, 0, 0,
		5, 10, 10, 10, 10, 10, 10, 5,
		-5, 0, 0, 0, 0, 0, 0, -5,
		-5, 0, 0, 0, 0, 0, 0, -5,
		-5, 0, 0, 0, 0, 0, 0, -5,
		-5, 0, 0, 0, 0, 0, 0, -5,
		-5, 0, 0, 0, 0, 0, 0, -5,
		0, 0, 0, 5, 5, 0, 0, 0,
	},
	[QUEEN] = {
		-20, -10, -10, -5, -5, -10, -10, -20,
		-10, 0, 0, 0, 0, 0, 0, -10,
		-10, 0, 5, 5, 5, 5, 0, -10,
		-5, 0, 5, 5, 5, 5, 0, -5,
		0, 0, 5, 5, 5, 5, 0, -5,
		-10, 5, 5, 5, 5, 5, 0, -10,
		-10, 0, 5, 0, 0, 0, 0, -10,
		-20, -10, -10, -5, -5, -10, -10, -20,
	},
	[KING] = {
		-30, -40, -40, -50, -50, -40, -40, -30,
		-30, -40, -40, -50, -50, -40, -40, -30,
		-30, -40, -40, -50, -50, -40, -40, -30,
		-30, -40, -40, -50, -50, -40, -40, -30,
		-20, -30, -30, -40, -40, -30, -30, -20,
		-10, -20, -20, -20, -20, -20, -20, -10,
		20, 20, 0, 0, 0, 0, 20, 20,
		20, 30, 10, 0, 0, 10, 30, 20,
	},
}
local KING_END = {
	-50, -40, -30, -20, -20, -30, -40, -50,
	-30, -20, -10, 0, 0, -10, -20, -30,
	-30, -10, 20, 30, 30, 20, -10, -30,
	-30, -10, 30, 40, 40, 30, -10, -30,
	-30, -10, 30, 40, 40, 30, -10, -30,
	-30, -10, 20, 30, 30, 20, -10, -30,
	-30, -30, 0, 0, 0, 0, -30, -30,
	-50, -30, -30, -30, -30, -30, -30, -50,
}

local function encode(from, to, promo, flag)
	return from + to * 128 + promo * 16384 + flag * 131072
end
local function decode(m)
	return m % 128, floor(m / 128) % 128, floor(m / 16384) % 8, floor(m / 131072)
end
Engine.encode, Engine.decode = encode, decode

function Engine.square(file, rank) -- file, rank 0..7
	return rank * 16 + file
end
function Engine.fileRank(sq)
	return sq % 16, floor(sq / 16)
end
local function sqName(sq)
	return string.char(97 + sq % 16) .. tostring(floor(sq / 16) + 1)
end
Engine.squareName = sqName

local Pos = {}
Pos.__index = Pos

function Engine.new(fen)
	local self = setmetatable({}, Pos)
	self:load(fen or Engine.START)
	return self
end

function Pos:load(fen)
	local parts = string.split(fen, " ")
	local board = table.create(128, 0)
	board[0] = 0
	local rank, file = 7, 0
	for i = 1, #parts[1] do
		local c = string.sub(parts[1], i, i)
		if c == "/" then
			rank -= 1
			file = 0
		elseif tonumber(c) then
			file += tonumber(c)
		else
			local t = FROM_LETTER[string.lower(c)]
			local sq = rank * 16 + file
			board[sq] = c == string.upper(c) and t or -t
			if t == KING then
				if board[sq] > 0 then
					self.wk = sq
				else
					self.bk = sq
				end
			end
			file += 1
		end
	end
	self.board = board
	self.side = parts[2] == "b" and -1 or 1
	local castle = 0
	local c = parts[3] or "-"
	if string.find(c, "K", 1, true) then castle += 1 end
	if string.find(c, "Q", 1, true) then castle += 2 end
	if string.find(c, "k", 1, true) then castle += 4 end
	if string.find(c, "q", 1, true) then castle += 8 end
	self.castle = castle
	local ep = parts[4] or "-"
	self.ep = ep ~= "-" and (tonumber(string.sub(ep, 2, 2)) - 1) * 16 + (string.byte(ep, 1) - 97) or -1
	self.half = tonumber(parts[5] or "0") or 0
	self.full = tonumber(parts[6] or "1") or 1
	self.n = 0
	self.uM, self.uCap, self.uCastle, self.uEp, self.uHalf, self.uHash = {}, {}, {}, {}, {}, {}
	self.hash = self:computeHash()
	self.hist = { self.hash }
end

function Pos:computeHash()
	local h = 0
	for sq = 0, 119 do
		if band(sq, 0x88) == 0 and self.board[sq] ~= 0 then
			h = bxor(h, ZP[self.board[sq]][sq])
		end
	end
	if self.side < 0 then h = bxor(h, ZSIDE) end
	return bxor(h, ZCASTLE[self.castle], ZEP[self.ep])
end

function Pos:fen()
	local rows = {}
	for rank = 7, 0, -1 do
		local row, empty = "", 0
		for file = 0, 7 do
			local p = self.board[rank * 16 + file]
			if p == 0 then
				empty += 1
			else
				if empty > 0 then row ..= empty; empty = 0 end
				row ..= p > 0 and string.upper(LETTER[p]) or LETTER[-p]
			end
		end
		if empty > 0 then row ..= empty end
		table.insert(rows, row)
	end
	local c = ""
	if band(self.castle, 1) ~= 0 then c ..= "K" end
	if band(self.castle, 2) ~= 0 then c ..= "Q" end
	if band(self.castle, 4) ~= 0 then c ..= "k" end
	if band(self.castle, 8) ~= 0 then c ..= "q" end
	return `{table.concat(rows, "/")} {self.side > 0 and "w" or "b"} {c == "" and "-" or c} {self.ep >= 0 and sqName(self.ep) or "-"} {self.half} {self.full}`
end

-- атакована ли клетка sq стороной by (1 белые, -1 чёрные)
function Pos:attacked(sq, by)
	local board = self.board
	local t = sq - 15 * by
	if band(t, 0x88) == 0 and board[t] == by then return true end
	t = sq - 17 * by
	if band(t, 0x88) == 0 and board[t] == by then return true end
	local knight, king = KNIGHT * by, KING * by
	for i = 1, 8 do
		t = sq + KNIGHT_D[i]
		if band(t, 0x88) == 0 and board[t] == knight then return true end
		t = sq + KING_D[i]
		if band(t, 0x88) == 0 and board[t] == king then return true end
	end
	local queen, rook, bishop = QUEEN * by, ROOK * by, BISHOP * by
	for i = 1, 4 do
		local d = ROOK_D[i]
		t = sq + d
		while band(t, 0x88) == 0 do
			local p = board[t]
			if p ~= 0 then
				if p == rook or p == queen then return true end
				break
			end
			t += d
		end
		d = BISHOP_D[i]
		t = sq + d
		while band(t, 0x88) == 0 do
			local p = board[t]
			if p ~= 0 then
				if p == bishop or p == queen then return true end
				break
			end
			t += d
		end
	end
	return false
end

function Pos:inCheck(side)
	side = side or self.side
	return self:attacked(side > 0 and self.wk or self.bk, -side)
end

local function addPawn(list, from, to, promoRank, flag)
	if floor(to / 16) == promoRank then
		for promo = QUEEN, KNIGHT, -1 do
			list[#list + 1] = encode(from, to, promo, 0)
		end
	else
		list[#list + 1] = encode(from, to, 0, flag)
	end
end

-- псевдолегальные ходы (без проверки шаха своему королю); capturesOnly — только взятия и превращения
function Pos:pseudo(list, capturesOnly)
	local board, side = self.board, self.side
	for sq = 0, 119 do
		local p = board[sq]
		if band(sq, 0x88) == 0 and p * side > 0 then
			local kind = p * side
			if kind == PAWN then
				local dir = 16 * side
				local promoRank = side > 0 and 7 or 0
				local one = sq + dir
				if board[one] == 0 and (not capturesOnly or floor(one / 16) == promoRank) then
					addPawn(list, sq, one, promoRank, 0)
					local startRank = side > 0 and 1 or 6
					if floor(sq / 16) == startRank and board[one + dir] == 0 and not capturesOnly then
						list[#list + 1] = encode(sq, one + dir, 0, 3)
					end
				end
				for _, t in { one - 1, one + 1 } do
					if band(t, 0x88) == 0 then
						if board[t] * side < 0 then
							addPawn(list, sq, t, promoRank, 0)
						elseif t == self.ep then
							list[#list + 1] = encode(sq, t, 0, 1)
						end
					end
				end
			elseif kind == KNIGHT or kind == KING then
				local dirs = kind == KNIGHT and KNIGHT_D or KING_D
				for i = 1, 8 do
					local t = sq + dirs[i]
					if band(t, 0x88) == 0 then
						local q = board[t]
						if q * side < 0 or (q == 0 and not capturesOnly) then
							list[#list + 1] = encode(sq, t, 0, 0)
						end
					end
				end
				if kind == KING and not capturesOnly then
					local home = side > 0 and 4 or 116
					local ks, qs = side > 0 and 1 or 4, side > 0 and 2 or 8
					if sq == home and band(self.castle, ks + qs) ~= 0 and not self:attacked(home, -side) then
						if band(self.castle, ks) ~= 0 and board[home + 1] == 0 and board[home + 2] == 0
							and board[home + 3] == ROOK * side
							and not self:attacked(home + 1, -side) and not self:attacked(home + 2, -side) then
							list[#list + 1] = encode(sq, home + 2, 0, 2)
						end
						if band(self.castle, qs) ~= 0 and board[home - 1] == 0 and board[home - 2] == 0 and board[home - 3] == 0
							and board[home - 4] == ROOK * side
							and not self:attacked(home - 1, -side) and not self:attacked(home - 2, -side) then
							list[#list + 1] = encode(sq, home - 2, 0, 2)
						end
					end
				end
			else
				local dirs = kind == ROOK and ROOK_D or kind == BISHOP and BISHOP_D or KING_D
				for i = 1, #dirs do
					local d = dirs[i]
					local t = sq + d
					while band(t, 0x88) == 0 do
						local q = board[t]
						if q == 0 then
							if not capturesOnly then
								list[#list + 1] = encode(sq, t, 0, 0)
							end
						else
							if q * side < 0 then
								list[#list + 1] = encode(sq, t, 0, 0)
							end
							break
						end
						t += d
					end
				end
			end
		end
	end
	return list
end

-- делает ход; возвращает false (и откатывает), если свой король остался под шахом
function Pos:make(m)
	local from, to, promo, flag = decode(m)
	local board, side = self.board, self.side
	local p = board[from]
	local cap = board[to]
	local n = self.n + 1
	self.n = n
	self.uM[n], self.uCastle[n], self.uEp[n], self.uHalf[n], self.uHash[n] = m, self.castle, self.ep, self.half, self.hash
	local h = bxor(self.hash, ZP[p][from], ZCASTLE[self.castle], ZEP[self.ep], ZSIDE)
	board[from] = 0
	if cap ~= 0 then
		h = bxor(h, ZP[cap][to])
	end
	if flag == 1 then
		local capSq = to - 16 * side
		cap = board[capSq]
		board[capSq] = 0
		h = bxor(h, ZP[cap][capSq])
	elseif flag == 2 then
		local rFrom, rTo
		if to % 16 == 6 then
			rFrom, rTo = to + 1, to - 1
		else
			rFrom, rTo = to - 2, to + 1
		end
		local rook = board[rFrom]
		board[rTo], board[rFrom] = rook, 0
		h = bxor(h, ZP[rook][rFrom], ZP[rook][rTo])
	end
	local placed = promo > 0 and promo * side or p
	board[to] = placed
	h = bxor(h, ZP[placed][to])
	self.uCap[n] = cap
	if p == KING then
		self.wk = to
	elseif p == -KING then
		self.bk = to
	end
	self.castle = band(self.castle, CASTLE_MASK[from], CASTLE_MASK[to])
	self.ep = flag == 3 and (from + to) / 2 or -1
	self.half = (cap ~= 0 or p * side == PAWN) and 0 or self.half + 1
	if side < 0 then
		self.full += 1
	end
	self.side = -side
	self.hash = bxor(h, ZCASTLE[self.castle], ZEP[self.ep])
	self.hist[n + 1] = self.hash
	if self:attacked(side > 0 and self.wk or self.bk, -side) then
		self:unmake()
		return false
	end
	return true
end

function Pos:unmake()
	local n = self.n
	local m = self.uM[n]
	local from, to, promo, flag = decode(m)
	local board = self.board
	local side = -self.side
	local p = board[to]
	if promo > 0 then
		p = PAWN * side
	end
	board[from] = p
	board[to] = 0
	local cap = self.uCap[n]
	if flag == 1 then
		board[to - 16 * side] = cap
	else
		board[to] = cap
	end
	if flag == 2 then
		local rFrom, rTo
		if to % 16 == 6 then
			rFrom, rTo = to + 1, to - 1
		else
			rFrom, rTo = to - 2, to + 1
		end
		board[rFrom], board[rTo] = board[rTo], 0
	end
	if p == KING then
		self.wk = from
	elseif p == -KING then
		self.bk = from
	end
	self.side = side
	if side < 0 then
		self.full -= 1
	end
	self.castle, self.ep, self.half, self.hash = self.uCastle[n], self.uEp[n], self.uHalf[n], self.uHash[n]
	self.hist[n + 1] = nil
	self.n = n - 1
end

function Pos:legalMoves()
	local out = {}
	for _, m in self:pseudo({}) do
		if self:make(m) then
			self:unmake()
			out[#out + 1] = m
		end
	end
	return out
end

function Pos:hasLegal()
	for _, m in self:pseudo({}) do
		if self:make(m) then
			self:unmake()
			return true
		end
	end
	return false
end

function Pos:repetitions()
	local count, n = 1, self.n
	local i = n + 1 - 2
	while i >= 1 and i >= n + 1 - self.half do
		if self.hist[i] == self.hash then
			count += 1
		end
		i -= 2
	end
	return count
end

function Pos:insufficient()
	local minors, other = 0, 0
	local bishopColors = {}
	for sq = 0, 119 do
		local p = band(sq, 0x88) == 0 and abs(self.board[sq]) or 0
		if p == KNIGHT then
			minors += 1
		elseif p == BISHOP then
			minors += 1
			bishopColors[(sq % 16 + floor(sq / 16)) % 2] = true
		elseif p ~= 0 and p ~= KING then
			other += 1
		end
	end
	if other > 0 then return false end
	if minors <= 1 then return true end
	-- только слоны одного цвета полей
	local onlyBishops = true
	for sq = 0, 119 do
		if band(sq, 0x88) == 0 and abs(self.board[sq]) == KNIGHT then onlyBishops = false end
	end
	return onlyBishops and not (bishopColors[0] and bishopColors[1])
end

-- "play" | "checkmate" | "stalemate" | "fifty" | "repetition" | "material"
function Pos:status()
	if not self:hasLegal() then
		return self:inCheck() and "checkmate" or "stalemate"
	end
	if self.half >= 100 then return "fifty" end
	if self:repetitions() >= 3 then return "repetition" end
	if self:insufficient() then return "material" end
	return "play"
end

function Engine.uci(m)
	local from, to, promo = decode(m)
	return sqName(from) .. sqName(to) .. (promo > 0 and LETTER[promo] or "")
end

function Pos:fromUci(text)
	for _, m in self:legalMoves() do
		if Engine.uci(m) == text then
			return m
		end
	end
	return nil
end

-- запись хода (SAN) до того, как он сделан
function Pos:san(m)
	local from, to, promo, flag = decode(m)
	local kind = abs(self.board[from])
	local s
	if flag == 2 then
		s = to % 16 == 6 and "O-O" or "O-O-O"
	else
		local capture = self.board[to] ~= 0 or flag == 1
		if kind == PAWN then
			s = (capture and string.char(97 + from % 16) .. "x" or "") .. sqName(to)
			if promo > 0 then
				s ..= "=" .. string.upper(LETTER[promo])
			end
		else
			local sameFile, sameRank, other = false, false, false
			for _, o in self:legalMoves() do
				local of, ot = decode(o)
				if ot == to and of ~= from and abs(self.board[of]) == kind then
					other = true
					if of % 16 == from % 16 then sameFile = true end
					if floor(of / 16) == floor(from / 16) then sameRank = true end
				end
			end
			local dis = ""
			if other then
				if not sameFile then
					dis = string.char(97 + from % 16)
				elseif not sameRank then
					dis = tostring(floor(from / 16) + 1)
				else
					dis = sqName(from)
				end
			end
			s = string.upper(LETTER[kind]) .. dis .. (capture and "x" or "") .. sqName(to)
		end
	end
	if self:make(m) then
		if self:inCheck() then
			s ..= self:hasLegal() and "+" or "#"
		end
		self:unmake()
	end
	return s
end

function Pos:perft(depth)
	if depth == 0 then return 1 end
	local total = 0
	for _, m in self:pseudo({}) do
		if self:make(m) then
			total += self:perft(depth - 1)
			self:unmake()
		end
	end
	return total
end

-- ===== Компьютер =====

function Pos:evaluate()
	local board = self.board
	local score, material = 0, 0
	for sq = 0, 119 do
		local p = band(sq, 0x88) == 0 and board[sq] or 0
		if p ~= 0 and abs(p) ~= KING and abs(p) ~= PAWN then
			material += VALUE[abs(p)]
		end
	end
	local endgame = material <= 2600
	for sq = 0, 119 do
		local p = band(sq, 0x88) == 0 and board[sq] or 0
		if p ~= 0 then
			local f, r = sq % 16, floor(sq / 16)
			local kind = abs(p)
			local idx = p > 0 and (7 - r) * 8 + f + 1 or r * 8 + f + 1
			local table_ = (kind == KING and endgame) and KING_END or PST[kind]
			local v = (kind == KING and 0 or VALUE[kind]) + table_[idx]
			score += p > 0 and v or -v
		end
	end
	return score * self.side
end

local MATE = 100000

local function orderMoves(pos, list, best)
	local board = pos.board
	local scores = table.create(#list, 0)
	for i, m in list do
		if m == best then
			scores[i] = 1e9
		else
			local from, to, promo = decode(m)
			local victim = abs(board[to])
			local s = 0
			if victim > 0 then
				s = 10000 + VALUE[victim] * 10 - VALUE[abs(board[from])] / 10
			end
			if promo > 0 then
				s += 8000 + VALUE[promo]
			end
			scores[i] = s
		end
	end
	return scores
end

-- выбирает следующий по порядку ход (частичная сортировка выбором)
local function pick(list, scores, i)
	local best = i
	for j = i + 1, #list do
		if scores[j] > scores[best] then
			best = j
		end
	end
	list[i], list[best] = list[best], list[i]
	scores[i], scores[best] = scores[best], scores[i]
	return list[i]
end

-- opts: { depth, time, clock = fn() -> секунды, yield = fn(), noise = число (разброс оценки хода), random = fn(a,b) }
function Engine.search(pos, opts)
	local clock = opts.clock or os.clock
	local deadline = clock() + (opts.time or 1)
	local nodes, stopped = 0, false
	local yield = opts.yield

	local function tick()
		nodes += 1
		if nodes % 1024 == 0 then
			if yield then yield() end
			if clock() > deadline or (opts.cancel and opts.cancel()) then
				stopped = true
			end
		end
	end

	local function quiesce(alpha, beta, ply)
		tick()
		local stand = pos:evaluate()
		if stand >= beta then return stand end
		if stand > alpha then alpha = stand end
		if ply > 12 or stopped then return stand end
		local list = pos:pseudo({}, true)
		local scores = orderMoves(pos, list, nil)
		for i = 1, #list do
			local m = pick(list, scores, i)
			if pos:make(m) then
				local score = -quiesce(-beta, -alpha, ply + 1)
				pos:unmake()
				if score >= beta then return score end
				if score > alpha then alpha = score end
			end
		end
		return alpha
	end

	local function negamax(depth, alpha, beta, ply)
		tick()
		if stopped then return 0 end
		if ply > 0 and (pos.half >= 100 or pos:repetitions() >= 2) then
			return 0
		end
		local check = pos:inCheck()
		if check then depth += 1 end
		if depth <= 0 then
			return quiesce(alpha, beta, ply)
		end
		local list = pos:pseudo({})
		local scores = orderMoves(pos, list, nil)
		local legal = 0
		local best = -MATE * 2
		for i = 1, #list do
			local m = pick(list, scores, i)
			if pos:make(m) then
				legal += 1
				local score = -negamax(depth - 1, -beta, -alpha, ply + 1)
				pos:unmake()
				if stopped then return 0 end
				if score > best then best = score end
				if score > alpha then alpha = score end
				if alpha >= beta then break end
			end
		end
		if legal == 0 then
			return check and -(MATE - ply) or 0
		end
		return best
	end

	local root = pos:legalMoves()
	if #root == 0 then return nil end
	if #root == 1 then return root[1] end
	local random = opts.random or math.random
	local noise = {}
	for _, m in root do
		noise[m] = (opts.noise or 0) > 0 and random(-opts.noise, opts.noise) or 0
	end
	local bestMove = root[1]
	local maxDepth = opts.depth or 4
	for depth = 1, maxDepth do
		local scores = orderMoves(pos, root, bestMove)
		local alpha, iterBest = -MATE * 2, nil
		for i = 1, #root do
			local m = pick(root, scores, i)
			pos:make(m)
			local score = -negamax(depth - 1, -MATE * 2, -(alpha - 2 * (opts.noise or 0)), 1) + noise[m]
			pos:unmake()
			if stopped then break end
			if score > alpha then
				alpha, iterBest = score, m
			end
		end
		if iterBest and not stopped then
			bestMove = iterBest
		elseif iterBest and depth > 1 then
			bestMove = iterBest -- лучший ход недосчитанной итерации тоже годится: он был первым в порядке
		end
		if stopped or alpha >= MATE - 100 then break end
	end
	return bestMove, nodes
end

return Engine
