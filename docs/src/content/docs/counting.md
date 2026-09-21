---
title: What gets counted
description: Which FX chains the report reads, and how each plugin is classified.
---

The report has five sections:

| Section | Where the plugins come from |
| --- | --- |
| Instruments | Instruments on track FX chains, on the master, and on the active take of a media item |
| Effects | Everything else on those same chains |
| Input FX | Each track's record-input FX chain |
| Monitoring plugins | The master track's input chain |
| Offline/inactive plugins | Anything bypassed or offline, plus every FX on a take that is not the active take |

## Instrument or effect

REAPER reports a type for each plugin: `VST`, `VST3`, `AU`, `CLAP`, `JS`, and
the instrument variants `VSTi`, `VST3i`, `AUi`, `CLAPi`. A plugin counts as an
instrument when its type ends in `i`. Everything else counts as an effect.

## Takes

A media item's take can carry its own FX chain, instruments included. That is
how a MIDI item makes sound without an instrument on its track.

FX on the active take count as instruments or effects like any others. FX on
the other takes go to Offline/inactive, because they do not play.

## Counting

Each section counts instances, keyed by the name REAPER reports for the FX. Two
copies of the same plugin on two tracks show as `2x`.
