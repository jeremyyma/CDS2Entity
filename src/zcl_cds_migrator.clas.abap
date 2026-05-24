CLASS zcl_cds_migrator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_cds,
        name        TYPE ddlname,
        sql_view    TYPE ddstrucobjname,
        source      TYPE string,
        new_name    TYPE ddlname,
        new_sql     TYPE ddstrucobjname,
        new_source  TYPE string,
        is_classic  TYPE abap_bool,
      END OF ty_cds,
      ty_cds_list TYPE STANDARD TABLE OF ty_cds WITH KEY name.

    " Find classic CDS views in package using DDHEADANNO
    METHODS find_in_package
      IMPORTING iv_package        TYPE devclass
      RETURNING VALUE(rt_results) TYPE ty_cds_list.

    " Transform classic CDS to entity CDS with modern annotations
    METHODS transform
      CHANGING cs_cds TYPE ty_cds.

    " Create new entity CDS view in system
    METHODS create_entity
      IMPORTING is_cds           TYPE ty_cds
      RETURNING VALUE(rv_success) TYPE abap_bool.

  PRIVATE SECTION.
    " Read CDS source code from database tables
    METHODS read_source
      IMPORTING iv_name          TYPE ddlname
      RETURNING VALUE(rv_source) TYPE string.

    " Check if CDS has sqlViewName annotation (classic CDS indicator)
    METHODS is_classic
      IMPORTING iv_source         TYPE string
      RETURNING VALUE(rv_classic) TYPE abap_bool.

    " Generate entity CDS source with all modern annotations
    METHODS generate_entity_source
      IMPORTING iv_source        TYPE string
                iv_new_sql_view  TYPE ddstrucobjname
      RETURNING VALUE(rv_entity) TYPE string.

ENDCLASS.


CLASS zcl_cds_migrator IMPLEMENTATION.

  METHOD find_in_package.
    " Find CDS views with sqlViewName annotation in specified package
    SELECT ddheadanno~ddlname,
           ddheadanno~value
      FROM ddheadanno
      INNER JOIN tadir
        ON tadir~obj_name = ddheadanno~ddlname
      WHERE ddheadanno~name = 'ABAPCATALOG.SQLVIEWNAME'
        AND tadir~pgmid = 'R3TR'
        AND tadir~object = 'DDLS'
        AND tadir~devclass = @iv_package
      INTO TABLE @DATA(lt_classic_cds).

    LOOP AT lt_classic_cds ASSIGNING FIELD-SYMBOL(<cds>).
      DATA(lv_source) = read_source( <cds>-ddlname ).
      CHECK lv_source IS NOT INITIAL.

      " Extract SQL view name from annotation value (format: 'VIEWNAME')
      DATA(lv_sql_view) = <cds>-value.
      REPLACE ALL OCCURRENCES OF '''' IN lv_sql_view WITH ''.

      APPEND VALUE #(
        name       = <cds>-ddlname
        sql_view   = lv_sql_view
        source     = lv_source
        is_classic = abap_true
      ) TO rt_results.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_source.
    TRY.
        " Read CDS source from repository
        DATA lt_source_tab TYPE TABLE OF string.

        " Use READ REPORT to get source (works for DDLS objects)
        READ REPORT iv_name INTO lt_source_tab.

        IF sy-subrc = 0 AND lt_source_tab IS NOT INITIAL.
          " Convert table to single string
          rv_source = concat_lines_of(
            table = lt_source_tab
            sep   = cl_abap_char_utilities=>newline
          ).
        ELSE.
          " Fallback: Try using CL_DDL_TOOLS if available
          TRY.
              CALL METHOD ('CL_DDL_TOOLS')=>('READ_DDL_SOURCE')
                EXPORTING
                  iv_ddlname = iv_name
                RECEIVING
                  rv_source  = rv_source.
            CATCH cx_sy_dyn_call_error.
              " Method not available, return empty
              CLEAR rv_source.
          ENDTRY.
        ENDIF.

      CATCH cx_root.
        CLEAR rv_source.
    ENDTRY.
  ENDMETHOD.


  METHOD is_classic.
    rv_classic = xsdbool(
      iv_source CS 'sqlViewName' AND
      NOT iv_source CS 'VIEW ENTITY'
    ).
  ENDMETHOD.


  METHOD transform.
    " Generate new CDS name with _V2 suffix
    cs_cds-new_name = |{ cs_cds-name }_V2|.

    " Generate new SQL view name with _V2 suffix (max 16 chars)
    cs_cds-new_sql = |{ cs_cds-sql_view }_V2|.
    IF strlen( cs_cds-new_sql ) > 16.
      cs_cds-new_sql = |{ cs_cds-sql_view(13) }_V2|.
    ENDIF.

    " Generate modernized entity source
    cs_cds-new_source = generate_entity_source(
      iv_source       = cs_cds-source
      iv_new_sql_view = cs_cds-new_sql
    ).
  ENDMETHOD.


  METHOD generate_entity_source.
    DATA(lv_result) = iv_source.
    DATA(lv_label) = ''.

    " Step 1: Transform DEFINE VIEW → DEFINE VIEW ENTITY
    lv_result = replace( val  = lv_result
                         sub  = 'DEFINE VIEW '
                         with = 'DEFINE VIEW ENTITY '
                         occ  = 1 ).

    " Step 2: Remove deprecated annotations (not supported in entity views)
    " Remove @AbapCatalog.sqlViewName
    lv_result = replace( val   = lv_result
                         regex = '@AbapCatalog\.sqlViewName\s*:\s*''[^'']+''[\s\n]*'
                         with  = ''
                         occ   = 0 ).

    " Remove @AbapCatalog.preserveKey
    lv_result = replace( val   = lv_result
                         regex = '@AbapCatalog\.preserveKey\s*:\s*(true|false)[\s\n]*'
                         with  = ''
                         occ   = 0 ).

    " Remove @AbapCatalog.compiler.compareFilter
    lv_result = replace( val   = lv_result
                         regex = '@AbapCatalog\.compiler\.compareFilter\s*:\s*(true|false)[\s\n]*'
                         with  = ''
                         occ   = 0 ).

    " Step 3: Extract existing @EndUserText.label if present
    FIND REGEX '@EndUserText\.label\s*:\s*''([^'']+)''' IN lv_result
      SUBMATCHES lv_label IGNORING CASE.

    " Step 4: Add required annotations if missing
    " Add @EndUserText.label (required for entity views)
    IF NOT lv_result CS '@EndUserText.label'.
      IF lv_label IS INITIAL.
        lv_label = 'CDS Entity View'. " Default label
      ENDIF.
      lv_result = |@EndUserText.label: '{ lv_label }'\n{ lv_result }|.
    ENDIF.

    " Add @AccessControl.authorizationCheck (required)
    IF NOT lv_result CS '@AccessControl'.
      lv_result = |@AccessControl.authorizationCheck: #NOT_REQUIRED\n{ lv_result }|.
    ENDIF.

    " Add @Metadata.ignorePropagatedAnnotations (best practice)
    IF NOT lv_result CS '@Metadata.ignorePropagatedAnnotations'.
      lv_result = |@Metadata.ignorePropagatedAnnotations: true\n{ lv_result }|.
    ENDIF.

    " Add @Metadata.allowExtensions (enable CDS extension)
    IF NOT lv_result CS '@Metadata.allowExtensions'.
      lv_result = |@Metadata.allowExtensions: true\n{ lv_result }|.
    ENDIF.

    " Step 5: Add KEY to first field if no KEY exists (required in entity views)
    IF NOT lv_result CS 'key ' AND NOT lv_result CS 'KEY '.
      lv_result = replace( val   = lv_result
                           regex = '(\{\s*)(\w+)'
                           with  = '$1key $2'
                           occ   = 1 ).
    ENDIF.

    rv_entity = lv_result.
  ENDMETHOD.


  METHOD create_entity.
    " Create new CDS entity view using BAPI or direct insert
    " Note: Actual implementation requires CDS API or manual creation
    " This method prepares the source for creation
    rv_success = abap_false.

    TRY.
        " TODO: Implement actual CDS creation using appropriate API
        " For now, return false to indicate manual creation needed
        " In real scenario, use cl_dd_ddl_handler_factory or similar API

        " Placeholder for future implementation
        MESSAGE 'Entity creation requires manual activation in SE24/SE80' TYPE 'I'.

      CATCH cx_root INTO DATA(lx_error).
        MESSAGE lx_error->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
