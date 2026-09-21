---
title: Export formats
description: What each Copy button puts on the clipboard.
---

Every format lists the same five sections in the same order. An empty section
prints `N/A`. The examples below are trimmed to the first two sections.

## Plain Text

```
Instruments:
2x   VST3: Serum (Xfer Records)
1x   VSTi: Vital (Vital Audio)

Effects:
3x   VST3: ReaEQ (Cockos)
```

## Markdown

Each section is a table. The name column is as wide as the widest name in that
section, so the counts line up.

```
**Instruments:**
|Plugin Name               |Instances |
|--------------------------|---------:|
|VST3: Serum (Xfer Records)|2         |
|VSTi: Vital (Vital Audio) |1         |

**Effects:**
|Plugin Name         |Instances |
|--------------------|---------:|
|VST3: ReaEQ (Cockos)|3         |
```

## BB Plain

Plain text with bold headings:

```
[b]Instruments:[/b]
2x   VST3: Serum (Xfer Records)
1x   VSTi: Vital (Vital Audio)
```

## BB Code

Plain text wrapped in `[CODE]` tags, which forces a fixed-width font on forums:

```
[CODE]
Instruments:
2x   VST3: Serum (Xfer Records)
1x   VSTi: Vital (Vital Audio)
[/CODE]
```
