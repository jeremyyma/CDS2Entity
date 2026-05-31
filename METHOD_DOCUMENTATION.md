# Method Documentation - ZCL_CDS_MIGRATOR

## Class Overview

`ZCL_CDS_MIGRATOR` provides discovery, transformation, and (placeholder) creation for CDS modernization.

Public API:
- `FIND_IN_PACKAGE`
- `TRANSFORM`
- `CREATE_ENTITY`

Private helpers:
- `READ_SOURCE`
- `IS_CLASSIC`
- `GENERATE_ENTITY_SOURCE`

---

## Public Methods

### FIND_IN_PACKAGE( iv_package )

Purpose:
- Find classic CDS views in the given package.

Parameters:
- `iv_package` TYPE `devclass`

Returns:
- `ty_cds_list`

Implementation details:
1. Read DDLS object names from `TADIR` for the package.
2. For each DDLS object, read source using `READ_SOURCE`.
3. Keep only classic CDS based on `IS_CLASSIC`.
4. Extract SQL view name via regex on `sqlViewName` annotation.
5. Return `ty_cds_list` with source and metadata.

Example:
```abap
DATA(lt_cds) = NEW zcl_cds_migrator( )->find_in_package( 'ZPACKAGE' ).
```

---

### TRANSFORM( CHANGING cs_cds )

Purpose:
- Generate target naming and transformed entity source.

Parameters:
- `cs_cds` TYPE `ty_cds` (CHANGING)

Implementation details:
1. Set `new_name = <name>_V2`.
2. Set `new_sql = <sql_view>_V2` and truncate to 16 chars when needed.
3. Generate transformed source via `GENERATE_ENTITY_SOURCE`.

Example:
```abap
LOOP AT lt_cds ASSIGNING FIELD-SYMBOL(<cds>).
  lo_migrator->transform( CHANGING cs_cds = <cds> ).
ENDLOOP.
```

---

### CREATE_ENTITY( is_cds )

Purpose:
- Extension point for creating entity CDS objects in system.

Parameters:
- `is_cds` TYPE `ty_cds`

Returns:
- `abap_bool`

Current behavior:
- Returns `abap_false`.
- Shows informational message about manual activation/creation.
- Does not call a persistence API yet.

Example:
```abap
IF lo_migrator->create_entity( ls_cds ) = abap_true.
  WRITE: / ls_cds-new_name, 'created'.
ENDIF.
```

---

## Private Methods

### READ_SOURCE( iv_name )

Purpose:
- Read complete CDS source for a DDLS object.

Parameters:
- `iv_name` TYPE `ddlname`

Returns:
- `string`

Implementation details:
1. Primary path: `READ REPORT iv_name INTO lt_source_tab`.
2. Convert line table to single string using newline separator.
3. Fallback path: dynamic call to `CL_DDL_TOOLS=>READ_DDL_SOURCE`.
4. Any failure returns initial string (safe fallback).

Rationale:
- `READ REPORT` is usually stable for DDLS source retrieval.
- Dynamic fallback avoids hard dependency where API may vary.

---

### IS_CLASSIC( iv_source )

Purpose:
- Identify whether source is classic CDS.

Parameters:
- `iv_source` TYPE `string`

Returns:
- `abap_bool`

Rule:
- True when source contains `sqlViewName` and does not contain `VIEW ENTITY`.

---

### GENERATE_ENTITY_SOURCE( iv_source, iv_new_sql_view )

Purpose:
- Apply all source-level modernization edits.

Parameters:
- `iv_source` TYPE `string`
- `iv_new_sql_view` TYPE `ddstrucobjname`

Returns:
- `string`

Current transformation actions:
1. Replace first `DEFINE VIEW ` with `DEFINE VIEW ENTITY `.
2. Remove `@AbapCatalog.sqlViewName` annotation.
3. Remove `@AbapCatalog.preserveKey` annotation.
4. Remove `@AbapCatalog.compiler.compareFilter` annotation.
5. Ensure `@EndUserText.label` exists (default `'CDS Entity View'`).
6. Ensure `@AccessControl.authorizationCheck: #NOT_REQUIRED` exists.
7. Ensure `@Metadata.ignorePropagatedAnnotations: true` exists.
8. Ensure `@Metadata.allowExtensions: true` exists.
9. Add `key` to first field when no key is present.

Important note:
- `iv_new_sql_view` is currently not used in replacement logic because SQL view annotations are removed for entity views.

---

## Call Sequence

```
ZCDS_MIGRATION
  -> FIND_IN_PACKAGE
     -> READ_SOURCE (per DDLS)
     -> IS_CLASSIC
  -> TRANSFORM (per classic CDS)
     -> GENERATE_ENTITY_SOURCE
  -> CREATE_ENTITY (commit mode only, placeholder)
```

---

## Type Definitions

### TY_CDS

```abap
BEGIN OF ty_cds,
  name        TYPE ddlname,
  sql_view    TYPE ddstrucobjname,
  source      TYPE string,
  new_name    TYPE ddlname,
  new_sql     TYPE ddstrucobjname,
  new_source  TYPE string,
  is_classic  TYPE abap_bool,
END OF ty_cds
```

### TY_CDS_LIST

```abap
ty_cds_list TYPE STANDARD TABLE OF ty_cds WITH KEY name
```

---

## Test Coverage Summary

The current ABAP Unit test validates `TRANSFORM` behavior for:
- Entity syntax conversion
- Deprecated annotation removal
- Required/recommended annotation insertion
- Key injection

---

**Last Updated:** 2026-05-30
**Version:** 2.1.0
