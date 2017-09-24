--


class = require("utilities/middleclass")
require("utilities/strict")

local function match_bb(s, pattern)
  -- dollar at end is probably redundant
  local m1, m2 = s:match(pattern .. "%s*(.*)$")
  if m2 == nil or (m2 ~= "" and m2:sub(1,1) ~= ";")then
      return nil
  end
  return m1
end


-- NOTES
--
-- 1. We don't need to do a full recusive parse. We just need to get it 
--    into a state the Lua interpreter can parse.
-- 2. In the case of Manic Miner in Blitz, it should be valid source.
-- 3. It doesn't need to be the fastest code on the planet.
--
-- Examples
-- ========
--    -(MyIdentifier) ; comment
--    MyFunc()
--    _
--    3 * 4
--    (+5 * my_identier)
--
--    fred<>0 and func() and id
--
--    fred + sid * (k + j + (func1())) - 1
--    "my string"
--
-- These result in an empty expression
--    ; comment
--
-- blank string is also an empty expression
--
--
-- These result in syntax error
--    -
--    Wrong parameter
--
function parse_expr(s)
  -- param type check
  if type(s) ~= "string" then
    return nil, "No string to parse"
  end
  -- space or nothing line
  if s:find('^%s*$') then
    return ""
  end
  -- comment only line
  if s:find('^%s*;') then
    return ""
  end
  
  -- string
  local expr = s:match_bb('^%s*("[^"]*")')
  if expr then
    return expr
  end
  
  
  
end

