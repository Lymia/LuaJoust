-- Translation of Lymia.nyuroki
-- Adapted from https://github.com/Lymia/JoustExt/blob/master/examples/nyuroki-esoteric.jx

local function rushBody()
  for i=10,30 do
    advance()

    for _=1,2 do
      if test() then
        minus(20) -- offset clear
        for _=1,500 do -- inflexable timer clear
          if not test() then break end
          plus()
        end
        while test() do -- anti-defense clear loop
          m() w() m() p()
        end
        break
      end
    end

    if i % 2 == 0 then plus() else minus() end -- leave behind a trail
  end

  -- We are clearly on their flag. Random walk time.
  local seed = 12345
  while true do
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    if (seed / 3) & 1 == 0 then p() else m() end
  end
end

advance(8)
     if test() then      rushBody() end  p(5)
r()  if test() then a(1) rushBody() end  m(5)
r()  if test() then a(2) rushBody() end  p(5)
r()  if test() then a(3) rushBody() end  m(5)
r()  if test() then a(4) rushBody() end  p(51)
r()  if test() then a(5) rushBody() end  m(50)
r()  if test() then a(6) rushBody() end  m(50)
r()  if test() then a(7) rushBody() end  p(50)
r()  m(128-109) -- throw off simpler careless clears
a(4)
a( ) m(20)
a( ) p(20)
a( ) m(20)
a( ) p(20)
a(4) -- violate rule of 4, since we didn't get a decoy clash
rushBody()
