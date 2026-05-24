*&---------------------------------------------------------------------*
*& Report test_ddheadanno
*&---------------------------------------------------------------------*
*& Test DDHEADANNO table structure and data
*&---------------------------------------------------------------------*
REPORT test_ddheadanno.

PARAMETERS p_pack TYPE devclass DEFAULT 'Z*'.

START-OF-SELECTION.

" Test 1: Check all fields in DDHEADANNO
WRITE: / 'Test 1: Sample DDHEADANNO records'.
ULINE.

SELECT * FROM ddheadanno
  UP TO 10 ROWS
  INTO @DATA(ls_anno).
  WRITE: / 'Record found:', ls_anno.
ENDSELECT.

IF sy-subrc <> 0.
  WRITE: / 'No records found in DDHEADANNO'.
ENDIF.

SKIP 2.

" Test 2: Check structure - what fields exist?
WRITE: / 'Test 2: Check for SQLVIEWNAME annotations'.
ULINE.

SELECT * FROM ddheadanno
  WHERE name = 'ABAPCATALOG.SQLVIEWNAME'
  UP TO 10 ROWS
  INTO @ls_anno.
  WRITE: / ls_anno.
ENDSELECT.

IF sy-subrc <> 0.
  WRITE: / 'No ABAPCATALOG.SQLVIEWNAME found'.
ENDIF.

SKIP 2.

" Test 3: Try different name patterns
WRITE: / 'Test 3: Search for any AbapCatalog annotations'.
ULINE.

SELECT * FROM ddheadanno
  WHERE name LIKE '%ABAPCATALOG%'
  UP TO 10 ROWS
  INTO @ls_anno.
  WRITE: / ls_anno.
ENDSELECT.

IF sy-subrc <> 0.
  WRITE: / 'No AbapCatalog annotations found'.
ENDIF.

SKIP 2.

" Test 4: Check case sensitivity
WRITE: / 'Test 4: Try lowercase'.
ULINE.

SELECT * FROM ddheadanno
  WHERE name = 'AbapCatalog.sqlViewName'
  UP TO 10 ROWS
  INTO @ls_anno.
  WRITE: / ls_anno.
ENDSELECT.

IF sy-subrc <> 0.
  WRITE: / 'No lowercase match found'.
ENDIF.

SKIP 2.

" Test 5: Join with TADIR
WRITE: / 'Test 5: DDLS objects in package'.
ULINE.

SELECT obj_name FROM tadir
  WHERE pgmid = 'R3TR'
    AND object = 'DDLS'
    AND devclass LIKE @p_pack
  UP TO 10 ROWS
  INTO @DATA(lv_ddls).
  WRITE: / 'DDLS found:', lv_ddls.
ENDSELECT.

IF sy-subrc <> 0.
  WRITE: / 'No DDLS objects found in package', p_pack.
ENDIF.
