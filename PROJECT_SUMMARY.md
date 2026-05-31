# CDS2Entity - Project Summary

## Overview

CDS2Entity is a minimal ABAP utility to modernize classic CDS views into entity CDS syntax.

Current implementation focuses on:
- Package-level discovery of classic DDLS objects
- Deterministic source transformation
- Preview-first workflow via ALV
- Safe placeholder commit path for future extension

---

## Current Scope (As Implemented)

Repository objects:
- Main class: `src/zcl_cds_migrator.clas.abap`
- Report: `src/zcds_migration.prog.abap`
- Unit tests: `src/zcl_cds_migrator.clas.testclasses.abap`

Not currently implemented:
- Dependency analyzer class
- Migration manager/orchestrator class
- Automatic DDLS creation API execution

---

## Functional Capabilities

1. Find classic CDS views in a package
2. Read source via `READ REPORT` with dynamic fallback to `CL_DDL_TOOLS`
3. Detect classic CDS via source checks (`sqlViewName` + not `VIEW ENTITY`)
4. Transform source into entity-compliant form
5. Preview results in ALV in display mode

---

## Transformation Coverage

Current transformation actions performed by code:
1. `DEFINE VIEW` -> `DEFINE VIEW ENTITY`
2. Remove `@AbapCatalog.sqlViewName`
3. Remove `@AbapCatalog.preserveKey`
4. Remove `@AbapCatalog.compiler.compareFilter`
5. Add `@EndUserText.label` if missing
6. Add `@AccessControl.authorizationCheck` if missing
7. Add `@Metadata.ignorePropagatedAnnotations` if missing
8. Add `@Metadata.allowExtensions` if missing
9. Add `key` to first field when missing

Naming output:
- New CDS name gets `_V2` suffix
- New SQL marker gets `_V2` suffix and 16-char safeguard

---

## Runtime Modes

### Display Mode (Primary)

- Discovers and transforms
- Shows output in ALV
- No persistent write

### Commit Mode (Placeholder)

- Iterates transformed records
- Calls `CREATE_ENTITY`
- Current method returns `abap_false` by design

---

## Quality Status

- ABAP Unit test class exists and validates core transform behavior
- Report includes user-facing status and summary output
- Error handling in source reading uses safe fallback behavior

---

## Known Limitations

1. No automatic DDLS creation yet
2. Package scan is direct package only (no recursive subpackages)
3. No dependency-order migration

---

## Recommended Usage

1. Run in display mode first
2. Review transformed output
3. Use transformed source for controlled manual creation/activation
4. Treat commit mode as future extension point

---

## Version Snapshot

- Status: Working, preview-first migration utility
- Version: 2.1.0
- Last Updated: 2026-05-30
