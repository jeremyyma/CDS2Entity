*&---------------------------------------------------------------------*
*& Report zcds_migration
*&---------------------------------------------------------------------*
*& Simple CDS to Entity Migration Tool
*&---------------------------------------------------------------------*
REPORT zcds_migration.

PARAMETERS: p_pack   TYPE devclass OBLIGATORY,
            p_disp   RADIOBUTTON GROUP mode DEFAULT 'X',
            p_commit RADIOBUTTON GROUP mode.

DATA: go_migrator TYPE REF TO zcl_cds_migrator,
      gt_cds      TYPE zcl_cds_migrator=>ty_cds_list,
      go_alv      TYPE REF TO cl_salv_table.

START-OF-SELECTION.

  go_migrator = NEW #( ).

  " Find classic CDS views in package using DDHEADANNO
  gt_cds = go_migrator->find_in_package( p_pack ).

  IF gt_cds IS INITIAL.
    MESSAGE |No classic CDS views found in package { p_pack }| TYPE 'I'.
    RETURN.
  ENDIF.

  " Transform each CDS to entity format
  LOOP AT gt_cds ASSIGNING FIELD-SYMBOL(<cds>).
    go_migrator->transform( CHANGING cs_cds = <cds> ).
  ENDLOOP.

  " Display mode: Show results in ALV
  IF p_disp = abap_true.
    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = go_alv
          CHANGING  t_table      = gt_cds
        ).

        go_alv->get_functions( )->set_all( abap_true ).
        go_alv->get_columns( )->set_optimize( abap_true ).
        go_alv->get_display_settings( )->set_list_header(
          |Classic CDS to Entity Migration - Package { p_pack } (Display Only)|
        ).

        go_alv->display( ).

      CATCH cx_salv_msg INTO DATA(lx_alv).
        MESSAGE lx_alv->get_text( ) TYPE 'E'.
    ENDTRY.

  " Commit mode: Create new entity views
  ELSE.
    DATA(lv_success_count) = 0.
    DATA(lv_error_count) = 0.

    LOOP AT gt_cds ASSIGNING <cds>.
      IF go_migrator->create_entity( <cds> ) = abap_true.
        lv_success_count = lv_success_count + 1.
        WRITE: / <cds>-name, '→', <cds>-new_name, '✓'.
      ELSE.
        lv_error_count = lv_error_count + 1.
        WRITE: / <cds>-name, '→', <cds>-new_name, '✗'.
      ENDIF.
    ENDLOOP.

    ULINE.
    WRITE: / 'Summary:', lv_success_count, 'created,', lv_error_count, 'failed'.
    MESSAGE |Migration completed: { lv_success_count } created, { lv_error_count } failed| TYPE 'I'.
  ENDIF.