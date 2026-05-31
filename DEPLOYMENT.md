# CDS2Entity - Deployment Guide

## Scope

This guide reflects the current implementation in this repository:

- Report: `ZCDS_MIGRATION`
- Class: `ZCL_CDS_MIGRATOR`
- Test class include: `ZCL_CDS_MIGRATOR` test classes

No additional scanner/analyzer/manager classes are required.

---

## Prerequisites

- SAP system with ABAP 7.50+ syntax support
- Developer authorization to create/activate `CLAS` and `PROG`
- Package with DDLS objects to scan

Recommended transactions/tools:
- `SE24` for class activation and ABAP Unit
- `SE38` for report execution
- ADT or SAP GUI editor

---

## Objects to Deploy

Deploy these repository files:

- `src/zcl_cds_migrator.clas.abap`
- `src/zcl_cds_migrator.clas.xml`
- `src/zcl_cds_migrator.clas.testclasses.abap`
- `src/zcds_migration.prog.abap`
- `src/zcds_migration.prog.xml`
- `src/package.devc.xml`

---

## Installation Steps

1. Import via abapGit (recommended) or create objects manually.
2. Activate class `ZCL_CDS_MIGRATOR`.
3. Activate report `ZCDS_MIGRATION`.
4. Ensure test include is active.

Manual creation mapping:
- `SE24` -> class `ZCL_CDS_MIGRATOR`
- `SE38` -> report `ZCDS_MIGRATION`

---

## Validation Steps (Required)

1. Syntax and activation check in `SE24` and `SE38`.
2. Run ABAP Unit:
   - `SE24` -> `ZCL_CDS_MIGRATOR` -> Test -> Execute
3. Run report in display mode first:
   - `SE38` -> `ZCDS_MIGRATION`
   - Provide `P_PACK`
   - Keep `P_DISP` selected
   - Execute and verify ALV results

---

## Runtime Usage

### Display Mode (Recommended)

Purpose:
- Discover classic CDS views
- Generate preview of transformed source and names
- No write action

### Commit Mode (Current Status)

Current behavior:
- Calls `CREATE_ENTITY` placeholder
- Returns failures (`abap_false`) by design
- Prints summary output and messages

Use commit mode only for flow testing until object creation API is implemented.

---

## Troubleshooting

### No CDS found

Checks:
- Package contains DDLS entries in `TADIR`
- Source includes `sqlViewName` and is not already `VIEW ENTITY`

### Empty source during read

Behavior:
- Tool tries `READ REPORT` first
- Falls back to dynamic `CL_DDL_TOOLS=>READ_DDL_SOURCE`

If both fail:
- Verify DDLS object exists and is active
- Verify release/API availability and authorizations

### Unexpected commit failures

Current expected state:
- `CREATE_ENTITY` is a stub and does not persist new DDLS objects yet

---

## Transport and Release Notes

- Validate in display mode before transport
- Do not transport `CLAUDE.md`
- Keep commit messages explicit when exporting repository changes

---

**Deployment Guide Version**: 2.1.0
**Last Updated**: 2026-05-30
