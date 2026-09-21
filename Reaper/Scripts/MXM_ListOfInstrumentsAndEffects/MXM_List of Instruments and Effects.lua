--[[
  MXM_List of Instruments and Effects.lua -- the report window.

  The ReaPack manifest -- description, version, @provides -- lives in
  Various/MXM_List of Instruments and Effects.lua, which names the category and
  never ships to Scripts/. Deliberately no @version tag here: any .lua below the
  repository root carrying one would be indexed as a package of its own.

  Requires ReaImGui 0.10+. The scan and the formatting live in lib/, know
  nothing about the GUI, and are covered by tests/.
]]

local sep = package.config:sub(1, 1)
local _, thisFile = reaper.get_action_context()
local ROOT = thisFile:match('^(.*[\\/])')
package.path = ROOT .. 'lib' .. sep .. '?.lua;' .. package.path

------------------------------------------------------------------ dependency
if not reaper.APIExists('ImGui_GetBuiltinPath') then
  reaper.ShowMessageBox(
    'List of Instruments and Effects needs ReaImGui, which is not installed.\n\n' ..
    'Extensions > ReaPack > Browse packages > search "ReaImGui"\n' ..
    '> right-click > Install, then restart REAPER.',
    'List of Instruments and Effects: missing dependency', 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ok, ImGui = pcall(function() return require 'imgui' '0.10' end)
if not ok then
  reaper.ShowMessageBox(
    'ReaImGui 0.10 or newer is required.\n\n' .. tostring(ImGui) ..
    '\n\nUpdate it through ReaPack and restart REAPER.',
    'List of Instruments and Effects: ReaImGui too old', 0)
  return
end

------------------------------------------------------------------- start up
local scan   = require 'scan'
local report = require 'report'

local FONT_SIZE = 14

local ctx  = ImGui.CreateContext('List of Instruments and Effects')
local SANS = ImGui.CreateFont('sans-serif')   -- 0.10: no size here
local MONO = ImGui.CreateFont('monospace')    -- the reports are column-aligned
ImGui.Attach(ctx, SANS)
ImGui.Attach(ctx, MONO)

local BUTTONS = {
  { 'Plain Text', 'plaintext' },
  { 'Markdown',   'markdown'  },
  { 'BB Plain',   'bbplain'   },
  { 'BB Code',    'bbcode'    },
}

local st = {
  fmt     = 'plaintext',  -- the format the last Copy button chose
  debug   = false,
  buckets = nil,
  copy    = '',           -- what a Copy button would put on the clipboard
  preview = '',           -- what the window shows
  projfn  = nil,          -- project identity, to notice a tab switch
  state   = nil,          -- GetProjectStateChangeCount, to notice an edit
}

-- Formats the cached scan. Normally the window shows plain text whichever
-- format was copied; with Debug ticked it shows exactly what was copied.
local function render()
  st.copy    = report.format(st.buckets, st.fmt)
  st.preview = st.debug and st.copy or report.format(st.buckets, 'plaintext')
end

local function rescan()
  st.buckets = scan.scan(0)
  render()
end

-- Scanning every frame would walk the whole project 60 times a second, so the
-- report is rebuilt only when the project actually moved underneath it. The
-- file name catches a switch to another project tab; the change count catches
-- an edit within one. Comparing the name rather than the ReaProject avoids
-- relying on two calls returning the same userdata.
local function poll_project()
  local _, projfn = reaper.EnumProjects(-1, '')
  local state = reaper.GetProjectStateChangeCount(0)

  if projfn ~= st.projfn or state ~= st.state then
    st.projfn, st.state = projfn, state
    rescan()
  end
end

------------------------------------------------------------------ the window
-- The report is column-aligned, so it is drawn in the monospace font. The pop
-- is guaranteed: a font left on the stack by a failed frame would be pushed
-- again by the next one, and the leak would compound.
local function preview()
  ImGui.PushFont(ctx, MONO, FONT_SIZE)
  local ok, err = pcall(ImGui.InputTextMultiline, ctx, '##preview', st.preview,
                        -1, -1, ImGui.InputTextFlags_ReadOnly)
  ImGui.PopFont(ctx)
  if not ok then error(err, 0) end
end

local function draw(FS)
  ImGui.SeparatorText(ctx, 'Copy to clipboard')

  for i, b in ipairs(BUTTONS) do
    if i > 1 then ImGui.SameLine(ctx) end
    if ImGui.Button(ctx, b[1], FS * 5.5) then
      st.fmt = b[2]
      rescan()
      ImGui.SetClipboardText(ctx, st.copy)
    end
  end

  ImGui.SameLine(ctx)
  local changed, debug = ImGui.Checkbox(ctx, 'Debug', st.debug)
  if changed then
    st.debug = debug
    render()
  end

  ImGui.Spacing(ctx)
  preview()
end

------------------------------------------------------------------- the frame
local function frame()
  ImGui.PushFont(ctx, SANS, FONT_SIZE)

  -- Every dimension is a multiple of the font size. ReaImGui already reports
  -- logical, DPI-independent units and rasterises glyphs at device resolution,
  -- so sizing off the font is what makes the window right on any display --
  -- multiplying by GetWindowDpiScale (2.0 on a Retina Mac) would draw it double
  -- size.
  local FS = ImGui.GetFontSize(ctx)

  poll_project()

  ImGui.SetNextWindowSize(ctx, FS * 46, FS * 34, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, 'List of Instruments and Effects', true)

  if visible then
    local okdraw, err = pcall(draw, FS)
    if not okdraw then
      ImGui.TextColored(ctx, 0xC2413BFF, 'Drawing error: ' .. tostring(err))
    end
    ImGui.End(ctx)        -- ONLY when Begin returned true
  end

  ImGui.PopFont(ctx)      -- always, Begin or not

  if open then reaper.defer(frame) end   -- 0.10 closes by not re-deferring
end

-- poll_project() runs before the first Begin, so the window has its report
-- ready on the very first frame.
reaper.defer(frame)
