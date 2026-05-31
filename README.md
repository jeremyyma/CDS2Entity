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
SE38 → ZCDS_MIGRATION
  Package: [Your package]
  Mode: Display Only (preview) or Commit (placeholder flow)
  → F8
```

## What It Does

1. **Finds** DDLS objects in package using TADIR and filters classic CDS by source
2. **Removes** 3 deprecated annotations
3. **Adds** 4 modern annotations
4. **Transforms** syntax to entity format
5. **Ensures** KEY fields are present
6. **Generates** new names with _V2 suffix
7. **Displays** results in ALV grid; commit path is currently a placeholder

**Result:** Modernized preview-ready entity source with clean migration output.

## The Code

### One Class: `ZCL_CDS_MIGRATOR`

```abap
" Find classic CDS views by scanning DDLS in package and checking source
DATA(lt_cds) = NEW zcl_cds_migrator( )->find_in_package( 'ZPACKAGE' ).

" Transform to entity CDS with modern annotations
LOOP AT lt_cds ASSIGNING FIELD-SYMBOL(<cds>).
  NEW zcl_cds_migrator( )->transform( CHANGING cs_cds = <cds> ).
ENDLOOP.

" Optional: Create new entity views
LOOP AT lt_cds ASSIGNING <cds>.
  NEW zcl_cds_migrator( )->create_entity( <cds> ).
ENDLOOP.
```

**That's it!** ~220 lines of clean ABAP with inline method documentation.

## Transformations

### Quick Overview

| Transformation | Action |
|----------------|--------|
| `DEFINE VIEW` → `DEFINE VIEW ENTITY` | ✅ Updated |
| `@AbapCatalog.sqlViewName` | ❌ Removed |
| `@AbapCatalog.preserveKey` | ❌ Removed |
| `@AbapCatalog.compiler.compareFilter` | ❌ Removed |
| `@EndUserText.label` | ✅ Added |
| `@AccessControl.authorizationCheck` | ✅ Added |
| `@Metadata.ignorePropagatedAnnotations` | ✅ Added |
| `@Metadata.allowExtensions` | ✅ Added |
| First field → `key` | ✅ Enhanced |

**Total: 9 transformation actions applied automatically!**

📖 **See [TRANSFORMATION_GUIDE.md](TRANSFORMATION_GUIDE.md) for complete details**

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

" Find all classic CDS in package via TADIR + source checks
DATA(lt_cds) = lo_migrator->find_in_package( 'ZPACKAGE' ).

WRITE: / 'Found', lines( lt_cds ), 'classic CDS views'.

" Transform each one
LOOP AT lt_cds ASSIGNING FIELD-SYMBOL(<cds>).
  lo_migrator->transform( CHANGING cs_cds = <cds> ).
  
  WRITE: / <cds>-name, '→', <cds>-new_name.
  WRITE: / '  SQL:', <cds>-sql_view, '→', <cds>-new_sql.
ENDLOOP.

" Optional: Create new entity views
LOOP AT lt_cds ASSIGNING <cds>.
  IF lo_migrator->create_entity( <cds> ) = abap_true.
    WRITE: / <cds>-new_name, 'created successfully'.
  ENDIF.
ENDLOOP.
```

### Report Parameters

**Package (P_PACK):** Package to scan for classic CDS views
- Required field
- Searches only within specified package

**Mode:**
- **Display Only (P_DISP):** Preview transformations in ALV grid (default)
- **Commit (P_COMMIT):** Execute creation flow (current `create_entity` method is placeholder)

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
@EndUserText.label: 'CDS Entity View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity Z_MY_VIEW as select from scarr {
  key carrid,
  carrname
}
```

**Clean, modern, and ABAP Cloud ready!** ✨

**Key improvements:**
- ❌ Removed deprecated `sqlViewName`
- ✅ Added required `@EndUserText.label`
- ✅ Added required `@AccessControl`
- ✅ Added recommended metadata annotations
- ✅ Added `key` to first field

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
✅ **Minimal API** - 3 focused public methods  
✅ **Type Safety** - Strong typing everywhere  
✅ **Testable** - Unit tests included  
✅ **ABAP 7.50+** - Modern ABAP syntax  

## Testing

```abap
SE24 → ZCL_CDS_MIGRATOR → Test → Execute (Ctrl+Shift+F10)
```

## Requirements

- SAP NetWeaver 7.50+
- ABAP authorization for reading DDLS objects

## Current Limitation

- `create_entity` is intentionally a placeholder and does not persist new DDLS objects yet.

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
