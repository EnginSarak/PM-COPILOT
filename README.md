<div align="center">

<img src="docs/01-main-menu.png" alt="PROMEDIA COPILOT" width="520"/>

**PROMEDIA COPILOT** · Version 1.5.1

*An internal PowerShell-based tool that automates renaming, printing, filing and Excel generation for warehouse pick lists and delivery notes*

*By [Engin Sarak](https://github.com/EnginSarak)*

![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&logoColor=white)
![Excel](https://img.shields.io/badge/Excel-COM%20interop-217346?logo=microsoftexcel&logoColor=white)
![Version](https://img.shields.io/badge/version-1.5.1-blue)

</div>

---

## Table of Contents

- [How it works](#how-it-works)
- [Install](#install)
- [First start](#first-start)
- [Controls](#controls)
- [Features](#features)
  - [Rename and create documents](#rename-and-create-documents)
  - [Groupage](#groupage)
  - [Pump picks](#pump-picks)
  - [Annotate pick lists](#annotate-pick-lists)
  - [Print](#print)
  - [Move to folders](#move-to-folders)
  - [Scanned documents](#scanned-documents)
  - [Certificate of Origin (beta)](#certificate-of-origin-beta)
  - [Settings](#settings)
- [Tech stack](#tech-stack)
- [Project structure](#project-structure)
- [Changelog](#changelog)

---

## How it works

Business Central saves pick lists and delivery notes as PDFs with names like `Custom Picking List.pdf` or `Delivery Note (2).pdf`. Every day the same steps follow: rename, mark groupages, build pump lists, print, file. PROMEDIA COPILOT reads the PDFs itself, pulls out order number, customer, address and serial numbers, and does the rest. It runs only on the local PC, needs no internet and sends nothing out.

A normal day:

| Step | Menu item | What happens |
| --- | --- | --- |
| 1 | | Save the day's PDFs from Business Central to the Downloads folder |
| 2 | **Auto rename/create documents** | Files get proper names, groupage sheets and pump lists are created |
| 3 | **Annotate WP documents** | Optional notes for the warehouse, written onto the pick list |
| 4 | **Print** | Delivery documents twice, pick lists once |
| 5 | **Auto move to folders** | Every file goes to its folder |
| 6 | **FÜ scan** / **Auto move FÜ documents** | Signed delivery notes scanned after pickup are renamed and filed |

| Code | Document | Name after renaming |
| --- | --- | --- |
| **PWS** | Delivery note | `PWS004410_SORD26-00412.pdf` |
| **PAC** | Packing list | `PAC004410_SORD26-00412.pdf` |
| **WP** | Warehouse pick list | `WP004521_NESTLE_DE_SORD26-00412.pdf` |
| **FÜ** | Signed delivery note, scanned after pickup | `FÜ_Nestle_DE_SORD26-00398_260930.pdf` |

A delivery note and a packing list with the same number form a pair.

---

## Install

```
Code → Download ZIP → unpack → run "PROMEDIA COPILOT.bat"
```

The user guide comes with the download as a PDF in German and English (`PM-COPILOT-HB-DE-001_Benutzerhandbuch_Rev1.0.pdf`, `PM-COPILOT-HB-EN-001_User_Guide_Rev1.0.pdf`).

The three Excel templates must stay in the folder under their names. For a desktop shortcut, right-click `PROMEDIA COPILOT.bat` → **Create shortcut**, move it to the desktop and set `promedia_copilot.ico` as its icon under **Properties → Change Icon**.

### Update

The tool never connects to the internet on its own. To update:

1. Download the new version: **Code → Download ZIP** (`PM-COPILOT-main.zip`)
2. Put the ZIP as it is (**do not unpack it**) into the folder where `PROMEDIA COPILOT.bat` is
3. Start the tool: it finds the ZIP, shows the new version and asks to install it

Settings, pairs and printed markers stay as they are. The ZIP is deleted after the
update; an update file that is not newer than the installed version is removed too.

---

## First start

The first start asks once for printer and folders. A white entry still needs a value, a green one is set. **Continue** appears once everything required is green.

<img src="docs/first-start.webp" width="620"/>

| Setting | Purpose |
| --- | --- |
| **Downloads folder** | Where the PDFs from Business Central land |
| **Default printer** | Printer for delivery documents and pick lists |
| **Outbound main folder** | Root of the shipping folders: country, then customer |
| **Pick list folder** | Where processed pick lists go, with their groupage sheets and pump lists |
| **'Noch zu drucken' folder** | Optional second target for pick lists to be printed again later |
| **Pump control folder** | Where the pump scan control files go |
| **Halle M scan folder** | Where the scans of signed delivery notes land |
| **COO folder** | Optional: the certificate of origin folder with `COO calculation.xlsx`, `Coo IHK Formulare`, `Coo Italy` and the customer folders |
| **Banner style** | A single plain line (default) or the large banner |

The outbound folder is searched by country, customer and, if present, location and month. Countries may be named in German, English or as a code (`Deutschland`, `Germany`, `DE`), and month folders are recognized in many spellings (`Oktober 2026`, `Okt 26`, `2026-10`).

```
O:\Outbound
├── Deutschland
│   └── Nestle DE
│       ├── 2025                    year folder, archive only
│       └── September 2026
├── Frankreich
│   └── Hemodia
│       └── Oktober 2026
└── Saudi Arabien
    └── Tamer
        ├── Jeddah
        └── Riyadh
```

---

## Controls

Keyboard only: `↑` `↓` to move, `Enter` to select, `Esc` or `Backspace` to go back. Yes/no questions take `y` (or `j`) and `Enter`, anything else counts as no.

<img src="docs/main-menu.webp" width="560"/>

---

## Features

### Rename and create documents

Reads PWS / PAC / WP numbers and order numbers out of every PDF in the Downloads folder and renames the files. A pick list gets the first two words of the customer name, a document with several orders gets the first order number plus the last four digits of the others (`SORD26-00405_0406`). Anything that is not a Business Central document stays untouched.

<img src="docs/rename.webp" width="620"/>

A delivery note without its packing list, or the other way round, shows up as a red line.

<img src="docs/missing-pair.webp" width="560"/>

Each run ends with a summary of renamed files, files already correct, errors and missing pairs.

<img src="docs/rename-summary.webp" width="560"/>

### Groupage

Two or more pick lists for the same customer form a groupage. After a `y`, PROMEDIA COPILOT stamps **GROUPAGE** onto page 1 of each pick list and creates the groupage sheet from the template, with customer and pick numbers already filled in.

<img src="docs/groupage-done.webp" width="620"/>

The sheet opens in Excel on purpose: country, carrier, pallet count and planned pickup date are not on the pick list, so the team adds them, saves and closes Excel.

<p>
  <img src="docs/groupage-sheet.webp" width="48%"/>
  <img src="docs/groupage-sheet-filled.webp" width="48%"/>
</p>

<img src="docs/groupage-stamp.webp" width="520"/>

### Pump picks

If a pick list contains pumps, PROMEDIA COPILOT offers two Excel files built straight from the serial numbers in the PDF:

- `Pumpen.xlsx`: serial numbers grouped by bin, with counts and a total. Rows already in the PICKING bin are left out.
- `Control.xlsx`: the scan sheet for the warehouse floor. A scanned serial turns green, anything still red was missed.

<img src="docs/pumps.webp" width="620"/>

<img src="docs/pump-list.webp" width="400"/>

### Annotate pick lists

**Annotate WP documents** writes notes for the warehouse onto page 1 of a pick list, line by line. `del` removes the last line, `cancel` aborts, an empty line saves. On a groupage the text goes below the stamp. The text is written into the PDF and cannot be removed afterwards.

<img src="docs/annotate.webp" width="620"/>
<img src="docs/annotate-saved.webp" width="620"/>

<img src="docs/annotate-pdf.webp" width="520"/>

### Print

Delivery documents and warehouse picks in one list, sent straight to the configured printer. Delivery note and packing list print as two complete, sorted sets. Pick lists print once, a groupage as one entry with all its pick lists. Excel sheets open for a last check and are printed from Excel.

<img src="docs/print.webp" width="560"/>
<img src="docs/print-delivery.webp" width="560"/>

Anything already sent is marked `[printed]`, so nothing goes out twice by accident. The marker disappears once the files have left the Downloads folder.

<img src="docs/print-printed.webp" width="560"/>

### Move to folders

**Auto move to folders** files everything in three groups: delivery documents to the customer folder, pick lists with their pump list or groupage sheet to the pick list folder, and pump control files to the pump control folder.

<img src="docs/move.webp" width="560"/>

For delivery documents a small folder navigator opens. **From the document** shows the customer, location, country, packages (pallets and cartons `CT` counted separately) and net and gross weight read from the delivery notes. **Current** is the folder PROMEDIA COPILOT picked: country, customer, location and month, as far as matching folders exist. If the month folder is missing, creating it is offered first, named like the existing month folders.

<img src="docs/move-navigator.webp" width="560"/>

If the month folder exists, the navigator opens it directly and **Move here** is preselected. For customers with several locations it lands in the right one; one level up, the match is marked `<-- location`.

<p>
  <img src="docs/move-existing-month.webp" width="48%"/>
  <img src="docs/move-location.webp" width="48%"/>
</p>

Plain year folders such as `2025` are treated as archive and never offered as a target. Deliveries to the same customer, location and country move together. A file that is open elsewhere is reported as failed with the reason instead of being skipped silently.

<img src="docs/move-picks.webp" width="620"/>

### Scanned documents

The warehouse scans every signed delivery note after pickup, and the scans land in the Halle M folder with names like `doc0001.pdf`. **FÜ scan** reads them with the OCR built into Windows, no internet and no extra software, and proposes a name: `FÜ_<customer>_<order number>_<scan date>.pdf`. Each one is confirmed with `y`.

<img src="docs/fu-scan.webp" width="560"/>
<img src="docs/fu-scan-summary.webp" width="560"/>

**Auto move FÜ documents** files the renamed scans into the same customer folders as the delivery documents, using the address and the date read from the scan. OCR on paper is never perfect, so every proposal is worth a quick look.

<img src="docs/fu-move.webp" width="620"/>

### Certificate of Origin (beta)

For the German certificate of origin (IHK) Axium sends a draft e-mail with the Axium sales invoice and, for goods of Egyptian origin, the certificates of origin of the Italian chamber of commerce. Save the attachments with **Download all** as a ZIP into the Downloads folder, then choose **Certificate of Origin**. A short screen tells what is needed, `Enter` starts. If there is more than one thing to do, a list shows the draft ZIPs and the issued certificates in the Downloads folder.

Every ZIP with PDFs counts, whatever the attachments are called: PROMEDIA COPILOT reads each PDF and recognizes the invoice and the Italian certificates by their content. The draft number (8 digits) comes from the ZIP name; dates such as `20261016` are not taken for it. If the name has no number, the number of an attached IHK draft is used, otherwise it is asked for. Update ZIPs of PROMEDIA COPILOT itself are left out. The invoice decides by its origin column:

| Origin | What happens |
| --- | --- |
| **Egypt** | New Italian certificates go to the sheet `COO Italy`, one row per lot. The lots of the invoice go to `COO DE` under the draft number. `Formular IHK` is set to the draft number and saved as `COO <number>_IHK Formulare.pdf` in `Coo IHK Formulare`, ready for the IHK upload. New Italian certificates are filed in `Coo Italy` as `CO Italia_Lot <lots>_<number>.pdf`. |
| **Italy** | Nothing is calculated. A summary of the invoice is shown to check the IHK draft. |

How the numbers are worked out:

- Pallets per lot by rule of three: EA of the lot / (EA of the invoice / packages of the invoice). For the Italian certificates the same with their quantities and pallets.
- Net and gross weight are split by the EA share of each lot, so the rows always add up to the totals of the document.
- The Italian chamber often swaps net and gross weight. The bigger value is always taken as gross weight.
- For each lot the preview shows the covering Italian certificates and the gross weight still left on them. A lot without an Italian certificate or with too little weight left is shown in red.
- Each Italian certificate is checked before anything is written:
  - **Pallets** for its EA by the EA per pallet of the article in the catalog. The article number comes from the invoice line of its lots. Without a catalog entry the usual EA per pallet of the earlier certificates of the article is used.
  - **Net and gross weight per EA** by the earlier certificates of the same article in `Coo Italy` (net within 1 %, gross within 3 %).
  - If it does not fit, for example 8 pallets where 8,400 EA make 7, the preview shows the expected values in red and the run stops; it only goes on if you confirm. Usually the Italian chamber has to cancel and reissue such a certificate. Articles with fewer than 3 earlier certificates get no weight check.
  - The catalog comes from the catalog backup of PROMEDIA Control: put `Katalog_Backup_*.json` into the Downloads folder once (and again after catalog changes). The newest one is kept as `_coo_catalog.json` next to the script. The values of the earlier certificates are read once and kept in `_coo_history.txt`, after that only new files are read.
- The pallets of the invoice are checked against the catalog too; a difference is shown in red.
- If the invoice also has goods of other origin, its totals cannot be used: pallets, net and gross weight of the Egyptian goods are typed in from the IHK draft, with a suggestion from the Italian certificates.

Before anything is written, everything is shown in a preview and confirmed with `y`. A draft number that is already in `COO DE` is not entered a second time; it is only compared with the invoice. Before each change a copy of `COO calculation.xlsx` goes to `_coo_backup` in the PROMEDIA COPILOT folder (the last 20 are kept). If the workbook is open, by you or a colleague, nothing is changed.

**Issued certificates.** When the certificate comes back from the IHK, save it into the Downloads folder: the scan named `COO_<number>_<customer>.pdf` (older spellings such as `Coo 40068203 MPC UAE.pdf` work too) or the IHK downloads `..._digital_CoO.pdf` and `..._cert_doc.pdf`. **Certificate of Origin** lists them by number and moves them into the customer folder in the COO folder:

- The customer folder is found by the file name (`Tamer` -> `Tamer Jeddah _SA`), otherwise by the consignee in the document (`TAMER ... JEDDAH ... SAUDI ARABIA`). If neither is clear, the folder is chosen from a list.
- Files are named `COO_<number>_<customer>.pdf`, with the customer part taken from the newest certificate in that folder (`Tamer`, `MPC_UAE`, `Seeder_Qatar`). IHK downloads keep their name.
- A file that is already in the customer folder (same content, any name) is only removed from the Downloads folder. A different file with the same name is never replaced; the new one gets ` (2)`.

The COO folder is set under **Settings**. Writing takes about half a minute, because Excel recalculates the whole workbook once.

### Settings

Printer and folders can be changed at any time, in the same list as on first start. They are stored next to the script. `reset.bat` clears everything; run it before handing the folder to someone else.

<img src="docs/settings.webp" width="620"/>

---

## Tech stack

| Layer | What |
| --- | --- |
| Runtime | PowerShell 5.1, Windows Console API |
| Spreadsheets | Excel COM interop |
| PDF parsing | Manual PDF stream inflate + text-token extraction, no external library; a layout-aware reader (fonts, CMaps, object streams) for invoices and certificates of origin |
| OCR | Windows.Media.Ocr, built into Windows |

---

## Project structure

```
PROMEDIA COPILOT/
├── PROMEDIA COPILOT.bat         starts the tool
├── _promedia_copilot.ps1        the program
├── promedia_copilot.ico         icon for a desktop shortcut
├── reset.bat                   clears personal settings
├── update.txt                  version + file list for the offline update
├── pumplist_template.xlsx      pump list template
├── pump_control_template.xlsx  scan control template
├── groupage_template.xlsx      groupage sheet template
├── PM-COPILOT-HB-DE-001_Benutzerhandbuch_Rev1.0.pdf   user guide, German
├── PM-COPILOT-HB-EN-001_User_Guide_Rev1.0.pdf        user guide, English
└── docs/                       screenshots used above
```

`_promedia_copilot_settings.txt`, `_promedia_copilot_pairs.txt`,
`_promedia_copilot_printed.txt`, `_coo_history.txt`, `_coo_catalog.json` and the `_coo_backup` folder are created at runtime and never leave the machine.

---

## Changelog

### 1.5.1

- Certificate of Origin: Italian certificates are checked before anything is written.
  Pallets by the EA per pallet of the article in the catalog backup (`Katalog_Backup_*.json`),
  net and gross weight per EA by the earlier certificates of the same article. A certificate
  that does not fit stops the run with the expected values, instead of the fixed 1,200 EA
  per pallet hint. The pallets of the invoice are checked against the catalog too.

### 1.5.0

- New menu item **Certificate of Origin (beta)**: reads the ZIP of the Axium draft e-mail
  (sales invoice and Italian certificates of origin, whatever the attachments are called),
  fills `COO Italy` and `COO DE` in `COO calculation.xlsx`, saves the IHK form as PDF and
  files new Italian certificates. Goods of Italian origin only get a summary to check the
  IHK draft.
- Issued certificates from the IHK in the Downloads folder are moved into the customer
  folder and named `COO_<number>_<customer>.pdf`.
- New setting **COO folder** for the certificate of origin folder.
- New PDF text reader for documents that are not made by Business Central.
- FÜ scan and Auto move FÜ documents are no longer beta.

### 1.2.5

- The plain banner is now the default. A banner style chosen in Settings stays as
  it is.

### 1.2.3

- Fixed the destination country of a delivery document being read from a
  region code in brackets: for "Bagnolo in Piano(RE) IT" the folder suggestion
  used RE (Reunion) instead of IT (Italy). Two-letter codes in brackets are now
  ignored for both country and location, and the country is determined before
  a trailing country line is removed from the address.
- The customer name FAROUK MAAMOUN is written as Tamer whenever it appears in a
  file name (renamed documents, pick lists, pump lists and pump control files).
  The documents themselves are not changed.

### 1.2.2

- Fixed a failed move (e.g. the target file is still open elsewhere) not showing
  any readable reason: moving a pick list, pump list or pump control file to a
  busy destination silently reported it as moved, because `Move-Item`'s own
  error does not stop the script unless told to. The move is now correctly
  reported as failed, with the real reason, and the screen stays up until a key
  is pressed instead of being redrawn away in a fraction of a second.
- The same fix applies to renaming documents (option 1) and to renaming scanned
  FÜ documents: a document that is open elsewhere is no longer silently marked
  as renamed.
- Creating a groupage sheet, pump list or pump control file now reports a
  missing or locked Excel template clearly instead of a generic COM error.

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
