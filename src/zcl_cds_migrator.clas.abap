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

protected section.
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

CLASS ZCL_CDS_MIGRATOR IMPLEMENTATION.


  METHOD find_in_package.
    " Find CDS views with sqlViewName annotation in specified package
    " DDHEADANNO structure: DDLNAME (object name), NAME (annotation name), VALUE
    SELECT ddheadanno~STRUCOBJN as name,
           ddheadanno~value
      FROM ddheadanno
      INNER JOIN tadir
        ON tadir~obj_name = ddheadanno~STRUCOBJN
      WHERE ddheadanno~name = 'ABAPCATALOG.SQLVIEWNAME'
"        AND tadir~pgmid = 'R3TR'
        AND tadir~object = 'DDLS'
        AND tadir~devclass = @iv_package
      INTO TABLE @DATA(lt_classic_cds).

    LOOP AT lt_classic_cds ASSIGNING FIELD-SYMBOL(<cds>).
      " Convert to correct type (C 240 -> C 40)
      DATA(lv_ddlname) = CONV ddlname( <cds>-name ).
      DATA(lv_source) = read_source( lv_ddlname ).

      " Keep candidate even if source cannot be read; this avoids silently
      " dropping valid DDLS hits from DDHEADANNO.

      " Extract SQL view name from annotation value (format: 'VIEWNAME')
      DATA(lv_sql_view) = <cds>-value.
      REPLACE ALL OCCURRENCES OF '''' IN lv_sql_view WITH ''.

      APPEND VALUE #(
        name       = lv_ddlname
        sql_view   = lv_sql_view
        source     = lv_source
        is_classic = COND #( WHEN lv_source IS INITIAL
                             THEN abap_true
                             ELSE is_classic( lv_source ) )
      ) TO rt_results.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_source.
    DATA: lt_source_tab TYPE STANDARD TABLE OF string WITH EMPTY KEY,
          lo_handler    TYPE REF TO object,
          lx_root       TYPE REF TO cx_root.

    CLEAR rv_source.

    " 1) Primary source read from DDDDLSRC (active then inactive)
    SELECT SINGLE source
      FROM ddddlsrc
      WHERE ddlname  = @iv_name
        AND as4local = 'A'
      INTO @rv_source.

    IF rv_source IS NOT INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE source
      FROM ddddlsrc
      WHERE ddlname  = @iv_name
        AND as4local = 'I'
      INTO @rv_source.

    IF rv_source IS NOT INITIAL.
      RETURN.
    ENDIF.

    " 2) Fallback to official OO DDLS handler API
    TRY.
        CALL METHOD ('CL_DD_DDL_HANDLER_FACTORY')=>('CREATE')
          RECEIVING
            ro_handler = lo_handler.

        IF lo_handler IS BOUND.
          TRY.
              CALL METHOD lo_handler->('READ_SOURCE')
                EXPORTING
                  name   = iv_name
                RECEIVING
                  source = rv_source.
            CATCH cx_sy_dyn_call_error.
              CLEAR lt_source_tab.
              CALL METHOD lo_handler->('READ_SOURCE')
                EXPORTING
                  name      = iv_name
                RECEIVING
                  rt_source = lt_source_tab.

              IF lt_source_tab IS NOT INITIAL.
                rv_source = concat_lines_of(
                  table = lt_source_tab
                  sep   = cl_abap_char_utilities=>newline
                ).
              ENDIF.
          ENDTRY.
        ENDIF.

      CATCH cx_root INTO lx_root.
        MESSAGE |Could not read CDS source for { iv_name } via DDDDLSRC and DDLS handler API: { lx_root->get_text( ) }| TYPE 'I'.
        CLEAR rv_source.
    ENDTRY.

    IF rv_source IS INITIAL.
      MESSAGE |Could not read CDS source for { iv_name } via DDDDLSRC and DDLS handler API.| TYPE 'I'.
    ENDIF.
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
    rv_success = abap_false.

    IF is_cds-new_name IS INITIAL OR is_cds-new_source IS INITIAL.
      RETURN.
    ENDIF.

    DATA: lv_name    TYPE ddlname,
          lt_source  TYPE STANDARD TABLE OF string WITH EMPTY KEY,
          lt_names   TYPE STANDARD TABLE OF ddlname WITH EMPTY KEY,
          lo_handler TYPE REF TO object,
          lx_error   TYPE REF TO cx_root.

    lv_name = is_cds-new_name.

    TRY.
        SPLIT is_cds-new_source AT cl_abap_char_utilities=>newline INTO TABLE lt_source.
        APPEND lv_name TO lt_names.

        " Official path: factory CREATE -> WRITE_SOURCE -> ACTIVATE
        lo_handler = cl_dd_ddl_handler_factory=>create( ).

        IF lo_handler IS NOT BOUND.
          MESSAGE |DDLS handler factory CREATE() did not return a handler for { lv_name }.| TYPE 'I'.
          RETURN.
        ENDIF.

        TRY.
            CALL METHOD lo_handler->('WRITE_SOURCE')
              EXPORTING
                name   = lv_name
                source = lt_source.
          CATCH cx_sy_dyn_call_error.
            TRY.
                CALL METHOD lo_handler->('WRITE')
                  EXPORTING
                    name   = lv_name
                    source = lt_source.
              CATCH cx_sy_dyn_call_error.
                CALL METHOD lo_handler->('SAVE')
                  EXPORTING
                    iv_ddlname = lv_name
                    it_source  = lt_source.
            ENDTRY.
        ENDTRY.

        TRY.
            CALL METHOD lo_handler->('ACTIVATE')
              EXPORTING
                names = lt_names.
          CATCH cx_sy_dyn_call_error.
            CALL METHOD lo_handler->('ACTIVATE')
              EXPORTING
                name = lv_name.
        ENDTRY.

        rv_success = abap_true.

      CATCH cx_root INTO lx_error.
        MESSAGE lx_error->get_text( ) TYPE 'I'.
        rv_success = abap_false.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.