local print = function() end

local function err(where, why)
	return error("syntax error: " .. why .. " at " .. where)
end

local function ass(there, where, why)
	if not there then return err(where, why) end
	return there
end

----------------------------------------

function parseJson(str, where)
	coroutine.yield() -- wait for arguments
	print("parseJson", where)
	where = parseElement(str, where)
	return where
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
		if ((after - before) & 1) == 1 then
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

local print = _G.print
print()
local parseJson = coroutine.wrap(parseJson)
-- parseJson('[1, 2, {"foo": 2, "bar": [3,  2, 1]}]', 1)
parseJson(editor:GetText(), 1)
for i = 1,100 do
	print(parseJson())
end
