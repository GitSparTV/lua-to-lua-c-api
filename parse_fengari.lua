local SIZE_C = 9
local SIZE_B = 9
local SIZE_Bx = (SIZE_C + SIZE_B)
local SIZE_A = 8
local SIZE_Ax = (SIZE_C + SIZE_B + SIZE_A)
local SIZE_OP = 6
local POS_OP = 0
local POS_A = (POS_OP + SIZE_OP)
local POS_C = (POS_A + SIZE_A)
local POS_B = (POS_C + SIZE_C)
local POS_Bx = POS_C
local POS_Ax = POS_A
local MAXARG_Bx = ((1 << SIZE_Bx) - 1)
local MAXARG_sBx = (MAXARG_Bx >> 1)
local MAXARG_Ax = ((1 << SIZE_Ax) - 1)
local MAXARG_A = ((1 << SIZE_A) - 1)
local MAXARG_B = ((1 << SIZE_B) - 1)
local MAXARG_C = ((1 << SIZE_C) - 1)

local LUA_TNONE = -1
local LUA_TNIL = 0
local LUA_TBOOLEAN = 1
local LUA_TLIGHTUSERDATA = 2
local LUA_TNUMBER = 3
local LUA_TSTRING = 4
local LUA_TTABLE = 5
local LUA_TFUNCTION = 6
local LUA_TUSERDATA = 7
local LUA_TTHREAD = 8
local LUA_NUMTAGS = 9
local LUA_TSHRSTR = LUA_TSTRING | (0 << 4)
local LUA_TLNGSTR = LUA_TSTRING | (1 << 4)
local LUA_TNUMFLT = LUA_TNUMBER | (0 << 4)
local LUA_TNUMINT = LUA_TNUMBER | (1 << 4)
local LUA_TLCL = LUA_TFUNCTION | (0 << 4)
local LUA_TLCF = LUA_TFUNCTION | (1 << 4)
local LUA_TCCL = LUA_TFUNCTION | (2 << 4)

local OpCodes = {[0] = "MOVE", "LOADK", "LOADKX", "LOADBOOL", "LOADNIL", "GETUPVAL", "GETTABUP", "GETTABLE", "SETTABUP", "SETUPVAL", "SETTABLE", "NEWTABLE", "SELF", "ADD", "SUB", "MUL", "MOD", "POW", "DIV", "IDIV", "BAND", "BOR", "BXOR", "SHL", "SHR", "UNM", "BNOT", "NOT", "LEN", "CONCAT", "JMP", "EQ", "LT", "LE", "TEST", "TESTSET", "CALL", "TAILCALL", "RETURN", "FORLOOP", "FORPREP", "TFORCALL", "TFORLOOP", "SETLIST", "CLOSURE", "VARARG", "EXTRAARG"}

local OpCodesI = {
	OP_MOVE = 0,
	OP_LOADK = 1,
	OP_LOADKX = 2,
	OP_LOADBOOL = 3,
	OP_LOADNIL = 4,
	OP_GETUPVAL = 5,
	OP_GETTABUP = 6,
	OP_GETTABLE = 7,
	OP_SETTABUP = 8,
	OP_SETUPVAL = 9,
	OP_SETTABLE = 10,
	OP_NEWTABLE = 11,
	OP_SELF = 12,
	OP_ADD = 13,
	OP_SUB = 14,
	OP_MUL = 15,
	OP_MOD = 16,
	OP_POW = 17,
	OP_DIV = 18,
	OP_IDIV = 19,
	OP_BAND = 20,
	OP_BOR = 21,
	OP_BXOR = 22,
	OP_SHL = 23,
	OP_SHR = 24,
	OP_UNM = 25,
	OP_BNOT = 26,
	OP_NOT = 27,
	OP_LEN = 28,
	OP_CONCAT = 29,
	OP_JMP = 30,
	OP_EQ = 31,
	OP_LT = 32,
	OP_LE = 33,
	OP_TEST = 34,
	OP_TESTSET = 35,
	OP_CALL = 36,
	OP_TAILCALL = 37,
	OP_RETURN = 38,
	OP_FORLOOP = 39,
	OP_FORPREP = 40,
	OP_TFORCALL = 41,
	OP_TFORLOOP = 42,
	OP_SETLIST = 43,
	OP_CLOSURE = 44,
	OP_VARARG = 45,
	OP_EXTRAARG = 46
}

local iABC  = 0
local iABx  = 1
local iAsBx = 2
local iAx   = 3

local luaP_opmodes = {
    [0] = iABC,
	iABx,
	iABx,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iAsBx,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iABC,
	iAsBx,
	iAsBx,
	iABC,
	iAsBx,
	iABC,
	iABx,
	iABC,
	iAx  
}

local function getOpMode(m)
    return luaP_opmodes[m] & 3
end

local BITRK = (1 << (SIZE_B - 1))

local function ISK(x)
    return (x & BITRK) ~= 0
end

local function INDEXK(r)
    return r & ~BITRK
end

local function MASK1(n, p)
	return ((~((~0) << (n))) << (p))
end

local function MASK0(n, p)
    return (~MASK1(n, p))
end

local function sanitizeString(val)
	if string.find(val, "[%G\n\r\"\\\a\b\f\r\v]") then
		local sanitized = {}

		for k = 1, #val do
			local char = string.sub(val, k, k)

			if char == "\n" then
				sanitized[k] = "\\n"
			elseif char == "\t" then
				sanitized[k] = "\\r"
			elseif char == "\"" then
				sanitized[k] = "\\\""
			elseif char == "\\" then
				sanitized[k] = "\\\\"
			elseif char == "\a" then
				sanitized[k] = "\\a"
			elseif char == "\b" then
				sanitized[k] = "\\b"
			elseif char == "\f" then
				sanitized[k] = "\\f"
			elseif char == "\r" then
				sanitized[k] = "\\r"
			elseif char == "\v" then
				sanitized[k] = "\\v"
			else
				if string.find(char, "[%g%s]") then
					sanitized[k] = char
				else
					sanitized[k] = string.format("\\x%X", string.byte(char))
				end
			end
		end

		val = table.concat(sanitized)
	end

	return val
end

local function emitconstant(val)
	local t = type(val)

	if t == "nil" then
		return "lua_pushnil(L);"
	elseif t == "number" then
		if math.type(val) == "integer" then
			return "lua_pushinteger(L, " .. val .. ");"
		else
			return "lua_pushnumber(L, " .. val .. ");"
		end
	elseif t == "string" then
		local has_zero = string.find(val, "\0", 1, true)
		local real_len = #val
		val = sanitizeString(val)

		if has_zero then
			return "lua_pushlstring(L, \"" .. val .. "\", " .. real_len .. ");"
		else
			return "lua_pushstring(L, \"" .. val .. "\");"
		end
	elseif t == "boolean" then
		return "lua_pushboolean(L, " .. (val and 1 or 0) .. ");"
	end

	return "invalid_type = " .. t
end

local function emitvalue(proto, val)
	if ISK(val) then
		return emitconstant(proto.constants[INDEXK(val) + 1][2])
	else
		return "lua_pushvalue(L, " .. val .. ");"
	end
end

local function luaO_fb2int(x)
	return (x < 8) and x or ((x & 7) + 8) << ((x >> 3) - 1);
end

local CAPI

CAPI = {
	[0] = function(pc, proto, A, B, C) return "lua_pushvalue(L, " .. B .. ");" end; -- OP_MOVE
	function(pc, proto, A, Bx)
		local const = proto.constants[Bx + 1]
		local val = const[2]

		return emitconstant(val)
	end;
	-- OP_LOADK
	function(pc, proto, A, Bx) return CAPI[OpCodesI.OP_LOADK](pc, proto, A, Bx) end; -- OP_LOADKX
	function(pc, proto, A, B, C) return "lua_pushboolean(L, " .. B .. ");" end; -- OP_LOADBOOL
	function(pc, proto, A, B, C)
		if B == 0 then
			return "lua_pushnil(L);"
		else
			return "for (int nil_range = 0; nil_range != " .. B + 1 .. "; ++nil_range) { lua_pushnil(L); }"
		end
	end;
	-- OP_LOADNIL
	function(pc, proto, A, B, C) return "lua_pushvalue(L, lua_upvalueindex(" .. B .. "));" end; -- OP_GETUPVAL
	function(pc, proto, A, B, C)
		local consts = proto.constants
		local Cconst = consts[INDEXK(C) + 1]

		if B == 0 and ISK(C) and Cconst[1] == LUA_TLNGSTR and not string.find(Cconst[2], "\0", 1, true) then
			return "lua_getglobal(L, \"" .. sanitizeString(Cconst[2]) .. "\");"
		else
			return emitvalue(proto, C) .. " lua_gettable(L, lua_upvalueindex(" .. (B + 1) .. "));"
		end
	end;
	-- OP_GETTABUP
	function(pc, proto, A, B, C)
		local consts = proto.constants
		local Cconst = consts[INDEXK(C) + 1]

		if ISK(C) and Cconst[1] == LUA_TLNGSTR and not string.find(Cconst[2], "\0", 1, true) then
			return "lua_getfield(L, " .. B .. ", \"" .. sanitizeString(Cconst[2]) .. "\");"
		else
			return emitvalue(proto, C) .. " lua_gettable(L, " .. B .. ");"
		end
	end;
	-- OP_GETTABLE
	function(pc, proto, A, B, C)
		local consts = proto.constants
		local Cconst = consts[INDEXK(C) + 1]
		local Bconst = consts[INDEXK(B) + 1]

		if A == 0 and ISK(B) and Bconst[1] == LUA_TLNGSTR and not string.find(Bconst[2], "\0", 1, true) then
			return emitvalue(proto, C) .. " " .. "lua_setglobal(L, \"" .. sanitizeString(Bconst[2]) .. "\");"
		else
			return emitvalue(proto, B) .. " " .. emitvalue(proto, C) .. " lua_settable(L, lua_upvalueindex(" .. (A + 1) .. "));"
		end
	end;
	-- OP_SETTABUP
	function(pc, proto, A, B, C) return "{lua_Debug ar; lua_getstack(L, 0, &ar); lua_getinfo(L, \"f\", &ar);} lua_pushvalue(L, " .. A .. "); lua_setupvalue(L, 1, " .. B .. "); lua_pop(L, 1);" end; -- OP_SETUPVAL
	function(pc, proto, A, B, C)
		local consts = proto.constants
		local Bconst = consts[INDEXK(B) + 1]

		if ISK(B) and Bconst[1] == LUA_TLNGSTR and not string.find(Bconst[2], "\0", 1, true) then
			return emitvalue(proto, C) .. " lua_setfield(L, " .. A .. ", \"" .. sanitizeString(Bconst[2]) .. "\");"
		else
			return emitvalue(proto, B) .. " " .. emitvalue(proto, C) .. " lua_settable(L, " .. A .. ");"
		end
	end;
	-- OP_SETTABLE
	function(pc, proto, A, B, C)
		if B == 0 and C == 0 then return "lua_newtable(L);" end

		return "lua_createtable(L, " .. luaO_fb2int(B) .. ", " .. luaO_fb2int(C) .. ");"
	end;
	-- OP_NEWTABLE
	function(pc, proto, A, B, C) return "lua_getfield(L, " .. A .. ", \"" .. sanitizeString(proto.constants[INDEXK(C) + 1][2]) .. "\"); lua_pushvalue(L, " .. A .. "); " end; -- OP_SELF
	function(pc, proto, A, B, C) return "lua_arith(L, LUA_OPADD);" end; -- OP_ADD
	function(pc, proto, A, B, C) return "lua_arith(L, LUA_OPSUB);" end; -- OP_SUB
	function(pc, proto, A, B, C) return "lua_arith(L, LUA_OPMUL);" end; -- OP_MUL
	function(pc, proto, A, B, C) return "lua_arith(L, LUA_OPMOD);" end; -- OP_MOD
	function(pc, proto, A, B, C) return "lua_arith(L, LUA_OPPOW);" end; -- OP_POW
	function(pc, proto, A, B, C) return "lua_arith(L, LUA_OPDIV);" end; -- OP_DIV
	function(pc, proto, A, B, C) return "lua_arith(L, LUA_OPIDIV);" end; -- OP_IDIV
	function(pc, proto, A, B, C) return "lua_arith(L, LUA_OPBAND);" end; -- OP_BAND
	function(pc, proto, A, B, C) return "lua_arith(L, LUA_OPBOR);" end; -- OP_BOR
	function(pc, proto, A, B, C) return "lua_arith(L, LUA_OPBXOR);" end; -- OP_BXOR
	function(pc, proto, A, B, C) return "lua_arith(L, LUA_OPSHL);" end; -- OP_SHL
	function(pc, proto, A, B, C) return "lua_arith(L, LUA_OPSHR);" end; -- OP_SHR
	function(pc, proto, A, B, C) return "lua_arith(L, LUA_OPUNM);" end; -- OP_UNM
	function(pc, proto, A, B, C) return "lua_arith(L, LUA_OPBNOT);" end; -- OP_BNOT
	function(pc, proto, A, B, C) return "lua_pushboolean(L, !lua_toboolean(L, " .. B .. "));" end; -- OP_NOT
	function(pc, proto, A, B, C) return "lua_len(L, " .. B .. ")" end; -- OP_LEN
	function(pc, proto, A, B, C) return "lua_concat(L, )" end; -- OP_CONCAT
	function(pc, proto, A, sBx) return "goto instruction_" .. pc + 1 + sBx .. ";" end; -- OP_JMP
	function(pc, proto, A, B, C) return "if (lua_compare(L, LUA_OPEQ) == " .. A .. ") goto instruction_" .. pc + 2 .. ";" end; -- OP_EQ
	function(pc, proto, A, B, C) return "if (lua_compare(L, LUA_OPLT) == " .. A .. ") goto instruction_" .. pc + 2 .. ";" end; -- OP_LT
	function(pc, proto, A, B, C) return "if (lua_compare(L, LUA_OPLE) == " .. A .. ") goto instruction_" .. pc + 2 .. ";" end; -- OP_LE
	function(pc, proto, A, B, C) return "if (lua_toboolean(L, " .. A .. ") != " .. C .. ") goto instruction_" .. pc + 2 .. ";" end; -- OP_TEST
	function(pc, proto, A, B, C) return "if (lua_toboolean(L, " .. B .. ") != " .. C .. ") { goto instruction_" .. pc + 2 .. "; } else { lua_pushvalue(L, " .. B .. "); }" end; -- OP_TESTSET
	function(pc, proto, A, B, C) return "lua_call(L, " .. (B == 0 and "lua_gettop(L) - " .. (A + 1) or (B - 1)) .. ", " .. (C == 0 and "LUA_MULTRET" or (C - 1)) .. ");" end; -- OP_CALL
	function(pc, proto, A, B, C) return CAPI[OpCodesI.OP_CALL](proto, A, B, C) end; -- OP_TAILCALL
	function(pc, proto, A, B, C) return "return " .. (B == 0 and "lua_gettop(L)" or (B - 1)) .. ";" end; -- OP_RETURN
	function(pc, proto, A, sBx) return "}" end; -- OP_FORLOOP
	function(pc, proto, A, sBx) return "for (int i = lua_tointeger(L, " .. A .. "), int limit = lua_tointeger(L, " .. A + 1 .. ", int step = lua_tointeger(L, " .. A + 2 .. "); i > limit; i += step) {" end; -- OP_FORPREP
	function(pc, proto, A, B, C) return "lua_pushvalue(L, " .. A .. "); lua_pushvalue(L, " .. A + 1 .. "); lua_pushvalue(L, " .. A + 2 .. "); lua_call(L, 2, " .. C .. ");" end; -- OP_TFORCALL
	function(pc, proto, A, sBx) return "if (!lua_isnil(L, " .. A + 3 .. ")) goto instruction_" .. pc + 1 + sBx .. ";" end; -- OP_TFORLOOP
	function(pc, proto, A, B, C) return "// " .. B .. " fields were pushed to a table at index " .. A end; -- OP_SETLIST
	function(pc, proto, A, Bx)
		local proto = proto.protos[Bx + 1]
		local name = proto.name
		local upvalues = #proto.upvalues

		if upvalues == 0 then
			return "lua_pushcfunction(L, " .. name .. ");"
		else
			return "lua_pushcclosure(L, " .. name .. ", " .. #proto.upvalues .. ");"
		end
	end;
	-- OP_CLOSURE
	function(pc, proto, A, B, C)
		if B == 1 then
			return "lua_pushvalue(L, " .. A .. ");"
		elseif B == 0 then
			return "for (int vararg_index = " .. A .. ", top_index = lua_gettop(L); vararg_index > top_index; ++vararg_index) { lua_pushvalue(L, vararg_index); }"
		else
			return "{int top_index = lua_gettop(L); for (int vararg_index = " .. A .. "; vararg_index > " .. (B == 0 and "top_index" or "top_index < " .. (A + B) .. " : top_index" .. (A + B)) .. "; ++vararg_index) { lua_pushvalue(L, vararg_index); } for (int nil_index = top_index, int remainig = top_index - " .. B .. "; nil_index != " .. B .. "; ++nil_index) { lua_pushnil(L); } }"
		end
	end;
	-- OP_VARARG
	function(pc, proto, Ax) return "EXTRAARG" end; -- OP_EXTRAARG
}

function Dump(buffer)

local reader = {
	buffer = string.dump(buffer),
	pos = 1,
	protosObj = {},
	currentProtoi = 0
}

function reader:read(n)
	local substr = string.sub(self.buffer, self.pos, self.pos + n - 1)
	self.pos = self.pos + n

	return substr
end

function reader:byte()
	return self:read(1)
end

function reader:byteNum()
	return string.byte(self:byte())
end

function reader:int()
	return (string.unpack("i4", self:read(4)))
end

function reader:uint()
	return (string.unpack("I4", self:read(4)))
end

function reader:double()
	return (string.unpack("n", self:read(8)))
end

function reader:string()
	local size = self:byteNum()

	if (size == 0xFF) then
		size = self:int()
	elseif size == 0 then
		return nil
	end

	return self:read(size - 1)
end

local jumping_opcodes = {
	[OpCodesI.OP_JMP] = 1,
	[OpCodesI.OP_TFORLOOP] = 1,
	[OpCodesI.OP_LE] = 2,
	[OpCodesI.OP_EQ] = 2,
	[OpCodesI.OP_LT] = 2,
	[OpCodesI.OP_LE] = 2,
}

function reader:code()
	local n = self:int()

	local instructions = self.currentProto.instructions
	local labeled = {}

	for i = 1, n do
		ins = self:uint()

		instructions[i] = {
			code = ins,
			opcode = (ins >> POS_OP) & MASK1(SIZE_OP, 0),
			A = (ins >> POS_A) & MASK1(SIZE_A, 0),
			B = (ins >> POS_B) & MASK1(SIZE_B, 0),
			C = (ins >> POS_C) & MASK1(SIZE_C, 0),
			Bx = (ins >> POS_Bx) & MASK1(SIZE_Bx, 0),
			Ax = (ins >> POS_Ax) & MASK1(SIZE_Ax, 0),
			sBx = ((ins >> POS_Bx) & MASK1(SIZE_Bx, 0)) - MAXARG_sBx
		}

		local opcode = ((ins >> POS_OP) & MASK1(SIZE_OP, 0))
		local jump = jumping_opcodes[opcode]

		if jump == 1 then
			labeled[i + 1 + ((ins >> POS_Bx) & MASK1(SIZE_Bx, 0)) - MAXARG_sBx] = true
		elseif jump == 2 then
			labeled[i + 2] = true
		end

		if opcode == OpCodesI.OP_SETLIST then
			for I = i - (ins >> POS_B) & MASK1(SIZE_B, 0), i - 1 do
				instructions[I].setlist = (ins >> POS_A) & MASK1(SIZE_A, 0)
			end
		end
	end

	for k, v in pairs(labeled) do
		instructions[k].has_label = true
	end
end

function reader:constants()
	local n = self:int()

	local constants = self.currentProto.constants

	for i = 1, n do
		local t = self:byteNum()

		if t == LUA_TNIL then
			constants[#constants + 1] = {LUA_TNIL, nil}
		elseif t == LUA_TBOOLEAN then
			constants[#constants + 1] = {LUA_TBOOLEAN, self:byteNum() ~= 0}
		elseif t == LUA_TNUMFLT then
			constants[#constants + 1] = {LUA_TNUMFLT, self:double()}
		elseif t == LUA_TNUMINT then
			constants[#constants + 1] = {LUA_TNUMINT, self:int()}
		elseif t == LUA_TSHRSTR or t == LUA_TLNGSTR then
			constants[#constants + 1] = {LUA_TLNGSTR, self:string()}
		else
			error("unrecognized constant '" .. t .. "'")
		end
	end
end

function reader:upvalues()
	local n = self:int()

	local upvalues = self.currentProto.upvalues

	for i = 1, n do
		upvalues[i] = {
			instack = self:byteNum() ~= 0,
			idx = self:byteNum()
		}
	end
end

function reader:protos()
	local n = self:int()

	local protos = self.currentProto.protos
	local parent = self.currentProto

	for i = 1, n do
		self:pushFunc()

		self:func(parent)
		protos[i] = self.currentProto

		self:goTo(parent.i)

		protos[i].name = "closure_of_" .. (self.currentProto.parent and self.currentProto.i or "lua_openmodule") .. "_" .. i
		protos[i].parent = self.currentProto
	end
end

function reader:debug()
	do
		local n = self:int()
	
		local lineinfo = self.currentProto.lineinfo

		for i = 1, n do
			lineinfo[i] = self:int()
		end
	end

	do
		local n = self:int()

		local locals = self.currentProto.locals

		for i = 1, n do
			locals[i] = {
				varname = self:string(),
				startpc = self:int(),
				endpc = self:int()
			}
		end
	end

	do
		local n = self:int()

		local upvalues = self.currentProto.upvalues

		for i = 1, n do
			upvalues[i].name = self:string()
		end
	end
end

function reader:pushFunc()
	self.protosObj[#self.protosObj + 1] = {
		instructions = {},
		locals = {},
		lineinfo = {},
		constants = {},
		upvalues = {},
		protos = {},
	}

	self.currentProto = self.protosObj[#self.protosObj]

	self.currentProto.i = #self.protosObj
end

function reader:goTo(n)
	self.currentProto = self.protosObj[n]
end

function reader:func(parent)
	self.currentProto.source = self:string()

	if not self.currentProto.source then
		self.currentProto.source = parent.source
	end

	self.currentProto.lineDefined = self:int()
	self.currentProto.lastLineDefined = self:int()
	self.currentProto.numParams = self:byteNum()
	self.currentProto.isVararg = self:byteNum() ~= 0
	self.currentProto.maxStackSize = self:byteNum()

	self:code()
	self:constants()
	self:upvalues()
	self:protos()
	self:debug()
end

local output = {}

local function print(...)
	for k = 1, select("#", ...) do
		output[#output + 1] = select(k, ...)
	end

	output[#output + 1] = "\n"
end

local function dumpFunc(proto)
	if #proto.protos ~= 0 then
		for cproto = 1, #proto.protos do
			dumpFunc(proto.protos[cproto])
		end
	end

	print("static int " .. (proto.name or "lua_openmodule") .. "(lua_State* L) {")

	for k = 1, #proto.instructions do
		local inst = proto.instructions[k]
		local name = OpCodes[inst.opcode]

		if getOpMode(inst.opcode) == iABC then
			print("    ", (inst.has_label and "instruction_" .. k .. ":   " or "") .. CAPI[inst.opcode](k, proto, inst.A, inst.B, inst.C) .. (inst.setlist and (" lua_rawseti(L, " .. inst.setlist .. ", " .. (inst.A - inst.setlist)) .. ");" or ""))
		elseif getOpMode(inst.opcode) == iABx then
			print("    ", (inst.has_label and "instruction_" .. k .. ":   " or "") .. CAPI[inst.opcode](k, proto, inst.A, inst.Bx) .. (inst.setlist and (" lua_rawseti(L, " .. inst.setlist .. ", " .. (inst.A - inst.setlist)) .. ");" or ""))
		elseif getOpMode(inst.opcode) == iAsBx then
			print("    ", (inst.has_label and "instruction_" .. k .. ":   " or "") .. CAPI[inst.opcode](k, proto, inst.A, inst.sBx) .. (inst.setlist and (" lua_rawseti(L, " .. inst.setlist .. ", " .. (inst.A - inst.setlist)) .. ");" or ""))
		elseif getOpMode(inst.opcode) == iAx then
			print("    ", (inst.has_label and "instruction_" .. k .. ":   " or "") .. CAPI[inst.opcode](k, proto, inst.Ax) .. (inst.setlist and (" lua_rawseti(L, " .. inst.setlist .. ", " .. (inst.A - inst.setlist)) .. ");" or ""))
		end
	end

	print("}\n")
end

function reader:dumpFuncs()
	output = {}

	dumpFunc(self.protosObj[1])

	return table.concat(output)
end

function reader:header()
	self.signature = self:read(4)
	assert(self.signature == "\x1bLua")

	self.version = self:byteNum()
	assert(self.version == 0x53)

	self.format = self:byteNum()
	assert(self.format == 0)

	self.data = self:read(6)
	assert(self.data == "\25\147\13\10\26\10")

	self.intSize = self:byteNum()
	assert(self.intSize == 4)

	self.size_tSize = self:byteNum()
	assert(self.size_tSize == 4)

	self.instructionSize = self:byteNum()
	assert(self.instructionSize == 4)

	self.integerSize = self:byteNum()
	assert(self.integerSize == 4)

	self.numberSize = self:byteNum()
	assert(self.numberSize == 8)

	self.integerTest = self:int()
	assert(self.integerTest == 0x5678)

	self.numberTest = self:double()
	assert(self.numberTest == 370.5)
end

function reader:bytecode()
	self:header()

	self:pushFunc()

	local upvaluesi = self:byteNum()

	self:func()

	assert(upvaluesi == #self.currentProto.upvalues)
end

reader:bytecode(file)

return reader:dumpFuncs()

end