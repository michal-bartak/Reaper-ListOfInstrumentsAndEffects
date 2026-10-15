--[[
  report.lua -- turns the buckets scan.lua produces into the four export formats.

  Pure string work: it never touches reaper.* or ImGui, so tests/ can check every
  format under plain Lua.

  The section list below is the single source of order and wording. The formats
  differ only in how a heading is decorated and how a table is drawn, which is
  what keeps them from drifting apart the way four hand-written copies did.
]]

local M = {}

local SECTIONS = {
  { 'instruments', 'Instruments'              },
  { 'effects',     'Effects'                  },
  { 'inputfx',     'Input FX'                 },
  { 'monitoring',  'Monitoring plugins'       },
  { 'offline',     'Offline/inactive plugins' },
}

-- Characters, not bytes. A vendor or plugin name carrying an accent is more
-- bytes than characters, and its column came out short by the difference.
-- Codepoints, not display columns: a CJK name still misaligns, which nothing
-- short of a width table would fix, and plugin names are not that.
local function width(s)
  return utf8.len(s) or #s          -- nil on a malformed sequence
end

local function PadColumn(content, len)
  local s = tostring(content)
  return s .. string.rep(' ', math.max(0, len - width(s)))
end

-- Sorted-key iterator. From https://stackoverflow.com/a/15706820
local function spairs(t, order)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end

  if order then
    table.sort(keys, function(a, b) return order(t, a, b) end)
  else
    table.sort(keys)
  end

  local i = 0
  return function()
    i = i + 1
    if keys[i] then return keys[i], t[keys[i]] end
  end
end

local function by_name(t, a, b) return a < b end

local function plain_table(counts)
  local msg, found = '', false

  for name, quantity in spairs(counts, by_name) do
    msg = msg .. PadColumn(quantity .. 'x ', 5) .. name .. '\n'
    found = true
  end

  return found and msg or 'N/A\n'
end

local NAME_HEADER = 'Plugin Name'

local function markdown_table(counts)
  -- The heading is a cell like any other, so it sets the floor for the column.
  -- Left out, a section whose widest name was shorter than "Plugin Name" drew a
  -- heading that overhung its own column and the counts stopped lining up.
  local maxnamewidth, quantitywidth, found = width(NAME_HEADER), 10, false

  for name in pairs(counts) do
    maxnamewidth = math.max(maxnamewidth, width(name))
    found = true
  end

  if not found then return 'N/A\n' end

  local msg = ''
  msg = msg .. '|' .. PadColumn(NAME_HEADER, maxnamewidth)
  msg = msg .. '|' .. PadColumn('Instances', quantitywidth) .. '|\n'
  msg = msg .. '|' .. PadColumn(string.rep('-', maxnamewidth), maxnamewidth)
  msg = msg .. '|' .. PadColumn(string.rep('-', quantitywidth - 1) .. ':', quantitywidth) .. '|\n'

  for name, quantity in spairs(counts, by_name) do
    msg = msg .. '|' .. PadColumn(name, maxnamewidth)
    msg = msg .. '|' .. PadColumn(quantity, quantitywidth) .. '|\n'
  end

  return msg
end

local FORMATS = {
  plaintext = { heading = function(t) return t .. ':'              end, render = plain_table    },
  markdown  = { heading = function(t) return '**' .. t .. ':**'    end, render = markdown_table },
  bbplain   = { heading = function(t) return '[b]' .. t .. ':[/b]' end, render = plain_table    },
  bbcode    = { heading = function(t) return t .. ':'              end, render = plain_table,
                prefix = '[CODE]\n', suffix = '[/CODE]' },
}

M.FORMATS = { 'plaintext', 'markdown', 'bbplain', 'bbcode' }

--- The DAW line, from reaper.GetAppVersion(): "7.42/macOS-arm64" -> "REAPER 7.42".
--- What follows the slash is the build's platform and architecture, which says
--- nothing about the production. Taken as an argument, so this module still
--- never touches reaper.*.
function M.daw(appversion)
  local v = tostring(appversion or ''):match('^([^/]+)')
  return v and ('REAPER ' .. v) or 'REAPER'
end

--[[ Renders buckets in one of the formats named in M.FORMATS.

  Sections are separated by a blank line, with none before the first, and an
  empty section still prints its heading over "N/A" so the reader can tell the
  question was asked.

  `daw`, when given, heads the report in a section of its own -- see M.daw().
]]
function M.format(buckets, fmt, daw)
  local f = FORMATS[fmt] or FORMATS.plaintext
  local msg = f.prefix or ''

  if daw then
    msg = msg .. f.heading('DAW') .. '\n' .. daw .. '\n\n'
  end

  for i, section in ipairs(SECTIONS) do
    local key, title = section[1], section[2]
    if i > 1 then msg = msg .. '\n' end
    msg = msg .. f.heading(title) .. '\n' .. f.render(buckets[key] or {})
  end

  return msg .. (f.suffix or '')
end

return M
