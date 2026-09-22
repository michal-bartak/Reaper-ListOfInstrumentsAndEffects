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
| Offline/inactive plugins | Anything bypassed or offline, anything inside a bypassed or offline container, plus every FX on a take that is not the active take |

## Instrument or effect

REAPER reports a type for each plugin: `VST`, `VST3`, `AU`, `CLAP`, `JS`, and
the instrument variants `VSTi`, `VST3i`, `AUi`, `CLAPi`. A plugin counts as an
instrument when its type ends in `i`. Everything else counts as an effect.

## Takes

A media item's take can carry its own FX chain, instruments included. That is
how a MIDI item makes sound without an instrument on its track.

FX on the active take count as instruments or effects like any others. FX on
the other takes go to Offline/inactive, because they do not play.

## Containers

REAPER 7 lets an FX be a *container* holding a chain of its own, nested as deep
as you like. What a container holds is counted, at every level, and classified
like anything else.

The container itself is never listed. It is a wrapper, not a plugin you
installed, so naming it would only pad the report.

Bypassing a container, or taking it offline, applies to everything inside it
however deep — the whole contents move to Offline/inactive.

An **offline** container is a special case. REAPER unloads what is inside one
and will then tell a script nothing about it, so the report reads the contents
out of the project state instead. Two small consequences:

- A JSFX is named from its effect file, so it reads the same as it would
  anywhere else. If that file has been moved or deleted you get its path
  instead.
- An offline container on a media item's *take* is not read, and its contents
  are left out.

:::note
Reading inside containers needs REAPER 7.06 or newer. On 7.00–7.05 the contents
are not counted — though the container is still never reported as if it were a
plugin. REAPER 6 has no containers.
:::

## Counting

Each section counts instances, keyed by the name REAPER reports for the FX. Two
copies of the same plugin on two tracks show as `2x`.
