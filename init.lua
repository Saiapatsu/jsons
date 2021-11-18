local print = function() end

----------------------------------------

function parseJson(str, where)
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
	or     string.match(str, "^true()", where)
	or     string.match(str, "^false()", where)
	or     string.match(str, "^null()", where)
end

----------------------------------------

function parseObject(str, where)
	print("parseObject", where)
	if string.sub(str, where, where) ~= "{" then return end
	local there = string.match(str, "^[ \r\n\t]*}()", where + 1)
	if there then return there end
	where = parseMembers(str, where + 1)
	if where == nil then return end
	if string.sub(str, where, where) ~= "}" then return end
	return where + 1
end

function parseArray(str, where)
	print("parseArray", where)
	if string.sub(str, where, where) ~= "[" then return end
	local there = string.match(str, "^[ \r\n\t]*%]()", where + 1)
	if there then return there end
	where = parseElements(str, where + 1)
	if where == nil then return end
	if string.sub(str, where, where) ~= "]" then return end
	return where + 1
end

function parseString(str, where)
	print("parseString", where)
	if string.sub(str, where, where) ~= '"' then return end
	local after, before = where + 1
	while true do
		before, after = string.match(str, '()\\*"()', after)
		if before == nil then return end
		if ((after - before) & 1) == 1 then return after end
	end
end

function parseNumber(str, where)
	print("parseNumber", where)
	where = string.match(str, "^-()", where) or where
	where = string.match(str, "^0()", where) or string.match(str, "^%d+()", where)
	if where == nil then return end
	where = string.match(str, "^%.%d+()", where) or where
	return  string.match(str, "^[eE][-+]?%d+()", where) or where
end

----------------------------------------

function parseMembers(str, where)
	print("parseMembers", where)
	where = parseMember(str, where)
	if where == nil then return end
	if string.sub(str, where, where) == "," then
		return parseMembers(str, where + 1)
	else
		return where
	end
end

function parseElements(str, where)
	print("parseElements", where)
	where = parseElement(str, where)
	if where == nil then return end
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
	where = parseString(str, where)
	if where == nil then return end
	where = parseWhitespace(str, where)
	where = string.match(str, "^:()", where)
	if where == nil then return end
	return parseElement(str, where)
end

function parseElement(str, where)
	print("parseElement", where)
	where = parseWhitespace(str, where)
	where = parseValue(str, where)
	if where == nil then return end
	return parseWhitespace(str, where)
end

----------------------------------------

print(parseJson('"foo\\"bar" "ww"', 1))
