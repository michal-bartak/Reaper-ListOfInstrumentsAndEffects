--[[
  theme.lua -- the look: corners, padding, and how loud the lines are.

  A trimmed port of lib/gui/theme.lua from the AutoColor repo, carrying the
  parts this window has a use for: the style push, the section heading, the
  hand-drawn button and its circled-i variant, the checkbox with its ghost tick,
  and the dimming that fades the window behind the About dialog. The tab and
  table helpers stay there -- this window has no tabs and no tables.

  What ReaImGui 0.10 can and cannot do here:

    * Rounding: frames (buttons, inputs, checkboxes), child panels, popups,
      windows, scrollbars and grabs all have style vars.
    * Line THICKNESS is not adjustable. Dear ImGui draws a separator at a
      hard-coded 1 unit, so the knob is prominence -- Col_Separator's alpha --
      not width.

  Everything is sized off the font, so it holds at any text size and on any
  display. Nothing multiplies by the DPI scale: ReaImGui already works in
  logical units.
]]

local M = {}

-- Tweakables ---------------------------------------------------------------
M.ROUNDING       = 0.20   -- x font size; corner radius for frames and panels
M.PAD_X          = 0.55   -- x font size; horizontal padding inside controls
M.PAD_Y          = 0.28   -- x font size; vertical padding inside controls
M.FRAME_BG_ALPHA = 0.60   -- backgrounds of checkboxes and text fields
M.UNIFY_BUTTONS  = false  -- also drag buttons down to that background?
                          -- off: buttons keep the theme's own colour
M.BORDER_ALPHA   = 0.55   -- 0..1, how visible borders and separators are
M.SECTION_SCALE  = 1.07   -- x font size, for section headings
M.SECTION_CASE   = 'upper'-- 'upper' (LIKE THIS) | 'title' (Like This) | 'none'
M.SECTION_ALPHA  = 0.75   -- headings sit back a little from body text
M.MODAL_PAD      = 1.20   -- x font size; padding inside a modal dialog
M.INFO_SCALE     = 1.25   -- x font size; the circled "i" glyph, which is small
M.DIM_CONTENT    = 0.30   -- 0..1; opacity of the window's content while the
                          -- About dialog is open. Fades everything toward the
                          -- dark background, so bright elements lose the most --
                          -- which is what a veil over the top cannot do.
M.CHECKBOX_SCALE = 0.62   -- x the normal control height; the tick box only.
                          -- FLOORS at text height / frame height: ImGui builds
                          -- the square from the line height plus FramePadding,
                          -- and padding cannot go negative.
M.GHOST_CHECK       = 0x000000  -- a faint tick drawn on UNticked checkboxes,
M.GHOST_CHECK_ALPHA = 0.30      -- so the box reads as a checkbox either way
M.CHECK_THICKNESS   = 0.15      -- x the box height
M.GLYPH_NUDGE_Y  = -0.02  -- x the text height; lifts a glyph off the line box.
                          -- ImGui centres the text's LINE BOX, and the baked
                          -- font reserves more air above the capitals (room for
                          -- accents) than below the descenders, so a
                          -- line-box-centred glyph reads low. A FRACTION of the
                          -- text height, so it holds at any font size.

local ImGui, ctx
local nvars, ncols = 0, 0

function M.init(imgui, context) ImGui, ctx = imgui, context end

--- Round to a whole LOGICAL pixel. A fractional padding puts a frame's edges on
--- half a pixel, and the halves round in opposite directions top and bottom, so
--- the control comes out lopsided.
local function px(v) return math.floor(v + 0.5) end

--- Fade a colour ImGui is already using, rather than inventing one, so this
--- keeps working if the user changes REAPER's theme.
local function dim(idx, alpha)
  local col = ImGui.GetStyleColor(ctx, idx)
  local a   = (col & 0xFF) / 255
  ImGui.PushStyleColor(ctx, idx, (col & ~0xFF) | math.floor(a * alpha * 255))
  ncols = ncols + 1
end

local function copy(dst, src, alpha)
  local col = ImGui.GetStyleColor(ctx, src)
  local a   = (col & 0xFF) / 255
  ImGui.PushStyleColor(ctx, dst, (col & ~0xFF) | math.floor(a * (alpha or 1) * 255))
  ncols = ncols + 1
end

--- Push the whole look. Call once per frame, before Begin, so the window itself
--- is rounded. Counted, not a hardcoded number, so pop() cannot drift.
function M.push(FS)
  nvars, ncols = 0, 0
  local r = math.max(2, FS * M.ROUNDING)

  local function var(idx, a, b)
    ImGui.PushStyleVar(ctx, idx, a, b)
    nvars = nvars + 1
  end

  var(ImGui.StyleVar_FrameRounding,     r)
  var(ImGui.StyleVar_ChildRounding,     r)
  var(ImGui.StyleVar_PopupRounding,     r)
  var(ImGui.StyleVar_WindowRounding,    r)
  var(ImGui.StyleVar_GrabRounding,      r)
  var(ImGui.StyleVar_ScrollbarRounding, r)

  var(ImGui.StyleVar_FramePadding, px(FS * M.PAD_X), px(FS * M.PAD_Y))

  -- Checkboxes and text fields draw on Col_FrameBg, buttons on Col_Button --
  -- which is why a checkbox looks unlike a button in most themes. Dim the frame
  -- backgrounds, then optionally give buttons the same ones so the row reads as
  -- one family.
  dim(ImGui.Col_FrameBg,        M.FRAME_BG_ALPHA)
  dim(ImGui.Col_FrameBgHovered, M.FRAME_BG_ALPHA)
  dim(ImGui.Col_FrameBgActive,  M.FRAME_BG_ALPHA)

  if M.UNIFY_BUTTONS then
    copy(ImGui.Col_Button,        ImGui.Col_FrameBg,        M.FRAME_BG_ALPHA)
    copy(ImGui.Col_ButtonHovered, ImGui.Col_FrameBgHovered, M.FRAME_BG_ALPHA)
    copy(ImGui.Col_ButtonActive,  ImGui.Col_FrameBgActive,  M.FRAME_BG_ALPHA)
  end

  dim(ImGui.Col_Border,    M.BORDER_ALPHA)
  dim(ImGui.Col_Separator, M.BORDER_ALPHA)
end

function M.pop()
  if ncols > 0 then ImGui.PopStyleColor(ctx, ncols); ncols = 0 end
  if nvars > 0 then ImGui.PopStyleVar(ctx, nvars);   nvars = 0 end
end

--- Fade the window's content, and stop it taking clicks, while a dialog is up.
---
--- StyleVar_Alpha, not a rectangle drawn over the top: alpha is global and
--- consulted as each widget draws, so it reaches inside child windows, which a
--- draw-list rect cannot. Col_ModalWindowDimBg is no use either -- ImGui paints
--- it during Render(), after every PushStyleColor has been popped, so it always
--- takes the style default, which in the dark style is near-white and
--- BRIGHTENS the window.
---
--- DisabledAlpha goes to 1.0 so BeginDisabled adds no fade of its own: the
--- fade is DIM_CONTENT, not DIM_CONTENT times ImGui's default.
function M.push_content_dim()
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, M.DIM_CONTENT)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_DisabledAlpha, 1.0)
  ImGui.BeginDisabled(ctx, true)
end

function M.pop_content_dim()
  ImGui.EndDisabled(ctx)
  ImGui.PopStyleVar(ctx, 2)
end

--- The colour ImGui would use right now, style stack included.
---
--- GetColor and not GetStyleColor: GetColor multiplies in the current
--- StyleVar_Alpha, GetStyleColor hands back the raw style entry and ignores it.
--- draw_label paints through the draw list, outside ImGui's own widget
--- rendering, so it has to apply that alpha itself -- otherwise every button's
--- TEXT would sit at full brightness on top of a faded button for as long as
--- push_content_dim dims the window behind the About dialog.
---
--- Deliberately unguarded. ReaImGui's shim gives the ImGui table an __index
--- that RAISES on an unknown field, so `ImGui.GetColor and ...` could never
--- fall back to anything: it would throw instead. GetColor is present in 0.10,
--- which this script already refuses to start without.
local function live(idx)
  return ImGui.GetColor(ctx, idx)
end

local function draw_label(x0, y0, x1, y1, text)
  if text == '' then return end
  local tw, th = ImGui.CalcTextSize(ctx, text)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx),
                         x0 + ((x1 - x0) - tw) * 0.5,
                         y0 + ((y1 - y0) - th) * 0.5 + th * M.GLYPH_NUDGE_Y,
                         live(ImGui.Col_Text), text)
end

--- A button whose label this module draws, so it can be centred by the ink
--- rather than by ImGui's line box. Everything after '##' is id only.
function M.button(label, w, h)
  local text = label:match('^(.-)##') or label
  local tw = ImGui.CalcTextSize(ctx, text)

  -- The button is given NOTHING to draw, so left to auto-size it would come out
  -- as two paddings and no text. Width has to be worked out here. Height still
  -- auto-sizes: CalcTextSize of an empty string returns a zero width but a full
  -- line's height, which is what ImGui pads.
  if not w or w == 0 then
    local fpx = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
    w = tw + 2 * fpx
  end

  -- '##' .. label: nothing visible, and the whole string is still the id, so
  -- two buttons with the same text stay distinct.
  local clicked = ImGui.Button(ctx, '##' .. label, w, h or 0)

  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = ImGui.GetItemRectMax(ctx)
  if x0 then draw_label(x0, y0, x1, y1, text) end

  return clicked
end

--- A square button carrying the circled "i" glyph, U+24D8.
function M.info_button(id)
  local sz = ImGui.GetFrameHeight(ctx)
  ImGui.PushFont(ctx, nil, ImGui.GetFontSize(ctx) * M.INFO_SCALE)
  local clicked = M.button('\u{24D8}##' .. id, sz, sz)
  ImGui.PopFont(ctx)
  return clicked
end

--- The square an icon button occupies.
function M.icon_size()
  return ImGui.GetFrameHeight(ctx)
end

local function titlecase(s)
  return (s:gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b:lower() end))
end

--- A section heading, optionally over a rule.
---
--- Drawn as plain text rather than SeparatorText, which indents its label by
--- SeparatorTextPadding.x with no way to reach it per call.
--- The heading style on its own: set back from body text, cased, a little
--- larger. No spacing of its own, so it can share a line with something else.
function M.label(text)
  local col = ImGui.GetStyleColor(ctx, ImGui.Col_Text)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text,
                       (col & ~0xFF) | math.floor(M.SECTION_ALPHA * 255))

  if     M.SECTION_CASE == 'upper' then text = text:upper()
  elseif M.SECTION_CASE == 'title' then text = titlecase(text) end

  ImGui.PushFont(ctx, nil, ImGui.GetFontSize(ctx) * M.SECTION_SCALE)
  ImGui.Text(ctx, text)
  ImGui.PopFont(ctx)

  ImGui.PopStyleColor(ctx)
end

function M.section(label, divider)
  if divider then
    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)
  end

  M.label(label)
  ImGui.Spacing(ctx)
end

--- The height ImGui actually lays a line of text out with. NOT GetFontSize(),
--- which is only the size asked for -- the baked line height is larger, and
--- GetFrameHeight() is built from it. Must be called inside a frame.
local function text_height()
  local _, h = ImGui.CalcTextSize(ctx, 'X')
  return h
end

--- Draw a tick inside the given box. ImGui only draws one when the box is
--- checked, so both states are drawn here instead: the real colour when on, a
--- ghost when off.
local function draw_tick(x0, y0, size, col)
  local dl  = ImGui.GetWindowDrawList(ctx)
  local t   = math.max(1, size * M.CHECK_THICKNESS)
  local pad = size * 0.24
  local ax, ay = x0 + pad,        y0 + size * 0.54
  local bx, by = x0 + size * 0.42, y0 + size - pad
  local cx, cy = x0 + size - pad,  y0 + pad
  ImGui.DrawList_AddLine(dl, ax, ay, bx, by, col, t)
  ImGui.DrawList_AddLine(dl, bx, by, cx, cy, col, t)
end

--- A checkbox with a smaller tick box than a full-height control, and a ghost
--- tick when it is off. The box size comes from FramePadding, so that is what
--- gets squeezed.
---
--- Unlike AutoColor's, this one always sits on the centre line of a
--- full-height row: its only use is beside the Copy buttons, and ImGui lays a
--- SameLine item out from the row's TOP, so the smaller box -- and its label,
--- which ImGui places one padding below the box's top -- would ride high.
--- The nudge down happens inside a group: SameLine takes its y from where the
--- PREVIOUS item started, so a bare nudge would drag whatever follows on the
--- row down with it. A group reports the row's top instead.
--- @return changed, value
function M.checkbox(label, value)
  local full = ImGui.GetFrameHeight(ctx)
  local th   = text_height()
  -- ImGui's square is text height + 2 * padding.y. Solve for the padding
  -- against the TEXT HEIGHT, not the font size, or `box` describes a square
  -- that was never painted.
  local pad  = math.max(0, (full * M.CHECKBOX_SCALE - th) * 0.5)
  local box  = th + pad * 2

  -- Take the theme's tick colour before hiding the built-in mark, so the "on"
  -- state still matches REAPER's theme. live(), so both ticks fade with the
  -- rest of the window behind the About dialog -- see live() above; the ghost
  -- has no style entry to read, so it takes the style alpha by hand.
  local markcol = live(ImGui.Col_CheckMark)
  local galpha  = M.GHOST_CHECK_ALPHA * ImGui.GetStyleVar(ctx, ImGui.StyleVar_Alpha)
  local ghost   = ((M.GHOST_CHECK & 0xFFFFFF) << 8) | math.floor(galpha * 255)

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, pad, pad)
  ImGui.PushStyleColor(ctx, ImGui.Col_CheckMark, 0x00000000)   -- we draw it
  ImGui.BeginGroup(ctx)
  ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + (full - box) * 0.5)
  local rv, v = ImGui.Checkbox(ctx, label, value)
  ImGui.PopStyleColor(ctx)
  ImGui.PopStyleVar(ctx)

  -- The item rect spans box AND label, so its width is not the square -- but
  -- its height is. Centre the tick in that rather than trusting `box`.
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local _,  y1 = ImGui.GetItemRectMax(ctx)
  if x0 then
    local off = ((y1 - y0) - box) * 0.5
    draw_tick(x0 + off, y0 + off, box, v and markcol or ghost)
  end
  ImGui.EndGroup(ctx)

  return rv, v
end

--- Move the cursor so an item of width w comes out centred.
function M.center(w)
  local avail = ImGui.GetContentRegionAvail(ctx)
  if avail > w then
    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail - w) * 0.5)
  end
end

return M
