---
title: Installation
description: Install the script and ReaImGui through ReaPack.
---

The easiest way is to use ReaPack.

```
https://github.com/michal-bartak/ReaPack/raw/main/index.xml
```

In REAPER
* open *Extensions → ReaPack → Import repositories* and paste that URL. 
* open *Extensions → ReaPack → Browse packages*, find **List of Instruments and Effects** and install it.

ReaPack adds `MXM List of Instruments and Effects` actions to the Action List as well as deploy dedicated [toolbar icon](#the-toolbar-icons)

:::note
Add this script to toolbar of your choice, then assigning the icon.

To quickly find action or icons, search for `mxm`.
:::

<details>
<summary>Manual installation steps</summary>

1. Open *Options → Show REAPER resource path in explorer/finder*. Everything below goes into that
   folder:

   | OS | Resource path |
   |----|------|
   | macOS | `~/Library/Application Support/REAPER/` |
   | Windows | `%AppData%\REAPER\` |
   | Linux | `~/.config/REAPER/` |

1. Copy the **contents** of `Reaper/` over it, merging with what is already there:

   ```
   Reaper/Scripts/MXM_ListOfInstrumentsAndEffects/  ->  <resource path>/Scripts/MXM_ListOfInstrumentsAndEffects/
   Reaper/Data/toolbar_icons/         ->  <resource path>/Data/toolbar_icons/
   ```

In REAPER
* open *Actions → Show action list → New action → Load ReaScript*, and load the lua script.
* add the action to toolbar of choice, assigning provided icon
</details>
