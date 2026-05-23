# CDS2Entity - Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CDS2Entity Migration Tool                    │
│                     (ABAP Cloud Solution)                           │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌──────────────────────────────────────────────────────────────┐ │
│   │  ZCDS_MIGRATION_TOOL (ABAP Report)                           │ │
│   │  - Selection Screen (Package, Options)                       │ │
│   │  - ALV Grid Display (CDS List with Checkboxes)               │ │
│   │  - Result Display (Summary & Details)                        │ │
│   └──────────────────────────────────────────────────────────────┘ │
│                              │                                       │
└──────────────────────────────┼───────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      ORCHESTRATION LAYER                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌──────────────────────────────────────────────────────────────┐ │
│   │  ZCL_CDS_MIGRATION_MANAGER                                   │ │
│   │  ┌────────────────────────────────────────────────────────┐  │ │
│   │  │ + execute_migration()                                  │  │ │
│   │  │ + get_cds_list_with_dependencies()                     │  │ │
│   │  │ + save_migration_results()                             │  │ │
│   │  └────────────────────────────────────────────────────────┘  │ │
│   └──────────────────────────────────────────────────────────────┘ │
│                 │              │              │                      │
│        ┌────────┘              │              └────────┐            │
└────────┼───────────────────────┼───────────────────────┼────────────┘
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        BUSINESS LOGIC LAYER                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐     │
│  │              │      │              │      │              │     │
│  │ZCL_CDS_      │      │ZCL_CDS_      │      │ZCL_CDS_      │     │
│  │SCANNER       │      │DEPENDENCY_   │      │MIGRATOR      │     │
│  │              │      │ANALYZER      │      │              │     │
│  ├──────────────┤      ├──────────────┤      ├──────────────┤     │
│  │              │      │              │      │              │     │
│  │+ scan_       │      │+ extract_    │      │+ migrate_    │     │
│  │  package()   │      │  dependencies│      │  single_cds()│     │
│  │              │      │  ()          │      │              │     │
│  │+ is_classic_ │      │              │      │+ migrate_    │     │
│  │  cds()       │      │+ get_        │      │  multiple_   │     │
│  │              │      │  dependent_  │      │  cds()       │     │
│  │+ get_cds_    │      │  views()     │      │              │     │
│  │  source()    │      │              │      │+ generate_   │     │
│  │              │      │+ analyze_    │      │  entity_     │     │
│  │              │      │  migration_  │      │  source()    │     │
│  │              │      │  order()     │      │              │     │
│  │              │      │              │      │              │     │
│  └──────────────┘      └──────────────┘      └──────────────┘     │
│         │                     │                      │              │
└─────────┼─────────────────────┼──────────────────────┼──────────────┘
          │                     │                      │
          ▼                     ▼                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        DATA ACCESS LAYER                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌───────────┐  ┌───────────┐  ┌──────────┐  ┌──────────────────┐ │
│  │ DD02L     │  │ TADIR     │  │ DDDDLSRC │  │ CL_DD_DDL_       │ │
│  │ (CDS      │  │ (Object   │  │ (CDS     │  │ HANDLER_FACTORY  │ │
│  │ Metadata) │  │ Directory)│  │ Source)  │  │ (DDL API)        │ │
│  └───────────┘  └───────────┘  └──────────┘  └──────────────────┘ │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════
                           DATA FLOW
═══════════════════════════════════════════════════════════════════════

┌────────────┐
│ 1. SCAN    │  User enters package → Scanner reads DD02L/TADIR
└────────────┘  → Identifies classic CDS views → Returns list
      │
      ▼
┌────────────┐
│ 2. ANALYZE │  Analyzer parses CDS source code → Extracts
└────────────┘  dependencies (FROM, JOIN, ASSOCIATION) → Builds
      │         dependency graph → Performs topological sort
      ▼
┌────────────┐
│ 3. SELECT  │  User reviews list in ALV grid → Checks boxes
└────────────┘  for CDS views to migrate → Confirms selection
      │
      ▼
┌────────────┐
│ 4. MIGRATE │  Migrator processes each selected view in order
└────────────┘  → Transforms annotations → Converts DEFINE VIEW
      │         to DEFINE VIEW ENTITY → Adds KEY fields →
      ▼         Updates sqlViewName (_V2 suffix)
┌────────────┐
│ 5. RESULT  │  Displays migration summary → Shows generated
└────────────┘  source code → Optional: Save to system

═══════════════════════════════════════════════════════════════════════
                         COMPONENT DETAILS
═══════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────┐
│  ZCL_CDS_SCANNER                                                     │
├─────────────────────────────────────────────────────────────────────┤
│  Purpose: Discover and classify CDS views                           │
│                                                                      │
│  Input:  Package name, include subpackages flag                     │
│  Output: Table of CDS views with metadata                           │
│                                                                      │
│  Key Logic:                                                          │
│  - Query DD02L for views in package                                 │
│  - Read CDS source via CL_DD_DDL_HANDLER_FACTORY                    │
│  - Detect classic vs entity by checking for:                        │
│    * sqlViewName annotation                                         │
│    * DEFINE VIEW (not DEFINE VIEW ENTITY)                           │
│    * Absence of entity-specific annotations                         │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  ZCL_CDS_DEPENDENCY_ANALYZER                                         │
├─────────────────────────────────────────────────────────────────────┤
│  Purpose: Extract and analyze CDS dependencies                      │
│                                                                      │
│  Input:  CDS view name or source code                               │
│  Output: Dependency list, migration order                           │
│                                                                      │
│  Key Logic:                                                          │
│  - Parse source code with REGEX patterns:                           │
│    * FROM clause: 'FROM\s+([A-Z/_][A-Z0-9_/]*)'                    │
│    * ASSOCIATION: 'ASSOCIATION\s+\[.*?\]\s+TO\s+(\w+)'            │
│    * JOIN: '(LEFT|RIGHT|INNER|OUTER)?\s*JOIN\s+(\w+)'             │
│  - Build dependency graph                                           │
│  - Topological sort for migration order                             │
│  - Detect circular dependencies                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  ZCL_CDS_MIGRATOR                                                    │
├─────────────────────────────────────────────────────────────────────┤
│  Purpose: Generate entity-based CDS source code                     │
│                                                                      │
│  Input:  Classic CDS view metadata and source                       │
│  Output: Entity CDS source code                                     │
│                                                                      │
│  Key Transformations:                                                │
│  1. DEFINE VIEW → DEFINE VIEW ENTITY                                │
│  2. sqlViewName: 'ZOLD' → sqlViewName: 'ZOLD_V2'                   │
│  3. Add required annotations:                                       │
│     - @AccessControl.authorizationCheck                             │
│     - @Metadata.ignorePropagatedAnnotations                         │
│     - @EndUserText.label                                            │
│     - @AbapCatalog.viewEnhancementCategory                          │
│  4. Ensure KEY fields (add to first field if missing)               │
│  5. Transform associations to entity syntax                         │
└─────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════
                        DATA STRUCTURES
═══════════════════════════════════════════════════════════════════════

TY_CDS_VIEW                     TY_DEPENDENCY
├─ ddlname                      ├─ source_ddl
├─ sql_view_name                ├─ target_ddl
├─ package                      ├─ dependency_type
├─ description                  └─ target_field
├─ is_classic
├─ entity_category              TY_MIGRATION_RESULT
├─ source_code                  ├─ ddlname
├─ dependencies[]               ├─ old_sql_view
└─ selected                     ├─ new_ddl_name
                                ├─ new_sql_view
                                ├─ new_source_code
                                ├─ status
                                └─ message

═══════════════════════════════════════════════════════════════════════
                      PROCESSING SEQUENCE
═══════════════════════════════════════════════════════════════════════

User Input → Report Selection Screen
     │
     ├─→ [SCAN] ZCL_CDS_SCANNER
     │       │
     │       ├─→ Query DD02L (CDS metadata)
     │       ├─→ Query TADIR (object directory)
     │       ├─→ Read CDS source (CL_DD_DDL_HANDLER)
     │       └─→ Return: tt_cds_views
     │
     ├─→ [ANALYZE] ZCL_CDS_DEPENDENCY_ANALYZER
     │       │
     │       ├─→ Parse CDS source (REGEX)
     │       ├─→ Extract dependencies
     │       ├─→ Build dependency graph
     │       ├─→ Topological sort
     │       └─→ Return: tt_dependencies + ordered list
     │
     ├─→ [DISPLAY] ALV Grid
     │       │
     │       └─→ User selects CDS views (checkboxes)
     │
     └─→ [MIGRATE] ZCL_CDS_MIGRATOR
             │
             ├─→ For each selected CDS (in order):
             │   ├─→ Transform annotations
             │   ├─→ Update SQL view name (+_V2)
             │   ├─→ Convert to entity syntax
             │   ├─→ Add KEY fields
             │   └─→ Generate source code
             │
             └─→ [RESULT] Display summary & details

═══════════════════════════════════════════════════════════════════════
```

## Architecture Principles

### 1. **Separation of Concerns**
- Scanner: Data discovery
- Analyzer: Dependency management
- Migrator: Code transformation
- Manager: Orchestration

### 2. **Single Responsibility**
Each class has one clear purpose and can be used independently.

### 3. **Dependency Injection**
Manager creates and coordinates scanner, analyzer, and migrator instances.

### 4. **Extensibility**
- Easy to add new transformation rules
- Support for custom annotations
- Pluggable dependency extractors

### 5. **Testability**
- Unit tests for each component
- Integration tests for full workflow
- Mock-friendly design

### 6. **ABAP Cloud Ready**
- Uses released APIs where available
- Compatible with ABAP Cloud restrictions
- No use of deprecated features

---

**Architecture Version**: 1.0.0  
**Last Updated**: 2026-05-23
