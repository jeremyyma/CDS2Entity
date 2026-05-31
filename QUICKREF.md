# CDS2Entity - Quick Reference

## Objects

- Class: `ZCL_CDS_MIGRATOR`
- Report: `ZCDS_MIGRATION`
- Unit test class: `LTC_CDS_MIGRATOR` (in class test include)

## Run Tool

```
SE38 -> ZCDS_MIGRATION
  P_PACK   = <package>
  P_DISP   = X   (default)
  P_COMMIT =     (optional)
F8
```

## Recommended Workflow

1. Run display mode first.
2. Review ALV output (`name`, `new_name`, `sql_view`, `new_sql`, `new_source`).
3. Use generated source for controlled activation flow.
4. Treat commit mode as placeholder until create API is implemented.

## API Snippets

### Find + Transform

```abap
DATA(lo_migrator) = NEW zcl_cds_migrator( ).
DATA(lt_cds) = lo_migrator->find_in_package( 'ZPACKAGE' ).

LOOP AT lt_cds ASSIGNING FIELD-SYMBOL(<cds>).
  lo_migrator->transform( CHANGING cs_cds = <cds> ).
ENDLOOP.
```

### Commit Flow (Current Placeholder)

```abap
LOOP AT lt_cds ASSIGNING <cds>.
  IF lo_migrator->create_entity( <cds> ) = abap_true.
    WRITE: / <cds>-new_name, 'created'.
  ENDIF.
ENDLOOP.
```

## Detection Logic

A CDS is treated as classic when source:
- Contains `sqlViewName`
- Does not contain `VIEW ENTITY`

Discovery source:
- `TADIR` with `R3TR/DDLS` in package

## Source Read Fallback

1. `READ REPORT iv_name INTO lt_source_tab`
2. Dynamic `CL_DDL_TOOLS=>READ_DDL_SOURCE`

## Transform Actions

1. `DEFINE VIEW` -> `DEFINE VIEW ENTITY`
2. Remove `@AbapCatalog.sqlViewName`
3. Remove `@AbapCatalog.preserveKey`
4. Remove `@AbapCatalog.compiler.compareFilter`
5. Add `@EndUserText.label` if missing
6. Add `@AccessControl.authorizationCheck` if missing
7. Add `@Metadata.ignorePropagatedAnnotations` if missing
8. Add `@Metadata.allowExtensions` if missing
9. Add `key` to first field when missing

## Naming Rules

- `new_name = <old_name>_V2`
- `new_sql = <old_sql>_V2` (truncate to 16 chars)

## Testing

```
SE24 -> ZCL_CDS_MIGRATOR -> Test -> Execute (Ctrl+Shift+F10)
```

## Current Limitation

- `create_entity` does not persist DDLS objects yet.

---

Last Updated: 2026-05-30
