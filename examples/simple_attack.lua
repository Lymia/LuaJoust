advance(8) -- rule of 9
for _=1,21 do
  advance()
  -- offset clear
  while test() do
    plus(5)
    while test() do minus() end
  end
end
