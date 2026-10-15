--[[
  mockreaper.lua -- just enough of the ReaScript API for lib/scan.lua.

  A project is described as a plain table (see tests/test_scan.lua for one).
  Tracks, takes and items are the very tables from that description, handed back
  as the "objects" scan.lua passes around, so an assertion can talk about them
  by name.

  Installing it sets the global `reaper`, which is what scan.lua indexes.

  FX ADDRESSES. REAPER encodes a container's contents into the FX index itself,
  as a mixed-radix number built from the chain length at every level. This mock
  hands out synthetic ids instead and remembers them. That is faithful to the
  contract scan.lua actually depends on: it never computes an address, it asks
  for one with container_item.N and passes back whatever it is given.
  Reproducing REAPER's arithmetic here would test arithmetic that nothing runs.
]]

local M = {}

local MONITORINGIDX = 0x1000000
local CONTAINERBASE = 0x2000000

local REG   -- obj -> (index -> fx entry)
local KIDS  -- fx entry -> { child index, ... }; set only for containers

-- Numbers every FX reachable from one track or take: the normal chain at
-- 0.., the record chain at MONITORINGIDX.., and everything nested inside a
-- container at a synthetic id of its own.
local function index_object(obj)
  local reg = REG[obj]
  if reg then return reg end

  reg = {}
  local next_child = CONTAINERBASE

  local function nest(fx)
    if not fx.container then return end
    local kids = {}
    for _, kid in ipairs(fx.container) do
      local id = next_child
      next_child = next_child + 1
      reg[id] = kid
      kids[#kids + 1] = id
      nest(kid)                                   -- containers inside containers
    end
    KIDS[fx] = kids                               -- {} for an empty container
  end

  for i, fx in ipairs(obj.fx  or {}) do reg[i - 1] = fx                 ; nest(fx) end
  for i, fx in ipairs(obj.rec or {}) do reg[MONITORINGIDX + i - 1] = fx ; nest(fx) end

  REG[obj] = reg
  return reg
end

local function accessors(prefix, resolve)
  local r = _G.reaper

  -- Top-level only, as in REAPER: a container counts as one entry here however
  -- much it holds.
  r[prefix .. '_GetCount'] = function(obj)
    return #((resolve(obj).fx) or {})
  end

  r[prefix .. '_GetRecCount'] = function(obj)
    return #((resolve(obj).rec) or {})
  end

  local function fx_at(obj, idx)
    return index_object(resolve(obj))[idx]
  end

  r[prefix .. '_GetFXName'] = function(obj, idx)
    local fx = fx_at(obj, idx)
    return true, fx and fx.name or ''
  end

  r[prefix .. '_GetEnabled'] = function(obj, idx)
    local fx = fx_at(obj, idx)
    -- Enabled unless the fixture says otherwise, the way REAPER defaults. Note
    -- this reports the entry's OWN flag and nothing else: REAPER does not fold
    -- a container's bypass into its contents, which is the behaviour scan.lua
    -- has to compensate for.
    return fx == nil or fx.bypassed ~= true
  end

  r[prefix .. '_GetOffline'] = function(obj, idx)
    local fx = fx_at(obj, idx)
    return fx ~= nil and fx.offline == true
  end

  r[prefix .. '_GetNamedConfigParm'] = function(obj, idx, parm)
    local fx = fx_at(obj, idx)
    if not fx then return false, '' end

    local kids = KIDS[fx]

    if parm == 'fx_type' then
      -- REAPER names the built-in wrapper "Container" whatever it holds, and
      -- keeps answering even when the thing is offline.
      if kids then return true, fx.type or 'Container' end
      if fx.type == nil then return false, '' end
      return true, fx.type
    end

    --[[ An OFFLINE container is a black box.

      REAPER unloads its contents, and then container_count, container_item.N
      and the raw 0x2000000 arithmetic all come back empty -- verified against
      REAPER 7.80. Only fx_type still answers. Modelling that here is the whole
      point: without it the suite passes a case the real thing fails.
    ]]
    if kids and fx.offline then return false, '' end

    -- Fails for anything that is not a container -- which is also how REAPER 6
    -- answers, for every FX.
    if parm == 'container_count' then
      if not kids then return false, '' end
      return true, tostring(#kids)
    end

    local n = parm:match('^container_item%.(%d+)$')
    if n and kids then
      local id = kids[tonumber(n) + 1]
      if id then return true, tostring(id) end
    end

    return false, ''
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

  An FX carrying `container = { ...more FX... }` is a container, nested as deep
  as you like. Give it no `type` unless a test wants one: REAPER reports
  "Container", but scan.lua recognises a container by container_count, not by
  its type.
]]
function M.install(project)
  local r = {}
  _G.reaper = r
  REG, KIDS = {}, {}

  r.CountTracks        = function() return #(project.tracks or {}) end
  r.GetTrack           = function(_, i) return project.tracks[i + 1] end
  r.GetMasterTrack     = function() return project.master or {} end

  -- The project state, which is the only place an offline container's contents
  -- survive. A fixture track carries it as `chunk = [[...]]`.
  r.GetTrackStateChunk = function(track, _, _)
    if not track.chunk then return false, '' end
    return true, track.chunk
  end

  -- Where lib/scan.lua goes looking for a JSFX's desc: line. nil unless the
  -- fixture points it at one.
  r.GetResourcePath    = function() return project.resource end

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
