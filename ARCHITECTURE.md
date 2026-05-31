# CDS2Entity - Architecture

## Overview

CDS2Entity is intentionally small and focused. The current implementation has:

- 1 executable report: `ZCDS_MIGRATION`
- 1 main class: `ZCL_CDS_MIGRATOR`
- 1 ABAP Unit test class: `LTC_CDS_MIGRATOR`

The architecture prioritizes simplicity, portability across systems, and minimal dependencies.

---

## Runtime Flow

```
User (SE38)
  -> ZCDS_MIGRATION
     -> ZCL_CDS_MIGRATOR=>find_in_package( )
        -> SELECT TADIR (DDLS in package)
        -> read_source( ) per DDLS
        -> is_classic( ) filter
     -> transform( ) per result
        -> generate_entity_source( )
     -> Display mode: ALV preview
     -> Commit mode: create_entity( ) placeholder
```

---

## Components

### 1) Report `ZCDS_MIGRATION`

Responsibilities:
- Accept input package and mode (`Display` / `Commit`)
- Call migration class APIs
- Show preview list in ALV (`CL_SALV_TABLE`) in display mode
- Show success/failure summary in commit mode

Parameters:
- `P_PACK` (required package)
- `P_DISP` (default display mode)
- `P_COMMIT` (commit mode)

### 2) Class `ZCL_CDS_MIGRATOR`

Public methods:
- `FIND_IN_PACKAGE`
- `TRANSFORM`
- `CREATE_ENTITY`

Private methods:
- `READ_SOURCE`
- `IS_CLASSIC`
- `GENERATE_ENTITY_SOURCE`

Data type:
- `TY_CDS` and `TY_CDS_LIST` hold source, target names, transformed source, and classification flag.

### 3) Test Class `LTC_CDS_MIGRATOR`

Current automated coverage:
- Validates transformation behavior in `TRANSFORM`
- Checks syntax conversion to entity view
- Checks removal of deprecated annotations
- Checks addition of required/recommended annotations
- Checks `KEY` auto-insertion

---

## Data Access Strategy

### Object Discovery

`FIND_IN_PACKAGE` reads repository objects from `TADIR`:
- `PGMID = 'R3TR'`
- `OBJECT = 'DDLS'`
- `DEVCLASS = iv_package`

### Source Retrieval

`READ_SOURCE` uses a two-step fallback:
1. `READ REPORT iv_name INTO lt_source_tab` (primary path)
2. Dynamic fallback to `CL_DDL_TOOLS=>READ_DDL_SOURCE` when primary path returns empty or unavailable

Reasoning:
- `READ REPORT` is simple and reliable for many systems.
- Dynamic call avoids hard compile dependency on releases where the class/method may differ.

### Classic CDS Detection

`IS_CLASSIC` returns true only when source:
- Contains `sqlViewName`
- Does not contain `VIEW ENTITY`

This is source-based detection, not DDHEADANNO-driven detection.

---

## Transformation Pipeline

`TRANSFORM` builds target names and delegates source rewrite to `GENERATE_ENTITY_SOURCE`.

Concrete transformation actions currently implemented:
1. `DEFINE VIEW` -> `DEFINE VIEW ENTITY` (first occurrence)
2. Remove `@AbapCatalog.sqlViewName`
3. Remove `@AbapCatalog.preserveKey`
4. Remove `@AbapCatalog.compiler.compareFilter`
5. Add `@EndUserText.label` if missing
6. Add `@AccessControl.authorizationCheck: #NOT_REQUIRED` if missing
7. Add `@Metadata.ignorePropagatedAnnotations: true` if missing
8. Add `@Metadata.allowExtensions: true` if missing
9. Add `key` to first field if no key exists

Naming behavior:
- New CDS name: `<old_name>_V2`
- New SQL view marker: `<old_sql>_V2`, truncated to 16 chars if needed

Note:
- `GENERATE_ENTITY_SOURCE` currently does not consume `iv_new_sql_view` in replacements, because SQL view annotations are removed for entity syntax.

---

## Commit Behavior

`CREATE_ENTITY` is currently a placeholder:
- Returns `abap_false`
- Emits informational message that manual activation/creation is needed
- No repository write API is currently executed

Impact:
- Display mode is the effective production path today.
- Commit mode is a scaffold for future implementation.

---

## Design Principles Applied

- Keep it minimal (single core class)
- Prefer stable language/runtime features
- Fail safe (empty source or exceptions do not dump)
- Keep report orchestration straightforward
- Preserve extension point for future create API

---

## Known Limits

- Scans direct package only (no subpackage recursion)
- No dependency graph ordering
- No automatic persistent creation of new DDLS objects yet

---

**Architecture Version**: 2.1.0
**Last Updated**: 2026-05-30
