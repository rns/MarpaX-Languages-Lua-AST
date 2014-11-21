g = function ()
  local x = 1
  a = { 'b', 'c' }
  w = { 'x', 'y', 'z' }
  -- not just BNF, but pure Lua statements are allowed in a grammar
  for i = 2, n do
    x = x * i
  end
end

