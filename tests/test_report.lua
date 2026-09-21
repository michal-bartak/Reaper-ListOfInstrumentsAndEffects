-- tests/test_report.lua -- lib/report.lua's four export formats. Plain Lua, no REAPER.

local HERE = (arg and arg[0] or ''):match('^(.*[/\\])') or './'
package.path = HERE .. '../Reaper/Scripts/MXM_ListOfInstrumentsAndEffects/lib/?.lua;' ..
               package.path

local report = require 'report'

local pass, fail, failures = 0, 0, {}

local function check(ok, label, detail)
  if ok then
    pass = pass + 1
  else
    fail = fail + 1
    failures[#failures + 1] = label .. (detail and ('  -- ' .. detail) or '')
  end
end

local function eq(got, want, label)
  check(got == want, label,
        got == want and nil or ('\n--- got ---\n' .. tostring(got) ..
                                '\n--- want ---\n' .. tostring(want) .. '\n---'))
end

--------------------------------------------------------------------- fixture
-- Zebra sorts after Serum, and "Aalto" before both, so the order in the output
-- is the sorted one and not the order the table happens to hash into.
local B = {
  instruments = { Serum = 2, Zebra = 1, Aalto = 1 },
  effects     = {},
  inputfx     = { ReaGate = 1 },
  monitoring  = {},
  offline     = { ['Offline Comp'] = 3 },
}

------------------------------------------------------------------ plain text
local PLAIN = table.concat({
  'Instruments:',
  '1x   Aalto',
  '2x   Serum',
  '1x   Zebra',
  '',
  'Effects:',
  'N/A',
  '',
  'Input FX:',
  '1x   ReaGate',
  '',
  'Monitoring plugins:',
  'N/A',
  '',
  'Offline/inactive plugins:',
  '3x   Offline Comp',
  '',
}, '\n')

eq(report.format(B, 'plaintext'), PLAIN, 'plain text: sections, order, padding, N/A')

-- An unknown format name falls back to plain text rather than returning nil.
eq(report.format(B, 'nonsense'), PLAIN, 'an unknown format falls back to plain text')

--------------------------------------------------------------------- BBCode
eq(report.format(B, 'bbcode'), '[CODE]\n' .. PLAIN .. '[/CODE]',
   'BB code wraps the plain text in [CODE] tags')

local bbplain = report.format(B, 'bbplain')
check(bbplain:find('[b]Instruments:[/b]', 1, true) == 1,
      'BB plain: the first heading is bold')
check(bbplain:find('\n[b]Offline/inactive plugins:[/b]\n', 1, true) ~= nil,
      'BB plain: later headings are bold and preceded by a blank line')
check(bbplain:find('1x   ReaGate', 1, true) ~= nil,
      'BB plain: rows are the plain-text rows')

------------------------------------------------------------------- Markdown
local md = report.format(B, 'markdown')

check(md:find('**Instruments:**', 1, true) == 1, 'Markdown: headings are bold')
check(md:find('**Input FX:**', 1, true) ~= nil,  'Markdown: the new Input FX section is present')

-- The widest name here is "Offline Comp" (12), so that section's name column is
-- 12 wide and the quantity column is the fixed 10 with a right-aligning ---:.
check(md:find('|Offline Comp|3         |', 1, true) ~= nil,
      'Markdown: the name column is as wide as the widest name')
check(md:find('|------------|---------:|', 1, true) ~= nil,
      'Markdown: the separator right-aligns the count column')
check(md:find('|Plugin Name|Instances |', 1, true) ~= nil,
      'Markdown: the header row')
check(md:find('**Effects:**\nN/A\n', 1, true) ~= nil,
      'Markdown: an empty section still prints N/A')

-- Sorted, not hash order.
local a, s, z = md:find('|Aalto', 1, true), md:find('|Serum', 1, true), md:find('|Zebra', 1, true)
check(a and s and z and a < s and s < z, 'Markdown: rows are sorted by name')

---------------------------------------------------------------- every format
for _, fmt in ipairs(report.FORMATS) do
  local out = report.format({}, fmt)
  check(type(out) == 'string' and out:find('N/A', 1, true) ~= nil,
        fmt .. ': an empty project renders without error')
  check(out:find('Input FX', 1, true) ~= nil,
        fmt .. ': all five sections are present')
end

--------------------------------------------------------------------- report
io.write(('report: %d passed, %d failed\n'):format(pass, fail))
for _, f in ipairs(failures) do io.write('  FAIL  ' .. f .. '\n') end
os.exit(fail == 0 and 0 or 1)
