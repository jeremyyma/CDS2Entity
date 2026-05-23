*&---------------------------------------------------------------------*
*& Include  ZCDS_MIGRATION_EXAMPLES
*&---------------------------------------------------------------------*
*& Example usage scenarios for CDS migration tool
*&---------------------------------------------------------------------*

" Example 1: Scan a package and display results
REPORT zcds_migration_example1.

DATA: lo_scanner   TYPE REF TO zcl_cds_scanner,
      lt_cds_views TYPE zcl_cds_scanner=>tt_cds_views.

START-OF-SELECTION.

  " Create scanner instance
  CREATE OBJECT lo_scanner.

  " Scan package
  TRY.
      lt_cds_views = lo_scanner->scan_package(
        iv_package             = 'ZPACKAGE'
        iv_include_subpackages = abap_true
      ).

      " Display results
      LOOP AT lt_cds_views INTO DATA(ls_cds).
        WRITE: / 'CDS View:', ls_cds-ddlname.
        WRITE: / '  SQL View:', ls_cds-sql_view_name.
        WRITE: / '  Package:', ls_cds-package.
        WRITE: / '  Description:', ls_cds-description.
        WRITE: / '  Is Classic:', ls_cds-is_classic.
        NEW-LINE.
      ENDLOOP.

    CATCH cx_root INTO DATA(lx_error).
      WRITE: / 'Error:', lx_error->get_text( ).
  ENDTRY.

*&---------------------------------------------------------------------*

" Example 2: Analyze dependencies for a specific CDS view
REPORT zcds_migration_example2.

DATA: lo_analyzer    TYPE REF TO zcl_cds_dependency_analyzer,
      lt_dependencies TYPE zcl_cds_dependency_analyzer=>tt_dependencies,
      lt_dependent_views TYPE STANDARD TABLE OF ddlname.

START-OF-SELECTION.

  " Create analyzer instance
  CREATE OBJECT lo_analyzer.

  " Extract dependencies for a specific CDS view
  lt_dependencies = lo_analyzer->extract_dependencies( 'Z_MY_CDS_VIEW' ).

  WRITE: / 'Direct Dependencies:'.
  LOOP AT lt_dependencies INTO DATA(ls_dep).
    WRITE: / '  Type:', ls_dep-dependency_type.
    WRITE: / '  Target:', ls_dep-target_ddl.
    NEW-LINE.
  ENDLOOP.

  " Get all dependent views (recursive)
  lt_dependent_views = lo_analyzer->get_dependent_views( 'Z_MY_CDS_VIEW' ).

  WRITE: / 'All Dependent Views (Recursive):'.
  LOOP AT lt_dependent_views INTO DATA(lv_dep_view).
    WRITE: / '  -', lv_dep_view.
  ENDLOOP.

*&---------------------------------------------------------------------*

" Example 3: Migrate a single CDS view
REPORT zcds_migration_example3.

DATA: lo_scanner   TYPE REF TO zcl_cds_scanner,
      lo_migrator  TYPE REF TO zcl_cds_migrator,
      ls_cds_view  TYPE zcl_cds_scanner=>ty_cds_view,
      ls_result    TYPE zcl_cds_migrator=>ty_migration_result.

START-OF-SELECTION.

  " Create instances
  CREATE OBJECT lo_scanner.
  CREATE OBJECT lo_migrator.

  " Read CDS metadata
  DATA(lt_cds_views) = lo_scanner->scan_package(
    iv_package             = 'ZPACKAGE'
    iv_include_subpackages = abap_false
  ).

  " Get first classic CDS view
  READ TABLE lt_cds_views INTO ls_cds_view INDEX 1.
  IF sy-subrc = 0.
    ls_cds_view-selected = abap_true.

    " Migrate
    ls_result = lo_migrator->migrate_single_cds( ls_cds_view ).

    " Display result
    WRITE: / 'Migration Result:'.
    WRITE: / '  Original CDS:', ls_result-ddlname.
    WRITE: / '  Old SQL View:', ls_result-old_sql_view.
    WRITE: / '  New CDS:', ls_result-new_ddl_name.
    WRITE: / '  New SQL View:', ls_result-new_sql_view.
    WRITE: / '  Status:', ls_result-status.
    WRITE: / '  Message:', ls_result-message.
    NEW-LINE.

    " Display generated source code
    IF ls_result-status = 'SUCCESS'.
      WRITE: / 'Generated Source Code:'.
      WRITE: / '========================================'.
      SPLIT ls_result-new_source_code AT cl_abap_char_utilities=>newline
        INTO TABLE DATA(lt_source_lines).
      LOOP AT lt_source_lines INTO DATA(lv_line).
        WRITE: / lv_line.
      ENDLOOP.
    ENDIF.
  ENDIF.

*&---------------------------------------------------------------------*

" Example 4: Full migration workflow with dependency ordering
REPORT zcds_migration_example4.

DATA: lo_manager  TYPE REF TO zcl_cds_migration_manager,
      lt_cds_views TYPE zcl_cds_scanner=>tt_cds_views,
      ls_summary  TYPE zcl_cds_migration_manager=>ty_migration_summary.

START-OF-SELECTION.

  " Create manager
  CREATE OBJECT lo_manager.

  " Get CDS list with dependencies
  TRY.
      lt_cds_views = lo_manager->get_cds_list_with_dependencies(
        iv_package             = 'ZPACKAGE'
        iv_include_subpackages = abap_true
      ).

      WRITE: / 'Found', lines( lt_cds_views ), 'classic CDS view(s)'.
      NEW-LINE.

      " Display views with dependencies
      LOOP AT lt_cds_views INTO DATA(ls_cds).
        WRITE: / ls_cds-ddlname, '(', ls_cds-sql_view_name, ')'.
        IF ls_cds-dependencies IS NOT INITIAL.
          WRITE: / '  Dependencies:'.
          LOOP AT ls_cds-dependencies INTO DATA(lv_dep).
            WRITE: / '    -', lv_dep.
          ENDLOOP.
        ENDIF.
        NEW-LINE.
      ENDLOOP.

      " Select all for migration
      LOOP AT lt_cds_views ASSIGNING FIELD-SYMBOL(<cds>).
        <cds>-selected = abap_true.
      ENDLOOP.

      " Execute migration
      WRITE: / '========================================'.
      WRITE: / 'Starting Migration...'.
      WRITE: / '========================================'.
      NEW-LINE.

      ls_summary = lo_manager->execute_migration(
        iv_package             = 'ZPACKAGE'
        iv_include_subpackages = abap_true
      ).

      " Display summary
      WRITE: / 'Migration Complete!'.
      WRITE: / '  Total Found:', ls_summary-total_found.
      WRITE: / '  Total Selected:', ls_summary-total_selected.
      WRITE: / '  Total Migrated:', ls_summary-total_migrated.
      WRITE: / '  Total Errors:', ls_summary-total_errors.
      NEW-LINE.

      " Display each result
      LOOP AT ls_summary-results INTO DATA(ls_result).
        WRITE: / 'View:', ls_result-ddlname, '→', ls_result-new_ddl_name.
        WRITE: / '  Status:', ls_result-status.
        IF ls_result-status = 'ERROR'.
          WRITE: / '  Error:', ls_result-message.
        ENDIF.
      ENDLOOP.

    CATCH cx_root INTO DATA(lx_error).
      WRITE: / 'Error:', lx_error->get_text( ).
  ENDTRY.

*&---------------------------------------------------------------------*

" Example 5: Generate entity source without migration
REPORT zcds_migration_example5.

DATA: lo_scanner   TYPE REF TO zcl_cds_scanner,
      lo_migrator  TYPE REF TO zcl_cds_migrator,
      ls_cds_view  TYPE zcl_cds_scanner=>ty_cds_view,
      lv_entity_source TYPE string.

START-OF-SELECTION.

  " Create instances
  CREATE OBJECT lo_scanner.
  CREATE OBJECT lo_migrator.

  " Manually create CDS view structure
  ls_cds_view-ddlname = 'Z_MY_CDS_VIEW'.
  ls_cds_view-sql_view_name = 'ZMYCDS'.
  ls_cds_view-source_code = |@AbapCatalog.sqlViewName: 'ZMYCDS'\n| &&
                            |@AbapCatalog.compiler.compareFilter: true\n| &&
                            |@AccessControl.authorizationCheck: #CHECK\n| &&
                            |@EndUserText.label: 'My Classic View'\n| &&
                            |define view Z_MY_CDS_VIEW\n| &&
                            |  as select from scarr\n| &&
                            |\{\n| &&
                            |  scarr.carrid,\n| &&
                            |  scarr.carrname,\n| &&
                            |  scarr.currcode\n| &&
                            |\}|.

  " Generate entity source
  lv_entity_source = lo_migrator->generate_entity_source(
    is_cds_view     = ls_cds_view
    iv_new_sql_view = 'ZMYCDS_V2'
  ).

  " Display generated source
  WRITE: / 'Generated Entity CDS Source:'.
  WRITE: / '========================================'.
  SPLIT lv_entity_source AT cl_abap_char_utilities=>newline
    INTO TABLE DATA(lt_source_lines).
  LOOP AT lt_source_lines INTO DATA(lv_line).
    WRITE: / lv_line.
  ENDLOOP.

*&---------------------------------------------------------------------*

" Example 6: Check if a CDS view is classic
REPORT zcds_migration_example6.

DATA: lo_scanner TYPE REF TO zcl_cds_scanner,
      lv_is_classic TYPE abap_bool.

PARAMETERS: p_cds TYPE ddlname OBLIGATORY.

START-OF-SELECTION.

  " Create scanner
  CREATE OBJECT lo_scanner.

  " Check if classic
  lv_is_classic = lo_scanner->is_classic_cds( p_cds ).

  IF lv_is_classic = abap_true.
    WRITE: / 'CDS view', p_cds, 'is CLASSIC (needs migration)'.
  ELSE.
    WRITE: / 'CDS view', p_cds, 'is already ENTITY-BASED or not found'.
  ENDIF.

  " Display source for verification
  DATA(lv_source) = lo_scanner->get_cds_source( p_cds ).
  IF lv_source IS NOT INITIAL.
    NEW-LINE.
    WRITE: / 'Source Code:'.
    WRITE: / '========================================'.
    SPLIT lv_source AT cl_abap_char_utilities=>newline
      INTO TABLE DATA(lt_source_lines).
    LOOP AT lt_source_lines INTO DATA(lv_line).
      WRITE: / lv_line.
    ENDLOOP.
  ENDIF.
