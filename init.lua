local print = function() end

local function err(where, why)
	return error("syntax error: " .. why .. " at " .. where)
end

local function ass(there, where, why)
	if there == nil then return err(where, why) end
	return there
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

function parseJson(str, where)
	coroutine.yield() -- wait for arguments
	print("parseJson", where)
	return parseElement(str, where)
end

----------------------------------------

function parseWhitespace(str, where)
	print("parseWhitespace", where)
	return string.match(str, "^[ \r\n\t]*()", where)
end

function parseValue(str, where)
	print("parseValue", where)
	return parseObject(str, where)
	or     parseArray(str, where)
	or     parseString(str, where)
	or     parseNumber(str, where)
	or     parseOther(str, where)
end

----------------------------------------

function parseObject(str, where)
	print("parseObject", where)
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
	print("parseArray", where)
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

function parseString(str, where)
	print("parseString", where)
	if string.sub(str, where, where) ~= '"' then return end
	local after, before = where + 1
	while true do
		before, after = string.match(str, '()\\*"()', after)
		ass(before, where, "unterminated string")
		if ((after - before) % 2) == 1 then
			coroutine.yield("string", string.sub(str, where, after - 1))
			return after
		end
	end
end

function parseNumber(str, where)
	print("parseNumber", where)
	local there = where
	where = string.match(str, "^-()", where) or where
	where = string.match(str, "^0()", where) or string.match(str, "^%d+()", where)
	if where == nil then return end
	where = string.match(str, "^%.%d+()", where) or where
	where = string.match(str, "^[eE][-+]?%d+()", where) or where
	coroutine.yield("number", string.sub(str, there, where - 1))
	return where
end

function parseOther(str, where)
	local there
	there = string.match(str, "^true()", where); if there then coroutine.yield("true", "true") return there end
	there = string.match(str, "^false()", where); if there then coroutine.yield("false", "false") return there end
	there = string.match(str, "^null()", where); if there then coroutine.yield("null", "null") return there end
end

----------------------------------------

function parseMembers(str, where)
	print("parseMembers", where)
	where = parseMember(str, where)
	if string.sub(str, where, where) == "," then
		return parseMembers(str, where + 1)
	else
		return where
	end
end

function parseElements(str, where)
	print("parseElements", where)
	where = parseElement(str, where)
	if string.sub(str, where, where) == "," then
		return parseElements(str, where + 1)
	else
		return where
	end
end

----------------------------------------

function parseMember(str, where)
	print("parseMember", where)
	where = parseWhitespace(str, where)
	where = ass(parseString(str, where), where, "expected string")
	where = parseWhitespace(str, where)
	where = ass(string.match(str, "^:()", where), where, "expected :")
	return parseElement(str, where)
end

function parseElement(str, where)
	print("parseElement", where)
	where = parseWhitespace(str, where)
	where = ass(parseValue(str, where), where, "unrecognizable value")
	return parseWhitespace(str, where)
end

----------------------------------------

local function line(level) return "\n" .. string.rep("\t", level) end
local function pretty(print, level, get, type, value)
	if type == "array" then
		print("[")
		type, value = get()
		if type ~= nil then
			print(line(level + 1))
			pretty(print, level + 1, get, type, value)
			for type, value in get do
				print("," .. line(level + 1))
				pretty(print, level + 1, get, type, value)
			end
			print(line(level))
		end
		print("]")
		
	elseif type == "object" then
		print("{")
		local _, key = get()
		if key ~= nil then
			type, value = get()
			print(line(level + 1))
			print(key .. ": ")
			pretty(print, level + 1, get, type, value)
			for _, key in get do
				type, value = get()
				print("," .. line(level + 1) .. key .. ": ")
				pretty(print, level + 1, get, type, value)
			end
			print(line(level))
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

function jsons.parser(str, where)
	local parser = coroutine.wrap(parseJson)
	parser(str, where or 1)
	return parser
end

function jsons.pretty(parser)
	local rope = {}
	pretty(
		function(x) return table.insert(rope, x) end,
		0,
		parser,
		parser()
	)
	return table.concat(rope)
end

return jsons
