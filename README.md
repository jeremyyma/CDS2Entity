# CDS2Entity - Simple CDS Migration Tool

Clean, minimal ABAP solution for migrating classic CDS views to entity-based CDS.

[![abapGit](https://img.shields.io/badge/abapGit-compatible-brightgreen)](https://abapgit.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![ABAP](https://img.shields.io/badge/ABAP-Clean%20Code-orange)](https://github.com/SAP/styleguides)

## Quick Start

### Install via abapGit

```
ZABAPGIT → New Online → https://github.com/jeremyyma/CDS2Entity.git
```

### Run

```
SE38 → ZCDS_MIGRATION → Enter package → F8
```

## What It Does

1. **Finds** classic CDS views in a package
2. **Transforms** them to entity-based CDS
3. **Shows** results in ALV grid

## The Code

### One Class: `ZCL_CDS_MIGRATOR`

```abap
" Find classic CDS views
DATA(lt_cds) = NEW zcl_cds_migrator( )->find_in_package( 'ZPACKAGE' ).

" Transform to entity CDS
LOOP AT lt_cds ASSIGNING FIELD-SYMBOL(<cds>).
  NEW zcl_cds_migrator( )->transform( CHANGING cs_cds = <cds> ).
ENDLOOP.
```

**That's it!** ~120 lines of clean ABAP.

## Transformations

| From | To |
|------|-----|
| `DEFINE VIEW` | `DEFINE VIEW ENTITY` |
| `@AbapCatalog.sqlViewName` | ❌ Removed (deprecated in entity views) |
| No KEY | `key` added to first field |
| Missing `@AccessControl` | Added with `#NOT_REQUIRED` |

## Installation

### Method 1: abapGit (Recommended)

```
ZABAPGIT → New Online
URL: https://github.com/jeremyyma/CDS2Entity.git
Package: $TMP (or your Z package)
Pull → Activate
```

### Method 2: Manual

1. SE24 → Create class `ZCL_CDS_MIGRATOR`
2. Copy code from `src/zcl_cds_migrator.clas.abap`
3. SE38 → Create program `ZCDS_MIGRATION`
4. Copy code from `src/zcds_migration.prog.abap`
5. Activate

## Usage Example

```abap
DATA(lo_migrator) = NEW zcl_cds_migrator( ).

" Find all classic CDS in package
DATA(lt_cds) = lo_migrator->find_in_package( 'ZPACKAGE' ).

WRITE: / 'Found', lines( lt_cds ), 'classic CDS views'.

" Transform each one
LOOP AT lt_cds ASSIGNING FIELD-SYMBOL(<cds>).
  lo_migrator->transform( CHANGING cs_cds = <cds> ).
  
  WRITE: / <cds>-name, '→', <cds>-new_name.
  WRITE: / '  SQL:', <cds>-sql_view, '→', <cds>-new_sql.
ENDLOOP.
```

## Example Transformation

### Before (Classic CDS)
```abap
@AbapCatalog.sqlViewName: 'ZMYVIEW'
define view Z_MY_VIEW as select from scarr {
  carrid,
  carrname
}
```

### After (Entity CDS)
```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view entity Z_MY_VIEW_V2 as select from scarr {
  key carrid,
  carrname
}
```

**Note:** `sqlViewName` annotation is removed as it's deprecated in CDS entity views.

## What's Included

```
src/
├── zcl_cds_migrator.clas.abap           120 lines
├── zcl_cds_migrator.clas.testclasses.abap  60 lines
├── zcds_migration.prog.abap              40 lines
└── XML metadata for abapGit
```

**Total: ~220 lines of code**

Compare to previous version: **~1,800 lines** → **~220 lines** (88% reduction!)

## Clean Code Principles Applied

✅ **Single Responsibility** - One class, one job  
✅ **Simple Names** - `find_in_package`, `transform`  
✅ **Short Methods** - Average 10 lines  
✅ **No Comments** - Code explains itself  
✅ **Minimal API** - Only 2 public methods  
✅ **Type Safety** - Strong typing everywhere  
✅ **Testable** - Unit tests included  
✅ **ABAP 7.50+** - Modern ABAP syntax  

## Testing

```abap
SE24 → ZCL_CDS_MIGRATOR → Test → Execute (Ctrl+Shift+F10)
```

## Requirements

- SAP NetWeaver 7.50+
- ABAP authorization for reading/creating DDLS objects

## License

MIT - Use freely

## Contributing

Keep it simple! Additions should:
- Solve a real problem
- Add <50 lines of code
- Include tests
- Follow clean code principles

---

**Built with ❤️ and Clean Code principles**

*"Simplicity is the ultimate sophistication" - Leonardo da Vinci*
