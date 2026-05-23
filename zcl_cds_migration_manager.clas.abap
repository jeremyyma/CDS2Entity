CLASS zcl_cds_migration_manager DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_migration_summary,
        total_found     TYPE i,
        total_selected  TYPE i,
        total_migrated  TYPE i,
        total_errors    TYPE i,
        results         TYPE zcl_cds_migrator=>tt_migration_results,
      END OF ty_migration_summary.

    METHODS:
      "! Main orchestration method
      "! @parameter iv_package | Package to scan
      "! @parameter iv_include_subpackages | Include sub-packages
      "! @parameter rs_summary | Migration summary
      execute_migration
        IMPORTING
          iv_package             TYPE devclass
          iv_include_subpackages TYPE abap_bool DEFAULT abap_true
        RETURNING
          VALUE(rs_summary)      TYPE ty_migration_summary
        RAISING
          cx_static_check,

      "! Get list of CDS views with dependencies
      "! @parameter iv_package | Package to scan
      "! @parameter rt_cds_views | List of CDS views
      get_cds_list_with_dependencies
        IMPORTING
          iv_package             TYPE devclass
          iv_include_subpackages TYPE abap_bool DEFAULT abap_true
        RETURNING
          VALUE(rt_cds_views)    TYPE zcl_cds_scanner=>tt_cds_views
        RAISING
          cx_static_check,

      "! Save migration results to files
      "! @parameter it_results | Migration results
      "! @parameter iv_target_package | Target package for new CDS
      save_migration_results
        IMPORTING
          it_results       TYPE zcl_cds_migrator=>tt_migration_results
          iv_target_package TYPE devclass
        RAISING
          cx_static_check.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA:
      mo_scanner   TYPE REF TO zcl_cds_scanner,
      mo_analyzer  TYPE REF TO zcl_cds_dependency_analyzer,
      mo_migrator  TYPE REF TO zcl_cds_migrator.

    METHODS:
      initialize,

      enrich_with_dependencies
        CHANGING
          ct_cds_views TYPE zcl_cds_scanner=>tt_cds_views.

ENDCLASS.



CLASS zcl_cds_migration_manager IMPLEMENTATION.

  METHOD execute_migration.
    DATA: lt_cds_views TYPE zcl_cds_scanner=>tt_cds_views,
          lt_selected  TYPE zcl_cds_scanner=>tt_cds_views.

    CLEAR rs_summary.

    " Initialize components
    initialize( ).

    " Step 1: Scan package for classic CDS views
    lt_cds_views = mo_scanner->scan_package(
      iv_package             = iv_package
      iv_include_subpackages = iv_include_subpackages
    ).

    rs_summary-total_found = lines( lt_cds_views ).

    IF lt_cds_views IS INITIAL.
      rs_summary-total_selected = 0.
      rs_summary-total_migrated = 0.
      RETURN.
    ENDIF.

    " Step 2: Enrich with dependency information
    enrich_with_dependencies( CHANGING ct_cds_views = lt_cds_views ).

    " Step 3: Filter selected CDS views
    lt_selected = lt_cds_views.
    DELETE lt_selected WHERE selected = abap_false.
    rs_summary-total_selected = lines( lt_selected ).

    IF lt_selected IS INITIAL.
      rs_summary-total_migrated = 0.
      RETURN.
    ENDIF.

    " Step 4: Migrate selected CDS views
    rs_summary-results = mo_migrator->migrate_multiple_cds( lt_selected ).

    " Step 5: Calculate statistics
    LOOP AT rs_summary-results INTO DATA(ls_result).
      IF ls_result-status = 'SUCCESS'.
        rs_summary-total_migrated = rs_summary-total_migrated + 1.
      ELSEIF ls_result-status = 'ERROR'.
        rs_summary-total_errors = rs_summary-total_errors + 1.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_cds_list_with_dependencies.
    CLEAR rt_cds_views.

    " Initialize components
    initialize( ).

    " Scan for classic CDS views
    rt_cds_views = mo_scanner->scan_package(
      iv_package             = iv_package
      iv_include_subpackages = iv_include_subpackages
    ).

    IF rt_cds_views IS INITIAL.
      RETURN.
    ENDIF.

    " Enrich with dependencies
    enrich_with_dependencies( CHANGING ct_cds_views = rt_cds_views ).

  ENDMETHOD.


  METHOD save_migration_results.
    DATA: lv_filename TYPE string,
          lv_path     TYPE string.

    " This method would save the generated CDS source code to files
    " In a real ABAP Cloud environment, you would use appropriate APIs
    " to create the CDS view objects in the system

    LOOP AT it_results INTO DATA(ls_result).
      IF ls_result-status = 'SUCCESS'.
        " Create file name
        lv_filename = |{ ls_result-new_ddl_name }.ddls|.

        " In a real implementation:
        " 1. Create transport request
        " 2. Create DDLS object using CL_DD_DDL_HANDLER_FACTORY
        " 3. Set source code
        " 4. Activate

        TRY.
            " Example: Create DDL object (pseudo-code)
            " DATA(lo_handler) = cl_dd_ddl_handler_factory=>create( ).
            " DATA(lo_ddl) = lo_handler->create_new(
            "   iv_name    = ls_result-new_ddl_name
            "   iv_package = iv_target_package
            " ).
            " lo_ddl->set_source( ls_result-new_source_code ).
            " lo_ddl->save( ).
            " lo_ddl->activate( ).

            " For now, just output to log
            WRITE: / |Created: { ls_result-new_ddl_name }|.

          CATCH cx_root INTO DATA(lx_error).
            WRITE: / |Error creating { ls_result-new_ddl_name }: { lx_error->get_text( ) }|.
        ENDTRY.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD initialize.
    IF mo_scanner IS NOT BOUND.
      mo_scanner = NEW #( ).
    ENDIF.

    IF mo_analyzer IS NOT BOUND.
      mo_analyzer = NEW #( ).
    ENDIF.

    IF mo_migrator IS NOT BOUND.
      mo_migrator = NEW #( ).
    ENDIF.
  ENDMETHOD.


  METHOD enrich_with_dependencies.
    " Add dependency information to each CDS view
    LOOP AT ct_cds_views ASSIGNING FIELD-SYMBOL(<fs_cds>).
      " Extract dependencies
      DATA(lt_deps) = mo_analyzer->extract_dependencies(
        iv_ddlname = <fs_cds>-ddlname
        iv_source  = <fs_cds>-source_code
      ).

      " Store dependency list
      LOOP AT lt_deps INTO DATA(ls_dep).
        APPEND ls_dep-target_ddl TO <fs_cds>-dependencies.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
