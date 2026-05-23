# CDS2Entity - Deployment Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation Steps](#installation-steps)
3. [Configuration](#configuration)
4. [Testing](#testing)
5. [Usage Guide](#usage-guide)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### System Requirements
- SAP NetWeaver 7.50 or higher
- ABAP Development Tools (ADT) Eclipse plugin (recommended)
- ABAP Cloud environment (recommended but not required)

### Required Authorizations
```abap
S_DEVELOP - Development authorization
  ACTVT: 01 (Create), 02 (Change), 03 (Display)
  OBJTYPE: DDLS (CDS View), PROG (Report), CLAS (Class)
  DEVCLASS: Your package

S_TCODE - Transaction authorization
  TCD: SE38, SE80, SE24 (for development)
```

---

## Installation Steps

### Step 1: Create Development Package

1. Open transaction `SE80`
2. Create a new package (e.g., `ZCDS_MIGRATION`)
3. Set package properties:
   - Package Type: Development
   - Software Component: HOME (or your custom component)
   - Transport Layer: As per your landscape

### Step 2: Create Classes

Create the following classes in sequence:

#### 2.1 Create ZCL_CDS_SCANNER

```
Transaction: SE24
Class Name: ZCL_CDS_SCANNER
Class Type: Usual ABAP Class
```

Copy content from: `zcl_cds_scanner.clas.abap`

**Public Methods:**
- `SCAN_PACKAGE` - Scans a package for classic CDS views
- `IS_CLASSIC_CDS` - Checks if a CDS view is classic
- `GET_CDS_SOURCE` - Retrieves CDS source code

#### 2.2 Create ZCL_CDS_DEPENDENCY_ANALYZER

```
Transaction: SE24
Class Name: ZCL_CDS_DEPENDENCY_ANALYZER
Class Type: Usual ABAP Class
```

Copy content from: `zcl_cds_dependency_analyzer.clas.abap`

**Public Methods:**
- `EXTRACT_DEPENDENCIES` - Extracts dependencies from CDS view
- `GET_DEPENDENT_VIEWS` - Gets all dependent views recursively
- `ANALYZE_MIGRATION_ORDER` - Determines migration order

#### 2.3 Create ZCL_CDS_MIGRATOR

```
Transaction: SE24
Class Name: ZCL_CDS_MIGRATOR
Class Type: Usual ABAP Class
```

Copy content from: `zcl_cds_migrator.clas.abap`

**Public Methods:**
- `MIGRATE_SINGLE_CDS` - Migrates a single CDS view
- `MIGRATE_MULTIPLE_CDS` - Migrates multiple views in order
- `GENERATE_ENTITY_SOURCE` - Generates entity CDS source

#### 2.4 Create ZCL_CDS_MIGRATION_MANAGER

```
Transaction: SE24
Class Name: ZCL_CDS_MIGRATION_MANAGER
Class Type: Usual ABAP Class
```

Copy content from: `zcl_cds_migration_manager.clas.abap`

**Public Methods:**
- `EXECUTE_MIGRATION` - Main orchestration method
- `GET_CDS_LIST_WITH_DEPENDENCIES` - Returns CDS list
- `SAVE_MIGRATION_RESULTS` - Persists results

### Step 3: Create Report Program

```
Transaction: SE38
Program Name: ZCDS_MIGRATION_TOOL
Type: Executable Program
```

Copy content from: `zcds_migration_tool.prog.abap`

### Step 4: Create Test Class (Optional)

```
Transaction: SE24
Class Name: ZCL_CDS_TEST
Class Type: Test Class
```

Copy content from: `zcl_cds_test.clas.abap`

### Step 5: Activate All Objects

1. Select all created objects in your package
2. Right-click → Activate
3. Ensure no syntax errors

---

## Configuration

### Setting Up Text Symbols

For the report `ZCDS_MIGRATION_TOOL`, add these text symbols:

```
Transaction: SE38 → Text Elements → Text Symbols

Symbol    Text
------    ----
001       Source Package Selection
002       Migration Options
003       Classic CDS to Entity-Based CDS Migration Tool
```

### Setting Up Selection Texts

```
Transaction: SE38 → Text Elements → Selection Texts

Name      Text
------    ----
P_PACK    Source Package
P_SUB     Include Subpackages
P_TPKG    Target Package
P_DISP    Display Only (No Save)
P_SAVE    Save Migration Results
```

---

## Testing

### Unit Testing

Run the test class:

```abap
Transaction: SE24
Class: ZCL_CDS_TEST
→ Execute Unit Tests (Ctrl+Shift+F10)
```

### Integration Testing

#### Test Case 1: Scan a Test Package

1. Create a test package with classic CDS views
2. Run report `ZCDS_MIGRATION_TOOL`
3. Enter test package name
4. Check "Display Only"
5. Execute (F8)
6. Verify CDS views are found

#### Test Case 2: Dependency Analysis

1. Create interdependent CDS views
2. Run the scanner
3. Verify dependencies are correctly identified
4. Check migration order is logical

#### Test Case 3: Single Migration

1. Select one simple CDS view
2. Run migration
3. Review generated entity CDS source
4. Verify:
   - SQL view name has `_V2` suffix
   - `DEFINE VIEW ENTITY` syntax
   - KEY fields are present
   - Required annotations added

---

## Usage Guide

### Basic Workflow

#### 1. Scan for Classic CDS Views

```
Transaction: SE38
Report: ZCDS_MIGRATION_TOOL

Parameters:
  Source Package: ZPACKAGE
  Include Subpackages: ✓
  Display Only: ✓

Execute: F8
```

#### 2. Review Results

The tool displays:
- List of classic CDS views found
- SQL view names
- Package information
- Dependencies

#### 3. Select CDS Views to Migrate

- Use checkbox in ALV grid to select views
- Consider dependency order
- Start with leaf nodes (no dependents)

#### 4. Execute Migration

- Uncheck "Display Only"
- Check "Save Migration Results"
- Execute (F8)

#### 5. Review Generated Code

- Check migration status
- Review generated entity CDS source
- Verify transformations

### Advanced Usage

#### Programmatic Access

```abap
DATA: lo_manager TYPE REF TO zcl_cds_migration_manager,
      ls_summary TYPE zcl_cds_migration_manager=>ty_migration_summary.

CREATE OBJECT lo_manager.

" Execute migration
ls_summary = lo_manager->execute_migration(
  iv_package             = 'ZPACKAGE'
  iv_include_subpackages = abap_true
).

" Process results
LOOP AT ls_summary-results INTO DATA(ls_result).
  " Handle each result
ENDLOOP.
```

#### Batch Processing

```abap
" Process multiple packages
DATA: lt_packages TYPE TABLE OF devclass.

APPEND 'ZPACKAGE1' TO lt_packages.
APPEND 'ZPACKAGE2' TO lt_packages.

LOOP AT lt_packages INTO DATA(lv_package).
  DATA(ls_summary) = lo_manager->execute_migration(
    iv_package             = lv_package
    iv_include_subpackages = abap_true
  ).
  " Process results
ENDLOOP.
```

---

## Troubleshooting

### Common Issues

#### Issue 1: No CDS Views Found

**Symptoms:**
```
Found 0 classic CDS view(s)
```

**Solutions:**
1. Verify package name is correct
2. Check if CDS views are already entity-based
3. Ensure CDS views are activated
4. Check authorization for reading DDLS objects

#### Issue 2: SQL View Name Too Long

**Symptoms:**
```
Error: SQL view name exceeds 16 characters
```

**Solution:**
The tool automatically truncates long names:
```abap
" Manual workaround
IF strlen( old_name ) > 13.
  new_name = |{ old_name(13) }_V2|.
ELSE.
  new_name = |{ old_name }_V2|.
ENDIF.
```

#### Issue 3: Circular Dependencies

**Symptoms:**
```
Warning: Circular dependency detected
```

**Solution:**
1. Review dependency graph
2. Break circular references
3. Migrate in stages
4. Use forward declarations if available

#### Issue 4: Missing KEY Fields

**Symptoms:**
```
Entity view requires at least one KEY field
```

**Solution:**
The tool automatically adds KEY to the first field. Manual review:
```abap
" Before (Classic)
define view Z_VIEW as select from table {
  field1,
  field2
}

" After (Entity - Auto-corrected)
define view entity Z_VIEW as select from table {
  key field1,
  field2
}
```

#### Issue 5: Complex Annotations Not Transformed

**Symptoms:**
```
Warning: Custom annotations may require review
```

**Solution:**
1. Review generated code manually
2. Add custom annotations as needed
3. Extend the migrator class for specific annotations

### Debug Mode

Enable debug mode to trace execution:

```abap
" Add breakpoint in migration manager
BREAK-POINT.

" Or use debug logs
WRITE: / 'Debug:', variable.
```

### Support Contacts

- **Technical Issues**: Your ABAP development team
- **CDS Questions**: SAP CDS documentation
- **Tool Enhancement**: Submit to your development lead

---

## Post-Migration Checklist

After successful migration:

- [ ] Review all generated entity CDS views
- [ ] Validate KEY field assignments
- [ ] Check annotation completeness
- [ ] Test with dependent objects
- [ ] Update documentation
- [ ] Create transport request
- [ ] Activate new CDS views
- [ ] Test in quality system
- [ ] Migrate to production
- [ ] Update consuming applications
- [ ] Archive classic CDS views

---

## Maintenance

### Regular Updates

1. **Monitor SAP Notes**: Check for CDS entity syntax updates
2. **Review Transformations**: Update transformation rules as needed
3. **Test New Patterns**: Add support for new CDS features
4. **Update Documentation**: Keep examples current

### Enhancement Opportunities

- Add support for CDS view extensions
- Implement DCL migration
- Add custom annotation mapping
- Integrate with transport management
- Add rollback capabilities

---

## Appendix

### Useful Transactions

| Transaction | Purpose |
|-------------|---------|
| SE38 | ABAP Editor - Run reports |
| SE24 | Class Builder - Manage classes |
| SE80 | Object Navigator - Package management |
| SE11 | ABAP Dictionary - View CDS metadata |
| STMS | Transport Management |

### Reference Documentation

- [SAP ABAP CDS Views](https://help.sap.com/docs/ABAP_PLATFORM_NEW)
- [ABAP Cloud Development](https://help.sap.com/docs/BTP)
- [CDS Entity Views Guide](https://help.sap.com/docs/ABAP_CDS)

---

**Document Version**: 1.0.0  
**Last Updated**: 2026-05-23  
**Maintained By**: ABAP Cloud Development Team
