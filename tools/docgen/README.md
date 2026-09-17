# docgen — walkthrough document generator

Builds `docs/UOI-Azure-Portal-Demo-Walkthrough.docx`, the step-by-step presenter
guide with portal screenshots.

This exists because the repository previously contained the *output* but not the
*generator*, so nobody but the original author could regenerate or correct the
document. Now the build is reproducible from a clean checkout.

## Build

```powershell
cd tools/docgen
npm install
node build-doc.js ../../docs/UOI-Azure-Portal-Demo-Walkthrough.docx
```

`build-doc.js` takes an optional output path as its first argument and defaults
to writing beside itself. All prose, tables and figure placement live inline in
that one file — there is no template and no external content source.

## Validating the output

The document is a zip container; a corrupt one often still opens in Word while
failing elsewhere. If you have the `docx` skill available:

```powershell
$env:PYTHONUTF8='1'; $env:PYTHONIOENCODING='utf-8'
python scripts/office/validate.py docs/UOI-Azure-Portal-Demo-Walkthrough.docx
```

A good build reports **433 paragraphs**, **14 embedded images**, and
`All validations PASSED`. The paragraph count will drift as the prose is
edited — the figure count should not, unless a step was added or removed.

> The validator emits spurious failures under Windows' default cp1252 encoding.
> Set `PYTHONUTF8=1` and `PYTHONIOENCODING=utf-8` as shown or you will chase
> errors that are not there.

## Screenshots

`shots-redacted/` holds the 14 figures the document embeds. Every one has been
put through `redact.ps1`, which paints over:

- the signed-in account chip in the portal header (present on every frame), and
- the subscription name and subscription ID on the resource-group blade.

`redact.ps1` reads from a `shots/` directory and writes to `shots-redacted/`.
It never edits in place, so the originals survive a mistake.

```powershell
pwsh ./redact.ps1
```

Two things worth knowing if you re-capture:

- Frames are **1680x950**. The redaction rectangles are hard-coded to that
  geometry and will land in the wrong place at any other window size.
- The header fill is sampled at **x=420, y=20**. Do not move this to the right
  of centre — around x=1200 you hit the Copilot button and the patch is painted
  the wrong colour.

**Never commit the unredacted `shots/` directory.** The original captures carry
the signed-in user's alias and directory name. `.gitignore` blocks `shots/`,
along with the Playwright `state.json` and `edge-profile/`, both of which hold
live Azure Portal session cookies.

Capture itself is manual: sign in to the portal, size the window to 1680x950,
and grab each blade in the order the document uses them. The Playwright capture
scripts used originally are deliberately *not* included — they were bound to one
tenant, one account and one signed-in browser profile, so they would not have
worked for anyone else and would have shipped identifiers with them.

## Identifiers

The document must not hard-code environment identifiers. Subscription, data
collection endpoint and DCR immutable ID appear as `<your-subscription-id>`,
`<your-dce-endpoint>` and `<your-dcr-immutable-id>`, matching the convention in
`docs/demo-azure-portal.md`. Readers resolve them with the `az` commands in that
guide's Environment section.

Before committing a rebuilt document, confirm nothing leaked back in. A plain
text search will *not* find these — the text is compressed inside the zip:

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
$tmp = "$env:TEMP\docxscan"
[System.IO.Compression.ZipFile]::ExtractToDirectory(
  'docs/UOI-Azure-Portal-Demo-Walkthrough.docx', $tmp)
Select-String "$tmp\word\document.xml" -Pattern 'your-real-subscription-id'
Remove-Item $tmp -Recurse -Force
```
