-- nonspecfic helper functions

local helpers = {}

function helpers.destroyDescendants(instance)
    for _, instanceChild in instance:GetDescendants() do
        instanceChild:Destroy()
    end
end

-- roblox lua table.copy does not behave like i expected with nested tables
-- any changes to values in x.table will replicate to table.clone(x).table
-- recursively copies instances in table
function helpers.deepCopy(original)
	local copy = {}

	for k, v in pairs(original) do
		if type(v) == "table" then
			v = helpers.deepCopy(v)
		end
		copy[k] = v
	end

	return copy
end

return helpers