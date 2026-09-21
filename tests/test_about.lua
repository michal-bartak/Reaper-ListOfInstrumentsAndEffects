-- tests/test_about.lua -- the version the About dialog shows is the version ReaPack ships.

local HERE = (arg and arg[0] or ''):match('^(.*[/\\])') or './'
local REPO = HERE .. '../'
package.path = REPO .. 'Reaper/Scripts/MXM_ListOfInstrumentsAndEffects/lib/?.lua;' .. package.path

local about = require 'about'

local pass, fail, failures = 0, 0, {}

local function check(ok, label, detail)
  if ok then
    pass = pass + 1
  else
    fail = fail + 1
    failures[#failures + 1] = label .. (detail and ('  -- ' .. detail) or '')
  end
end

local MANIFEST = REPO .. 'Various/MXM_List of Instruments and Effects.lua'
local f = assert(io.open(MANIFEST, 'r'), 'cannot read ' .. MANIFEST)
local manifest = f:read('a')
f:close()

local shipped = manifest:match('%-%-%s*@version%s+(%S+)')

check(shipped ~= nil, 'the manifest declares a @version')
check(shipped == about.VERSION,
      'about.VERSION matches the manifest',
      'manifest ' .. tostring(shipped) .. ', about.lua ' .. tostring(about.VERSION))

for _, key in ipairs({ 'NAME', 'AUTHOR', 'LICENCE', 'COPYRIGHT', 'TAGLINE' }) do
  check(type(about[key]) == 'string' and about[key] ~= '', 'about.' .. key .. ' is set')
end

for _, key in ipairs({ 'URL_REPO', 'URL_DOCS' }) do
  check((about[key] or ''):match('^https://') ~= nil, 'about.' .. key .. ' is an https URL',
        tostring(about[key]))
end

io.write(('about: %d passed, %d failed\n'):format(pass, fail))
for _, x in ipairs(failures) do io.write('  FAIL  ' .. x .. '\n') end
os.exit(fail == 0 and 0 or 1)
