--[[
  scan.lua -- walks every FX chain in a project and tallies plugin names.

  Pure logic: it talks to reaper.* and nothing else, so tests/ can drive it
  under plain Lua against tests/mockreaper.lua.

  REAPER keeps FX in more places than the chain on a track. A track also has a
  record-input chain, the master track's input chain is the monitoring chain,
  and every take of every media item can carry its own chain -- instruments
  included, which is how a MIDI item makes sound without an instrument on the
  track. Since REAPER 7 an FX can also be a CONTAINER holding a chain of its
  own, nested as deep as you like. All of them are counted here.
]]

local chunk = require 'chunk'

local M = {}

-- Selects the record/input chain instead of the normal one. The same bit means
-- "monitoring" on the master track and "input FX" on any other track.
M.MONITORINGIDX = 0x1000000

-- How far to follow containers inside containers. Real projects nest a level
-- or two; this is only here so a malformed reply cannot spin forever inside a
-- defer loop.
local MAX_DEPTH = 16

--[[ The FX addresses inside a container, or nil if idx is not a container.

  container_item.N hands back a ready-made address, with the 0x2000000
  container bit and any 0x1000000 record-chain bit already set. Working it out
  here instead would mean reproducing REAPER's mixed-radix scheme, whose
  multiplier for a container sitting in a RECORD chain is undocumented -- so we
  ask rather than derive.

  Gate on the boolean, never on the string: REAPER 6 fails every
  container_count query, so the walk simply never descends and behaves exactly
  as it did before containers existed. container_item.N needs REAPER 7.06+; on
  7.00-7.05 container contents are missed, which is also the old behaviour.

  An empty container returns an empty list, not nil: it is still a container,
  and must not be tallied as if it were a plugin.

  Returns nil for an OFFLINE container too, because REAPER unloads its contents
  and then answers nothing about them -- see is_container, which is how one is
  recognised when this cannot say.
]]
local function container(parm, obj, idx)
  local ok, count = parm(obj, idx, 'container_count')
  if not ok then return nil end

  local kids = {}
  for n = 0, (tonumber(count) or 0) - 1 do
    local got, id = parm(obj, idx, 'container_item.' .. n)
    local addr = got and tonumber(id)
    if addr then kids[#kids + 1] = addr end
  end
  return kids
end

-- One classifier serves tracks and takes; these adapt the two API families to
-- a common shape. reaper.* is indexed at call time, not at load time, so a test
-- can swap the whole table out before the first scan.
local TRACK = {
  name    = function(o, i) local _, s = reaper.TrackFX_GetFXName(o, i, '') return s end,
  enabled = function(o, i) return reaper.TrackFX_GetEnabled(o, i) end,
  offline = function(o, i) return reaper.TrackFX_GetOffline(o, i) end,
  type    = function(o, i) local ok, s = reaper.TrackFX_GetNamedConfigParm(o, i, 'fx_type')
                           return ok and s or nil end,
  children = function(o, i) return container(reaper.TrackFX_GetNamedConfigParm, o, i) end,
  chunk    = function(o) local ok, s = reaper.GetTrackStateChunk(o, '', false)
                         return ok and s or nil end,
}

local TAKE = {
  name    = function(o, i) local _, s = reaper.TakeFX_GetFXName(o, i, '') return s end,
  enabled = function(o, i) return reaper.TakeFX_GetEnabled(o, i) end,
  offline = function(o, i) return reaper.TakeFX_GetOffline(o, i) end,
  type    = function(o, i) local ok, s = reaper.TakeFX_GetNamedConfigParm(o, i, 'fx_type')
                           return ok and s or nil end,
  children = function(o, i) return container(reaper.TakeFX_GetNamedConfigParm, o, i) end,
}

-- fx_type is VST, VST3, AU, CLAP, JS... with an "i" suffix on the instrument
-- variants: VSTi, VST3i, AUi, CLAPi.
local function is_instrument(api, obj, idx)
  local t = api.type(obj, idx)
  return t ~= nil and t:sub(-1) == 'i'
end

local function tally(bucket, name)
  bucket[name] = (bucket[name] or 0) + 1
end

--[[ What REAPER shows for a JSFX, given the effect file the chunk names.

  The chunk says "sstillwell/3x3"; REAPER's own FX list says "JS: 3x3 EQ",
  taken from the desc: line inside that file. Resolving it matters because the
  same JSFX would otherwise be tallied under two different names depending on
  whether the container holding it happened to be online.

  Falls back to the path, still marked JS, if the file cannot be read.
]]
local function jsfx_name(relpath)
  local label = 'JS: ' .. tostring(relpath)
  local base  = reaper.GetResourcePath and reaper.GetResourcePath()
  if not (relpath and base) then return label end

  -- '/' throughout: that is how the chunk writes these, and Windows opens
  -- them happily either way.
  local f = io.open(base .. '/Effects/' .. relpath, 'r')
  if not f then return label end

  local desc
  for _ = 1, 40 do                      -- desc: lives at the top, or nowhere
    local line = f:read('l')
    if not line then break end
    desc = line:match('^%s*desc:%s*(.-)%s*$')
    if desc and desc ~= '' then break end
    desc = nil
  end
  f:close()

  return desc and ('JS: ' .. desc) or label
end

local function entry_name(e)
  return e.name or jsfx_name(e.js)
end

--[[ What an offline container holds, read out of the project state.

  Empty rather than nil whenever the chunk cannot be reached or the container
  cannot be found in it, so the caller says nothing instead of guessing: a name
  that is wrong is worse than a name that is missing. The chunk is fetched only
  when this is called -- it is the whole track, items and plugin state
  included, and worth nothing to a project with no offline container in it.
]]
local function offline_contents(w, path)
  if not (w.tag and w.api.chunk) then return {} end

  local text = w.api.chunk(w.obj)
  if not text then return {} end

  return chunk.container_contents(text, w.tag, path) or {}
end

--[[ Is this FX one of REAPER's built-in containers?

  fx_type keeps answering "Container" when the thing is offline, which is the
  only thing that still does -- so this, and not container_count, is what says
  whether something is a wrapper or a plugin.
]]
local function is_container(api, obj, idx)
  return api.type(obj, idx) == 'Container'
end

--[[ Puts one FX into a bucket, descending into it if it is a container.

  chain is 'normal', 'input', 'monitoring' or 'inactive-take'. The order of the
  tests is the classification: anything bypassed or offline is inactive whatever
  it is, and so is anything on a take that is not the one playing back.

  inactive says an enclosing container was bypassed or offline. REAPER reports
  each FX's own bypass flag and nothing more, so the contents of a muted
  container still read as enabled -- the state has to be carried down by hand,
  at every level.
]]
local function classify(b, w, idx, path, inactive, depth)
  local api, obj, chain = w.api, w.obj, w.chain
  depth = depth or 0

  local dead = inactive or not api.enabled(obj, idx) or api.offline(obj, idx)

  -- A container is a wrapper, not a plugin anyone installed, so it is never
  -- tallied itself -- only what it holds, which inherits its dead state.
  -- Recognised either way round: kids proves it, and for an offline one, whose
  -- contents REAPER has unloaded, fx_type is all that is left to go on.
  local kids = api.children(obj, idx)
  if kids or is_container(api, obj, idx) then
    if kids then
      if depth < MAX_DEPTH then
        for n, child in ipairs(kids) do
          local below = { table.unpack(path) }
          below[#below + 1] = n - 1           -- container_item.N is 0-based
          classify(b, w, child, below, dead, depth + 1)
        end
      end
    else
      -- Offline: REAPER has unloaded it and answers nothing through any FX
      -- index, so the project state is the only place the contents survive.
      -- All of it is inactive by definition of the container being offline.
      for _, e in ipairs(offline_contents(w, path)) do
        tally(b.offline, entry_name(e))
      end
    end
    return
  end

  local name = api.name(obj, idx)

  if dead then
    tally(b.offline, name)
  elseif chain == 'inactive-take' then
    tally(b.offline, name)
  elseif chain == 'monitoring' then
    tally(b.monitoring, name)
  elseif chain == 'input' then
    tally(b.inputfx, name)
  elseif is_instrument(api, obj, idx) then
    tally(b.instruments, name)
  else
    tally(b.effects, name)
  end
end

local function scan_track(b, track)
  local w = { api = TRACK, obj = track, chain = 'normal', tag = 'FXCHAIN' }
  for i = 0, reaper.TrackFX_GetCount(track) - 1 do
    classify(b, w, i, { i })
  end
end

local function scan_rec_chain(b, track, chain)
  local w = { api = TRACK, obj = track, chain = chain, tag = 'FXCHAIN_REC' }
  for i = 0, reaper.TrackFX_GetRecCount(track) - 1 do
    -- The FX index carries the record-chain bit; the chunk ordinal does not.
    classify(b, w, i + M.MONITORINGIDX, { i })
  end
end

local function scan_items(b, proj)
  for i = 0, reaper.CountMediaItems(proj) - 1 do
    local item   = reaper.GetMediaItem(proj, i)
    local active = reaper.GetMediaItemInfo_Value(item, 'I_CURTAKE')

    for t = 0, reaper.CountTakes(item) - 1 do
      local take = reaper.GetTake(item, t)
      if take then                       -- nil for an empty take slot
        -- No tag: an item chunk holds every take's chain and picking the
        -- right one is unverified guesswork, so an offline container on a take
        -- contributes nothing rather than something possibly wrong.
        local w = {
          api   = TAKE,
          obj   = take,
          chain = (t == active) and 'normal' or 'inactive-take',
        }
        for fx = 0, reaper.TakeFX_GetCount(take) - 1 do
          classify(b, w, fx, { fx })
        end
      end
    end
  end
end

--[[ Tallies the whole project.

  proj defaults to 0, the current project, and is resolved on every call: the
  window stays correct when you switch project tabs under it.

  Returns five name -> count tables.
]]
function M.scan(proj)
  proj = proj or 0

  local b = {
    instruments = {},
    effects     = {},
    inputfx     = {},
    monitoring  = {},
    offline     = {},
  }

  for i = 0, reaper.CountTracks(proj) - 1 do
    local track = reaper.GetTrack(proj, i)
    scan_track(b, track)
    scan_rec_chain(b, track, 'input')
  end

  local master = reaper.GetMasterTrack(proj)
  scan_track(b, master)
  scan_rec_chain(b, master, 'monitoring')

  scan_items(b, proj)

  return b
end

return M
