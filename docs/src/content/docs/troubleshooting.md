---
title: Troubleshooting
description: Common problems and what to do.
---

## "needs ReaImGui, which is not installed"

Install ReaImGui through ReaPack, then restart REAPER. See
[Installation](/ListOfInstrumentsAndEffects/installation/).

## "ReaImGui 0.10 or newer is required"

Update ReaImGui through ReaPack, then restart REAPER.

## An instrument is listed under Effects

The check is the trailing `i` in the type REAPER reports. A plugin whose type
has no `i` counts as an effect, even if it makes sound.

## A plugin is missing

Check whether it is bypassed, offline, or on a take that is not the active
take. All three go to Offline/inactive.
