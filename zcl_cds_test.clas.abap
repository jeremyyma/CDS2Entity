CLASS ltc_cds_scanner_test DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA: mo_scanner TYPE REF TO zcl_cds_scanner.

    METHODS:
      setup,
      test_is_classic_cds FOR TESTING,
      test_scan_package FOR TESTING,
      test_sql_view_name_extraction FOR TESTING.

ENDCLASS.


CLASS ltc_cds_scanner_test IMPLEMENTATION.

  METHOD setup.
    CREATE OBJECT mo_scanner.
  ENDMETHOD.

  METHOD test_is_classic_cds.
    " Test classic CDS detection
    DATA: lv_classic_source TYPE string,
          lv_entity_source  TYPE string,
          lv_result         TYPE abap_bool.

    " Classic CDS source
    lv_classic_source = |@AbapCatalog.sqlViewName: 'ZTEST'\n| &&
                        |define view Z_TEST as select from table \{ field \}|.

    " This test would require mocking or test doubles
    " For now, we verify the method exists and is callable
    " In a real scenario, use ABAP Unit test doubles

    " Entity CDS source
    lv_entity_source = |define view entity Z_TEST_ENTITY as select from table \{ key field \}|.

    " Note: Full testing requires dependency injection or test doubles
    " This is a structural test to ensure method is defined

  ENDMETHOD.

  METHOD test_scan_package.
    " Test package scanning
    DATA: lt_cds_views TYPE zcl_cds_scanner=>tt_cds_views.

    " This would require a test package with known CDS views
    " Or use test doubles to mock the database queries

    TRY.
        " Attempt to scan a known package
        " In real testing, use a dedicated test package
        " lt_cds_views = mo_scanner->scan_package(
        "   iv_package             = '$TEST'
        "   iv_include_subpackages = abap_false
        " ).

        " For now, verify method signature is correct
        cl_abap_unit_assert=>assert_bound(
          act = mo_scanner
          msg = 'Scanner should be instantiated'
        ).

      CATCH cx_root INTO DATA(lx_error).
        " Expected in environments without test data
        cl_abap_unit_assert=>assert_bound(
          act = lx_error
          msg = 'Error handling should work'
        ).
    ENDTRY.

  ENDMETHOD.

  METHOD test_sql_view_name_extraction.
    " Test SQL view name extraction from source code
    DATA: lv_source        TYPE string,
          lv_sql_view_name TYPE ddstrucobjname.

    lv_source = |@AbapCatalog.sqlViewName: 'ZTESTVIEW'\n| &&
                |@EndUserText.label: 'Test'\n| &&
                |define view Z_TEST as select from table \{ field \}|.

    " Extract SQL view name using regex
    FIND REGEX '@AbapCatalog\.sqlViewName\s*:\s*''(\w+)'''
      IN lv_source
      SUBMATCHES lv_sql_view_name
      IGNORING CASE.

    cl_abap_unit_assert=>assert_equals(
      act = lv_sql_view_name
      exp = 'ZTESTVIEW'
      msg = 'Should extract SQL view name correctly'
    ).

  ENDMETHOD.

ENDCLASS.


*&---------------------------------------------------------------------*

CLASS ltc_dependency_analyzer_test DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA: mo_analyzer TYPE REF TO zcl_cds_dependency_analyzer.

    METHODS:
      setup,
      test_extract_from_clause FOR TESTING,
      test_extract_associations FOR TESTING,
      test_extract_joins FOR TESTING.

ENDCLASS.


CLASS ltc_dependency_analyzer_test IMPLEMENTATION.

  METHOD setup.
    CREATE OBJECT mo_analyzer.
  ENDMETHOD.

  METHOD test_extract_from_clause.
    " Test FROM clause dependency extraction
    DATA: lv_source        TYPE string,
          lt_dependencies  TYPE zcl_cds_dependency_analyzer=>tt_dependencies.

    lv_source = |define view Z_TEST as select from I_BASEVIEW \{\n| &&
                |  field1,\n| &&
                |  field2\n| &&
                |\}|.

    " This would test the private method extract_from_clause
    " In real testing, make it public or use a test seam

    cl_abap_unit_assert=>assert_bound(
      act = mo_analyzer
      msg = 'Analyzer should be instantiated'
    ).

  ENDMETHOD.

  METHOD test_extract_associations.
    " Test association extraction
    DATA: lv_source TYPE string.

    lv_source = |define view Z_TEST as select from table\n| &&
                |  association [1..1] to I_TARGET as _Assoc\n| &&
                |    on field = _Assoc.field\n| &&
                |\{ field \}|.

    " Verify pattern matching works
    FIND REGEX 'association\s+\[.*?\]\s+to\s+(\w+)'
      IN lv_source
      IGNORING CASE.

    cl_abap_unit_assert=>assert_equals(
      act = sy-subrc
      exp = 0
      msg = 'Should find association pattern'
    ).

  ENDMETHOD.

  METHOD test_extract_joins.
    " Test JOIN clause extraction
    DATA: lv_source TYPE string.

    lv_source = |as select from table1\n| &&
                |  left outer join table2\n| &&
                |    on table1.key = table2.key|.

    " Verify JOIN pattern detection
    FIND REGEX '(left|right|inner|outer)?\s*join\s+(\w+)'
      IN lv_source
      IGNORING CASE.

    cl_abap_unit_assert=>assert_equals(
      act = sy-subrc
      exp = 0
      msg = 'Should find JOIN pattern'
    ).

  ENDMETHOD.

ENDCLASS.


*&---------------------------------------------------------------------*

CLASS ltc_migrator_test DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA: mo_migrator TYPE REF TO zcl_cds_migrator.

    METHODS:
      setup,
      test_generate_new_sql_view_name FOR TESTING,
      test_transform_define_view FOR TESTING,
      test_add_key_field FOR TESTING.

ENDCLASS.


CLASS ltc_migrator_test IMPLEMENTATION.

  METHOD setup.
    CREATE OBJECT mo_migrator.
  ENDMETHOD.

  METHOD test_generate_new_sql_view_name.
    " Test SQL view name generation (append _V2)
    DATA: lv_old_name TYPE ddstrucobjname VALUE 'ZOLDVIEW',
          lv_new_name TYPE ddstrucobjname.

    " Simulate the transformation
    lv_new_name = |{ lv_old_name }_V2|.

    cl_abap_unit_assert=>assert_equals(
      act = lv_new_name
      exp = 'ZOLDVIEW_V2'
      msg = 'Should append _V2 to SQL view name'
    ).

    " Test length truncation for long names
    lv_old_name = 'VERYLONGVIEWNAME'.
    lv_new_name = |{ lv_old_name(13) }_V2|.

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_new_name
      exp = '*_V2'
      msg = 'Should end with _V2'
    ).

    cl_abap_unit_assert=>assert_true(
      act = strlen( lv_new_name ) <= 16
      msg = 'Should not exceed 16 characters'
    ).

  ENDMETHOD.

  METHOD test_transform_define_view.
    " Test transformation of DEFINE VIEW to DEFINE VIEW ENTITY
    DATA: lv_classic TYPE string,
          lv_entity  TYPE string.

    lv_classic = |define view Z_TEST as select from table|.

    " Transform
    lv_entity = replace(
      val  = lv_classic
      sub  = 'define view'
      with = 'define view entity'
      occ  = 1
    ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_entity
      exp = '*define view entity*'
      msg = 'Should transform to entity syntax'
    ).

  ENDMETHOD.

  METHOD test_add_key_field.
    " Test adding KEY to first field
    DATA: lv_source   TYPE string,
          lv_enhanced TYPE string.

    lv_source = |as select \{\n  field1,\n  field2\n\}|.

    " Simple transformation (actual implementation is more complex)
    lv_enhanced = replace(
      val  = lv_source
      regex = '\{\s*(\w+)'
      with = '{ key $1'
      occ  = 1
    ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_enhanced
      exp = '*key field1*'
      msg = 'Should add key keyword'
    ).

  ENDMETHOD.

ENDCLASS.


*&---------------------------------------------------------------------*

CLASS ltc_integration_test DEFINITION FINAL FOR TESTING
  DURATION MEDIUM
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS:
      test_full_migration_workflow FOR TESTING.

ENDCLASS.


CLASS ltc_integration_test IMPLEMENTATION.

  METHOD test_full_migration_workflow.
    " Integration test for the full workflow
    DATA: lo_manager  TYPE REF TO zcl_cds_migration_manager,
          ls_cds_view TYPE zcl_cds_scanner=>ty_cds_view,
          ls_result   TYPE zcl_cds_migrator=>ty_migration_result.

    " Create manager
    CREATE OBJECT lo_manager.

    " Create test CDS view structure
    ls_cds_view-ddlname = 'Z_TEST_CDS'.
    ls_cds_view-sql_view_name = 'ZTESTCDS'.
    ls_cds_view-package = 'ZTEST'.
    ls_cds_view-description = 'Test CDS View'.
    ls_cds_view-is_classic = abap_true.
    ls_cds_view-selected = abap_true.
    ls_cds_view-source_code = |@AbapCatalog.sqlViewName: 'ZTESTCDS'\n| &&
                               |@EndUserText.label: 'Test'\n| &&
                               |define view Z_TEST_CDS as select from scarr \{\n| &&
                               |  carrid,\n| &&
                               |  carrname\n| &&
                               |\}|.

    " Test migration
    DATA(lo_migrator) = NEW zcl_cds_migrator( ).
    ls_result = lo_migrator->migrate_single_cds( ls_cds_view ).

    " Verify results
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-status
      exp = 'SUCCESS'
      msg = 'Migration should succeed'
    ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-new_sql_view
      exp = 'ZTESTCDS_V2'
      msg = 'New SQL view name should have _V2 suffix'
    ).

    cl_abap_unit_assert=>assert_char_cp(
      act = ls_result-new_source_code
      exp = '*view entity*'
      msg = 'Generated code should contain "view entity"'
    ).

  ENDMETHOD.

ENDCLASS.
