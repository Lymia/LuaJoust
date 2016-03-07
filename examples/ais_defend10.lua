-- Translated version of ais_defend10
-- From http://codu.org/eso/bfjoust/in_egobot.hg/index.cgi/raw-file/1a319ed095d1/ais523_defend10.bfjoust

advance(2)
plus()
retreat()
plus()
while test() do while test() do end end
retreat()
wait(127)

for i = 10, 30 do
  for _ = 1, 3 do
    plus(256)
    advance(i-1)
    for _ = 1, 129 - i do
      wait()
      plus()
    end
    retreat(i-1)
  end
end
