# Star Citizen Operations Tracker

A portfolio-grade, multi-user operations tracker for **Star Citizen** built with Python, Streamlit, Supabase/PostgreSQL, and live external data integrations.

The project is designed around a practical data problem: players generate activity across contracts, salvage, mining, commodities, blueprints, and loot, but the information is normally scattered across game sessions and external websites. This app centralizes those workflows into an authenticated system with persistent records, calculations, dashboards, inventory views, exports, and API-assisted reference data.

> **Portfolio note:** This public release maps to the internally validated Deep Space Blue V21 build, but uses normal semantic release numbering for GitHub.

## Live Demo

Streamlit deployment: `https://sc-tracker-tool.streamlit.app/`

The application uses user authentication, so some functionality requires an account.

## What the App Demonstrates

- Authenticated multi-user application design
- PostgreSQL persistence through Supabase
- Row Level Security for user-isolated records
- CRUD workflows for contracts, resources, commodities, blueprints, and loot
- Automated financial and inventory calculations
- Interactive Plotly dashboards and filters
- CSV, ZIP, Excel, and optional Google Sheets exports
- External API/data integrations for live reference information
- Session persistence and encrypted refresh-token cookie handling
- Database migrations and schema repair workflows
- Offline connection-contract tests for core CRUD behavior

## Core Workflows

### Contracts and Salvage

Track mission activity with contract type, payout, salvage proceeds, expenses, crew size, notes, and calculated take-home pay.

Core calculations include:

```text
Gross income = Contract payout + Salvage proceeds
Net payout = Gross income - Expenses
Individual share = Net payout / Crew members
```

The current release includes the salvage-aware contract save/verification logic introduced in the final internal migration.

### Mining and Ore Ledger

Record mined, purchased, and sold ore or gems using SCU quantity, unit price, total value, location, and notes. The ledger supports inventory and cash-flow calculations instead of storing only a single value.

### Commodity Trading

Track commodity purchases, sales, and losses. The workflow includes inventory, trade net, fees, route information, market references, and saved trade history.

### Dashboards

The dashboard combines contract, ore, and commodity activity into a consolidated operational view with filters and interactive visualizations.

### Saved Records and Exports

Users can search, edit, delete, and export their own records. Export options include formatted Excel workbooks, CSV packages, and optional Google Sheets creation when credentials are configured.

## Architecture

```text
Browser
  │
  ▼
Streamlit application (app.py)
  │
  ├── Supabase Authentication
  │
  ├── Supabase PostgreSQL
  │     └── Row Level Security by authenticated user ID
  │
  ├── UEX live/reference data
  ├── SC Trade Tools integration
  ├── SC Craft Tools reference integration
  └── Google Sheets API (optional export)
```

### Data Security Model

- Authentication is handled by Supabase.
- Private rows are associated with the authenticated user's Supabase user ID.
- Row Level Security policies restrict access to user-owned records.
- Application secrets are supplied through Streamlit Secrets and are not stored in GitHub.
- `.streamlit/secrets.toml` is explicitly ignored by Git.

## Technology Stack

| Layer | Technology |
|---|---|
| Application | Python, Streamlit |
| Database | PostgreSQL via Supabase |
| Authentication | Supabase Auth |
| Data analysis | Pandas |
| Visualization | Plotly |
| Excel export | XlsxWriter |
| External data | UEX, SC Trade Tools, SC Craft Tools |
| Optional cloud export | Google Sheets API / gspread |
| Image handling | Pillow |
| Session persistence | Encrypted Streamlit cookie manager |

## Repository Structure

```text
star-citizen-tracker/
├── .github/
│   └── workflows/
│       └── ci.yml
├── .streamlit/
│   ├── config.toml
│   └── secrets.toml.example
├── assets/
├── data/
│   └── mining_locations.csv
├── database/
│   ├── schema.sql
│   ├── migrations/
│   │   └── schema_migration_*.sql
│   └── verification/
│       └── commodity_sales_verification.sql
├── docs/
│   └── screenshots/
├── tests/
│   └── offline_connection_tests.py
├── .gitignore
├── CHANGELOG.md
├── README.md
├── app.py
└── requirements.txt
```

## Local Setup

### 1. Clone the repository

```bash
git clone https://github.com/Ticklrx3/star-citizen-tracker.git
cd star-citizen-tracker
```

### 2. Create a virtual environment

Windows PowerShell:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure secrets

Copy:

```text
.streamlit/secrets.toml.example
```

to:

```text
.streamlit/secrets.toml
```

Then supply your own credentials locally. Never commit the real secrets file.

Required values:

```toml
SUPABASE_URL = "..."
SUPABASE_KEY = "..."
COOKIE_PASSWORD = "..."
APP_PUBLIC_URL = "http://localhost:8501/"
```

Optional integrations can also use `UEX_API_TOKEN`, `SC_TRADE_TOOLS_TOKEN`, and `GOOGLE_SERVICE_ACCOUNT_JSON`.

### 5. Prepare the database

For a fresh environment, review `database/schema.sql` and the ordered migrations in `database/migrations/` before running SQL against Supabase.

For the existing production database, **do not rebuild the database**. The latest required migration is:

```text
database/migrations/schema_migration_v10_contract_salvage_and_connections.sql
```

If that migration has already been successfully applied, no additional V21 database migration is required.

### 6. Run locally

```bash
streamlit run app.py
```

## Validation

Compile the application:

```bash
python -m py_compile app.py
```

Run the offline CRUD/connection contract tests:

```bash
python tests/offline_connection_tests.py
```

These tests use an in-memory Supabase-compatible query chain and do not modify the live database.

## Streamlit Community Cloud Deployment

Deploy with:

- Repository: `Ticklrx3/star-citizen-tracker`
- Branch: the branch being validated, such as `release-v1`
- Entrypoint: `app.py`

Add the real secret values in Streamlit Community Cloud's Secrets interface rather than GitHub.

For a test deployment, set `APP_PUBLIC_URL` to the test Streamlit URL so password recovery and redirect behavior can be validated independently of production.

## Release Process

1. Build and validate changes on a release branch.
2. Confirm startup and authentication on a separate Streamlit test deployment.
3. Test contracts, salvage, mining, commodities, saved records, dashboards, exports, avatars, and integrations.
4. Merge the validated branch into `main`.
5. Tag the public release using semantic versioning, for example `v1.0.0`.

## Screenshots

Add current application screenshots under `docs/screenshots/` and reference them here. Recommended views:

- Dashboard
- Contract + salvage workflow
- Mining/Ore Ledger
- Commodity tracker
- Saved Records
- Export workflow

This keeps the README focused on the product while making the repository useful as a professional portfolio project.

## Security

Do not commit:

- `.streamlit/secrets.toml`
- Supabase keys that are intended to remain private
- cookie encryption passwords
- external API tokens
- Google service-account credentials
- exported user data

If a credential is ever committed publicly, remove it from the repository and rotate/revoke it at the provider.

## Disclaimer

This is an unofficial fan-made project and is not affiliated with or endorsed by Cloud Imperium Games or Roberts Space Industries. Game names and related trademarks belong to their respective owners.
