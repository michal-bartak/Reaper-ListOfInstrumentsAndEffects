---
title: Installation
description: Install the script and ReaImGui through ReaPack.
---

## 1. Install ReaImGui

In REAPER, open *Extensions → ReaPack → Browse packages*. Search for
`ReaImGui`, right-click it and choose *Install*. Restart REAPER.

## 2. Add the repository

Open *Extensions → ReaPack → Import repositories* and paste:

```
https://github.com/michal-bartak/ReaPack/raw/main/index.xml
```

This is the **MXM Scripts** repository. It carries all of my REAPER scripts.

## 3. Install the script

Open *Extensions → ReaPack → Browse packages*, find
**List of Instruments and Effects**, right-click and choose *Install*.

The script installs to `Scripts/MXM Scripts/MXM_ListOfInstrumentsAndEffects/`
under REAPER's resource path.

## 4. Run it

Open the Action List and search for *List of Instruments and Effects*.

## Toolbar button

The package ships a toolbar icon at three resolutions. To use it, right-click a
toolbar, choose *Customize toolbar*, add the action, then set its icon to
`mxm_toolbar_list_of_instruments_and_effects.png`.

## Upgrading from 2.x

Install ReaImGui first. Without it, version 3.0 shows a message box and stops.
