# CDS2Entity - Quick Reference Guide

## Quick Start (5 Minutes)

### 1. Install
```
SE24 → Create classes:
- ZCL_CDS_SCANNER
- ZCL_CDS_DEPENDENCY_ANALYZER
- ZCL_CDS_MIGRATOR
- ZCL_CDS_MIGRATION_MANAGER

SE38 → Create report:
- ZCDS_MIGRATION_TOOL
```

### 2. Run
```
SE38 → ZCDS_MIGRATION_TOOL
Enter package name → F8
Select CDS views → F8
```

### 3. Result
✅ Entity-based CDS generated with `_V2` suffix

---

## Command Reference

### Main Report Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| P_PACK | Source package to scan | Z* |
| P_SUB | Include sub-packages | ✓ |
| P_TPKG | Target package for new CDS | ZTMP |
| P_DISP | Display only (no save) | ✓ |
| P_SAVE | Save migration results | ☐ |

---

## API Quick Reference

### Scanner API

```abap
DATA(lo_scanner) = NEW zcl_cds_scanner( ).

" Scan package
DATA(lt_cds) = lo_scanner->scan_package(
  iv_package = 'ZPACKAGE'
  iv_include_subpackages = abap_true
).

" Check if classic
DATA(lv_classic) = lo_scanner->is_classic_cds( 'Z_MY_VIEW' ).

" Get source
DATA(lv_source) = lo_scanner->get_cds_source( 'Z_MY_VIEW' ).
```

### Analyzer API

```abap
DATA(lo_analyzer) = NEW zcl_cds_dependency_analyzer( ).

" Extract dependencies
DATA(lt_deps) = lo_analyzer->extract_dependencies(
  iv_ddlname = 'Z_MY_VIEW'
).

" Get all dependent views
DATA(lt_all) = lo_analyzer->get_dependent_views( 'Z_MY_VIEW' ).

" Analyze order
DATA(lt_order) = lo_analyzer->analyze_migration_order( lt_cds ).
```

### Migrator API

```abap
DATA(lo_migrator) = NEW zcl_cds_migrator( ).

" Migrate single
DATA(ls_result) = lo_migrator->migrate_single_cds( ls_cds_view ).

" Migrate multiple (ordered)
DATA(lt_results) = lo_migrator->migrate_multiple_cds( lt_cds_views ).

" Generate source only
DATA(lv_source) = lo_migrator->generate_entity_source(
  is_cds_view = ls_cds_view
  iv_new_sql_view = 'ZNEWVIEW_V2'
).
```

### Manager API (Full Workflow)

```abap
DATA(lo_manager) = NEW zcl_cds_migration_manager( ).

" Get CDS list with dependencies
DATA(lt_cds) = lo_manager->get_cds_list_with_dependencies(
  iv_package = 'ZPACKAGE'
  iv_include_subpackages = abap_true
).

" Execute migration
DATA(ls_summary) = lo_manager->execute_migration(
  iv_package = 'ZPACKAGE'
  iv_include_subpackages = abap_true
).

" Access results
WRITE: / 'Migrated:', ls_summary-total_migrated.
WRITE: / 'Errors:', ls_summary-total_errors.
```

---

## Transformation Rules

| Classic CDS | Entity CDS |
|-------------|------------|
| `DEFINE VIEW` | `DEFINE VIEW ENTITY` |
| `@AbapCatalog.sqlViewName: 'ZOLD'` | `@AbapCatalog.sqlViewName: 'ZOLD_V2'` |
| No KEY required | At least one KEY required |
| No `@AccessControl` required | `@AccessControl.authorizationCheck` added |
| Optional annotations | Required: `@EndUserText.label`, `@Metadata.ignorePropagatedAnnotations` |

---

## Common Patterns

### Pattern 1: Scan and Display

```abap
DATA(lo_scanner) = NEW zcl_cds_scanner( ).
DATA(lt_cds) = lo_scanner->scan_package( iv_package = 'ZPACKAGE' ).

LOOP AT lt_cds INTO DATA(ls_cds).
  WRITE: / ls_cds-ddlname, '->', ls_cds-sql_view_name.
ENDLOOP.
```

### Pattern 2: Check Before Migrate

```abap
DATA(lo_scanner) = NEW zcl_cds_scanner( ).

IF lo_scanner->is_classic_cds( 'Z_MY_VIEW' ) = abap_true.
  " Proceed with migration
ELSE.
  " Already entity-based or doesn't exist
ENDIF.
```

### Pattern 3: Selective Migration

```abap
DATA(lo_manager) = NEW zcl_cds_migration_manager( ).
DATA(lt_cds) = lo_manager->get_cds_list_with_dependencies(
  iv_package = 'ZPACKAGE'
).

" Select only views starting with 'Z_SALES'
LOOP AT lt_cds ASSIGNING FIELD-SYMBOL(<cds>) WHERE ddlname CP 'Z_SALES*'.
  <cds>-selected = abap_true.
ENDLOOP.

" Migrate selected
DATA(ls_summary) = lo_manager->execute_migration(
  iv_package = 'ZPACKAGE'
).
```

### Pattern 4: Migration with Error Handling

```abap
TRY.
    DATA(lo_manager) = NEW zcl_cds_migration_manager( ).
    DATA(ls_summary) = lo_manager->execute_migration(
      iv_package = 'ZPACKAGE'
    ).

    IF ls_summary-total_errors > 0.
      " Handle errors
      LOOP AT ls_summary-results INTO DATA(ls_result)
        WHERE status = 'ERROR'.
        WRITE: / 'Error:', ls_result-ddlname, ls_result-message.
      ENDLOOP.
    ENDIF.

  CATCH cx_root INTO DATA(lx_error).
    WRITE: / 'Fatal error:', lx_error->get_text( ).
ENDTRY.
```

---

## Troubleshooting Quick Fixes

### No CDS Found
```abap
" Check package exists
SELECT SINGLE devclass FROM tdevc WHERE devclass = 'ZPACKAGE'.

" Check CDS views exist
SELECT COUNT(*) FROM tadir
  WHERE pgmid = 'R3TR'
    AND object = 'DDLS'
    AND devclass = 'ZPACKAGE'.
```

### Name Too Long
```abap
" Manual truncation
DATA(lv_new) = |{ lv_old(13) }_V2|.
```

### Missing Dependencies
```abap
" Get dependency tree
DATA(lo_analyzer) = NEW zcl_cds_dependency_analyzer( ).
DATA(lt_deps) = lo_analyzer->get_dependent_views( 'Z_MY_VIEW' ).

" Check each dependency exists
LOOP AT lt_deps INTO DATA(lv_dep).
  SELECT SINGLE @abap_true FROM dd02l
    WHERE ddlname = @lv_dep
    INTO @DATA(lv_exists).
  IF sy-subrc <> 0.
    WRITE: / 'Missing dependency:', lv_dep.
  ENDIF.
ENDLOOP.
```

---

## Data Types Reference

### ty_cds_view
```abap
BEGIN OF ty_cds_view,
  ddlname         TYPE ddlname,          " CDS view name
  sql_view_name   TYPE ddstrucobjname,   " SQL view name
  package         TYPE devclass,         " Package
  description     TYPE ddtext,           " Description
  is_classic      TYPE abap_bool,        " Is classic CDS?
  entity_category TYPE string,           " Entity category
  source_code     TYPE string,           " Source code
  dependencies    TYPE TABLE OF ddlname, " Dependencies
  selected        TYPE abap_bool,        " Selected for migration?
END OF ty_cds_view.
```

### ty_dependency
```abap
BEGIN OF ty_dependency,
  source_ddl      TYPE ddlname,  " Source view
  target_ddl      TYPE ddlname,  " Target dependency
  dependency_type TYPE string,   " 'FROM', 'JOIN', 'ASSOCIATION'
  target_field    TYPE string,   " Target field
END OF ty_dependency.
```

### ty_migration_result
```abap
BEGIN OF ty_migration_result,
  ddlname           TYPE ddlname,          " Original CDS
  old_sql_view      TYPE ddstrucobjname,   " Old SQL view
  new_ddl_name      TYPE ddlname,          " New CDS name
  new_sql_view      TYPE ddstrucobjname,   " New SQL view (_V2)
  new_source_code   TYPE string,           " Generated source
  status            TYPE string,           " 'SUCCESS', 'ERROR'
  message           TYPE string,           " Status message
END OF ty_migration_result.
```

### ty_migration_summary
```abap
BEGIN OF ty_migration_summary,
  total_found     TYPE i,                          " Total found
  total_selected  TYPE i,                          " Total selected
  total_migrated  TYPE i,                          " Successfully migrated
  total_errors    TYPE i,                          " Errors
  results         TYPE tt_migration_results,       " Detailed results
END OF ty_migration_summary.
```

---

## Keyboard Shortcuts (Report)

| Key | Action |
|-----|--------|
| F8 | Execute / Continue |
| F3 | Back |
| Ctrl+F | Find in ALV |
| Space | Toggle checkbox |
| Ctrl+Y | Select all rows |

---

## Status Codes

| Code | Meaning |
|------|---------|
| SUCCESS | Migration completed successfully |
| ERROR | Migration failed |
| SKIPPED | View skipped (not selected or already migrated) |

---

## Best Practices

1. ✅ **Always test with display mode first**
2. ✅ **Scan for dependencies before migration**
3. ✅ **Migrate in dependency order (tool does this)**
4. ✅ **Review generated code before activation**
5. ✅ **Create transport backup of originals**
6. ✅ **Test in development first**
7. ✅ **Validate with unit tests**

---

## One-Liners

### Get all classic CDS in a package
```abap
DATA(lt_cds) = NEW zcl_cds_scanner( )->scan_package( 'ZPACKAGE' ).
```

### Check if CDS needs migration
```abap
DATA(lv_classic) = NEW zcl_cds_scanner( )->is_classic_cds( 'Z_VIEW' ).
```

### Full migration in one line
```abap
DATA(ls_sum) = NEW zcl_cds_migration_manager( )->execute_migration( iv_package = 'ZPKG' ).
```

---

## Links

- 📖 [Full Documentation](README.md)
- 🚀 [Deployment Guide](DEPLOYMENT.md)
- 💻 [Examples](zcds_migration_examples.prog.abap)
- 🧪 [Tests](zcl_cds_test.clas.abap)

---

**Version**: 1.0.0  
**Quick Reference** | Last Updated: 2026-05-23
