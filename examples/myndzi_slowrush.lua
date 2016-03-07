-- Translated version of myndzi_slowrush
-- From https://esolangs.org/wiki/BF_Joust_strategies#2009

a() p(22)
a() m(22)
a() p(6)
a() p(6)
a() p()
a() m()
a() m()
a() p()

local function clearLoop()
  while test() do
    minus()
    plus(22)
    while t() do m() end
  end
end

for i=10,30 do
  advance()
  while test() do
    clearLoop()
    plus()
    advance()
    clearLoop()
    minus()
    advance()
  end
  plus()
end
