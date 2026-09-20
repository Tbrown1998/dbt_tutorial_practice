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
- `DEV_HOST` — browser URL when logged in, WITHOUT the `https://`.
- `DEV_HTTP_PATH` — SQL Warehouses > (your warehouse) > Connection details > HTTP path.
- `DATABRICKS_PAT_TOKEN` — your personal access token.
- `DEV_CATALOG` / `DEV_SCHEMA` — where dbt writes tables. Catalog is often `main`;
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

- `uv` install — permanent, once per machine.
- `.venv` folder — a folder on disk, per project. Not a running process. Recreated
  anytime with `uv venv` or `uv sync`. Nothing to "start" or "stop".
- `.env` file — permanent file on disk.
- The loaded variables from `source .env` — temporary, gone when the terminal closes.

## Common errors and fixes

- **Python 3.14 / Pydantic V1 error** → venv built on wrong Python. `rm -rf .venv uv.lock`,
  then `uv venv --python 3.11`, then `uv add dbt-databricks` again.
- **"profiles.yml not found"** → wrong folder, or missing `DBT_PROFILES_DIR=..`. Add it to
  `.env` or use `--profiles-dir ..`.
- **Connection ERROR** → check host has no `https://`, token not expired, no trailing
  spaces in `http_path`, and that you ran `source .env` in this terminal.
- **`uv: command not found`** → run `source $HOME/.local/bin/env`.
