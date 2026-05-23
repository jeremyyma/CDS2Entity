CLASS zcl_cds_scanner DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_cds_view,
        ddlname         TYPE ddlname,
        sql_view_name   TYPE ddstrucobjname,
        package         TYPE devclass,
        description     TYPE ddtext,
        is_classic      TYPE abap_bool,
        entity_category TYPE string,
        source_code     TYPE string,
        dependencies    TYPE TABLE OF ddlname WITH DEFAULT KEY,
        selected        TYPE abap_bool,
      END OF ty_cds_view,
      tt_cds_views TYPE STANDARD TABLE OF ty_cds_view WITH DEFAULT KEY.

    METHODS:
      "! Scan package for CDS views
      "! @parameter iv_package | Package name to scan
      "! @parameter iv_include_subpackages | Include sub-packages
      "! @parameter rt_cds_views | Table of found CDS views
      scan_package
        IMPORTING
          iv_package             TYPE devclass
          iv_include_subpackages TYPE abap_bool DEFAULT abap_true
        RETURNING
          VALUE(rt_cds_views)    TYPE tt_cds_views
        RAISING
          cx_static_check,

      "! Check if CDS is classic (non-entity based)
      "! @parameter iv_ddlname | CDS view name
      "! @parameter rv_is_classic | True if classic CDS
      is_classic_cds
        IMPORTING
          iv_ddlname           TYPE ddlname
        RETURNING
          VALUE(rv_is_classic) TYPE abap_bool,

      "! Get CDS source code
      "! @parameter iv_ddlname | CDS view name
      "! @parameter rv_source | CDS source code
      get_cds_source
        IMPORTING
          iv_ddlname       TYPE ddlname
        RETURNING
          VALUE(rv_source) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS:
      get_subpackages
        IMPORTING
          iv_package            TYPE devclass
        RETURNING
          VALUE(rt_subpackages) TYPE STANDARD TABLE OF devclass,

      read_cds_metadata
        IMPORTING
          iv_ddlname        TYPE ddlname
        RETURNING
          VALUE(rs_cds_view) TYPE ty_cds_view.

ENDCLASS.



CLASS zcl_cds_scanner IMPLEMENTATION.

  METHOD scan_package.
    DATA: lt_packages TYPE STANDARD TABLE OF devclass,
          lt_ddls     TYPE STANDARD TABLE OF ddddlsrc,
          ls_cds_view TYPE ty_cds_view.

    CLEAR rt_cds_views.

    " Build package list
    APPEND iv_package TO lt_packages.
    IF iv_include_subpackages = abap_true.
      APPEND LINES OF get_subpackages( iv_package ) TO lt_packages.
    ENDIF.

    " Find all CDS views in packages
    SELECT ddlname, strucobjn AS sql_view_name, as4local, devclass
      FROM dd02l
      WHERE devclass IN @lt_packages
        AND sqltab NE @space
        AND as4local = 'A'
        AND tabclass = 'VIEW'
      INTO TABLE @DATA(lt_views).

    IF sy-subrc <> 0.
      " No views found - try alternative query
      SELECT ddlname, devclass
        FROM tadir
        WHERE pgmid = 'R3TR'
          AND object = 'DDLS'
          AND devclass IN @lt_packages
        INTO TABLE @DATA(lt_ddls_objects).

      LOOP AT lt_ddls_objects INTO DATA(ls_ddls_obj).
        ls_cds_view = read_cds_metadata( ls_ddls_obj-ddlname ).
        IF ls_cds_view-ddlname IS NOT INITIAL.
          " Only include classic CDS views
          IF is_classic_cds( ls_cds_view-ddlname ) = abap_true.
            ls_cds_view-is_classic = abap_true.
            ls_cds_view-selected = abap_false.
            APPEND ls_cds_view TO rt_cds_views.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ELSE.
      " Process views found
      LOOP AT lt_views INTO DATA(ls_view).
        ls_cds_view = read_cds_metadata( ls_view-ddlname ).
        IF ls_cds_view-ddlname IS NOT INITIAL.
          IF is_classic_cds( ls_cds_view-ddlname ) = abap_true.
            ls_cds_view-is_classic = abap_true.
            ls_cds_view-selected = abap_false.
            APPEND ls_cds_view TO rt_cds_views.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.


  METHOD is_classic_cds.
    DATA: lv_source TYPE string.

    rv_is_classic = abap_false.

    " Get CDS source code
    lv_source = get_cds_source( iv_ddlname ).

    IF lv_source IS INITIAL.
      RETURN.
    ENDIF.

    " Convert to uppercase for comparison
    TRANSLATE lv_source TO UPPER CASE.

    " Classic CDS characteristics:
    " 1. Does NOT have @AccessControl.authorizationCheck
    " 2. Does NOT have entity annotation
    " 3. Has sqlViewName annotation
    " 4. Uses DEFINE VIEW instead of DEFINE ROOT VIEW or DEFINE VIEW ENTITY

    IF lv_source CS 'SQLVIEWNAME' OR lv_source CS 'SQL_VIEW_NAME'.
      " Has sqlViewName - likely classic

      " Check if it's NOT an entity view
      IF NOT ( lv_source CS 'DEFINE VIEW ENTITY' OR
               lv_source CS 'DEFINE ROOT VIEW ENTITY' OR
               lv_source CS '@OBJECTMODEL.DATACATEGORY' ).
        rv_is_classic = abap_true.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD get_cds_source.
    DATA: lt_source TYPE STANDARD TABLE OF string.

    CLEAR rv_source.

    " Try to read CDS source using CL_DD_DDL_HANDLER_FACTORY
    TRY.
        DATA(lo_handler) = cl_dd_ddl_handler_factory=>create( ).
        DATA(lo_ddl) = lo_handler->read( CONV #( iv_ddlname ) ).

        IF lo_ddl IS BOUND.
          lt_source = lo_ddl->get_source( ).
          LOOP AT lt_source INTO DATA(lv_line).
            rv_source = |{ rv_source }{ lv_line }\n|.
          ENDLOOP.
        ENDIF.

      CATCH cx_root INTO DATA(lx_error).
        " Fallback: Try reading from repository
        TRY.
            SELECT SINGLE source FROM ddddlsrc02bt
              WHERE ddlname = @iv_ddlname
              INTO @rv_source.
          CATCH cx_root.
            CLEAR rv_source.
        ENDTRY.
    ENDTRY.

  ENDMETHOD.


  METHOD get_subpackages.
    DATA: lt_tdevc TYPE STANDARD TABLE OF tdevc.

    CLEAR rt_subpackages.

    " Get all subpackages recursively
    SELECT devclass, parentcl
      FROM tdevc
      WHERE parentcl = @iv_package
      INTO TABLE @DATA(lt_children).

    LOOP AT lt_children INTO DATA(ls_child).
      APPEND ls_child-devclass TO rt_subpackages.
      " Recursive call for nested packages
      APPEND LINES OF get_subpackages( ls_child-devclass ) TO rt_subpackages.
    ENDLOOP.

  ENDMETHOD.


  METHOD read_cds_metadata.
    DATA: lv_source TYPE string.

    CLEAR rs_cds_view.

    " Read basic metadata
    SELECT SINGLE ddlname, strucobjn, devclass, ddtext
      FROM dd02l
      WHERE ddlname = @iv_ddlname
        AND as4local = 'A'
      INTO @DATA(ls_dd02l).

    IF sy-subrc = 0.
      rs_cds_view-ddlname = ls_dd02l-ddlname.
      rs_cds_view-sql_view_name = ls_dd02l-strucobjn.
      rs_cds_view-package = ls_dd02l-devclass.
      rs_cds_view-description = ls_dd02l-ddtext.
    ELSE.
      " Try alternative approach
      SELECT SINGLE obj_name AS ddlname, devclass
        FROM tadir
        WHERE pgmid = 'R3TR'
          AND object = 'DDLS'
          AND obj_name = @iv_ddlname
        INTO @DATA(ls_tadir).

      IF sy-subrc = 0.
        rs_cds_view-ddlname = ls_tadir-ddlname.
        rs_cds_view-package = ls_tadir-devclass.
      ENDIF.
    ENDIF.

    " Get source code
    rs_cds_view-source_code = get_cds_source( iv_ddlname ).

    " Extract SQL view name from source if not found
    IF rs_cds_view-sql_view_name IS INITIAL AND rs_cds_view-source_code IS NOT INITIAL.
      FIND REGEX '@AbapCatalog\.sqlViewName\s*:\s*''(\w+)''' IN rs_cds_view-source_code
        SUBMATCHES rs_cds_view-sql_view_name IGNORING CASE.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
