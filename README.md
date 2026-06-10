# Just some shell scripts

The following is a repo containing some `.sh` scripts I wrote over the past two years, more will get added as they are made clean and ready for a public repo! Some of these I've been working on for a while and ported to Python for a project management app I'm working on. **create_project.sh** and **Make_quote-3.0.sh** are the ones!

I hope you find something in this repo useful :)

> These are provided AS IS and interact directly with the file system! Be careful while testing and experimenting with them, use a sandbox first (I never do but you should!)

---

## create_project.sh

Scaffolds a new project folder from a template, fills in a `README.md` with the captured metadata, and opens the result.

**Setup — edit the 3 lines at the top of the script:**

```bash
STUDIO_ROOT="/path/to/your/studio/root"
TEMPLATES_DIR="$STUDIO_ROOT/Templates/Project_Structures"
PROJECTS_ROOT="$STUDIO_ROOT/Projects"
```

`STUDIO_ROOT` is just a convenient anchor — `TEMPLATES_DIR` and `PROJECTS_ROOT` can point anywhere you want, they don't have to live under the same parent.

> **Quick test:** point `STUDIO_ROOT` at the `Studio/` folder included in this repo and run it as-is. The example templates are wired up and ready to go.

**Running it:**

```bash
bash create_project.sh
```

The script will ask for a project name, then show a numbered list of the template types it finds in `TEMPLATES_DIR`. Pick one, and it:

1. Copies the entire template folder into `Projects/<type>/<name>_<YYMMDD>/`
2. Writes a `README.md` with the project name, type, code, and date
3. Opens the new folder

**Adding your own template types:**

Drop a folder inside `Templates/Project_Structures/`. Whatever you name it becomes a selectable type. Whatever is inside gets copied into every new project of that type. No config changes needed.

```
Studio/                              ← STUDIO_ROOT
├── Templates/
│   └── Project_Structures/         ← TEMPLATES_DIR
│       ├── Archviz/                 ← type "Archviz" appears in the list
│       │   ├── Assets/
│       │   ├── Renders/
│       │   └── References/
│       ├── Animation/
│       │   ├── Assets/
│       │   ├── Output/
│       │   └── References/
│       └── YourCustomType/          ← add as many as you want
│           └── ...
└── Projects/                        ← PROJECTS_ROOT
    ├── archviz/                     ← auto-created on first use
    │   └── MyScene_260610/
    │       ├── Assets/
    │       ├── Renders/
    │       ├── References/
    │       └── README.md            ← auto-generated
    └── animation/
```

A sample `Studio/` structure is included in this repo so you can see the layout before pointing the script at your own files.

---

## Make_quote-3.0.sh

A 10-step terminal wizard that generates a polished, print-ready HTML quotation. Bilingual (English / Español), multi-currency, embeds your logo as base64 so the file is fully self-contained.

**Setup — edit the config block at the top:**

```bash
QUOTE_DIR="/path/to/your/quotes/folder/${MONTH_FOLDER}"
LOGO_PATH="/path/to/your/logo.png"
ARTIST_NAME="Your Name"
ARTIST_EMAIL="your@email.com"
ARTIST_ADDRESS="123 Your Street, City, Country"
```

`MONTH_FOLDER` is auto-generated (`jun26`, `jul26`, etc.) so quotes are organized by month automatically. `LOGO_PATH` is a square PNG — it gets embedded directly in the HTML so the file is portable.

**Running it:**

```bash
bash Make_quote-3.0.sh
```

**The 10 steps:**

| Step | What it asks |
|------|-------------|
| 1 | Language (English / Español) |
| 2 | Currency (USD / EUR / GBP / MXN) |
| 3 | Tax — yes/no, then rate (%) if yes |
| 4 | Quote number |
| 5 | Client info — name, contact, email, phone, address, PM, PO number |
| 6 | Project details — name, code, type, description |
| 7 | Number of line items |
| 8 | Line items — name, description, price each |
| 9 | Technical specifications (optional) |
| 10 | Project milestones (optional) |

**Output:**

An `.html` file saved to `QUOTE_DIR`, auto-opened in your default browser. Print to PDF from there (`Cmd+P` / `Ctrl+P`). The file includes a full pricing breakdown with tax, payment terms, T&Cs, and a signature block.

Tax is a simple percentage on the subtotal — works for VAT, sales tax, or whatever your jurisdiction uses. Enter `0` or skip it entirely if your quotes are tax-exclusive.

**Customizing the document:**

The payment terms, T&Cs, revision policy, and cancellation text are template strings inside the script — search for `L_PAYMENT_BODY` and `L_TNC_BODY` in the **LANGUAGE STRINGS** section and edit them to match your rates and policies. Both English and Spanish versions are there.

For layout or branding changes, the full HTML document lives between `cat > "$HTML_FILE" << HTMLEOF` and `HTMLEOF` — everything in that block is the output file, CSS included.

---

## Studio OS

These are somewhat antiquated but they could be useful for integrating them as backend for your own apps. Currently I use Python versions with a bit better logic in developing Studio OS — I'll make those available once they are nice and stable.

---

### Tested on MacOS

These should work on UNIX and UNIX like systems but I've only tested in MacOS just an additional disclaimer :)
