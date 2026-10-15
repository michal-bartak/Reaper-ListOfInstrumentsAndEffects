--[[
  chunk.lua -- pulls plugin names out of a REAPER state chunk.

  Needed for exactly one thing: an OFFLINE container. REAPER unloads its
  contents, and then nothing reaches them through an FX index -- not
  container_count, not container_item.N, not the raw 0x2000000 arithmetic.
  Only fx_type still answers, and all it says is "Container". The project state
  does still carry them, though; it has to, or saving would lose them.

  Pure string work: no reaper.*, so tests/ drive it against a chunk captured
  from a real project.

  The shape it leans on, as REAPER 7.80 writes it:

      <FXCHAIN
      BYPASS 0 0 0
      <CLAP "CLAPi: Deimos (TomTrnkAudio)" com.TomTrnkAudio.Deimos ""
      CFG 4 960 684 ""
      <STATE
      bxQAAEXcsjMButkVAwAAA...
      >
      >
      FXID {75F6EF50-0EB7-BD4A-81E9-8989569E7152}
      BYPASS 0 1 0
      <CONTAINER Container ""
      CONTAINER_CFG 2 2 2 0
      <IN_PINS
      >
      BYPASS 0 0 0
      <JS sstillwell/3x3 ""
      0 0 0 0 0 0 240 2400 - - -
      >
      >

  One token per line, '<' opens a block and a lone '>' closes it. Every FX --
  the container included -- is preceded by a BYPASS line, and nothing else is.
  That is what separates an FX from the <STATE>, <IN_PINS> and <OUT_PINS>
  blocks sitting at the same depth, without having to know every plugin tag
  REAPER might ever write.
]]

local M = {}

local function split(chunk)
  local out = {}
  for line in chunk:gmatch('[^\r\n]+') do
    out[#out + 1] = line:match('^%s*(.-)%s*$')
  end
  return out
end

--- The line the named block opens on, or nil. Anchored, so FXCHAIN does not
--- also match FXCHAIN_REC.
local function find_block(L, tag)
  for i = 1, #L do
    local line = L[i]
    if line == '<' .. tag or line:match('^<' .. tag .. '%s') then return i end
  end
end

--[[ The FX that are direct children of the block opening at `from`.

  In order, so the nth entry is FX index n-1 within that chain or container --
  the same order the FX API counts in.
]]
local function fx_children(L, from)
  local kids, depth, open = {}, 0, nil

  for i = from, #L do
    local line = L[i]

    if line:sub(1, 1) == '<' then
      depth = depth + 1
      if depth == 2 then
        -- An FX, and not a <STATE>/<IN_PINS>/<OUT_PINS>, iff BYPASS precedes it.
        if (L[i - 1] or ''):match('^BYPASS%s') then
          local tag, rest = line:match('^<(%S+)%s*(.*)$')
          open = { tag = tag, rest = rest or '', open = i }
        else
          open = nil
        end
      end

    elseif line == '>' then
      if depth == 2 and open then
        kids[#kids + 1] = open
        open = nil
      end
      depth = depth - 1
      if depth == 0 then break end
    end
  end

  return kids
end

--[[ What one FX opening line calls itself.

  Most plugins put the name REAPER displays in the first quoted field:
      <CLAP "CLAPi: Deimos (TomTrnkAudio)" com.TomTrnkAudio.Deimos ""
      <VST "VST3: ReaEQ (Cockos)" reaeq.vst3 0 "" ...
  A JSFX instead names the effect FILE, and the displayed name lives in that
  file's desc: line -- which is not this module's business, so the path comes
  back as { js = ... } for the caller to resolve.
]]
local function name_of(kid)
  local quoted = kid.rest:match('^"([^"]*)"')
  if quoted and quoted ~= '' then return { name = quoted } end

  local bare = kid.rest:match('^(%S+)')
  if kid.tag == 'JS' then return { js = bare } end
  return { name = bare or kid.tag }
end

local function collect(L, open, out)
  for _, kid in ipairs(fx_children(L, open)) do
    if kid.tag == 'CONTAINER' then
      collect(L, kid.open, out)     -- flattened: it is all inactive regardless
    else
      out[#out + 1] = name_of(kid)
    end
  end
end

--[[ Everything inside the container `path` names, at any depth.

  `tag` is the chain block to look in -- FXCHAIN for a track's own chain,
  FXCHAIN_REC for its record/input chain. `path` is the list of 0-based FX
  ordinals leading to the container, from the chain downwards: { 1 } for the
  second FX in the chain, { 1, 0 } for the first FX inside that one.

  Returns a list of { name = '...' } and { js = 'path' }, or nil when the chain
  or the container cannot be found. nil means "say nothing", never "there is
  nothing" -- a wrong name is worse than a missing one.
]]
function M.container_contents(chunk, tag, path)
  if type(chunk) ~= 'string' or chunk == '' then return nil end

  local L = split(chunk)
  local open = find_block(L, tag)
  if not open then return nil end

  local node
  for _, ordinal in ipairs(path) do
    node = fx_children(L, open)[ordinal + 1]
    if not node then return nil end
    open = node.open
  end

  if not node or node.tag ~= 'CONTAINER' then return nil end

  local out = {}
  collect(L, open, out)
  return out
end

return M
