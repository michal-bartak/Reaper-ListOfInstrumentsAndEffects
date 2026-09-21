-- tests/scan.lua -- lib/scan.lua against a fixture project. Plain Lua, no REAPER.

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

--------------------------------------------------------------------- fixture
local PROJECT = {
  tracks = {
    { fx  = { { name = 'Serum',   type = 'VST3i' },
              { name = 'ReaEQ',   type = 'VST'   },
              { name = 'Volume'                  } },  -- fx_type unavailable
      rec = { { name = 'ReaGate', type = 'VST'   } } },

    { fx  = { { name = 'Serum',          type = 'VST3i' },
              { name = 'Bypassed Synth', type = 'VSTi', bypassed = true },
              { name = 'Offline Comp',   type = 'VST',  offline  = true },
              { name = 'ReaJS',          type = 'JS'    } } },
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
  },
}

mockreaper.install(PROJECT)
local scan = require 'scan'
local b = scan.scan(0)

----------------------------------------------------------------- assertions
bucket_is(b, 'instruments', {
  Serum = 2,   -- an instrument on a track, counted once per instance
  Vital = 1,   -- an instrument on the ACTIVE take of an item
})

bucket_is(b, 'effects', {
  ReaEQ    = 1,
  Volume   = 1,   -- fx_type unavailable is not an instrument
  ReaJS    = 1,   -- JS does not end in "i"
  ReaLimit = 1,   -- master track FX
  ReaDelay = 1,   -- an effect on the active take of an item
})

bucket_is(b, 'inputfx', {
  ReaGate = 1,    -- a track's record-input chain, not the master's
})

bucket_is(b, 'monitoring', {
  ReaFIR = 1,     -- the master's record chain is the monitoring chain
})

bucket_is(b, 'offline', {
  ['Bypassed Synth'] = 1,   -- bypassed loses its instrument-ness, as before
  ['Offline Comp']   = 1,
  Sylenth            = 1,   -- on a take that is not the one playing back
  Vital              = 1,   -- bypassed, even on the active take
})

-- The empty take slot must not have been walked as if it were a take.
check(b.effects['Vital'] == nil, 'an empty take slot is skipped')

-- An empty project must still answer with five empty buckets.
mockreaper.install({})
local empty = scan.scan(0)
for _, name in ipairs({ 'instruments', 'effects', 'inputfx', 'monitoring', 'offline' }) do
  check(type(empty[name]) == 'table' and next(empty[name]) == nil,
        'empty project: ' .. name .. ' is empty')
end

--------------------------------------------------------------------- report
io.write(('scan: %d passed, %d failed\n'):format(pass, fail))
for _, f in ipairs(failures) do io.write('  FAIL  ' .. f .. '\n') end
os.exit(fail == 0 and 0 or 1)
