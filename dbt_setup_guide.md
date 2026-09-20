# dbt + uv + Databricks Setup Guide

A step-by-step record of how to set up a dbt project from scratch and get a working
Databricks connection. Follow top to bottom. Written to still make sense years later.

Context: I work inside WSL (Linux), not Windows. All commands run in a **bash** terminal
(prompt looks like `tosin@DESKTOP-...:~/...$`), never PowerShell or cmd.

---

## One-time setup (do this once per machine, ever)

Install `uv` (the tool that manages Python versions, virtual environments, and packages):

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env
uv --version
```

Notes:
- If `uv --version` says "not found" right after install, run the `source` line above. It
  puts uv on your PATH for the current terminal.
- To make uv available in every new terminal automatically:
  ```bash
  echo 'source $HOME/.local/bin/env' >> ~/.bashrc
  ```

That's it for one-time setup. Never reinstall uv again.

---

## Per-project setup (do this once for each new dbt project)

### Step 1. Get into the project folder

If cloning an existing repo:
```bash
git clone <repo-url>
cd <repo-folder>
```

If starting fresh, just create and enter a folder:
```bash
mkdir my_project && cd my_project
```

### Step 2. Initialize the uv project

```bash
uv init --bare --name my_project --python 3.11
```

- Creates `pyproject.toml` (the file that tracks dependencies).
- `--bare` = minimal, no sample files.
- The name gets normalized to hyphens (e.g. `my-project`). That's cosmetic, ignore it.
- The name does NOT need to match the repo/folder name.

### Step 3. Create the virtual environment on Python 3.11 (IMPORTANT)

```bash
uv venv --python 3.11
uv run python --version
```

- This must say `3.11.x`. If uv defaults to 3.14, dbt breaks (Pydantic V1 error).
- Run this BEFORE any `uv add` or `uv run`, otherwise uv auto-builds the venv with the
  wrong Python (usually conda's 3.14).
- If it says 3.11 isn't installed:
  ```bash
  uv python install 3.11
  uv venv --python 3.11
  ```

### Step 4. Install dbt (and Elementary if the course wants it)

```bash
uv add dbt-databricks
uv add 'elementary-data[databricks]~=0.22.0'
```

- `dbt-databricks` is the adapter for Databricks. Different warehouse = different adapter.
- Elementary is optional (data testing/observability). Skip if not needed.

### Step 5. Scaffold the dbt project

```bash
uv run dbt init my_dbt_project --skip-profile-setup
```

- Creates a subfolder `my_dbt_project/` with `dbt_project.yml`, `models/`, `seeds/`, etc.
- `--skip-profile-setup` skips interactive connection prompts (we set that up manually next).

**Result: a nested layout.**
```
my_project/                 <- OUTER: pyproject.toml, uv.lock, .venv, (profiles.yml, .env go here)
└── my_dbt_project/         <- INNER: dbt_project.yml, models/, seeds/, snapshots/, etc.
```
Remember this nesting. It matters for where files go and where commands run.

---

## Connecting to Databricks

### Step 6. Create profiles.yml in the OUTER folder

The profile name at the top MUST match the `profile:` line in `dbt_project.yml`
(open the inner `dbt_project.yml`, look near the top). Replace `my_dbt_project` below
with whatever that line says.

```yaml
my_dbt_project:
  target: "{{ env_var('DBT_TARGET', 'dev') }}"

  outputs:
    dev:
      type: databricks
      threads: 8
      host: "{{ env_var('DEV_HOST') }}"
      token: "{{ env_var('DATABRICKS_PAT_TOKEN') }}"
      catalog: "{{ env_var('DEV_CATALOG') }}"
      schema: "{{ env_var('DEV_SCHEMA') }}"
      http_path: "{{ env_var('DEV_HTTP_PATH') }}"
```

- Nothing is hardcoded here. Everything pulls from environment variables via `env_var()`.
- The real values live in a separate `.env` file (next step), kept out of git.

### Step 7. Create .env in the OUTER folder with real values

```
DBT_TARGET=dev
DBT_PROFILES_DIR=..
DEV_HOST=your-workspace.cloud.databricks.com
DATABRICKS_PAT_TOKEN=dapiXXXXXXXXXXXX
DEV_CATALOG=your_catalog
DEV_SCHEMA=your_schema
DEV_HTTP_PATH=/sql/1.0/warehouses/xxxxxxxx
```

Where to find each value in Databricks:
- `DEV_HOST` - browser URL when logged in, WITHOUT the `https://`.
- `DEV_HTTP_PATH` - SQL Warehouses > (your warehouse) > Connection details > HTTP path.
- `DATABRICKS_PAT_TOKEN` - your personal access token.
- `DEV_CATALOG` / `DEV_SCHEMA` - where dbt writes tables. Catalog is often `main`;
  schema can be anything, e.g. `dbt_tosin`.
- `DBT_PROFILES_DIR=..` tells dbt the profiles.yml is one folder up (because of the nesting).

### Step 8. Protect the token

```bash
echo ".env" >> .gitignore
```

Confirm it worked:
```bash
cat .gitignore
```
Look for `.env` in the list. This stops the token ever being pushed to GitHub.

### Step 9. Load the .env and test the connection

From the OUTER folder:
```bash
set -a && source .env && set +a
```

Then go into the inner dbt project and test:
```bash
cd my_dbt_project
uv run dbt debug
```

- Green `All checks passed!` = connected. Done.
- If it says "profiles.yml not found", the `DBT_PROFILES_DIR=..` line is missing from `.env`,
  or run it manually: `uv run dbt debug --profiles-dir ..`

---

## Every session after setup (the short daily routine)

Environment variables disappear when you close a terminal, so reload them each time you
open a fresh one:

```bash
cd ~/win/Desktop/cde/dbt_modelling/my_project   # outer folder
set -a && source .env && set +a                 # reload secrets
cd my_dbt_project                               # into the dbt project
uv run dbt debug                                # confirm connection
```

Then run your dbt work (e.g. `uv run dbt run`, `uv run dbt test`).

---

## Picking up an existing project (clone or copy)

You don't repeat the `uv add` steps. The lockfile rebuilds everything:

```bash
git clone <repo-url>
cd <repo-folder>
uv sync                    # recreates .venv with exact same packages
# add your own .env (secrets are never in the repo)
set -a && source .env && set +a
cd <dbt-project-subfolder>
uv run dbt debug
```

---

## Quick reference: what's permanent vs temporary

- `uv` install - permanent, once per machine.
- `.venv` folder - a folder on disk, per project. Not a running process. Recreated
  anytime with `uv venv` or `uv sync`. Nothing to "start" or "stop".
- `.env` file - permanent file on disk.
- The loaded variables from `source .env` - temporary, gone when the terminal closes.

## Common errors and fixes

- **Python 3.14 / Pydantic V1 error** → venv built on wrong Python. `rm -rf .venv uv.lock`,
  then `uv venv --python 3.11`, then `uv add dbt-databricks` again.
- **"profiles.yml not found"** → wrong folder, or missing `DBT_PROFILES_DIR=..`. Add it to
  `.env` or use `--profiles-dir ..`.
- **Connection ERROR** → check host has no `https://`, token not expired, no trailing
  spaces in `http_path`, and that you ran `source .env` in this terminal.
- **`uv: command not found`** → run `source $HOME/.local/bin/env`.

---

# PART 2: Setting up VS Code (the WSL extension trap)

This part caused hours of confusion once. Read the explanation first, then the fix.

## The symptom

You install the "Power User for dbt" extension. It refuses to work and says:

- "dbt core is not installed"
- "Python interpreter must be configured"
- "Could not find a Python interpreter with dbt installed in your terminal"

Meanwhile `uv run dbt debug` works perfectly in the terminal. So dbt IS installed.
The extension just can't see it.

## The cause (understand this and everything else makes sense)

There are TWO separate computers sharing one screen:

- The Windows side: `C:\Users\hp\...`, PowerShell, cmd
- The Linux side (WSL): `/home/tosin`, bash, where uv and dbt actually live

VS Code can run on EITHER side. If it runs on the Windows side, its extensions are
Windows programs. A Windows program cannot run a Linux program. No setting fixes that.

**The trap:** VS Code can show you a bash/WSL terminal even while VS Code itself is
running on the Windows side. So seeing a Linux prompt does NOT mean VS Code is in
WSL mode. That is the single most confusing part of this whole problem.

## How to tell which side VS Code is on

Look at the title bar at the very top of the window:

- `my_project [WSL: Ubuntu]`  = correct, running on the Linux side
- `my_project`                 = wrong, running on the Windows side

Second check: open "Python: Select Interpreter" and look at the paths listed.

- Paths like `/home/...` or `/mnt/...` = Linux side, correct
- Paths like `C:\Users\...python.exe`  = Windows side, wrong

## The fix (do these in order)

### Step 1. Install the WSL extension

In the VS Code Extensions panel, search for **WSL** by Microsoft
(id: `ms-vscode-remote.remote-wsl`). Install it.

Without this extension, VS Code can never enter WSL mode, and nothing else here works.

### Step 2. Reopen the folder in WSL

`Ctrl+Shift+P` then type **"WSL: Reopen Folder in WSL"** and press Enter.

The window reloads. Confirm the title bar now shows `[WSL: Ubuntu]`.

### Step 3. Install the extensions ON THE LINUX SIDE

This is the step everyone misses. Extensions are installed per side. Your Windows
extensions do NOT carry over to WSL. You must install them again for Linux.

Fastest way, run these in the WSL terminal:

```bash
code --install-extension ms-python.python
code --install-extension innoverio.vscode-dbt-power-user
```

Verify they landed on the Linux side:

```bash
code --list-extensions
```

The output should begin with "Extensions installed on WSL: Ubuntu:" and list both.
If a needed one is missing, install it and re-check.

### Step 4. Reload the window

`Ctrl+Shift+P` then **"Developer: Reload Window"**.

### Step 5. Select the interpreter

`Ctrl+Shift+P` then **"Python: Select Interpreter"**.

The list should now show Linux paths. Pick the one labelled **Workspace**:

```
my_project (3.11.x)  ./.venv/bin/python
```

Do NOT pick:
- the Conda `base` entry
- the `Global` entry
- the bare `cpython-3.11...` entry (that is raw Python without your packages)

### Step 6. Confirm it worked

- The "dbt core is not installed" message at the bottom of VS Code should be gone
- Open a `.sql` file in `models/`. Run/preview buttons appear at the top right
- Typing `{{ ref(` should autocomplete model names

If unsure, run `Ctrl+Shift+P` then **"dbt: Validate Project"**. It checks everything
and names whatever is still wrong.

## Things NOT to do (these waste time)

- Do NOT set `python.defaultInterpreterPath` manually in settings.json.
  It fails with "could not be resolved" because `.venv/bin/python` is a Linux symlink
  that the Windows side cannot follow.
- Do NOT set `dbt.dbtPythonPathOverride`. The extension's own docs say avoid it unless
  you use Meltano, because the extension relies on the interpreter to read env vars.
- Do NOT browse for the interpreter with the file picker. The `.venv/bin` folder can
  look EMPTY through the Windows-side browser even though the files are there. That is
  the symlink problem again, not a missing file.
- Do NOT run `source .venv/bin/activate`. That is the old pip way. With uv, `uv run`
  handles it. Mixing conda base and a manually activated venv just creates confusion.
  If your prompt shows both, type `deactivate`.

All of these are symptom-chasing. The real fix is always Steps 1 to 3 above:
get VS Code onto the Linux side, then install the extensions there.

## About the .vscode folder

VS Code creates `.vscode/settings.json` in your project root the moment you change a
workspace setting (like selecting an interpreter). This is normal, keep it.

But add it to `.gitignore`, because it stores machine-specific paths:

```bash
echo ".vscode/" >> .gitignore
```

## About the "/mnt/ is slow" warning

VS Code may warn that the workspace is on the Windows file system and recommend moving
it to the Linux file system.

What it means: the project sits on the Windows drive (`C:\...`), which Linux reaches
through `/mnt/c/`. Every file read crosses a translation layer, which is slow. dbt and
git touch thousands of small files, so runs feel sluggish. It is also the source of the
symlink weirdness above.

Optional fix, move the project into the Linux home:

```bash
mv /mnt/c/Users/hp/Desktop/cde ~/cde
```

Trade-off: files in the Linux home are less convenient to browse from Windows Explorer.
Not urgent. Everything works either way.

## Opening a different project later: what repeats and what doesn't

Done once, ever (applies to all projects):
- Installing the WSL extension
- Installing Python and dbt extensions on the WSL side

Done once per project:
- Selecting the interpreter (VS Code remembers it in that project's `.vscode/settings.json`)

Done every time you open a project:
- Launch it from a WSL terminal so it opens in WSL mode:
  ```bash
  cd /path/to/project
  code .
  ```

## Quick diagnosis table

| What you see | What it means | What to do |
|---|---|---|
| Title bar has no `[WSL: Ubuntu]` | VS Code is on the Windows side | Step 1 and 2 above |
| Interpreter list shows `C:\...python.exe` | Python extension is on the Windows side | Step 1 to 3 above |
| `code --list-extensions` missing `ms-python.python` | Extensions not installed on Linux side | Step 3 above |
| "could not be resolved" on an interpreter path | You are hand-editing settings.json | Remove it, do Step 1 to 5 |
| `.venv/bin` looks empty in the file browser | Symlinks, browsed from the Windows side | Stop browsing, do Step 1 to 5 |
| Terminal works but extension doesn't | Classic sign of the Windows/Linux split | Step 1 to 3 above |
