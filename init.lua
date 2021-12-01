--[[

jsons
=====

usage:
get an iterator with jsons.parser(str)
or get a pretty json string with jsons.pretty(str)
or get a minified json string with jsons.minify(str)
where str is a string containing one json value

iterator will return 0, 2 or 4 values:
	type: one of: nil, "object", "array", "string", "number", "boolean", "nil"
	where: current position in str
	if type is not "object" or "array":
		value: value of the above Lua type
		valuestr: string, the value copied verbatim from str

hierarchy is expressed using "object", "array" and nil types

example input:
"[123, 456, ["foo", {"qux": "baz", "test": 789}, "bar"], null, false]"

example output (empty line represents no return value at all):
"array"  , 1
"number" , 2 , 123   , "123"
"number" , 7 , 456   , "456"
"array"  , 12
"string" , 13, "foo" , '"foo"'
"object" , 20
"string" , 21, "qux" , '"qux"'
"string" , 28, "baz" , '"baz"'
"string" , 35, "test", '"test"'
"number" , 43, 789   , "789"

"string" , 49, "bar" , '"bar"'

"nil"    , 57, nil   , "null"
"boolean", 63, false , "false"

68
cannot resurrect a dead coroutine

throws syntax errors when it encounters them
thus, avoid causing side effects while using this
until the entire document has been parsed

if you don't like any of the values that the iterator returns,
just make a function that calls the iterator and returns only the ones you want
like, local type, value, value = parser(); return type, value
which will return only the type and the lua value, but not the location or
the verbatim value

this parser was created primarily with pretty-printing/beautification
and linearization/minification in mind, hence the "verbatim" return value
in addition, Lua has no "null" type that's separate from "nil"

use for anything else but the above at your own risk, because it has
never been used for anything else

(not to be confused with jsons for Python)

]]

----------------------------------------

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
	coroutine.yield() -- take str argument from jsons.parser() and wait for the actual user
	-- trace("parseJson")
	local where = 1
	if string.sub(str, 1, 3) == "\xef\xbb\xbf" then where = 4 end -- UTF-8 BOM
	where = parseElement(str, where)
	ass(where == #str + 1, where, "trailing data")
	return where
end

----------------------------------------

function parseWhitespace(str, where)
	-- trace("parseWhitespace", where)
	-- see also: empty element detection in parseArray and parseObject
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
	coroutine.yield("object", where)
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
	coroutine.yield("array", where)
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
			coroutine.yield("string", where, table.concat(rope), string.sub(str, where, after - 1))
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
	if string.sub(str, where, where) == "-" then where = where + 1 end
	where = string.match(str, "^0()", where) or string.match(str, "^%d+()", where)
	if where == nil then return end
	where = string.match(str, "^%.%d+()", where) or where
	where = string.match(str, "^[eE][-+]?%d+()", where) or where
	local result = string.sub(str, there, where - 1)
	coroutine.yield("number", there, tonumber(result), result) -- yeah just tonumber it
	return where
end

function parseOther(str, where)
	if string.sub(str, where, where + 3) == "true"  then coroutine.yield("boolean", where, true , "true" ) return where + 4 end
	if string.sub(str, where, where + 4) == "false" then coroutine.yield("boolean", where, false, "false") return where + 5 end
	if string.sub(str, where, where + 3) == "null"  then coroutine.yield("nil"    , where, nil  , "null" ) return where + 4 end
end

----------------------------------------

function parseMembers(str, where)
	-- trace("parseMembers", where)
	where = parseMember(str, where)
	while string.sub(str, where, where) == "," do
		where = parseMember(str, where + 1)
	end
	return where
end

function parseElements(str, where)
	-- trace("parseElements", where)
	where = parseElement(str, where)
	while string.sub(str, where, where) == "," do
		where = parseElement(str, where + 1)
	end
	return where
end

----------------------------------------

function parseMember(str, where)
	-- trace("parseMember", where)
	where = parseWhitespace(str, where)
	where = ass(parseString(str, where), where, "expected string")
	where = parseWhitespace(str, where)
	ass(string.sub(str, where, where) == ":", where, "expected :")
	return parseElement(str, where + 1)
end

function parseElement(str, where)
	-- trace("parseElement", where)
	where = parseWhitespace(str, where)
	where = ass(parseValue(str, where), where, "unrecognizable value")
	return parseWhitespace(str, where)
end

----------------------------------------

local function line(level) return "\n" .. string.rep("\t", level) end

-- the quick rundown on this function:
-- get a value to represent
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
		local key, key = get()
		if key ~= nil then
			type, value = get()
			print(line(level + 1) .. key .. ": ")
			pretty(print, level + 1, get, type, value)
			for key, key in get do
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

local function minify(print, get, type, value)
	if type == "array" then
		print("[")
		type, value = get()
		if type ~= nil then
			minify(print, get, type, value)
			for type, value in get do
				print(",")
				minify(print, get, type, value)
			end
		end
		print("]")
		
	elseif type == "object" then
		print("{")
		local key, key = get()
		if key ~= nil then
			type, value = get()
			print(key .. ":")
			minify(print, get, type, value)
			for key, key in get do
				type, value = get()
				print("," .. key .. ":")
				minify(print, get, type, value)
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
	local function parser2()
		local type, value, value, value = parser()
		return type, value
	end
	pretty(
		function(x) return table.insert(rope, x) end,
		0,
		parser2,
		parser2()
	)
	parser() -- check for trailing data
	return table.concat(rope)
end

function jsons.minify(parser)
	local rope = {}
	local function parser2()
		local type, value, value, value = parser()
		return type, value
	end
	minify(
		function(x) return table.insert(rope, x) end,
		parser2,
		parser2()
	)
	parser() -- check for trailing data
	return table.concat(rope)
end

return jsons
