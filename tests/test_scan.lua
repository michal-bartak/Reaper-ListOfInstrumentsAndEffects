-- tests/test_scan.lua -- lib/scan.lua against a fixture project. Plain Lua, no REAPER.

local HERE = (arg and arg[0] or ''):match('^(.*[/\\])') or './'
package.path = HERE .. '?.lua;' ..
               HERE .. '../Reaper/Scripts/MXM_ListOfInstrumentsAndEffects/lib/?.lua;' ..
               package.path

local mockreaper = require 'mockreaper'

local pass, fail, failures = 0, 0, {}

local function check(ok, label, detail)
  if ok then
    pass = pass + 1
  else
    fail = fail + 1
    failures[#failures + 1] = label .. (detail and ('  -- ' .. detail) or '')
  end
end

-- Compares a bucket against the counts it should hold, and nothing else.
local function bucket_is(b, name, want)
  local got = b[name]
  for k, v in pairs(want) do
    check(got[k] == v, name .. ': ' .. k .. ' = ' .. v,
          'got ' .. tostring(got[k]))
  end
  for k, v in pairs(got) do
    check(want[k] ~= nil, name .. ': no stray entries', k .. ' = ' .. v)
  end
end

--[[ A throwaway Effects tree, so the JSFX desc: lookup runs for real rather
  than being stubbed out. REAPER shows "JS: 3-Band EQ" where the chunk only
  says "loser/3BandEQ". ]]
local EFFECTS = (os.getenv('TMPDIR') or '/tmp/') .. 'lioae-test-' .. os.time()
os.execute('mkdir -p ' .. EFFECTS .. '/Effects/loser')
local jsfx = assert(io.open(EFFECTS .. '/Effects/loser/3BandEQ', 'w'))
jsfx:write('// a fixture\ndesc:3-Band EQ\nslider1:0<0,1,0.01>x\n')
jsfx:close()

--[[ Track 4's state, as REAPER writes it. Index 0 is the MUTED container,
  whose contents the FX API can still enumerate -- the names here are decoys
  that must never be used. Index 1 is the OFFLINE one, which the API cannot
  read, so these names are the only ones there are. ]]
local TRACK4_CHUNK = [==[
<FXCHAIN
BYPASS 0 0 0
<CONTAINER Container ""
CONTAINER_CFG 2 2 2 0
<IN_PINS
>
BYPASS 0 0 0
<VST "DECOY -- read from the chunk when it should not have been" x.dll 0 "" 0<> ""
>
FXID {1}
WAK 0 0
>
FXID {2}
WAK 0 0
BYPASS 0 1 0
<CONTAINER Container ""
CONTAINER_CFG 2 2 2 0
BYPASS 0 0 0
<VST "VST: Frozen Comp (Cockos)" y.dll 0 "" 0<> ""
>
FXID {3}
WAK 0 0
BYPASS 0 0 0
<JS loser/3BandEQ ""
0 200 0 2000
>
FXID {4}
WAK 0 0
>
FXID {5}
WAK 0 0
>
]==]

--------------------------------------------------------------------- fixture
local PROJECT = {
  resource = EFFECTS,
  tracks = {
    { fx  = { { name = 'Serum',   type = 'VST3i' },
              { name = 'ReaEQ',   type = 'VST'   },
              { name = 'Volume'                  } },  -- fx_type unavailable
      rec = { { name = 'ReaGate', type = 'VST'   } } },

    { fx  = { { name = 'Serum',          type = 'VST3i' },
              { name = 'Bypassed Synth', type = 'VSTi', bypassed = true },
              { name = 'Offline Comp',   type = 'VST',  offline  = true },
              { name = 'ReaJS',          type = 'JS'    } } },

    -- Containers. 'Band Split' carries the type REAPER really reports, to show
    -- the walk recognises a container by container_count and not by its type.
    { fx  = { { name = 'Band Split', type = 'Container', container = {
                  { name = 'ReaComp', type = 'VST'  },
                  { name = 'Massive', type = 'VSTi' },
                  { name = 'Inner',   container = {          -- nested one deeper
                      { name = 'ReaVerb', type = 'VST' } } } } },

              { name = 'Empty Box', container = {} } },      -- tallies nothing

      rec = { { name = 'Rec Box', container = {
                  { name = 'ReaXcomp', type = 'VST' } } } } },

    -- A muted or offline container takes everything it holds down with it,
    -- however deep -- REAPER leaves the contents reading as enabled.
    { fx  = { { name = 'Muted Box', bypassed = true, container = {
                  { name = 'Hidden Synth', type = 'VSTi' },
                  { name = 'Deep Box', container = {
                      { name = 'Hidden Verb', type = 'VST' } } } } },

              -- Offline: the FX API answers nothing about what is in here, so
              -- this name is a decoy too. The chunk is the only source.
              { name = 'Offline Box', offline = true, container = {
                  { name = 'NEVER REACHED', type = 'VST' } } } },
      chunk = TRACK4_CHUNK },
  },

  master = {
    fx  = { { name = 'ReaLimit', type = 'VST' } },
    rec = { { name = 'ReaFIR',   type = 'VST' } },
  },

  items = {
    -- take 0 is active: its instrument counts, the other take's does not
    { active = 0, takes = { { fx = { { name = 'Vital',   type = 'CLAPi' } } },
                            { fx = { { name = 'Sylenth', type = 'VSTi'  } } } } },

    -- an empty take slot, then the active take carrying an effect
    { active = 1, takes = { false,
                            { fx = { { name = 'ReaDelay', type = 'VST' } } } } },

    -- bypassed on the active take is still inactive
    { active = 0, takes = { { fx = { { name = 'Vital', type = 'CLAPi',
                                       bypassed = true } } } } },

    -- a container on a take
    { active = 0, takes = { { fx = { { name = 'Take Box', container = {
                                        { name = 'Kontakt', type = 'VSTi' } } } } } } },
  },
}

mockreaper.install(PROJECT)
local scan = require 'scan'
local b = scan.scan(0)

----------------------------------------------------------------- assertions
bucket_is(b, 'instruments', {
  Serum   = 2,   -- an instrument on a track, counted once per instance
  Vital   = 1,   -- an instrument on the ACTIVE take of an item
  Massive = 1,   -- an instrument inside a container
  Kontakt = 1,   -- an instrument inside a container on a take
})

bucket_is(b, 'effects', {
  ReaEQ    = 1,
  Volume   = 1,   -- fx_type unavailable is not an instrument
  ReaJS    = 1,   -- JS does not end in "i"
  ReaLimit = 1,   -- master track FX
  ReaDelay = 1,   -- an effect on the active take of an item
  ReaComp  = 1,   -- inside a container
  ReaVerb  = 1,   -- inside a container inside a container
})

bucket_is(b, 'inputfx', {
  ReaGate  = 1,   -- a track's record-input chain, not the master's
  ReaXcomp = 1,   -- inside a container in the record-input chain
})

bucket_is(b, 'monitoring', {
  ReaFIR = 1,     -- the master's record chain is the monitoring chain
})

bucket_is(b, 'offline', {
  ['Bypassed Synth'] = 1,   -- bypassed loses its instrument-ness, as before
  ['Offline Comp']   = 1,
  Sylenth            = 1,   -- on a take that is not the one playing back
  Vital              = 1,   -- bypassed, even on the active take
  ['Hidden Synth']   = 1,   -- inside a MUTED container
  ['Hidden Verb']    = 1,   -- two levels down from that muted container

  -- Read out of the project state: REAPER unloads an offline container and
  -- answers nothing about it through any FX index.
  ['VST: Frozen Comp (Cockos)'] = 1,
  ['JS: 3-Band EQ']             = 1,   -- desc: resolved, not the chunk's path
})

-- The chunk is a last resort, not a shortcut: a container the FX API CAN read
-- must be read from the API, decoys and all.
check(b.offline['NEVER REACHED'] == nil,
      'the FX API is not consulted for an offline container')
for name in pairs(b.offline) do
  check(not name:find('DECOY', 1, true),
        'the chunk is not consulted for a container the API can enumerate',
        name)
end

-- The empty take slot must not have been walked as if it were a take.
check(b.effects['Vital'] == nil, 'an empty take slot is skipped')

-- A container is a wrapper, not a plugin anyone installed, so it is never
-- named in the report -- not even the empty one, and not the one that reports
-- fx_type "Container".
for _, name in ipairs({ 'Band Split', 'Inner', 'Empty Box', 'Rec Box',
                        'Muted Box', 'Deep Box', 'Offline Box', 'Take Box' }) do
  local found
  for bucket, counts in pairs(b) do
    if counts[name] then found = bucket end
  end
  check(not found, 'a container is never tallied: ' .. name,
        found and ('landed in ' .. found))
end

-- An empty project must still answer with five empty buckets.
mockreaper.install({})
local empty = scan.scan(0)
for _, name in ipairs({ 'instruments', 'effects', 'inputfx', 'monitoring', 'offline' }) do
  check(type(empty[name]) == 'table' and next(empty[name]) == nil,
        'empty project: ' .. name .. ' is empty')
end

--[[ REAPER 6, where none of this exists.

  Containers arrived in 7, so nothing reports fx_type "Container" and every
  container_count fails. An FX REAPER will say nothing at all about must still
  be classified, not mistaken for a wrapper and skipped.
]]
mockreaper.install({ tracks = { { fx = { { name = 'ReaComp', type = 'VST' } } } } })
_G.reaper.TrackFX_GetNamedConfigParm = function() return false, '' end
local r6 = scan.scan(0)
check(r6.effects['ReaComp'] == 1,
      'REAPER 6: an FX is still classified when nothing can be asked about it')

--[[ REAPER 7.00-7.05, where container_count works but container_item.N does not.

  Nothing inside can be addressed, so the contents are missed -- but the
  container is still not a plugin and must not be reported as one.
]]
mockreaper.install({ tracks = { { fx = {
  { name = 'Band Split', container = { { name = 'ReaComp', type = 'VST' } } } } } } })
local inner = _G.reaper.TrackFX_GetNamedConfigParm
_G.reaper.TrackFX_GetNamedConfigParm = function(o, i, parm)
  if parm:match('^container_item%.') then return false, '' end
  return inner(o, i, parm)
end
local r705 = scan.scan(0)
check(next(r705.effects) == nil and next(r705.instruments) == nil,
      'REAPER 7.00-7.05: an unreachable container is skipped, not reported')

--------------------------------------------------------------------- report
os.execute('rm -rf ' .. EFFECTS)

io.write(('scan: %d passed, %d failed\n'):format(pass, fail))
for _, f in ipairs(failures) do io.write('  FAIL  ' .. f .. '\n') end
os.exit(fail == 0 and 0 or 1)
