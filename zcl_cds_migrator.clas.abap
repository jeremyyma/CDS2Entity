CLASS zcl_cds_migrator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_migration_result,
        ddlname           TYPE ddlname,
        old_sql_view      TYPE ddstrucobjname,
        new_ddl_name      TYPE ddlname,
        new_sql_view      TYPE ddstrucobjname,
        new_source_code   TYPE string,
        status            TYPE string, " 'SUCCESS', 'ERROR', 'SKIPPED'
        message           TYPE string,
      END OF ty_migration_result,
      tt_migration_results TYPE STANDARD TABLE OF ty_migration_result WITH DEFAULT KEY.

    METHODS:
      "! Migrate classic CDS to entity-based CDS
      "! @parameter is_cds_view | Classic CDS view to migrate
      "! @parameter rs_result | Migration result
      migrate_single_cds
        IMPORTING
          is_cds_view      TYPE zcl_cds_scanner=>ty_cds_view
        RETURNING
          VALUE(rs_result) TYPE ty_migration_result,

      "! Migrate multiple CDS views (respects dependencies)
      "! @parameter it_cds_views | List of CDS views to migrate
      "! @parameter rt_results | Migration results
      migrate_multiple_cds
        IMPORTING
          it_cds_views     TYPE zcl_cds_scanner=>tt_cds_views
        RETURNING
          VALUE(rt_results) TYPE tt_migration_results,

      "! Generate entity CDS source code
      "! @parameter is_cds_view | Classic CDS view
      "! @parameter rv_entity_source | Generated entity CDS source
      generate_entity_source
        IMPORTING
          is_cds_view            TYPE zcl_cds_scanner=>ty_cds_view
          iv_new_sql_view        TYPE ddstrucobjname OPTIONAL
        RETURNING
          VALUE(rv_entity_source) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS:
      transform_annotations
        IMPORTING
          iv_classic_source    TYPE string
        RETURNING
          VALUE(rv_entity_annotations) TYPE string,

      transform_select_list
        IMPORTING
          iv_classic_source    TYPE string
        RETURNING
          VALUE(rv_entity_select) TYPE string,

      generate_new_sql_view_name
        IMPORTING
          iv_old_sql_view      TYPE ddstrucobjname
        RETURNING
          VALUE(rv_new_name)   TYPE ddstrucobjname,

      add_required_entity_annotations
        IMPORTING
          iv_source            TYPE string
        RETURNING
          VALUE(rv_enhanced)   TYPE string.

ENDCLASS.



CLASS zcl_cds_migrator IMPLEMENTATION.

  METHOD migrate_single_cds.
    DATA: lv_new_source TYPE string,
          lv_new_sql_view TYPE ddstrucobjname.

    CLEAR rs_result.

    " Set source info
    rs_result-ddlname = is_cds_view-ddlname.
    rs_result-old_sql_view = is_cds_view-sql_view_name.

    TRY.
        " Generate new SQL view name (append _V2)
        lv_new_sql_view = generate_new_sql_view_name( is_cds_view-sql_view_name ).
        rs_result-new_sql_view = lv_new_sql_view.

        " Generate new DDL name (could keep same or append suffix)
        rs_result-new_ddl_name = |{ is_cds_view-ddlname }_ENTITY|.

        " Generate entity-based source code
        lv_new_source = generate_entity_source(
          is_cds_view     = is_cds_view
          iv_new_sql_view = lv_new_sql_view
        ).

        IF lv_new_source IS INITIAL.
          rs_result-status = 'ERROR'.
          rs_result-message = 'Failed to generate entity source code'.
          RETURN.
        ENDIF.

        rs_result-new_source_code = lv_new_source.
        rs_result-status = 'SUCCESS'.
        rs_result-message = |Successfully generated entity CDS: { rs_result-new_ddl_name }|.

      CATCH cx_root INTO DATA(lx_error).
        rs_result-status = 'ERROR'.
        rs_result-message = lx_error->get_text( ).
    ENDTRY.

  ENDMETHOD.


  METHOD migrate_multiple_cds.
    DATA: lt_ordered TYPE STANDARD TABLE OF ddlname,
          ls_result  TYPE ty_migration_result.

    CLEAR rt_results.

    " Analyze dependencies and determine migration order
    DATA(lo_analyzer) = NEW zcl_cds_dependency_analyzer( ).
    lt_ordered = lo_analyzer->analyze_migration_order( it_cds_views ).

    " Migrate in dependency order
    LOOP AT lt_ordered INTO DATA(lv_ddlname).
      READ TABLE it_cds_views INTO DATA(ls_cds) WITH KEY ddlname = lv_ddlname.
      IF sy-subrc = 0 AND ls_cds-selected = abap_true.
        ls_result = migrate_single_cds( ls_cds ).
        APPEND ls_result TO rt_results.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD generate_entity_source.
    DATA: lv_source       TYPE string,
          lv_annotations  TYPE string,
          lv_view_def     TYPE string,
          lv_select_list  TYPE string.

    CLEAR rv_entity_source.

    IF is_cds_view-source_code IS INITIAL.
      RETURN.
    ENDIF.

    lv_source = is_cds_view-source_code.

    " Determine new SQL view name
    DATA(lv_new_sql_view) = iv_new_sql_view.
    IF lv_new_sql_view IS INITIAL.
      lv_new_sql_view = generate_new_sql_view_name( is_cds_view-sql_view_name ).
    ENDIF.

    " Transform annotations from classic to entity format
    lv_annotations = transform_annotations( lv_source ).

    " Add required entity annotations
    lv_annotations = add_required_entity_annotations( lv_annotations ).

    " Update SQL view name annotation
    lv_annotations = replace(
      val  = lv_annotations
      regex = '@AbapCatalog\.sqlViewName\s*:\s*''[^'']+'''
      with = |@AbapCatalog.sqlViewName: '{ lv_new_sql_view }'|
      occ  = 0
    ).

    " Transform DEFINE VIEW to DEFINE VIEW ENTITY
    IF lv_source CS 'DEFINE ROOT VIEW'.
      lv_view_def = replace(
        val  = lv_source
        sub  = 'DEFINE ROOT VIEW'
        with = 'DEFINE ROOT VIEW ENTITY'
        occ  = 1
      ).
    ELSEIF lv_source CS 'DEFINE VIEW'.
      lv_view_def = replace(
        val  = lv_source
        sub  = 'DEFINE VIEW'
        with = 'DEFINE VIEW ENTITY'
        occ  = 1
      ).
    ELSE.
      lv_view_def = lv_source.
    ENDIF.

    " Transform SELECT list (entity syntax differences)
    lv_select_list = transform_select_list( lv_view_def ).

    " Combine all parts
    rv_entity_source = lv_select_list.

    " Final cleanup
    rv_entity_source = replace(
      val  = rv_entity_source
      sub  = is_cds_view-sql_view_name
      with = lv_new_sql_view
      occ  = 0
    ).

  ENDMETHOD.


  METHOD transform_annotations.
    DATA: lv_result TYPE string.

    lv_result = iv_classic_source.

    " Keep most annotations, but update specific ones for entity syntax
    " AbapCatalog.sqlViewName becomes less critical in entity views
    " but we'll keep it for compatibility

    " Add or update @AccessControl.authorizationCheck if missing
    IF NOT ( lv_result CS '@AccessControl.authorizationCheck' ).
      " Find position after last annotation
      FIND REGEX '@AbapCatalog' IN lv_result.
      IF sy-subrc = 0.
        lv_result = |@AccessControl.authorizationCheck: #NOT_REQUIRED\n{ lv_result }|.
      ENDIF.
    ENDIF.

    " Add @Metadata.ignorePropagatedAnnotations for clean entity views
    IF NOT ( lv_result CS '@Metadata.ignorePropagatedAnnotations' ).
      lv_result = |@Metadata.ignorePropagatedAnnotations: true\n{ lv_result }|.
    ENDIF.

    rv_entity_annotations = lv_result.

  ENDMETHOD.


  METHOD transform_select_list.
    DATA: lv_result TYPE string.

    lv_result = iv_classic_source.

    " Entity views require explicit key fields
    " If no key is defined, mark first field as key
    IF NOT ( lv_result CS 'key ' OR lv_result CS 'KEY ' ).
      " Find first field in select list
      FIND REGEX 'as\s+select[^{]*\{' IN lv_result IGNORING CASE.
      IF sy-subrc = 0.
        DATA(lv_pos) = sy-fdpos + sy-flen.
        " Find first field (skip whitespace)
        FIND REGEX '\s*(\w+)' IN lv_result+lv_pos.
        IF sy-subrc = 0.
          " Insert 'key' before first field
          lv_result = |{ lv_result(lv_pos) } key { lv_result+lv_pos }|.
        ENDIF.
      ENDIF.
    ENDIF.

    " Entity views use different association syntax
    " Classic: association [...] to <target> as <alias> on ...
    " Entity: association [...] to <target> as <alias> on ...
    " (Actually the same, but ensure proper formatting)

    rv_entity_select = lv_result.

  ENDMETHOD.


  METHOD generate_new_sql_view_name.
    " Append _V2 to the SQL view name
    IF iv_old_sql_view IS NOT INITIAL.
      rv_new_name = |{ iv_old_sql_view }_V2|.

      " Ensure it doesn't exceed max length (16 characters for DDSTRUCOBJNAME)
      IF strlen( rv_new_name ) > 16.
        " Truncate original name and append _V2
        rv_new_name = |{ iv_old_sql_view(13) }_V2|.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD add_required_entity_annotations.
    DATA: lv_result TYPE string.

    lv_result = iv_source.

    " Add @EndUserText.label if missing
    IF NOT ( lv_result CS '@EndUserText.label' ).
      lv_result = |@EndUserText.label: 'Entity View'\n{ lv_result }|.
    ENDIF.

    " Add @AbapCatalog.viewEnhancementCategory for extensibility
    IF NOT ( lv_result CS '@AbapCatalog.viewEnhancementCategory' ).
      lv_result = |@AbapCatalog.viewEnhancementCategory: [#NONE]\n{ lv_result }|.
    ENDIF.

    rv_enhanced = lv_result.

  ENDMETHOD.

ENDCLASS.
