--[[
  mockreaper.lua -- just enough of the ReaScript API for lib/scan.lua.

  A project is described as a plain table (see tests/scan.lua for one). Tracks,
  takes and items are the very tables from that description, handed back as the
  "objects" scan.lua passes around, so an assertion can talk about them by name.

  Installing it sets the global `reaper`, which is what scan.lua indexes.
]]

local M = {}

local MONITORINGIDX = 0x1000000

-- Picks the chain an FX index refers to and returns the entry.
local function chain_fx(chains, idx)
  if idx >= MONITORINGIDX then
    return (chains.rec or {})[idx - MONITORINGIDX + 1]
  end
  return (chains.fx or {})[idx + 1]
end

local function accessors(prefix, resolve)
  local r = _G.reaper

  r[prefix .. '_GetCount'] = function(obj)
    return #((resolve(obj).fx) or {})
  end

  r[prefix .. '_GetRecCount'] = function(obj)
    return #((resolve(obj).rec) or {})
  end

  r[prefix .. '_GetFXName'] = function(obj, idx)
    local fx = chain_fx(resolve(obj), idx)
    return true, fx and fx.name or ''
  end

  r[prefix .. '_GetEnabled'] = function(obj, idx)
    local fx = chain_fx(resolve(obj), idx)
    -- enabled unless the fixture says otherwise, the way REAPER defaults
    return fx == nil or fx.bypassed ~= true
  end

  r[prefix .. '_GetOffline'] = function(obj, idx)
    local fx = chain_fx(resolve(obj), idx)
    return fx ~= nil and fx.offline == true
  end

  r[prefix .. '_GetNamedConfigParm'] = function(obj, idx, parm)
    local fx = chain_fx(resolve(obj), idx)
    if not fx or parm ~= 'fx_type' then return false, '' end
    if fx.type == nil then return false, '' end
    return true, fx.type
  end
end

--[[ Installs a mock `reaper` built from `project`.

  project = {
    tracks = { { fx = {...}, rec = {...} }, ... },
    master = { fx = {...}, rec = {...} },
    items  = { { active = 0, takes = { { fx = {...} }, false, ... } }, ... },
  }

  An FX is { name = 'x', type = 'VSTi', bypassed = true, offline = true }; type
  nil means REAPER could not answer, which scan.lua treats as "not an
  instrument". A take of `false` is an empty take slot.
]]
function M.install(project)
  local r = {}
  _G.reaper = r

  r.CountTracks        = function() return #(project.tracks or {}) end
  r.GetTrack           = function(_, i) return project.tracks[i + 1] end
  r.GetMasterTrack     = function() return project.master or {} end

  r.CountMediaItems    = function() return #(project.items or {}) end
  r.GetMediaItem       = function(_, i) return project.items[i + 1] end
  r.CountTakes         = function(item) return #(item.takes or {}) end
  r.GetTake            = function(item, t)
    local take = (item.takes or {})[t + 1]
    return take or nil                      -- `false` is an empty take slot
  end
  r.GetMediaItemInfo_Value = function(item, parm)
    assert(parm == 'I_CURTAKE', 'unexpected item parm: ' .. tostring(parm))
    return item.active or 0
  end

  accessors('TrackFX', function(track) return track end)
  accessors('TakeFX',  function(take)  return take  end)

  return r
end

return M
