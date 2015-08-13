
-- short start of file comment

local t = loadstring(s..'}')()

-- defines a factorial function
-- continuation of the above comment
function fact (n)
  if n == 0 --[[ before then --]] then
    return 1
  else
    return n * fact(n-1)
  end
end

--[[
  long end-of-file comment
--]]
