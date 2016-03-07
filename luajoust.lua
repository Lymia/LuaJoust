#!/usr/bin/env lua5.3

-- Lua version check
if _VERSION ~= "Lua 5.3" then
  io.stderr:write("This version of Lua Joust requires Lua 5.3")
  os.exit(-1)
  return
end

-- cache some values for efficiency
local error, type, tostring, getmetatable, setmetatable = 
      error, type, tostring, getmetatable, setmetatable
local coroutine_yield, coroutine_status, coroutine_resume =
      coroutine.yield, coroutine.status, coroutine.resume
local stderr = io.stderr

-- Prevent globals writes
local _ENV = setmetatable({}, { 
  __index = _ENV,
  __newindex = function(_, k) error("write to global \""..k.."\"") end,
})

-- Error printing function
local function printerr(str)
  stderr:write(tostring(str).."\n")
end
local function fatalerr(err, exit)
  printerr(err)
  os.exit(exit)
  error("os.exit failed (intended status: "..exit..")")
end

-- IPC operation constants
local OP_PLUS    = 0
local OP_MINUS   = 1
local OP_ADVANCE = 2
local OP_RETREAT = 3
local OP_TEST    = 4

-------------------------
-- Program compilation --
-------------------------

local copyFunctions = {
  "_VERSION", "assert", "error", "ipairs", "load", "next", "pairs", "pcall",
  "print", "rawequals", "rawget", "rawlen", "rawset", "require", "select",
  "tonumber", "type", "xpcall"
}
local copyTables = { "coroutine", "math", "string", "table", "utf8" }
local safeObjType = { "nil", "string", "boolean" }

local function hasMetatable(obj)
  return pcall(function() setmetatable(obj, getmetatable(obj)) end)
end
local function copyTable(t)
  local new = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
      new[k] = copyTable(t)
    else
      new[k] = v
    end
  end
  return new
end

local function repeatClosure(fn)
  return function(n)
    if type(n) == "number" then
      for _=1,n do fn() end
    else
      fn()
    end
  end
end
local function loadLuaJoustLibrary(env)
  env.plus    = repeatClosure(function() coroutine_yield(OP_PLUS   ) end)
  env.minus   = repeatClosure(function() coroutine_yield(OP_MINUS  ) end)
  env.advance = repeatClosure(function() coroutine_yield(OP_ADVANCE) end)
  env.retreat = repeatClosure(function() coroutine_yield(OP_RETREAT) end)
  env.wait    = repeatClosure(function() coroutine_yield() end)
  env.test    = function() return coroutine_yield(OP_TEST) end

  env.p = env.plus
  env.m = env.minus
  env.a = env.advance
  env.r = env.retreat
  env.w = env.wait
  env.t = env.test

  env.OP_PLUS    = OP_PLUS
  env.OP_MINUS   = OP_MINUS
  env.OP_ADVANCE = OP_ADVANCE
  env.OP_RETREAT = OP_RETREAT
  env.OP_TEST    = OP_TEST
end
local function buildProgramEnvironment(programName)
  local env = {}
  env._G = env

  -- Copy standard library functions
  for _, fn in ipairs(copyFunctions) do
    env[fn] = _ENV[fn]
  end
  for _, table in ipairs(copyTables) do
    env[table] = copyTable(_ENV[table])
  end

  -- Implement debug print()
  function env.print(...)
    stderr:write("(debug) "..programName..": ")
    for _, v in ipairs({...}) do
      stderr:write(tostring(v))
      stderr:write(" ")
    end
    stderr:write("\n")
  end

  -- Protect the string metatable
  function env.getmetatable(obj)
    if type(obj) == table then
      return getmetatable(obj)
    else
      return nil
    end
  end
  function env.setmetatable(obj, mt)
    if type(obj) ~= "table" then
      error("Cannot set metatable on objects of type "..type(obj))
    end
    return setmetatable(obj, mt)
  end

  -- Hide addresses from tostring to enforce determinism
  function env.tostring(obj)
    local objType = type(obj)
    if safeObjType[objType] then
      return tostring(obj)
    end
    return objType..": <address hidden>"
  end

  -- Remove math.random() and math.randomseed()
  env.math.random = nil
  env.math.randomseed = nil

  -- Load Lua Joust library
  loadLuaJoustLibrary(env)

  return env
end
local function compileProgram(programName, contents)
  local env = buildProgramEnvironment(programName)
  return load(contents, programName, "t", env)
end

--------------------
-- Main Game Loop --
--------------------

local RESULT_A_WINS = 1
local RESULT_TIED   = 0
local RESULT_B_WINS = -1

local function runRound(programA, programB, tapeLength, isKettle)
  programA = coroutine.create(programA)
  programB = coroutine.create(programB)

  local kettleV = 1
  if isKettle then kettleV = -1 end

  local dpA , dpB  = 1, tapeLength
  local resA, resB = nil, nil

  local tape = {}
  tape[1] = 128
  tape[tapeLength] = 128
  for i=2,tapeLength-1 do tape[i] = 0 end

  local lastZeroA, lastZeroB = false, false

  for cycle=1,100000 do
    local testB = tape[dpB] == 0

    local statusA, resultA = coroutine_resume(programA, resA)
    local statusB, resultB = coroutine_resume(programB, resB)
    resA, resB = nil

    if statusA then
          if resultA == OP_PLUS    then tape[dpA] = (tape[dpA] + 1) % 256
      elseif resultA == OP_MINUS   then tape[dpA] = (tape[dpA] - 1) % 256
      elseif resultA == OP_ADVANCE then dpA = dpA + 1
      elseif resultA == OP_RETREAT then dpA = dpA - 1
      elseif resultA == OP_TEST    then resA = tape[dpA] ~= 0 end
    end

    if statusB then
          if resultB == OP_PLUS    then tape[dpB] = (tape[dpB] + kettleV) % 256
      elseif resultB == OP_MINUS   then tape[dpB] = (tape[dpB] - kettleV) % 256
      elseif resultB == OP_ADVANCE then dpB = dpB - 1
      elseif resultB == OP_RETREAT then dpB = dpB + 1
      elseif resultB == OP_TEST    then resB = testB end
    end

    local isZeroA, isZeroB = tape[1] == 0, tape[tapeLength] == 0

    local lostA, lostB = false, false
    if dpA < 1 or dpA > tapeLength then lostA = true end
    if dpB < 1 or dpB > tapeLength then lostB = true end
    if isZeroA and lastZeroA       then lostA = true end
    if isZeroB and lastZeroB       then lostB = true end

    if lostA and lostB then return RESULT_TIED   end
    if lostA           then return RESULT_B_WINS end
    if lostB           then return RESULT_A_WINS end

    lastZeroA, lastZeroB = isZeroA, isZeroB
  end

  return RESULT_TIED
end

local function resultChar(result)
  if result == RESULT_TIED   then return "X" end
  if result == RESULT_A_WINS then return "<" end
  if result == RESULT_B_WINS then return ">" end
  return "?"
end
local function luaJoust(programA, programB)
  local resultStr = ""
  local score     = 0

  local function runGame(tapeLength, isKettle)
    local result = runRound(programA, programB, tapeLength, isKettle)
    resultStr = resultStr..resultChar(result)
    score = score + result
  end

  for i=10,30 do runGame(i, false) end
  resultStr = resultStr.." "
  for i=10,30 do runGame(i, true) end

  return score, resultStr
end

----------------------
-- Input Processing --
----------------------

local programs = {...}
if #programs < 2 then
  fatalerr("Usage: ./luajoust.lua [program a] [program b] [program c] ...", -2)
end

for i, k in ipairs(programs) do
  local handle, err = io.open(k, "r")
  if not handle then
    fatalerr("Could not read file "..k..": "..err, i)
  end
  local contents = handle:read("a")
  handle:close()

  local fn, err = compileProgram(k, contents)
  if not fn then
    fatalerr("Failed to compile file "..k..": "..err, i)
  end

  programs[i] = { name = k, fn = fn }
end

if #programs == 2 then
  local score, resultStr = luaJoust(programs[1].fn, programs[2].fn)
  print(resultStr.." "..score)
else
  for idxA=1,#programs do
    for idxB=idxA+1,#programs do
      local score, resultStr = luaJoust(programs[idxA].fn, programs[idxB].fn)
      print(programs[idxA].name.." vs "..programs[idxB].name)
      print(resultStr.." "..score)
      print()
    end
  end
end
