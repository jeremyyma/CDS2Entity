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

    METHODS find_in_package
      IMPORTING iv_package        TYPE devclass
      RETURNING VALUE(rt_results) TYPE ty_cds_list.

    METHODS transform
      CHANGING cs_cds TYPE ty_cds.

  PRIVATE SECTION.
    METHODS read_source
      IMPORTING iv_name          TYPE ddlname
      RETURNING VALUE(rv_source) TYPE string.

    METHODS is_classic
      IMPORTING iv_source         TYPE string
      RETURNING VALUE(rv_classic) TYPE abap_bool.

    METHODS generate_entity_source
      IMPORTING iv_source        TYPE string
                iv_new_sql_view  TYPE ddstrucobjname
      RETURNING VALUE(rv_entity) TYPE string.

ENDCLASS.


CLASS zcl_cds_migrator IMPLEMENTATION.

  METHOD find_in_package.
    SELECT obj_name
      FROM tadir
      WHERE pgmid = 'R3TR'
        AND object = 'DDLS'
        AND devclass = @iv_package
      INTO TABLE @DATA(lt_ddls).

    LOOP AT lt_ddls ASSIGNING FIELD-SYMBOL(<ddl>).
      DATA(lv_source) = read_source( <ddl>-obj_name ).
      CHECK is_classic( lv_source ).

      APPEND VALUE #(
        name       = <ddl>-obj_name
        source     = lv_source
        is_classic = abap_true
      ) TO rt_results.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_source.
    DATA lo_ddl TYPE REF TO if_dd_ddl_handler.
    DATA lt_source TYPE string_table.

    TRY.
        lo_ddl = cl_dd_ddl_handler_factory=>create( )->read( CONV #( iv_name ) ).

        lt_source = lo_ddl->get_source( ).

        rv_source = concat_lines_of(
          table = lt_source
          sep   = cl_abap_char_utilities=>newline
        ).
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
    " Extract SQL view name
    FIND REGEX 'sqlViewName\s*:\s*''([^'']+)'''
      IN cs_cds-source
      SUBMATCHES cs_cds-sql_view
      IGNORING CASE.

    " Generate new names with _V2 suffix
    cs_cds-new_sql = |{ cs_cds-sql_view }_V2|.
    IF strlen( cs_cds-new_sql ) > 16.
      cs_cds-new_sql = |{ cs_cds-sql_view(13) }_V2|.
    ENDIF.

    cs_cds-new_name = |{ cs_cds-name }_V2|.

    " Generate entity source
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

ENDCLASS.
