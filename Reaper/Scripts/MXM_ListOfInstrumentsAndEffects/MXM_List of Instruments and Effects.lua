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
local about  = require 'about'
local theme  = require 'theme'

local FONT_SIZE = 14

local ctx  = ImGui.CreateContext('List of Instruments and Effects')
local SANS = ImGui.CreateFont('sans-serif')   -- 0.10: no size here
local MONO = ImGui.CreateFont('monospace')    -- the reports are column-aligned
ImGui.Attach(ctx, SANS)
ImGui.Attach(ctx, MONO)

theme.init(ImGui, ctx)

local BUTTONS = {
  { 'Plain Text', 'plaintext' },
  { 'Markdown',   'markdown'  },
  { 'BB Plain',   'bbplain'   },
  { 'BB Code',    'bbcode'    },
}

local ABOUT = 'About##dialog'

-- Where the main window is, taken while inside its own Begin/End, for the
-- About dialog to centre on afterwards -- by then GetWindowPos has moved on.
local main_x, main_y, main_w, main_h = 0, 0, 0, 0

local st = {
  fmt     = 'plaintext',  -- the format the last Copy button chose
  debug   = false,
  about   = false,        -- is the About dialog up?
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

local function about_body(FS)
  ImGui.Text(ctx, about.NAME)
  ImGui.SameLine(ctx)
  ImGui.TextColored(ctx, 0x808080FF, about.VERSION)

  ImGui.Spacing(ctx)
  ImGui.TextWrapped(ctx, about.TAGLINE)

  theme.section('Links', true)
  -- TextLinkOpenURL opens the browser itself, so this needs no SWS and no
  -- shell-out of our own.
  ImGui.TextLinkOpenURL(ctx, 'Documentation', about.URL_DOCS)
  ImGui.TextLinkOpenURL(ctx, 'Source code on GitHub', about.URL_REPO)

  theme.section('Author', true)
  ImGui.Text(ctx, about.AUTHOR)

  theme.section('Licence', true)
  ImGui.TextWrapped(ctx, about.LICENCE .. '. ' .. about.COPYRIGHT .. '.')

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  local bw = FS * 8
  theme.center(bw)
  if theme.button('Close##about', bw) then st.about = false end
end

--[[ The About dialog.

  Not a MODAL. ImGui paints Col_ModalWindowDimBg during Render(), after every
  PushStyleColor has been popped, so it always takes the style default -- which
  in the dark style is near-white, and the window appeared to BRIGHTEN. The dim
  is drawn by hand instead, in theme.push_content_dim.

  Not a POPUP either, though these flags are chosen to look like one. ImGui owns
  a popup's visibility and closes it on losing focus, so the dialog vanished on
  an alt-tab.

  What a popup gave away free and this has to ask for:
    * TopMost, or the dimmed main window could be raised ABOVE the dialog.
    * theme.push_content_dim's BeginDisabled, or the faded window behind would
      still be clickable.
    * Escape, and dismissal by a click outside -- both below.
]]
local function about_dialog(FS)
  if not st.about then return end

  ImGui.SetNextWindowPos(ctx, main_x + main_w * 0.5, main_y + main_h * 0.5,
                         ImGui.Cond_Always, 0.5, 0.5)
  ImGui.SetNextWindowSize(ctx, FS * 28, 0, ImGui.Cond_Always)

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,
                     FS * theme.MODAL_PAD, FS * theme.MODAL_PAD)
  local visible = ImGui.Begin(ctx, ABOUT, nil,
                              ImGui.WindowFlags_NoTitleBar
                              | ImGui.WindowFlags_NoResize
                              | ImGui.WindowFlags_NoMove
                              | ImGui.WindowFlags_NoCollapse
                              | ImGui.WindowFlags_NoDocking
                              | ImGui.WindowFlags_NoSavedSettings
                              | ImGui.WindowFlags_TopMost)
  ImGui.PopStyleVar(ctx)
  if not visible then return end

  local inside = ImGui.IsWindowHovered(ctx, ImGui.HoveredFlags_RootAndChildWindows)

  -- End is guaranteed, for the same reason PopFont is in preview(): a window
  -- left open by a failed frame corrupts the stack for every frame after it.
  local ok, err = pcall(about_body, FS)

  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then st.about = false end
  if ImGui.IsMouseClicked(ctx, 0) and not inside
     and ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_AnyWindow) then
    st.about = false
  end

  ImGui.End(ctx)
  if not ok then error(err, 0) end
end

local function draw(FS)
  main_x, main_y = ImGui.GetWindowPos(ctx)
  main_w, main_h = ImGui.GetWindowSize(ctx)

  theme.section('Copy to clipboard')

  for i, b in ipairs(BUTTONS) do
    if i > 1 then ImGui.SameLine(ctx) end
    if theme.button(b[1], FS * 5.5) then
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

  -- About sits at the right edge, out of the way of the Copy buttons.
  ImGui.SameLine(ctx)
  local sz = theme.icon_size()
  ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) +
                           ImGui.GetContentRegionAvail(ctx) - sz)
  if theme.info_button('about') then st.about = true end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, 'About') end

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
  theme.push(FS)          -- before Begin, so the window itself is rounded

  poll_project()

  ImGui.SetNextWindowSize(ctx, FS * 46, FS * 34, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, 'List of Instruments and Effects', true)

  if visible then
    -- The window's content fades, and stops taking clicks, while the dialog is
    -- up. Pushed around the pcall, not inside draw(), so a failed frame cannot
    -- leave BeginDisabled on the stack.
    local dimmed = st.about
    if dimmed then theme.push_content_dim() end

    local okdraw, err = pcall(draw, FS)

    if dimmed then theme.pop_content_dim() end
    if not okdraw then
      ImGui.TextColored(ctx, 0xC2413BFF, 'Drawing error: ' .. tostring(err))
    end
    ImGui.End(ctx)        -- ONLY when Begin returned true
  end

  -- The dialog is a window of its own, so it is drawn AFTER the main window has
  -- ended -- outside the dim, at full opacity, and still inside the theme and
  -- font pushes, so it is styled and sized like everything else.
  local okd, derr = pcall(about_dialog, FS)
  if not okd then
    reaper.ShowConsoleMsg('List of Instruments and Effects: About dialog error: ' ..
                          tostring(derr) .. '\n')
    st.about = false      -- or it throws again on every frame
  end

  theme.pop()             -- always, and before PopFont
  ImGui.PopFont(ctx)      -- always, Begin or not

  if open then reaper.defer(frame) end   -- 0.10 closes by not re-deferring
end

-- poll_project() runs before the first Begin, so the window has its report
-- ready on the very first frame.
reaper.defer(frame)
