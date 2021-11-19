-- luvit
local fs = require "fs"
local jsons = require "jsons"

local cd = args[1]:sub(1, args[1]:match("()[^\\/]*$") - 1)
local dir = cd .. "\\test"

local function print(a, b, c)
	io.write(table.concat({tostring(a), tostring(b), tostring(c)}, "\t"))
	io.write("\n")
end

local should = {
	y = true,
	n = false,
}

for name, type in fs.scandirSync(dir) do
	local success, value = pcall(jsons.pretty, jsons.parser(fs.readFileSync(dir .. "\\" .. name)))
	if success ~= should[name:sub(1, 1)] then
		if success then
			print(success, name, #value)
		else
			print(success, name, value:match(".*:(.*)"))
			-- print(success, name, value)
		end
	end
end
