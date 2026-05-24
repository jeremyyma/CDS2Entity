CLASS ltc_cds_migrator DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_cds_migrator.

    METHODS setup.
    METHODS test_is_classic_cds FOR TESTING.
    METHODS test_transform FOR TESTING.

ENDCLASS.


CLASS ltc_cds_migrator IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
  ENDMETHOD.


  METHOD test_is_classic_cds.
    " Classic CDS source
    DATA(lv_classic) = |@AbapCatalog.sqlViewName: 'ZTEST'\ndefine view Z_TEST as select from table \{ field \}|.

    " Entity CDS source
    DATA(lv_entity) = |define view entity Z_TEST as select from table \{ key field \}|.

    " Test
    cl_abap_unit_assert=>assert_true(
      act = mo_cut->is_classic( lv_classic )
      msg = 'Should detect classic CDS'
    ).

    cl_abap_unit_assert=>assert_false(
      act = mo_cut->is_classic( lv_entity )
      msg = 'Should not detect entity CDS as classic'
    ).
  ENDMETHOD.


  METHOD test_transform.
    " Given - Classic CDS with deprecated annotations
    DATA(ls_cds) = VALUE zcl_cds_migrator=>ty_cds(
      name   = 'Z_TEST'
      source = |@AbapCatalog.sqlViewName: 'ZTEST'\n| &&
               |@AbapCatalog.preserveKey: true\n| &&
               |@AbapCatalog.compiler.compareFilter: true\n| &&
               |define view Z_TEST as select from table \{ field \}|
    ).

    " When
    mo_cut->transform( CHANGING cs_cds = ls_cds ).

    " Then - Basic transformation
    cl_abap_unit_assert=>assert_equals(
      act = ls_cds-new_sql
      exp = 'ZTEST_V2'
      msg = 'Should extract and append _V2 to SQL view name'
    ).

    cl_abap_unit_assert=>assert_char_cp(
      act = ls_cds-new_source
      exp = '*VIEW ENTITY*'
      msg = 'Should contain VIEW ENTITY'
    ).

    cl_abap_unit_assert=>assert_char_cp(
      act = ls_cds-new_source
      exp = '*key field*'
      msg = 'Should add key to first field'
    ).

    " Then - Deprecated annotations removed
    DATA(lv_lower) = to_lower( ls_cds-new_source ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( NOT lv_lower CS 'sqlviewname' )
      msg = 'Should remove deprecated sqlViewName annotation'
    ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( NOT lv_lower CS 'preservekey' )
      msg = 'Should remove deprecated preserveKey annotation'
    ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( NOT lv_lower CS 'comparefilter' )
      msg = 'Should remove deprecated compareFilter annotation'
    ).

    " Then - Required annotations added
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( lv_lower CS '@endusertext.label' )
      msg = 'Should add @EndUserText.label annotation'
    ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( lv_lower CS '@accesscontrol' )
      msg = 'Should add @AccessControl annotation'
    ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( lv_lower CS '@metadata.ignorepropagatedannotations' )
      msg = 'Should add @Metadata.ignorePropagatedAnnotations'
    ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( lv_lower CS '@metadata.allowextensions' )
      msg = 'Should add @Metadata.allowExtensions'
    ).
  ENDMETHOD.
  ENDMETHOD.

ENDCLASS.
