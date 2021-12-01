-- local function trace(...)
	-- return print(...)
-- end

local function err(where, why)
	return error("syntax error: " .. why .. " at " .. where, 2)
end
local function ass(there, where, why)
	return there or error("syntax error: " .. why .. " at " .. where, 2)
end

----------------------------------------

local
	parseJson,
	parseWhitespace,
	parseValue,
	parseObject,
	parseArray,
	parseString,
	parseNumber,
	parseOther,
	parseMembers,
	parseElements,
	parseMember,
	parseElement

----------------------------------------

function parseJson(str)
	coroutine.yield() -- wait for arguments
	-- trace("parseJson")
	local where = 1
	if string.sub(str, 1, 3) == "\xef\xbb\xbf" then where = 4 end -- UTF-8 BOM
	local there = ass(parseElement(str, where), where, "incomplete document")
	ass(there == #str + 1, there, "trailing data")
	return there
end

----------------------------------------

function parseWhitespace(str, where)
	-- trace("parseWhitespace", where)
	return string.match(str, "^[ \r\n\t]*()", where)
end

function parseValue(str, where)
	-- trace("parseValue", where)
	return parseObject(str, where)
	or     parseArray(str, where)
	or     parseString(str, where)
	or     parseNumber(str, where)
	or     parseOther(str, where)
end

----------------------------------------

function parseObject(str, where)
	-- trace("parseObject", where)
	if string.sub(str, where, where) ~= "{" then return end
	coroutine.yield("object")
	local there = string.match(str, "^[ \r\n\t]*}()", where + 1)
	if there then
		coroutine.yield()
		return there
	else
		where = parseMembers(str, where + 1)
		ass(string.sub(str, where, where) == "}", where, "unterminated object")
		coroutine.yield()
		return where + 1
	end
end

function parseArray(str, where)
	-- trace("parseArray", where)
	if string.sub(str, where, where) ~= "[" then return end
	coroutine.yield("array")
	local there = string.match(str, "^[ \r\n\t]*%]()", where + 1)
	if there then
		coroutine.yield()
		return there
	else
		where = parseElements(str, where + 1)
		ass(string.sub(str, where, where) == "]", where, "unterminated array")
		coroutine.yield()
		return where + 1
	end
end

local escapes = {
	['"'] = '"',
	["\\"] = "\\",
	["/"] = "/",
	["b"] = "\b",
	["f"] = "\f",
	["n"] = "\n",
	["r"] = "\r",
	["t"] = "\t",
}
function parseString(str, where)
	-- note: this does not validate unicode
	-- it also probably gets \uxxxx escapes completely wrong
	-- trace("parseString", where)
	if string.sub(str, where, where) ~= '"' then return end
	local there = where + 1
	local after, what = there
	local rope = {}
	while true do
		-- after = string.match(str, '^[^\0-\31"\\]*()', after)
		after = string.match(str, "^[\32\33\35-\90%[%]\94-\255]*()", after)
		if (there ~= after) then table.insert(rope, string.sub(str, there, after - 1)) end
		what = string.sub(str, after, after)
		after = after + 1 -- after the "what" character
		
		if what == '"' then
			coroutine.yield("string", table.concat(rope), string.sub(str, where, after - 1))
			return after
			
		elseif what == "\\" then
			what = string.sub(str, after, after)
			if what == "u" then
				-- kind of stupid to check for "u" first...
				what = ass(string.match(str, "^%x%x%x%x", after + 1), after, "incomplete unicode escape sequence")
				if string.sub(str, after + 1, after + 2) ~= "00" then
					table.insert(rope, string.char(tonumber(string.sub(str, after + 1, after + 2), 16)))
				end
				table.insert(rope, string.char(tonumber(string.sub(str, after + 3, after + 4), 16)))
				after = after + 5
				
			else
				what = ass(escapes[what], after, "unrecognized escape sequence")
				table.insert(rope, what)
				after = after + 1
			end
			
		else
			err(after, "malformed string")
		end
		
		there = after
	end
end

function parseNumber(str, where)
	-- trace("parseNumber", where)
	local there = where
	where = string.match(str, "^-()", where) or where
	where = string.match(str, "^0()", where) or string.match(str, "^%d+()", where)
	if where == nil then return end
	where = string.match(str, "^%.%d+()", where) or where
	where = string.match(str, "^[eE][-+]?%d+()", where) or where
	local result = string.sub(str, there, where - 1)
	coroutine.yield("number", tonumber(result), result) -- yeah just tonumber it
	return where
end

function parseOther(str, where)
	local there
	there = string.match(str, "^true()", where); if there then coroutine.yield("true", true, "true") return there end
	there = string.match(str, "^false()", where); if there then coroutine.yield("false", false, "false") return there end
	there = string.match(str, "^null()", where); if there then coroutine.yield("null", nil, "null") return there end
end

----------------------------------------

function parseMembers(str, where)
	-- trace("parseMembers", where)
	where = parseMember(str, where)
	if string.sub(str, where, where) == "," then
		return parseMembers(str, where + 1)
	else
		return where
	end
end

function parseElements(str, where)
	-- trace("parseElements", where)
	where = parseElement(str, where)
	if string.sub(str, where, where) == "," then
		return parseElements(str, where + 1)
	else
		return where
	end
end

----------------------------------------

function parseMember(str, where)
	-- trace("parseMember", where)
	where = parseWhitespace(str, where)
	where = ass(parseString(str, where), where, "expected string")
	where = parseWhitespace(str, where)
	where = ass(string.match(str, "^:()", where), where, "expected :")
	return parseElement(str, where)
end

function parseElement(str, where)
	-- trace("parseElement", where)
	where = parseWhitespace(str, where)
	where = ass(parseValue(str, where), where, "unrecognizable value")
	return parseWhitespace(str, where)
end

----------------------------------------

local function line(level) return "\n" .. string.rep("\t", level) end
local function pretty(print, level, get, type, _, value)
	if type == "array" then
		print("[")
		type, _, value = get()
		if type ~= nil then
			print(line(level + 1))
			pretty(print, level + 1, get, type, _, value)
			for type, _, value in get do
				print("," .. line(level + 1))
				pretty(print, level + 1, get, type, _, value)
			end
			print(line(level))
		end
		print("]")
		
	elseif type == "object" then
		print("{")
		local _, _, key = get()
		if key ~= nil then
			type, _, value = get()
			print(line(level + 1))
			print(key .. ": ")
			pretty(print, level + 1, get, type, _, value)
			for _, _, key in get do
				type, _, value = get()
				print("," .. line(level + 1) .. key .. ": ")
				pretty(print, level + 1, get, type, _, value)
			end
			print(line(level))
		end
		print("}")
		
	else
		print(value)
	end
end

local function linear(print, get, type, _, value)
	if type == "array" then
		print("[")
		type, _, value = get()
		if type ~= nil then
			linear(print, get, type, _, value)
			for type, _, value in get do
				print(",")
				linear(print, get, type, _, value)
			end
		end
		print("]")
		
	elseif type == "object" then
		print("{")
		local _, _, key = get()
		if key ~= nil then
			type, _, value = get()
			print(key .. ":")
			linear(print, get, type, _, value)
			for _, _, key in get do
				type, _, value = get()
				print("," .. key .. ":")
				linear(print, get, type, _, value)
			end
		end
		print("}")
		
	else
		print(value)
	end
end

----------------------------------------

-- testing
--[[
local print = _G.print
print()
local parseJson = coroutine.wrap(parseJson)
parseJson('["foobar", [], "barfoo", {"foo": 1, "bar": null}]', 1)
-- parseJson(editor:GetText(), 1)
local rope = {}
inValue(function(x) return table.insert(rope, x) end, 0, parseJson, parseJson())
print(table.concat(rope))
]]

----------------------------------------

local jsons = {}

function jsons.parser(str)
	local parser = coroutine.wrap(parseJson)
	parser(str)
	return parser
end

-- warning: parser() will just skip any UTF-8 BOM, and pretty() does not preserve it
function jsons.pretty(parser)
	local rope = {}
	pretty(
		function(x) return table.insert(rope, x) end,
		0,
		parser,
		parser()
	)
	parser() -- check for trailing data
	return table.concat(rope)
end

function jsons.linear(parser)
	local rope = {}
	linear(
		function(x) return table.insert(rope, x) end,
		parser,
		parser()
	)
	parser() -- check for trailing data
	return table.concat(rope)
end

return jsons
