*&---------------------------------------------------------------------*
*& Report ZCDS_MIGRATION_TOOL
*&---------------------------------------------------------------------*
*& CDS Migration Tool - Migrate Classic CDS to Entity-Based CDS
*&---------------------------------------------------------------------*
REPORT zcds_migration_tool.

" Selection Screen
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS: p_pack TYPE devclass OBLIGATORY DEFAULT 'Z*'.
  PARAMETERS: p_sub AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  PARAMETERS: p_tpkg TYPE devclass OBLIGATORY DEFAULT 'ZTMP'.
  PARAMETERS: p_disp AS CHECKBOX DEFAULT 'X'.
  PARAMETERS: p_save AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b2.

" Global Data
DATA: gt_cds_views     TYPE zcl_cds_scanner=>tt_cds_views,
      gt_selected      TYPE zcl_cds_scanner=>tt_cds_views,
      gs_summary       TYPE zcl_cds_migration_manager=>ty_migration_summary,
      go_manager       TYPE REF TO zcl_cds_migration_manager,
      go_alv           TYPE REF TO cl_salv_table.

" Text Symbols
SELECTION-SCREEN: BEGIN OF LINE,
                  COMMENT 1(50) TEXT-003,
                  END OF LINE.

*&---------------------------------------------------------------------*
*& START-OF-SELECTION
*&---------------------------------------------------------------------*
START-OF-SELECTION.

  " Create manager instance
  CREATE OBJECT go_manager.

  " Step 1: Scan package and get CDS list with dependencies
  TRY.
      WRITE: / 'Scanning package:', p_pack.
      WRITE: / 'Include sub-packages:', p_sub.
      NEW-LINE.

      gt_cds_views = go_manager->get_cds_list_with_dependencies(
        iv_package             = p_pack
        iv_include_subpackages = p_sub
      ).

      IF gt_cds_views IS INITIAL.
        WRITE: / 'No classic CDS views found in package', p_pack.
        RETURN.
      ENDIF.

      WRITE: / 'Found', lines( gt_cds_views ), 'classic CDS view(s)'.
      NEW-LINE.

    CATCH cx_root INTO DATA(lx_error).
      WRITE: / 'Error during scan:', lx_error->get_text( ).
      RETURN.
  ENDTRY.

  " Step 2: Display CDS list for selection
  PERFORM display_cds_list.

*&---------------------------------------------------------------------*
*& END-OF-SELECTION
*&---------------------------------------------------------------------*
END-OF-SELECTION.

  " Step 3: Process selected CDS views
  IF p_disp = abap_false.
    PERFORM execute_migration.
  ENDIF.

*&---------------------------------------------------------------------*
*& Form display_cds_list
*&---------------------------------------------------------------------*
FORM display_cds_list.

  DATA: lt_display TYPE TABLE OF zcl_cds_scanner=>ty_cds_view,
        lr_functions TYPE REF TO cl_salv_functions_list,
        lr_selections TYPE REF TO cl_salv_selections,
        lr_columns TYPE REF TO cl_salv_columns_table,
        lr_column TYPE REF TO cl_salv_column_table.

  lt_display = gt_cds_views.

  " Display ALV with selection checkboxes
  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = go_alv
        CHANGING
          t_table      = lt_display
      ).

      " Enable all functions
      lr_functions = go_alv->get_functions( ).
      lr_functions->set_all( abap_true ).

      " Enable row selection
      lr_selections = go_alv->get_selections( ).
      lr_selections->set_selection_mode( if_salv_c_selection_mode=>row_column ).

      " Optimize columns
      lr_columns = go_alv->get_columns( ).
      lr_columns->set_optimize( abap_true ).

      " Set column headers
      TRY.
          lr_column ?= lr_columns->get_column( 'DDLNAME' ).
          lr_column->set_long_text( 'CDS View Name' ).
          lr_column->set_medium_text( 'CDS View' ).
          lr_column->set_short_text( 'CDS' ).

          lr_column ?= lr_columns->get_column( 'SQL_VIEW_NAME' ).
          lr_column->set_long_text( 'SQL View Name' ).
          lr_column->set_medium_text( 'SQL View' ).
          lr_column->set_short_text( 'SQL' ).

          lr_column ?= lr_columns->get_column( 'PACKAGE' ).
          lr_column->set_long_text( 'Package' ).
          lr_column->set_medium_text( 'Package' ).
          lr_column->set_short_text( 'Pkg' ).

          lr_column ?= lr_columns->get_column( 'DESCRIPTION' ).
          lr_column->set_long_text( 'Description' ).

          lr_column ?= lr_columns->get_column( 'SELECTED' ).
          lr_column->set_long_text( 'Selected' ).
          lr_column->set_cell_type( if_salv_c_cell_type=>checkbox ).

          " Hide technical columns
          lr_column ?= lr_columns->get_column( 'IS_CLASSIC' ).
          lr_column->set_visible( abap_false ).

          lr_column ?= lr_columns->get_column( 'SOURCE_CODE' ).
          lr_column->set_visible( abap_false ).

          lr_column ?= lr_columns->get_column( 'DEPENDENCIES' ).
          lr_column->set_technical( abap_false ).

        CATCH cx_salv_not_found.
          " Column not found, continue
      ENDTRY.

      " Display the ALV
      go_alv->display( ).

      " Allow user to select rows
      WRITE: / 'Please select CDS views to migrate and press F8 to continue.'.
      NEW-LINE.

    CATCH cx_salv_msg INTO DATA(lx_salv).
      WRITE: / 'Error displaying ALV:', lx_salv->get_text( ).
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form execute_migration
*&---------------------------------------------------------------------*
FORM execute_migration.

  DATA: lt_results TYPE zcl_cds_migrator=>tt_migration_results.

  " Get selected rows from ALV
  TRY.
      DATA(lt_selected_rows) = go_alv->get_selections( )->get_selected_rows( ).

      " Mark selected CDS views
      LOOP AT lt_selected_rows INTO DATA(lv_row).
        READ TABLE gt_cds_views INDEX lv_row ASSIGNING FIELD-SYMBOL(<fs_cds>).
        IF sy-subrc = 0.
          <fs_cds>-selected = abap_true.
        ENDIF.
      ENDLOOP.

    CATCH cx_root.
      " If no ALV selection available, use all with selected flag
  ENDTRY.

  " Count selected
  DATA(lv_selected_count) = 0.
  LOOP AT gt_cds_views INTO DATA(ls_cds) WHERE selected = abap_true.
    lv_selected_count = lv_selected_count + 1.
  ENDLOOP.

  IF lv_selected_count = 0.
    WRITE: / 'No CDS views selected for migration.'.
    RETURN.
  ENDIF.

  WRITE: / 'Migrating', lv_selected_count, 'CDS view(s)...'.
  NEW-LINE.

  " Execute migration
  TRY.
      gs_summary = go_manager->execute_migration(
        iv_package             = p_pack
        iv_include_subpackages = p_sub
      ).

      " Display results
      WRITE: / '========================================'.
      WRITE: / 'Migration Summary'.
      WRITE: / '========================================'.
      WRITE: / 'Total found      :', gs_summary-total_found.
      WRITE: / 'Total selected   :', gs_summary-total_selected.
      WRITE: / 'Total migrated   :', gs_summary-total_migrated.
      WRITE: / 'Total errors     :', gs_summary-total_errors.
      NEW-LINE.

      " Display detailed results
      IF gs_summary-results IS NOT INITIAL.
        WRITE: / '========================================'.
        WRITE: / 'Detailed Migration Results'.
        WRITE: / '========================================'.

        LOOP AT gs_summary-results INTO DATA(ls_result).
          WRITE: / '----------------------------------------'.
          WRITE: / 'Original CDS     :', ls_result-ddlname.
          WRITE: / 'Old SQL View     :', ls_result-old_sql_view.
          WRITE: / 'New CDS          :', ls_result-new_ddl_name.
          WRITE: / 'New SQL View     :', ls_result-new_sql_view.
          WRITE: / 'Status           :', ls_result-status.
          WRITE: / 'Message          :', ls_result-message.
          NEW-LINE.

          " Display generated source code
          IF ls_result-status = 'SUCCESS' AND ls_result-new_source_code IS NOT INITIAL.
            WRITE: / 'Generated Source Code:'.
            WRITE: / '========================================'.

            " Split source code into lines for better display
            SPLIT ls_result-new_source_code AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_source_lines).
            LOOP AT lt_source_lines INTO DATA(lv_line).
              WRITE: / lv_line.
            ENDLOOP.

            NEW-LINE.
          ENDIF.
        ENDLOOP.
      ENDIF.

      " Save results if requested
      IF p_save = abap_true.
        WRITE: / 'Saving migration results...'.
        go_manager->save_migration_results(
          it_results        = gs_summary-results
          iv_target_package = p_tpkg
        ).
        WRITE: / 'Migration results saved.'.
      ENDIF.

    CATCH cx_root INTO DATA(lx_error).
      WRITE: / 'Error during migration:', lx_error->get_text( ).
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Text Symbols
*&---------------------------------------------------------------------*
* Text-001: 'Source Package Selection'
* Text-002: 'Migration Options'
* Text-003: 'Classic CDS to Entity-Based CDS Migration Tool'
