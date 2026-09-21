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

local function PadColumn(content, len)
  local s = tostring(content)
  return s .. string.rep(' ', len - #s)
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

local function markdown_table(counts)
  local maxnamewidth, quantitywidth, found = 0, 10, false

  for name in pairs(counts) do
    maxnamewidth = math.max(maxnamewidth, #name)
    found = true
  end

  if not found then return 'N/A\n' end

  local msg = ''
  msg = msg .. '|' .. PadColumn('Plugin Name', maxnamewidth)
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

--[[ Renders buckets in one of the formats named in M.FORMATS.

  Sections are separated by a blank line, with none before the first, and an
  empty section still prints its heading over "N/A" so the reader can tell the
  question was asked.
]]
function M.format(buckets, fmt)
  local f = FORMATS[fmt] or FORMATS.plaintext
  local msg = f.prefix or ''

  for i, section in ipairs(SECTIONS) do
    local key, title = section[1], section[2]
    if i > 1 then msg = msg .. '\n' end
    msg = msg .. f.heading(title) .. '\n' .. f.render(buckets[key] or {})
  end

  return msg .. (f.suffix or '')
end

return M
