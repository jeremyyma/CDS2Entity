# CDS2Entity - Classic CDS to Entity-Based CDS Migration Tool

An ABAP Cloud solution for automatically scanning and migrating classic CDS views to entity-based CDS views in SAP systems.

[![abapGit](https://img.shields.io/badge/abapGit-compatible-brightgreen)](https://abapgit.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![SAP](https://img.shields.io/badge/SAP-7.50%2B-orange)](https://www.sap.com)

## Quick Start

### Install via abapGit (Recommended)

```
1. Open ZABAPGIT in your SAP system
2. Click "New Online"
3. URL: https://github.com/jeremyyma/CDS2Entity.git
4. Package: ZCDS_MIGRATION (or $TMP for testing)
5. Pull → Activate
```

📖 **Detailed Installation**: See [INSTALL_ABAPGIT.md](INSTALL_ABAPGIT.md)

### Download ZIP for Offline Installation

Download: [CDS2Entity-abapgit.zip](../../releases/latest) (42 KB)

## Overview

This tool helps ABAP Cloud developers transition from classic CDS views to the modern entity-based CDS approach by:

1. **Scanning** packages to identify classic CDS views
2. **Analyzing** dependencies between CDS views
3. **Generating** new entity-based CDS source code
4. **Managing** migration with user-selectable CDS views

## Features

- ✅ Package scanning (with sub-package support)
- ✅ Classic CDS view detection
- ✅ Dependency extraction and analysis
- ✅ Automatic migration order calculation (topological sort)
- ✅ Entity-based CDS source code generation
- ✅ SQL view name transformation (appends _V2)
- ✅ Interactive selection via ALV grid
- ✅ Migration summary and detailed results

## Components

### 1. ZCL_CDS_SCANNER
Main scanner class for discovering classic CDS views in packages.

**Key Methods:**
- `scan_package()` - Scans a package for classic CDS views
- `is_classic_cds()` - Determines if a CDS view is classic (non-entity)
- `get_cds_source()` - Retrieves CDS source code

### 2. ZCL_CDS_DEPENDENCY_ANALYZER
Analyzes dependencies between CDS views.

**Key Methods:**
- `extract_dependencies()` - Extracts all dependencies from a CDS view
- `get_dependent_views()` - Gets recursive dependency tree
- `analyze_migration_order()` - Calculates optimal migration order

**Dependency Types Detected:**
- FROM clause references
- JOIN clauses (LEFT, RIGHT, INNER, OUTER)
- ASSOCIATION declarations

### 3. ZCL_CDS_MIGRATOR
Generates entity-based CDS source code from classic CDS views.

**Key Methods:**
- `migrate_single_cds()` - Migrates a single CDS view
- `migrate_multiple_cds()` - Migrates multiple views in dependency order
- `generate_entity_source()` - Generates entity CDS source code

**Transformations Applied:**
- `DEFINE VIEW` → `DEFINE VIEW ENTITY`
- `sqlViewName` annotation updated (appends _V2)
- Adds required entity annotations:
  - `@AccessControl.authorizationCheck`
  - `@Metadata.ignorePropagatedAnnotations`
  - `@EndUserText.label`
  - `@AbapCatalog.viewEnhancementCategory`
- Ensures KEY fields are properly defined
- Transforms associations to entity syntax

### 4. ZCL_CDS_MIGRATION_MANAGER
Orchestrates the entire migration process.

**Key Methods:**
- `execute_migration()` - Main execution method
- `get_cds_list_with_dependencies()` - Returns scannable CDS list
- `save_migration_results()` - Persists migration results

### 5. ZCDS_MIGRATION_TOOL (Report)
Interactive ABAP report with selection screen and ALV display.

## Usage

### Running the Migration Tool

1. Execute transaction `SE38` or `SE80`
2. Run report `ZCDS_MIGRATION_TOOL`
3. Enter parameters:
   - **Package Name**: Source package to scan (e.g., `ZPACKAGE`)
   - **Include Sub-packages**: Check to include nested packages
   - **Target Package**: Destination package for new CDS views
   - **Display Only**: Check to preview without saving
   - **Save Results**: Check to create new CDS views

4. Press F8 to execute
5. Review the list of classic CDS views found
6. Select checkboxes for views to migrate
7. Press F8 again to execute migration

### Example: Programmatic Usage

```abap
DATA: lo_manager TYPE REF TO zcl_cds_migration_manager,
      lt_cds_views TYPE zcl_cds_scanner=>tt_cds_views,
      ls_summary TYPE zcl_cds_migration_manager=>ty_migration_summary.

" Create manager instance
CREATE OBJECT lo_manager.

" Get list of classic CDS views
lt_cds_views = lo_manager->get_cds_list_with_dependencies(
  iv_package             = 'ZPACKAGE'
  iv_include_subpackages = abap_true
).

" Mark views for migration
LOOP AT lt_cds_views ASSIGNING FIELD-SYMBOL(<cds>).
  <cds>-selected = abap_true. " Select all
ENDLOOP.

" Execute migration
ls_summary = lo_manager->execute_migration(
  iv_package             = 'ZPACKAGE'
  iv_include_subpackages = abap_true
).

" Display results
WRITE: / 'Total migrated:', ls_summary-total_migrated.
WRITE: / 'Total errors:', ls_summary-total_errors.
```

## Migration Example

### Before (Classic CDS)

```abap
@AbapCatalog.sqlViewName: 'ZMYVIEW'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'My Classic View'
define view Z_MY_CLASSIC_VIEW
  as select from scarr
  association [0..*] to spfli as _Flights on $projection.Carrid = _Flights.carrid
{
  scarr.carrid,
  scarr.carrname,
  scarr.currcode,
  _Flights
}
```

### After (Entity-Based CDS)

```abap
@AbapCatalog.sqlViewName: 'ZMYVIEW_V2'
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'My Classic View'
define view entity Z_MY_CLASSIC_VIEW_ENTITY
  as select from scarr
  association [0..*] to spfli as _Flights on $projection.Carrid = _Flights.carrid
{
  key scarr.carrid,
  scarr.carrname,
  scarr.currcode,
  _Flights
}
```

## Key Differences: Classic vs Entity CDS

| Aspect | Classic CDS | Entity CDS |
|--------|-------------|------------|
| Definition | `DEFINE VIEW` | `DEFINE VIEW ENTITY` |
| SQL View Name | Required | Optional (still supported) |
| Key Fields | Optional | Required (at least one) |
| Annotations | Less strict | More structured |
| Associations | Classic syntax | Enhanced syntax |
| Extensibility | Limited | Enhanced via categories |

## Installation

### Method 1: abapGit (Recommended) ⭐

See detailed instructions in [INSTALL_ABAPGIT.md](INSTALL_ABAPGIT.md)

```
ZABAPGIT → New Online → https://github.com/jeremyyma/CDS2Entity.git
```

### Method 2: Offline ZIP

1. Download [CDS2Entity-abapgit.zip](../../releases/latest)
2. ZABAPGIT → Import ZIP → Select file → Pull

### Method 3: Manual Installation

See [DEPLOYMENT.md](DEPLOYMENT.md) for manual setup instructions

## Prerequisites

- SAP NetWeaver 7.50 or higher
- ABAP Cloud environment (recommended)
- Authorization for:
  - Reading CDS views (`S_DEVELOP` with object type `DDLS`)
  - Creating CDS views (if saving results)
  - Transport requests (if saving to transportable packages)

## Limitations

- Works with standard CDS syntax (ABAP CDS, not SQL CDS)
- Complex annotations may require manual review
- DCL (Data Control Language) views are not migrated
- Custom annotations need manual verification
- Generated code should be reviewed before activation

## Best Practices

1. **Test First**: Always run with "Display Only" mode first
2. **Review Dependencies**: Check dependency graph before migration
3. **Start Small**: Begin with leaf nodes (views with no dependents)
4. **Backup**: Create a transport backup of original views
5. **Validate**: Test migrated views thoroughly
6. **Activate Together**: Activate dependent views in order

## Troubleshooting

### No CDS Views Found
- Verify package name is correct
- Check if views are classic (not already entity-based)
- Ensure you have read authorization

### Dependency Errors
- Review circular dependencies
- Check if dependent views exist
- Verify association syntax

### Migration Fails
- Review source code for complex patterns
- Check for unsupported annotations
- Validate SQL view name length (max 16 chars)

## Roadmap

Future enhancements:
- [ ] Support for parameterized CDS views
- [ ] DCL (authorization) migration
- [ ] Annotation mapping configuration
- [ ] Batch processing for large packages
- [ ] Integration with BTP ABAP Environment
- [ ] Generate migration documentation
- [ ] Support for CDS view extensions

## Contributing

This is an example implementation. Adapt to your organization's needs.

## License

MIT License - Free to use and modify

## Support

For issues or questions:
1. Review the documentation
2. Check SAP CDS documentation
3. Consult ABAP Cloud development guide

## References

- [SAP ABAP CDS Documentation](https://help.sap.com/docs/ABAP_PLATFORM)
- [ABAP Cloud Development Guide](https://help.sap.com/docs/BTP/ABAP_CLOUD)
- [CDS Entity Views](https://help.sap.com/docs/ABAP_CDS)

---

**Version**: 1.0.0  
**Last Updated**: 2026-05-23  
**Author**: ABAP Cloud Development Team
