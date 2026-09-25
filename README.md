<div align="center">

<img src="docs/01-main-menu.png" alt="PROMEDIA COPILOT" width="520"/>

**PROMEDIA COPILOT** · Version 1.2.1

*A PowerShell-based tool that automates renaming, printing, filing and Excel generation for warehouse pick lists and delivery notes*

*By [Engin Sarak](https://github.com/EnginSarak)*

![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&logoColor=white)
![Excel](https://img.shields.io/badge/Excel-COM%20interop-217346?logo=microsoftexcel&logoColor=white)
![Version](https://img.shields.io/badge/version-1.2.1-blue)

</div>

---

## Table of Contents

- [How it works](#how-it-works)
- [Features](#features)
  - [Rename and create documents](#rename-and-create-documents)
  - [Pump picks](#pump-picks)
  - [Print](#print)
  - [Move to folders](#move-to-folders)
  - [Scanned documents (beta)](#scanned-documents-beta)
  - [Settings](#settings)
- [Install](#install)
- [Tech stack](#tech-stack)
- [Project structure](#project-structure)
- [Changelog](#changelog)

---

## How it works

Business Central exports pick lists as PDFs with generic names like `Custom Picking
List.pdf`. Getting them into the right filename, the right printer tray and the
right folder is the same handful of steps every time, and building the pump list and
scan sheet for a pump pick used to mean re-typing serial numbers by hand.

PROMEDIA COPILOT reads the PDFs directly and does all of that: renaming, stamping, printing,
filing, and generating the Excel sheets from data already sitting in the file. No line
list export, no copy-paste, no template hunting.

Single PowerShell script, no install beyond unzip, keyboard-driven menu, one COM call
into Excel where a formula can't do the job.

---

## Features

### Rename and create documents

<img src="docs/02-rename-groupage.png" width="620"/>

Reads PAC / PWS / WP and the order number out of each PDF and renames it accordingly.
When two or more pick lists share a customer, it flags it as a groupage, stamps the
PDFs and builds the groupage sheet from the template with customer and pick numbers
already filled in.

### Pump picks

<img src="docs/03-pump-list.png" width="620"/>

If a pick list contains pumps, it offers to build two files straight from
the PDF, no line list needed:

- `Pumpen.xlsx`: serial numbers grouped by bin, with counts and a total. Rows still
  sitting in the PICKING bin are excluded.
- `Control.xlsx`: the scan sheet for the warehouse floor. A scanned serial turns
  green, anything still red was missed.

### Print

<img src="docs/04-print.png" width="620"/>

Delivery documents and warehouse picks in one list. Matched PAC/PWS pairs print
together, deliveries twice, picks once. Anything already sent is marked so it doesn't
go out twice by accident.

### Move to folders

<img src="docs/05-move.png" width="620"/>

Each entry moves the full bundle: pick list with its pump list, groupage with its
sheet. Control files get their own section and go to the pump control folder, not the
print queue. Delivery documents are routed by reading the destination address, country
and date out of the PDF, including addresses drawn with an embedded font, and
suggesting the matching month folder; the customer, location and country found in the
document are shown so the target can be checked before filing. Below the address it
also shows how many packages the delivery has and in which unit (pallets and cartons `CT`
are kept apart), plus net and gross weight, summed over all delivery notes in the entry. Deliveries going to the
same customer, location and country are grouped into one entry and moved together.
Plain year folders (e.g. `2026`) used only as an end-of-year archive are never treated
as a filing target; new month folders always go beside them, and when a month folder
doesn't exist yet, creating it is offered first.

### Scanned documents (beta)

<img src="docs/08-fu-scan.png" width="620"/>

Warehouse staff scan the signed delivery note after every pickup, and those scans land
in a folder with generic names. PROMEDIA COPILOT reads them with the OCR built into Windows,
no internet connection, no extra software, recognizes the delivery note, and renames
it the same way as the digital documents: `FÜ_<customer>_<order number>_<scan date>.pdf`.
A second entry, **Auto move FÜ documents**, then files the renamed scans into the same
customer/country folders as the regular delivery documents, using the destination
address read from the scan.

### Settings

<img src="docs/06-settings.png" width="620"/>

Folders and printer are asked once and stored next to the script, including the Halle M
scan folder used by the scanned-documents feature. `reset.bat` clears all of it, run it
before handing the folder to someone else.

---

## Install

```
Code → Download ZIP → unpack → run "PROMEDIA COPILOT.bat"
```

First start asks for folders and printer once.

### Update

The tool never connects to the internet on its own. To update:

1. Download the new version: **Code → Download ZIP** (`PM-COPILOT-main.zip`)
2. Put the ZIP as it is (**do not unpack it**) into the folder where `PROMEDIA COPILOT.bat` is
3. Start the tool: it finds the ZIP, shows the new version and asks to install it

Settings, pairs and printed markers stay as they are. The ZIP is deleted after the
update; an update file that is not newer than the installed version is removed too.

---

## Tech stack

| Layer | What |
| --- | --- |
| Runtime | PowerShell 5.1, Windows Console API |
| Spreadsheets | Excel COM interop |
| PDF parsing | Manual PDF stream inflate + text-token extraction, no external library |

---

## Project structure

```
PROMEDIA COPILOT/
├── PROMEDIA COPILOT.bat         starts the tool
├── _promedia_copilot.ps1        the program
├── reset.bat                   clears personal settings
├── update.txt                  version + file list for the offline update
├── pumplist_template.xlsx      pump list template
├── pump_control_template.xlsx  scan control template
├── groupage_template.xlsx      groupage sheet template
└── docs/                       screenshots used above
```

`_promedia_copilot_settings.txt`, `_promedia_copilot_pairs.txt` and
`_promedia_copilot_printed.txt` are created at runtime and never leave the machine.

---

## Changelog

### 1.2.1

- Minor fixes.

### 1.2.0

- Removed the online update check. The tool no longer connects to GitHub on startup
  or from the menu, and the "Check for updates" menu item is gone.
- New offline update: put the downloaded ZIP (`PM-COPILOT-main.zip`) into the folder
  of `PROMEDIA COPILOT.bat`, and on the next start the tool offers to install it,
  replaces its files, deletes the ZIP and restarts. Settings are kept.

### 1.1.0

- Move to folders: packages with unit (pallet, `CT`, ...) and net/gross weight are read from the delivery note and shown under the address. Grouped deliveries are summed per unit.

### 1.0.0

- Initial release.

---

*Customer names and numbers in the screenshots are made up.*
