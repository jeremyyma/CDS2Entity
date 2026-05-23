CLASS zcl_cds_dependency_analyzer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_dependency,
        source_ddl      TYPE ddlname,
        target_ddl      TYPE ddlname,
        dependency_type TYPE string, " 'ASSOCIATION', 'FROM', 'JOIN', 'UNION'
        target_field    TYPE string,
      END OF ty_dependency,
      tt_dependencies TYPE STANDARD TABLE OF ty_dependency WITH DEFAULT KEY.

    METHODS:
      "! Extract dependencies from CDS view
      "! @parameter iv_ddlname | CDS view name
      "! @parameter rt_dependencies | List of dependencies
      extract_dependencies
        IMPORTING
          iv_ddlname              TYPE ddlname
          iv_source               TYPE string OPTIONAL
        RETURNING
          VALUE(rt_dependencies)  TYPE tt_dependencies,

      "! Get all dependent CDS views (recursive)
      "! @parameter iv_ddlname | CDS view name
      "! @parameter rt_dependent_views | List of dependent CDS view names
      get_dependent_views
        IMPORTING
          iv_ddlname                 TYPE ddlname
        RETURNING
          VALUE(rt_dependent_views)  TYPE STANDARD TABLE OF ddlname,

      "! Analyze dependency graph for migration order
      "! @parameter it_cds_views | List of CDS views to analyze
      "! @parameter rt_migration_order | Ordered list (dependencies first)
      analyze_migration_order
        IMPORTING
          it_cds_views               TYPE zcl_cds_scanner=>tt_cds_views
        RETURNING
          VALUE(rt_migration_order)  TYPE STANDARD TABLE OF ddlname.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA: mt_dependency_cache TYPE tt_dependencies.

    METHODS:
      parse_cds_source
        IMPORTING
          iv_ddlname              TYPE ddlname
          iv_source               TYPE string
        RETURNING
          VALUE(rt_dependencies)  TYPE tt_dependencies,

      extract_from_clause
        IMPORTING
          iv_source               TYPE string
        RETURNING
          VALUE(rt_dependencies)  TYPE tt_dependencies,

      extract_associations
        IMPORTING
          iv_source               TYPE string
        RETURNING
          VALUE(rt_dependencies)  TYPE tt_dependencies,

      extract_joins
        IMPORTING
          iv_source               TYPE string
        RETURNING
          VALUE(rt_dependencies)  TYPE tt_dependencies.

ENDCLASS.



CLASS zcl_cds_dependency_analyzer IMPLEMENTATION.

  METHOD extract_dependencies.
    DATA: lv_source TYPE string,
          ls_dep    TYPE ty_dependency.

    CLEAR rt_dependencies.

    " Use provided source or fetch it
    IF iv_source IS NOT INITIAL.
      lv_source = iv_source.
    ELSE.
      DATA(lo_scanner) = NEW zcl_cds_scanner( ).
      lv_source = lo_scanner->get_cds_source( iv_ddlname ).
    ENDIF.

    IF lv_source IS INITIAL.
      RETURN.
    ENDIF.

    " Parse source code to extract dependencies
    rt_dependencies = parse_cds_source(
      iv_ddlname = iv_ddlname
      iv_source  = lv_source
    ).

  ENDMETHOD.


  METHOD parse_cds_source.
    DATA: lt_from_deps  TYPE tt_dependencies,
          lt_assoc_deps TYPE tt_dependencies,
          lt_join_deps  TYPE tt_dependencies.

    CLEAR rt_dependencies.

    " Extract FROM clause dependencies
    lt_from_deps = extract_from_clause( iv_source ).
    LOOP AT lt_from_deps INTO DATA(ls_dep).
      ls_dep-source_ddl = iv_ddlname.
      APPEND ls_dep TO rt_dependencies.
    ENDLOOP.

    " Extract associations
    lt_assoc_deps = extract_associations( iv_source ).
    LOOP AT lt_assoc_deps INTO ls_dep.
      ls_dep-source_ddl = iv_ddlname.
      APPEND ls_dep TO rt_dependencies.
    ENDLOOP.

    " Extract JOIN dependencies
    lt_join_deps = extract_joins( iv_source ).
    LOOP AT lt_join_deps INTO ls_dep.
      ls_dep-source_ddl = iv_ddlname.
      APPEND ls_dep TO rt_dependencies.
    ENDLOOP.

  ENDMETHOD.


  METHOD extract_from_clause.
    DATA: lv_source   TYPE string,
          ls_dep      TYPE ty_dependency,
          lt_matches  TYPE match_result_tab.

    CLEAR rt_dependencies.
    lv_source = iv_source.
    TRANSLATE lv_source TO UPPER CASE.

    " Pattern to match: FROM <view_name> or from <view_name>
    " Capture CDS view names (typically start with I_, Z, Y, or /XXX/)
    FIND ALL OCCURRENCES OF REGEX
      'FROM\s+([A-Z/_][A-Z0-9_/]*)'
      IN lv_source
      RESULTS lt_matches
      IGNORING CASE.

    LOOP AT lt_matches INTO DATA(ls_match).
      TRY.
          DATA(lv_view_name) = lv_source+ls_match-submatches[ 1 ]-offset(ls_match-submatches[ 1 ]-length).
          IF lv_view_name IS NOT INITIAL AND lv_view_name NE 'DUAL'.
            ls_dep-target_ddl = lv_view_name.
            ls_dep-dependency_type = 'FROM'.
            APPEND ls_dep TO rt_dependencies.
          ENDIF.
        CATCH cx_root.
          CONTINUE.
      ENDTRY.
    ENDLOOP.

    " Remove duplicates
    SORT rt_dependencies BY target_ddl.
    DELETE ADJACENT DUPLICATES FROM rt_dependencies COMPARING target_ddl.

  ENDMETHOD.


  METHOD extract_associations.
    DATA: lv_source   TYPE string,
          ls_dep      TYPE ty_dependency,
          lt_matches  TYPE match_result_tab.

    CLEAR rt_dependencies.
    lv_source = iv_source.
    TRANSLATE lv_source TO UPPER CASE.

    " Pattern: association [1..1] to <view_name>
    FIND ALL OCCURRENCES OF REGEX
      'ASSOCIATION\s+\[.*?\]\s+TO\s+([A-Z/_][A-Z0-9_/]*)'
      IN lv_source
      RESULTS lt_matches
      IGNORING CASE.

    LOOP AT lt_matches INTO DATA(ls_match).
      TRY.
          DATA(lv_view_name) = lv_source+ls_match-submatches[ 1 ]-offset(ls_match-submatches[ 1 ]-length).
          IF lv_view_name IS NOT INITIAL.
            ls_dep-target_ddl = lv_view_name.
            ls_dep-dependency_type = 'ASSOCIATION'.
            APPEND ls_dep TO rt_dependencies.
          ENDIF.
        CATCH cx_root.
          CONTINUE.
      ENDTRY.
    ENDLOOP.

    " Remove duplicates
    SORT rt_dependencies BY target_ddl.
    DELETE ADJACENT DUPLICATES FROM rt_dependencies COMPARING target_ddl.

  ENDMETHOD.


  METHOD extract_joins.
    DATA: lv_source   TYPE string,
          ls_dep      TYPE ty_dependency,
          lt_matches  TYPE match_result_tab.

    CLEAR rt_dependencies.
    lv_source = iv_source.
    TRANSLATE lv_source TO UPPER CASE.

    " Pattern: LEFT|RIGHT|INNER|OUTER JOIN <view_name>
    FIND ALL OCCURRENCES OF REGEX
      '(LEFT|RIGHT|INNER|OUTER)?\s*JOIN\s+([A-Z/_][A-Z0-9_/]*)'
      IN lv_source
      RESULTS lt_matches
      IGNORING CASE.

    LOOP AT lt_matches INTO DATA(ls_match).
      TRY.
          DATA(lv_view_name) = lv_source+ls_match-submatches[ 2 ]-offset(ls_match-submatches[ 2 ]-length).
          IF lv_view_name IS NOT INITIAL.
            ls_dep-target_ddl = lv_view_name.
            ls_dep-dependency_type = 'JOIN'.
            APPEND ls_dep TO rt_dependencies.
          ENDIF.
        CATCH cx_root.
          CONTINUE.
      ENDTRY.
    ENDLOOP.

    " Remove duplicates
    SORT rt_dependencies BY target_ddl.
    DELETE ADJACENT DUPLICATES FROM rt_dependencies COMPARING target_ddl.

  ENDMETHOD.


  METHOD get_dependent_views.
    DATA: lt_dependencies TYPE tt_dependencies,
          lt_processed    TYPE STANDARD TABLE OF ddlname.

    CLEAR rt_dependent_views.

    " Get direct dependencies
    lt_dependencies = extract_dependencies( iv_ddlname ).

    LOOP AT lt_dependencies INTO DATA(ls_dep).
      " Check if already processed (avoid circular dependencies)
      READ TABLE lt_processed WITH KEY table_line = ls_dep-target_ddl TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        APPEND ls_dep-target_ddl TO rt_dependent_views.
        APPEND ls_dep-target_ddl TO lt_processed.

        " Recursive call for nested dependencies
        DATA(lt_nested) = get_dependent_views( ls_dep-target_ddl ).
        LOOP AT lt_nested INTO DATA(lv_nested_ddl).
          READ TABLE lt_processed WITH KEY table_line = lv_nested_ddl TRANSPORTING NO FIELDS.
          IF sy-subrc <> 0.
            APPEND lv_nested_ddl TO rt_dependent_views.
            APPEND lv_nested_ddl TO lt_processed.
          ENDIF.
        ENDLOOP.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD analyze_migration_order.
    DATA: lt_all_deps       TYPE tt_dependencies,
          lt_ordered        TYPE STANDARD TABLE OF ddlname,
          lt_remaining      TYPE zcl_cds_scanner=>tt_cds_views,
          lv_progress_made  TYPE abap_bool.

    CLEAR rt_migration_order.
    lt_remaining = it_cds_views.

    " Build complete dependency graph
    LOOP AT it_cds_views INTO DATA(ls_cds).
      DATA(lt_deps) = extract_dependencies(
        iv_ddlname = ls_cds-ddlname
        iv_source  = ls_cds-source_code
      ).
      APPEND LINES OF lt_deps TO lt_all_deps.
    ENDLOOP.

    " Topological sort: Process views with no dependencies first
    DO.
      lv_progress_made = abap_false.

      LOOP AT lt_remaining INTO ls_cds.
        " Check if all dependencies are already in ordered list
        DATA(lv_can_process) = abap_true.

        LOOP AT lt_all_deps INTO DATA(ls_dep) WHERE source_ddl = ls_cds-ddlname.
          " Check if dependency is in remaining list (needs to be processed first)
          READ TABLE lt_remaining WITH KEY ddlname = ls_dep-target_ddl TRANSPORTING NO FIELDS.
          IF sy-subrc = 0.
            " Dependency still needs processing
            READ TABLE lt_ordered WITH KEY table_line = ls_dep-target_ddl TRANSPORTING NO FIELDS.
            IF sy-subrc <> 0.
              lv_can_process = abap_false.
              EXIT.
            ENDIF.
          ENDIF.
        ENDLOOP.

        IF lv_can_process = abap_true.
          APPEND ls_cds-ddlname TO rt_migration_order.
          DELETE lt_remaining WHERE ddlname = ls_cds-ddlname.
          lv_progress_made = abap_true.
        ENDIF.
      ENDLOOP.

      " Exit if no progress or all processed
      IF lv_progress_made = abap_false OR lt_remaining IS INITIAL.
        EXIT.
      ENDIF.
    ENDDO.

    " Add remaining (circular dependencies or orphaned)
    LOOP AT lt_remaining INTO ls_cds.
      APPEND ls_cds-ddlname TO rt_migration_order.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
