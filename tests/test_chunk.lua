-- tests/test_chunk.lua -- lib/chunk.lua against real REAPER state. Plain Lua.

local HERE = (arg and arg[0] or ''):match('^(.*[/\\])') or './'
package.path = HERE .. '../Reaper/Scripts/MXM_ListOfInstrumentsAndEffects/lib/?.lua;' ..
               package.path

local chunk = require 'chunk'

local pass, fail, failures = 0, 0, {}

local function check(ok, label, detail)
  if ok then
    pass = pass + 1
  else
    fail = fail + 1
    failures[#failures + 1] = label .. (detail and ('  -- ' .. detail) or '')
  end
end

local function shows(got, want, label)
  local ok = type(got) == 'table' and #got == #want
  if ok then
    for i, w in ipairs(want) do
      if got[i].name ~= w.name or got[i].js ~= w.js then ok = false end
    end
  end
  local seen = {}
  for _, e in ipairs(type(got) == 'table' and got or {}) do
    seen[#seen + 1] = e.name or ('js:' .. tostring(e.js))
  end
  check(ok, label, ok and nil or ('got [' .. table.concat(seen, ', ') .. ']'))
end

--[[ Captured from REAPER 7.80 with chunk_probe.lua: one CLAP instrument, then
  an OFFLINE container holding two JSFX. The base64 <STATE> lines are shortened
  -- they are opaque data either way, and what matters is that the walker does
  not mistake them for anything. ]]
local REAL = [==[
<FXCHAIN
WNDRECT 1160 459 1036 284
SHOW 2
LASTSEL 1
DOCKED 0
BYPASS 0 0 0
<CLAP "CLAPi: Deimos (TomTrnkAudio)" com.TomTrnkAudio.Deimos ""
CFG 4 960 684 ""
<STATE
bxQAAEXcsjMButkVAwAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAZgwAAABNYXN0
AFBvbHlEYW1wQW1vdW50AAAAAGkHAAAAUm5kU2VlZAAAAABmBQAAAEdsaWRl
>
>
MULTIFXLINK 0
FLOATPOS 0 0 0 0
FXID {75F6EF50-0EB7-BD4A-81E9-8989569E7152}
WAK 0 0
BYPASS 0 1 0
<CONTAINER Container ""
CONTAINER_CFG 2 2 2 0
<IN_PINS
>
<OUT_PINS
>
SHOW 0
LASTSEL 1
DOCKED 0
BYPASS 0 0 0
<JS sstillwell/3x3 ""
0 0 0 0 0 0 240 2400 - - - - - - - - - - - - - - - - - - - -
>
MULTIFXLINK 0
FLOATPOS 0 0 0 0
FXID {424B931E-7F4D-8D49-A692-00F57E8BD67D}
WAK 0 0
BYPASS 0 0 0
<JS loser/3BandEQ ""
0 200 0 2000 0 0 - - - - - - - - - - - - - - - - - - - - - -
>
MULTIFXLINK 0
FLOATPOS 0 0 0 0
FXID {A43B9101-57FA-B643-9D62-09FE12500C67}
WAK 0 0
>
MULTIFXLINK 0
FLOATPOS 0 0 0 0
FXID {829A47CD-3E70-CA44-8178-E3B6FA84CC62}
WAK 0 0
>
]==]

shows(chunk.container_contents(REAL, 'FXCHAIN', { 1 }),
      { { js = 'sstillwell/3x3' }, { js = 'loser/3BandEQ' } },
      'the offline container yields both JSFX, in chain order')

check(chunk.container_contents(REAL, 'FXCHAIN', { 0 }) == nil,
      'an FX that is not a container yields nothing')
check(chunk.container_contents(REAL, 'FXCHAIN', { 9 }) == nil,
      'an index past the end of the chain yields nothing')
check(chunk.container_contents(REAL, 'FXCHAIN_REC', { 1 }) == nil,
      'a chain the track does not have yields nothing, not the wrong one')
check(chunk.container_contents(REAL, 'FXCHAIN', { 1, 0 }) == nil,
      'a plain JSFX addressed as a container yields nothing')

for _, junk in ipairs({ '', 'not a chunk at all', '<FXCHAIN\n>\n' }) do
  check(chunk.container_contents(junk, 'FXCHAIN', { 0 }) == nil,
        'rubbish in, nothing out: ' .. ('%q'):format(junk:sub(1, 20)))
end
check(chunk.container_contents(nil, 'FXCHAIN', { 0 }) == nil, 'a nil chunk yields nothing')

--[[ Nesting, and a plugin that names itself in the usual quoted field. The VST
  line carries an embedded <...> on the same line, the way REAPER writes one. ]]
local NESTED = [==[
<FXCHAIN
BYPASS 0 1 0
<CONTAINER Container ""
CONTAINER_CFG 2 2 2 0
<IN_PINS
>
<OUT_PINS
>
BYPASS 0 0 0
<VST "VST3i: Serum (Xfer Records)" Serum.vst3 0 "" 1919247213<5678> ""
ZG9uZQ==
>
FXID {A}
WAK 0 0
BYPASS 0 0 0
<CONTAINER Container "Inner"
CONTAINER_CFG 2 2 2 0
BYPASS 0 0 0
<JS loser/3BandEQ ""
0
>
FXID {B}
WAK 0 0
>
FXID {C}
WAK 0 0
>
FXID {D}
WAK 0 0
>
]==]

shows(chunk.container_contents(NESTED, 'FXCHAIN', { 0 }),
      { { name = 'VST3i: Serum (Xfer Records)' }, { js = 'loser/3BandEQ' } },
      'a nested container is flattened into its parent')

shows(chunk.container_contents(NESTED, 'FXCHAIN', { 0, 1 }),
      { { js = 'loser/3BandEQ' } },
      'the inner container can be addressed on its own')

--------------------------------------------------------------------- report
io.write(('chunk: %d passed, %d failed\n'):format(pass, fail))
for _, f in ipairs(failures) do io.write('  FAIL  ' .. f .. '\n') end
os.exit(fail == 0 and 0 or 1)
