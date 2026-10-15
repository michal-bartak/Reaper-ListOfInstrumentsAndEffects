---
title: Installation
description: Install the script and ReaImGui through ReaPack.
---

The easiest way is through ReaPack.

```
https://github.com/michal-bartak/ReaPack/raw/main/index.xml
```

In REAPER:

* open *Extensions → ReaPack → Import repositories* and paste that URL
* open *Extensions → ReaPack → Browse packages*, find **List of Instruments and Effects**
  and install it

ReaPack adds the action to the Action List and installs a
[toolbar icon](#the-toolbar-icon) to go with it.

:::note
Add the action to a toolbar of your choice, then assign the icon.

Search for `mxm` to find either of them quickly.
:::

## The toolbar icon

<img src="/Reaper-ListOfInstrumentsAndEffects/toolbar-list-of-instruments-and-effects.svg" width="72" alt="The toolbar icon" />

ReaPack installs the icon into `Data/toolbar_icons/` at three sizes -- 1x, 150%
and 200% -- so REAPER picks the one your display needs.

<details>
<summary>Manual installation steps</summary>

1. Open *Options → Show REAPER resource path in explorer/finder*. Everything below goes into that
   folder:

   | OS | Resource path |
   |----|------|
   | macOS | `~/Library/Application Support/REAPER/` |
   | Windows | `%AppData%\REAPER\` |
   | Linux | `~/.config/REAPER/` |

1. Download `MXM_ListOfInstrumentsAndEffects-<version>.zip` from the
   [GitHub releases page](https://github.com/michal-bartak/Reaper-ListOfInstrumentsAndEffects/releases).

1. Unpack it into the resource path. The zip holds a `Scripts/` folder and a `Data/` folder; merge
   them with the ones already there, do not replace them:

   ```
   Scripts/MXM_ListOfInstrumentsAndEffects/  ->  <resource path>/Scripts/MXM_ListOfInstrumentsAndEffects/
   Data/toolbar_icons/                       ->  <resource path>/Data/toolbar_icons/
   ```

In REAPER:

* open *Actions → Show action list → New action → Load ReaScript* and load the `.lua` file from `Scripts/MXM_ListOfInstrumentsAndEffects/` location
* add the action to a toolbar of your choice, then assign the icon
</details>
