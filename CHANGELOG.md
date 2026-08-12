# Changelog

## v1.0.0 - Public Portfolio Release

### Added
- Professional public repository structure
- Architecture and technology documentation
- Organized database schema, migrations, and verification SQL
- Offline connection/CRUD tests under `tests/`
- CI validation for Python compilation and offline tests
- Expanded credential and local-artifact exclusions in `.gitignore`

### Retained from the validated application build
- Authenticated multi-user tracking
- Contract salvage proceeds
- Supabase connection verification
- Mining and ore ledger
- Commodity tracking
- Dashboards and exports
- Profile/avatar features
- UEX, SC Trade Tools, SC Craft Tools, and optional Google Sheets integrations

### Database
- No migration newer than `schema_migration_v10_contract_salvage_and_connections.sql` is required for the validated build.
