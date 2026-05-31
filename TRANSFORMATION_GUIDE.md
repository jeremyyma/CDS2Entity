# CDS Entity Transformation Guide

## Overview

This guide documents the exact transformations currently implemented in `ZCL_CDS_MIGRATOR`.

Classic CDS detection is source-based:
- Contains `sqlViewName`
- Does not contain `VIEW ENTITY`

Discovery source is `TADIR` (`R3TR/DDLS`) for the target package.

---

## Transformation Actions

The implementation currently applies these actions to each classic CDS source:

1. Convert definition syntax
   - `DEFINE VIEW ` -> `DEFINE VIEW ENTITY ` (first occurrence only)

2. Remove deprecated annotations
   - `@AbapCatalog.sqlViewName: '...'`
   - `@AbapCatalog.preserveKey: true|false`
   - `@AbapCatalog.compiler.compareFilter: true|false`

3. Ensure required/recommended annotations
   - Add `@EndUserText.label` if missing (default `'CDS Entity View'`)
   - Add `@AccessControl.authorizationCheck: #NOT_REQUIRED` if missing
   - Add `@Metadata.ignorePropagatedAnnotations: true` if missing
   - Add `@Metadata.allowExtensions: true` if missing

4. Ensure key field exists
   - If no `key` or `KEY` found, add `key` to first field in the select list

Total concrete edits: 9 actions.

---

## Name Generation

Outside the source rewrite, `TRANSFORM` also sets:

- `new_name = <old_name>_V2`
- `new_sql  = <old_sql>_V2` (truncated to 16 chars when needed)

Note:
- Source transformation removes SQL view annotations for entity views, so `iv_new_sql_view` is currently not injected into source text.

---

## Before/After Example

### Before (Classic)

```abap
@AbapCatalog.sqlViewName: 'ZCUSTOMER'
@AbapCatalog.preserveKey: true
@AbapCatalog.compiler.compareFilter: true
define view Z_CUSTOMER as select from kna1 {
  kunnr,
  name1
}
```

### After (Generated)

```abap
@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS Entity View'
define view entity Z_CUSTOMER as select from kna1 {
  key kunnr,
  name1
}
```

---

## Compliance Checklist

Required checks for generated output:
- `DEFINE VIEW ENTITY` exists
- At least one `key` exists
- No `@AbapCatalog.sqlViewName`
- No `@AbapCatalog.preserveKey`
- No `@AbapCatalog.compiler.compareFilter`
- `@EndUserText.label` exists
- `@AccessControl.authorizationCheck` exists
- `@Metadata.ignorePropagatedAnnotations` exists
- `@Metadata.allowExtensions` exists

---

## Implementation Notes

- Source retrieval uses `READ REPORT` first, then dynamic fallback `CL_DDL_TOOLS=>READ_DDL_SOURCE`.
- Regex removal is case-sensitive to current annotation spellings used in source.
- Key insertion is heuristic and targets the first field token after `{`.

---

## Current Limitations

1. No dependency-aware ordering
2. No parser-level CDS AST validation
3. No automatic object creation/activation in commit mode

---

**Last Updated:** 2026-05-30
**Tool Version:** 2.1.0
