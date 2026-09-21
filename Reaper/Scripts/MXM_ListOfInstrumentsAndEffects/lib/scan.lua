--[[
  scan.lua -- walks every FX chain in a project and tallies plugin names.

  Pure logic: it talks to reaper.* and nothing else, so tests/ can drive it
  under plain Lua against tests/mockreaper.lua.

  REAPER keeps FX in more places than the chain on a track. A track also has a
  record-input chain, the master track's input chain is the monitoring chain,
  and every take of every media item can carry its own chain -- instruments
  included, which is how a MIDI item makes sound without an instrument on the
  track. All of them are counted here.
]]

local M = {}

-- Selects the record/input chain instead of the normal one. The same bit means
-- "monitoring" on the master track and "input FX" on any other track.
M.MONITORINGIDX = 0x1000000

-- One classifier serves tracks and takes; these adapt the two API families to
-- a common shape. reaper.* is indexed at call time, not at load time, so a test
-- can swap the whole table out before the first scan.
local TRACK = {
  name    = function(o, i) local _, s = reaper.TrackFX_GetFXName(o, i, '') return s end,
  enabled = function(o, i) return reaper.TrackFX_GetEnabled(o, i) end,
  offline = function(o, i) return reaper.TrackFX_GetOffline(o, i) end,
  type    = function(o, i) local ok, s = reaper.TrackFX_GetNamedConfigParm(o, i, 'fx_type')
                           return ok and s or nil end,
}

local TAKE = {
  name    = function(o, i) local _, s = reaper.TakeFX_GetFXName(o, i, '') return s end,
  enabled = function(o, i) return reaper.TakeFX_GetEnabled(o, i) end,
  offline = function(o, i) return reaper.TakeFX_GetOffline(o, i) end,
  type    = function(o, i) local ok, s = reaper.TakeFX_GetNamedConfigParm(o, i, 'fx_type')
                           return ok and s or nil end,
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

--[[ Puts one FX into a bucket.

  chain is 'normal', 'input', 'monitoring' or 'inactive-take'. The order of the
  tests is the classification: anything bypassed or offline is inactive whatever
  it is, and so is anything on a take that is not the one playing back.
]]
local function classify(b, api, obj, idx, chain)
  local name = api.name(obj, idx)

  if not api.enabled(obj, idx) or api.offline(obj, idx) then
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
  for i = 0, reaper.TrackFX_GetCount(track) - 1 do
    classify(b, TRACK, track, i, 'normal')
  end
end

local function scan_rec_chain(b, track, chain)
  for i = 0, reaper.TrackFX_GetRecCount(track) - 1 do
    classify(b, TRACK, track, i + M.MONITORINGIDX, chain)
  end
end

local function scan_items(b, proj)
  for i = 0, reaper.CountMediaItems(proj) - 1 do
    local item   = reaper.GetMediaItem(proj, i)
    local active = reaper.GetMediaItemInfo_Value(item, 'I_CURTAKE')

    for t = 0, reaper.CountTakes(item) - 1 do
      local take = reaper.GetTake(item, t)
      if take then                       -- nil for an empty take slot
        local chain = (t == active) and 'normal' or 'inactive-take'
        for fx = 0, reaper.TakeFX_GetCount(take) - 1 do
          classify(b, TAKE, take, fx, chain)
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
