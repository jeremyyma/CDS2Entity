# Method Documentation - ZCL_CDS_MIGRATOR

## Public Methods

### find_in_package( iv_package )
**Purpose:** Find classic CDS views in package using DDHEADANNO

**Parameters:**
- `iv_package` (TYPE devclass) - Package name to scan

**Returns:** `ty_cds_list` - Table of classic CDS views with metadata

**How it works:**
- Queries DDHEADANNO table for entries with annotation name `ABAPCATALOG.SQLVIEWNAME`
- Joins with TADIR to filter by package and object type DDLS
- Reads source code for each found CDS view
- Extracts SQL view name from annotation value

**Example:**
```abap
DATA(lt_cds) = NEW zcl_cds_migrator( )->find_in_package( 'ZPACKAGE' ).
```

---

### transform( CHANGING cs_cds )
**Purpose:** Transform classic CDS to entity CDS with modern annotations

**Parameters:**
- `cs_cds` (TYPE ty_cds, CHANGING) - CDS metadata structure to transform

**How it works:**
- Generates new CDS name by appending `_V2` suffix
- Generates new SQL view name by appending `_V2` suffix (max 16 chars)
- Calls `generate_entity_source()` to modernize the source code

**Example:**
```abap
LOOP AT lt_cds ASSIGNING FIELD-SYMBOL(<cds>).
  go_migrator->transform( CHANGING cs_cds = <cds> ).
ENDLOOP.
```

---

### create_entity( is_cds )
**Purpose:** Create new entity CDS view in system

**Parameters:**
- `is_cds` (TYPE ty_cds) - CDS metadata with generated entity source

**Returns:** `abap_bool` - Success indicator

**How it works:**
- Placeholder method for future CDS creation API integration
- Currently returns `false` and displays information message
- Requires manual activation in SE24/SE80

**Note:** Actual CDS creation requires specialized API that may vary by SAP release.

**Example:**
```abap
IF go_migrator->create_entity( ls_cds ) = abap_true.
  WRITE: / 'Created:', ls_cds-new_name.
ENDIF.
```

---

## Private Methods

### read_source( iv_name )
**Purpose:** Read CDS source code from database tables

**Parameters:**
- `iv_name` (TYPE ddlname) - CDS view name

**Returns:** `string` - Complete CDS source code

**How it works:**
- First attempts to read from DDDDLSRC table (single-line storage)
- If not found, reads from DDDDLSRC02BT table (multi-line storage)
- Concatenates multi-line source with newline separator
- Returns empty string on error

---

### is_classic( iv_source )
**Purpose:** Check if CDS has sqlViewName annotation (classic CDS indicator)

**Parameters:**
- `iv_source` (TYPE string) - CDS source code

**Returns:** `abap_bool` - True if classic CDS, false if entity

**How it works:**
- Checks if source contains `sqlViewName` annotation
- Checks that source does NOT contain `VIEW ENTITY` keyword
- Both conditions must be true for classic CDS

**Note:** This method is still used internally for validation, though primary detection uses DDHEADANNO.

---

### generate_entity_source( iv_source, iv_new_sql_view )
**Purpose:** Generate entity CDS source with all modern annotations

**Parameters:**
- `iv_source` (TYPE string) - Original classic CDS source
- `iv_new_sql_view` (TYPE ddstrucobjname) - New SQL view name with _V2 suffix

**Returns:** `string` - Modernized entity CDS source

**How it works - 8 Transformations:**

1. **Transform syntax:** `DEFINE VIEW` → `DEFINE VIEW ENTITY`

2. **Remove deprecated annotations:**
   - `@AbapCatalog.sqlViewName`
   - `@AbapCatalog.preserveKey`
   - `@AbapCatalog.compiler.compareFilter`

3. **Add required annotations:**
   - `@EndUserText.label` (required for entity views)
   - `@AccessControl.authorizationCheck` (required)

4. **Add recommended annotations:**
   - `@Metadata.ignorePropagatedAnnotations: true`
   - `@Metadata.allowExtensions: true`

5. **Add KEY to first field** if no KEY exists (required in entity views)

---

## Method Call Flow

```
REPORT
  ↓
find_in_package()
  ├─→ read_source() [for each CDS]
  └─→ Returns: ty_cds_list
  ↓
transform() [for each CDS]
  └─→ generate_entity_source()
      ├─→ Remove deprecated annotations
      ├─→ Add modern annotations
      └─→ Add KEY field
  ↓
create_entity() [optional, if commit mode]
  └─→ Create new CDS view (manual for now)
```

---

## Type Definitions

### ty_cds
Structure holding CDS metadata for migration:

```abap
BEGIN OF ty_cds,
  name        TYPE ddlname,           " Original CDS name
  sql_view    TYPE ddstrucobjname,    " Original SQL view name
  source      TYPE string,            " Original source code
  new_name    TYPE ddlname,           " New CDS name (with _V2)
  new_sql     TYPE ddstrucobjname,    " New SQL view name (with _V2)
  new_source  TYPE string,            " Modernized entity source
  is_classic  TYPE abap_bool,         " Classic CDS indicator
END OF ty_cds
```

### ty_cds_list
Table type for multiple CDS views:

```abap
ty_cds_list TYPE STANDARD TABLE OF ty_cds WITH KEY name
```

---

## Usage Patterns

### Pattern 1: Display Only (Preview)
```abap
DATA(lo_migrator) = NEW zcl_cds_migrator( ).
DATA(lt_cds) = lo_migrator->find_in_package( 'ZPACKAGE' ).

LOOP AT lt_cds ASSIGNING FIELD-SYMBOL(<cds>).
  lo_migrator->transform( CHANGING cs_cds = <cds> ).
  WRITE: / <cds>-name, '→', <cds>-new_name.
ENDLOOP.
```

### Pattern 2: With Creation (Commit)
```abap
DATA(lo_migrator) = NEW zcl_cds_migrator( ).
DATA(lt_cds) = lo_migrator->find_in_package( 'ZPACKAGE' ).

LOOP AT lt_cds ASSIGNING FIELD-SYMBOL(<cds>).
  lo_migrator->transform( CHANGING cs_cds = <cds> ).
  
  IF lo_migrator->create_entity( <cds> ) = abap_true.
    WRITE: / <cds>-new_name, 'created successfully'.
  ENDIF.
ENDLOOP.
```

---

**Last Updated:** 2026-05-23  
**Version:** 2.1.0
