*&---------------------------------------------------------------------*
*& Report zcds_migration
*&---------------------------------------------------------------------*
*& Simple CDS to Entity Migration Tool
*&---------------------------------------------------------------------*
REPORT zcds_migration.

PARAMETERS p_pack TYPE devclass OBLIGATORY DEFAULT 'Z*'.

DATA: go_migrator TYPE REF TO zcl_cds_migrator,
      gt_cds      TYPE zcl_cds_migrator=>ty_cds_list,
      go_alv      TYPE REF TO cl_salv_table.

START-OF-SELECTION.

  go_migrator = NEW #( ).

  " Find classic CDS views
  gt_cds = go_migrator->find_in_package( p_pack ).

  IF gt_cds IS INITIAL.
    MESSAGE 'No classic CDS views found' TYPE 'I'.
    RETURN.
  ENDIF.

  " Transform each CDS
  LOOP AT gt_cds ASSIGNING FIELD-SYMBOL(<cds>).
    go_migrator->transform( CHANGING cs_cds = <cds> ).
  ENDLOOP.

  " Display results
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = go_alv
        CHANGING  t_table      = gt_cds
      ).

      go_alv->get_functions( )->set_all( abap_true ).
      go_alv->get_columns( )->set_optimize( abap_true ).
      go_alv->get_display_settings( )->set_list_header( 'Classic CDS to Entity Migration' ).

      go_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_alv).
      MESSAGE lx_alv->get_text( ) TYPE 'E'.
  ENDTRY.
