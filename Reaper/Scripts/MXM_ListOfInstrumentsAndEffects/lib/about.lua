--[[
  about.lua -- who made this, where it lives, and which version you are running.

  The version is duplicated. ReaPack reads it from the header of
  Various/MXM_List of Instruments and Effects.lua, which is a manifest and never
  ships to Scripts/, so nothing at runtime can see it. The copy here is the one
  the About dialog shows. tests/test_about.lua keeps the two from drifting.
]]

return {
  NAME    = 'List of Instruments and Effects',
  VERSION = '3.0',
  AUTHOR  = 'Michal MaXyM Bartak',
  LICENCE = 'GPL v3',
  COPYRIGHT = 'Copyright (c) 2026 Michal Bartak',

  TAGLINE = 'List every plugin an active REAPER project uses, grouped by category.',

  URL_REPO = 'https://github.com/michal-bartak/ListOfInstrumentsAndEffects',
  URL_DOCS = 'https://michal-bartak.github.io/ListOfInstrumentsAndEffects/',
}
