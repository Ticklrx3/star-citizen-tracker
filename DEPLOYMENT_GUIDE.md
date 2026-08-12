# Deployment Guide

This release should be promoted in two stages: first to a GitHub release branch and separate Streamlit test app, then to `main` and the production Streamlit URL.

## Before GitHub Changes

1. In Streamlit Community Cloud, open the current app's settings.
2. Copy the complete Secrets contents to a secure local file that is **not** inside the Git repository.
3. Record the current app URL/subdomain, repository, branch, entrypoint, and Python version.
4. Do not change the Supabase database during repository cleanup.

## Create the Release Branch

A fresh clone avoids stale GitHub username remotes:

```bash
git clone https://github.com/Ticklrx3/star-citizen-tracker.git
cd star-citizen-tracker
git switch -c release-v1
```

If using an existing clone, update its remote first:

```bash
git remote -v
git remote set-url origin https://github.com/Ticklrx3/star-citizen-tracker.git
git remote -v
```

## Replace the Working Tree with the Clean Package

Keep the hidden `.git` directory. Remove the old repository files and copy the **contents** of `star-citizen-tracker-public-v1` into the repository root.

Verify before committing:

```bash
git status
python -m py_compile app.py
python tests/offline_connection_tests.py
```

Then commit and push:

```bash
git add -A
git commit -m "Prepare v1.0.0 public release"
git push -u origin release-v1
```

## Deploy the Test Branch in Streamlit

Create a second Streamlit app using:

- Owner/repository: `Ticklrx3/star-citizen-tracker`
- Branch: `release-v1`
- Entrypoint: `app.py`
- A temporary test subdomain

Paste the saved Streamlit Secrets into the test app's Secrets settings.

For the test app only, update:

```toml
APP_PUBLIC_URL = "https://YOUR-TEST-SUBDOMAIN.streamlit.app/"
```

Keep the same Supabase project unless you intentionally want a separate test database. Do not rerun database migrations that are already applied.

## Validation Checklist

- [ ] App starts without dependency errors
- [ ] Registration and login work
- [ ] Keep-signed-in survives a browser refresh
- [ ] Password recovery returns to the correct app URL
- [ ] Existing saved records load
- [ ] New contract can be saved
- [ ] Contract salvage value saves and appears in calculations
- [ ] Contract edit and delete work
- [ ] Ore entry saves and updates inventory
- [ ] Commodity Bought/Sold/Lost flows work
- [ ] Dashboard totals include contracts, ore, and commodities
- [ ] Saved Records search/edit/delete work
- [ ] Excel/CSV exports work
- [ ] Google Sheets export works when credentials are configured
- [ ] Profile display name and avatar work
- [ ] UEX data loads
- [ ] SC Trade Tools behavior is correct for configured access
- [ ] SC Craft Tools link/embed behavior is acceptable
- [ ] No secrets appear in the GitHub repository

## Promote to Main

After validation, open a pull request from `release-v1` into `main`, review the changed files, and merge it.

Create a GitHub release/tag named:

```text
v1.0.0
```

## Repair the Production Streamlit Connection

Because the GitHub owner name changed, use Streamlit's documented delete-and-redeploy process for changed GitHub coordinates.

1. Confirm the production secrets backup again.
2. Record the current custom subdomain (`sc-tracker-tool`, if that remains the desired URL).
3. Delete the old Streamlit deployment.
4. Deploy a new app from `Ticklrx3/star-citizen-tracker`, branch `main`, entrypoint `app.py`.
5. Reuse the previous custom subdomain.
6. Re-enter the production Secrets.
7. Set `APP_PUBLIC_URL` to the production URL.
8. Verify Supabase Authentication redirect/URL configuration includes the production URL.
9. Run the same critical login/save/dashboard checks against production.

Do not delete or recreate the Supabase project as part of this process.
