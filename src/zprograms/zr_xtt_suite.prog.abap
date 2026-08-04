REPORT zr_xtt_suite.

" Phase 13.3: exercise bizhuka/xtt features on the author's own demo
" templates (deps/xtt/src/demo/*.w3mi.data.*):
"   050 - tree by group markers + ;func=SUM/AVG/COUNT aggregation
"   021 - formulas (shared/array) + second block {A-INFO}
"   080 - ;direction=column + code-side tree_create (REF TO data)
"   010 - DOCX: markers broken across <w:r> runs, unicode
" Data is deterministic so aggregates can be asserted exactly.

TYPES: BEGIN OF ty_rand_row,
         group   TYPE c LENGTH 100,
         caption TYPE c LENGTH 100,
         date    TYPE d,
         sum1    TYPE p LENGTH 8 DECIMALS 2,
         sum2    TYPE p LENGTH 8 DECIMALS 2,
       END OF ty_rand_row,
       ty_rand_rows TYPE STANDARD TABLE OF ty_rand_row WITH DEFAULT KEY,
       BEGIN OF ty_root,
         title TYPE string,
         t     TYPE ty_rand_rows,
       END OF ty_root,
       BEGIN OF ty_root_a,
         title TYPE string,
         t     TYPE ty_rand_rows,
         a     TYPE REF TO data,
       END OF ty_root_a,
       BEGIN OF ty_add_row,
         info TYPE string,
       END OF ty_add_row,
       ty_add_rows TYPE STANDARD TABLE OF ty_add_row WITH DEFAULT KEY,
       BEGIN OF ty_docx_root,
         title  TYPE c LENGTH 15,
         text   TYPE string,
         int    TYPE i,
         bottom TYPE string,
       END OF ty_docx_root,
       BEGIN OF ty_icon_row,
         id   TYPE c LENGTH 4,
         name TYPE c LENGTH 20,
         raw  TYPE xstring,
       END OF ty_icon_row,
       ty_icon_rows TYPE STANDARD TABLE OF ty_icon_row WITH DEFAULT KEY,
       BEGIN OF ty_icon_root,
         title TYPE string,
         t     TYPE ty_icon_rows,
       END OF ty_icon_root.

DATA gv_failed TYPE i.

START-OF-SELECTION.
  PERFORM test_050_tree.
  PERFORM test_021_formulas.
  PERFORM test_080_columns.
  PERFORM test_010_docx.
  PERFORM test_110_images.

  IF gv_failed = 0.
    WRITE / 'ALL XTT SUITE TESTS PASSED'.
  ELSE.
    WRITE / |XTT SUITE FAILED: { gv_failed } check(s)|.
  ENDIF.

*&---------------------------------------------------------------------*
*& 9 deterministic rows: 3 groups, sum1 = 100*n (total 4500), sum2 = 50
*&---------------------------------------------------------------------*
FORM fill_rand_table CHANGING ct_table TYPE ty_rand_rows.
  DATA ls_row TYPE ty_rand_row.
  DATA lv_n   TYPE i.
  CLEAR ct_table.
  DO 9 TIMES.
    lv_n = sy-index.
    CLEAR ls_row.
    CASE ( lv_n - 1 ) DIV 3.
      WHEN 0. ls_row-group = 'GRP A'.
      WHEN 1. ls_row-group = 'GRP B'.
      WHEN 2. ls_row-group = 'GRP C'.
    ENDCASE.
    ls_row-caption = |<Caption { lv_n } />|.
    ls_row-date    = '20260101'.
    ls_row-date    = ls_row-date + lv_n.
    ls_row-sum1    = lv_n * 100.
    ls_row-sum2    = 50.
    APPEND ls_row TO ct_table.
  ENDDO.
ENDFORM.

*&---------------------------------------------------------------------*
*& run merge on a template file, return raw result
*&---------------------------------------------------------------------*
FORM run_xtt_xlsx USING iv_template TYPE string
                        iv_out      TYPE string
                        is_block    TYPE any
                  CHANGING cv_raw    TYPE xstring.
  DATA lo_file TYPE REF TO zif_xtt_file.
  DATA lo_xtt  TYPE REF TO zcl_xtt_excel_xlsx.
  CREATE OBJECT lo_file TYPE zcl_xtt_file_raw
    EXPORTING
      iv_name    = iv_out
      iv_xstring = zcl_js_fs=>read_file_x( iv_template ).
  CREATE OBJECT lo_xtt
    EXPORTING
      io_file = lo_file.
  lo_xtt->merge( iv_block_name = 'R'
                 is_block      = is_block ).
  cv_raw = lo_xtt->get_raw( ).
  zcl_js_fs=>write_file_x( iv_path = iv_out
                           iv_data = cv_raw ).
ENDFORM.

*&---------------------------------------------------------------------*
*& extract one xml part of a zip as string
*&---------------------------------------------------------------------*
FORM zip_part USING iv_raw  TYPE xstring
                    iv_part TYPE string
              CHANGING cv_text TYPE string.
  DATA lo_zip  TYPE REF TO cl_abap_zip.
  DATA lv_hex  TYPE xstring.
  CLEAR cv_text.
  CREATE OBJECT lo_zip.
  lo_zip->load( iv_raw ).
  lo_zip->get( EXPORTING name    = iv_part
               IMPORTING content = lv_hex
               EXCEPTIONS zip_index_error = 1 ).
  IF sy-subrc = 0.
    cv_text = zcl_eui_conv=>xstring_to_string( lv_hex ).
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Office rejects a document whose XML is not well formed. The cheapest
*& killer is a duplicated attribute (<mergeCells count="8" count="28">),
*& which every structural check happily accepts - so scan every tag of
*& every part for repeated attribute names.
*&---------------------------------------------------------------------*
FORM assert_valid_office USING iv_raw TYPE xstring iv_msg TYPE string.
  DATA lo_zip   TYPE REF TO cl_abap_zip.
  DATA lv_hex   TYPE xstring.
  DATA lv_text  TYPE string.
  DATA lv_bad   TYPE string.
  DATA lv_ok    TYPE abap_bool.
  FIELD-SYMBOLS <ls_file> LIKE LINE OF lo_zip->files.

  CREATE OBJECT lo_zip.
  lo_zip->load( iv_raw ).

  LOOP AT lo_zip->files ASSIGNING <ls_file>.
    IF NOT ( <ls_file>-name CP '*.xml' OR <ls_file>-name CP '*.rels' ).
      CONTINUE.
    ENDIF.
    CLEAR lv_hex.
    lo_zip->get( EXPORTING name    = <ls_file>-name
                 IMPORTING content = lv_hex
                 EXCEPTIONS zip_index_error = 1 ).
    CHECK sy-subrc = 0.
    lv_text = zcl_eui_conv=>xstring_to_string( lv_hex ).
    PERFORM find_dup_attribute USING lv_text CHANGING lv_bad.
    IF lv_bad IS NOT INITIAL.
      CONCATENATE <ls_file>-name `: ` lv_bad INTO lv_bad.
      EXIT.
    ENDIF.
  ENDLOOP.

  IF lv_bad IS INITIAL.
    lv_ok = abap_true.
  ELSE.
    WRITE / |       { lv_bad }|.
  ENDIF.
  PERFORM assert USING lv_ok iv_msg.
ENDFORM.

*&---------------------------------------------------------------------*
*& first tag containing the same attribute name twice, if any
*&---------------------------------------------------------------------*
FORM find_dup_attribute USING iv_xml TYPE string
                        CHANGING cv_bad TYPE string.
  DATA lt_tags  TYPE stringtab.
  DATA lv_tag   TYPE string.
  DATA lt_attr  TYPE stringtab.
  DATA lt_seen  TYPE stringtab.
  DATA lv_attr  TYPE string.
  DATA lv_name  TYPE string.
  DATA lt_words TYPE stringtab.
  DATA lv_word  TYPE string.

  CLEAR cv_bad.
  SPLIT iv_xml AT '<' INTO TABLE lt_tags.

  LOOP AT lt_tags INTO lv_tag.
    CHECK lv_tag CS '='.
    SPLIT lv_tag AT '>' INTO lv_tag lv_name.
    CLEAR lt_seen.
    SPLIT lv_tag AT '"' INTO TABLE lt_attr.
    " odd entries hold ` name=`, even ones the quoted values
    LOOP AT lt_attr INTO lv_attr.
      CHECK sy-tabix MOD 2 = 1 AND lv_attr CS '='.
      " the segment ends with the attribute name: `<tag foo="` / `" bar="`
      CLEAR lv_name.
      SPLIT lv_attr AT ` ` INTO TABLE lt_words.
      LOOP AT lt_words INTO lv_word.
        IF lv_word CS '='.
          lv_name = lv_word.
        ENDIF.
      ENDLOOP.
      REPLACE ALL OCCURRENCES OF `=` IN lv_name WITH ``.
      CHECK lv_name IS NOT INITIAL.
      READ TABLE lt_seen TRANSPORTING NO FIELDS WITH KEY table_line = lv_name.
      IF sy-subrc = 0.
        CONCATENATE `duplicate attribute "` lv_name `" in <` lv_tag `>` INTO cv_bad.
        RETURN.
      ENDIF.
      APPEND lv_name TO lt_seen.
    ENDLOOP.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
FORM assert USING iv_ok TYPE abap_bool iv_msg TYPE string.
  IF iv_ok = abap_true.
    WRITE / |  OK   { iv_msg }|.
  ELSE.
    WRITE / |  FAIL { iv_msg }|.
    gv_failed = gv_failed + 1.
  ENDIF.
ENDFORM.

FORM assert_contains USING iv_text TYPE string iv_sub TYPE string iv_msg TYPE string.
  DATA lv_ok TYPE abap_bool.
  IF iv_text CS iv_sub.
    lv_ok = abap_true.
  ENDIF.
  PERFORM assert USING lv_ok iv_msg.
ENDFORM.

FORM assert_free USING iv_text TYPE string iv_sub TYPE string iv_msg TYPE string.
  DATA lv_ok TYPE abap_bool.
  IF NOT iv_text CS iv_sub.
    lv_ok = abap_true.
  ENDIF.
  PERFORM assert USING lv_ok iv_msg.
ENDFORM.

*&---------------------------------------------------------------------*
*& true if the produced zip has an entry matching iv_pattern (CP)
*&---------------------------------------------------------------------*
FORM zip_has USING iv_raw TYPE xstring
                   iv_pattern TYPE string
             CHANGING cv_found TYPE abap_bool.
  DATA lo_zip TYPE REF TO cl_abap_zip.
  FIELD-SYMBOLS <ls_file> LIKE LINE OF lo_zip->files.
  CLEAR cv_found.
  CREATE OBJECT lo_zip.
  lo_zip->load( iv_raw ).
  LOOP AT lo_zip->files ASSIGNING <ls_file>.
    IF <ls_file>-name CP iv_pattern.
      cv_found = abap_true.
      RETURN.
    ENDIF.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& 050: tree markers {R-T;group=} / level=0/1, func=SUM/AVG/COUNT
*&---------------------------------------------------------------------*
FORM test_050_tree.
  DATA ls_root  TYPE ty_root.
  DATA lv_raw   TYPE xstring.
  DATA lv_text  TYPE string.
  DATA lv_all   TYPE string.
  DATA lx_error TYPE REF TO cx_root.

  WRITE / '--- 050 tree + aggregation (xlsx) ---'.
  TRY.
      ls_root-title = 'Suite 050'.
      " NB: PERFORM ... CHANGING ls_root-t drops the argument in the
      " transpiler (structure component as FORM param) - use a local
      DATA lt_rows TYPE ty_rand_rows.
      PERFORM fill_rand_table CHANGING lt_rows.
      ls_root-t = lt_rows.
      PERFORM run_xtt_xlsx USING `deps/xtt/src/demo/zxxt_demo_050-xlsx.w3mi.data.xlsx`
                                 `data/xtt_suite_050.xlsx`
                                 ls_root
                           CHANGING lv_raw.

      PERFORM zip_part USING lv_raw `xl/worksheets/sheet1.xml` CHANGING lv_text.
      lv_all = lv_text.
      PERFORM zip_part USING lv_raw `xl/worksheets/sheet2.xml` CHANGING lv_text.
      CONCATENATE lv_all lv_text INTO lv_all.
      PERFORM zip_part USING lv_raw `xl/sharedStrings.xml` CHANGING lv_text.
      CONCATENATE lv_all lv_text INTO lv_all.

      PERFORM assert_free     USING lv_all `{R-` `no {R-...} markers left`.
      PERFORM assert_contains USING lv_all `Suite 050` `{R-TITLE} replaced`.
      PERFORM assert_contains USING lv_all `GRP B` `data rows written`.
      PERFORM assert_contains USING lv_all `&lt;Caption 1 /&gt;` `xml symbols escaped`.
      PERFORM assert_contains USING lv_all `4500` `func=SUM over SUM1 = 4500`.
      " func=COUNT writes the int into a CHAR100 (right-aligned, WRITE TO
      " semantics) - squash the padding before checking
      DATA lv_squash TYPE string.
      lv_squash = lv_all.
      REPLACE ALL OCCURRENCES OF REGEX ` +` IN lv_squash WITH ` `.
      PERFORM assert_contains USING lv_squash `Total count: 9` `func=COUNT = 9`.
      PERFORM assert_contains USING lv_all `50` `func=AVG over SUM2 = 50`.
      PERFORM assert_valid_office USING lv_raw `valid xlsx (no duplicate attributes)`.
    CATCH cx_root INTO lx_error.
      DATA lv_msg TYPE string.
      lv_msg = |exception: { lx_error->get_text( ) }|.
      PERFORM assert USING abap_false lv_msg.
  ENDTRY.
ENDFORM.

*&---------------------------------------------------------------------*
*& 021: formulas + second root block A (plain table)
*&---------------------------------------------------------------------*
FORM test_021_formulas.
  DATA ls_root  TYPE ty_root.
  DATA lt_add   TYPE ty_add_rows.
  DATA ls_add   TYPE ty_add_row.
  DATA lo_file  TYPE REF TO zif_xtt_file.
  DATA lo_xtt   TYPE REF TO zcl_xtt_excel_xlsx.
  DATA lv_raw   TYPE xstring.
  DATA lv_text  TYPE string.
  DATA lv_all   TYPE string.
  DATA lx_error TYPE REF TO cx_root.

  WRITE / '--- 021 formulas + block A (xlsx) ---'.
  TRY.
      ls_root-title = 'Suite 021'.
      DATA lt_rows TYPE ty_rand_rows.
      PERFORM fill_rand_table CHANGING lt_rows.
      ls_root-t = lt_rows.
      DO 3 TIMES.
        ls_add-info = |String { sy-index }|.
        APPEND ls_add TO lt_add.
      ENDDO.

      CREATE OBJECT lo_file TYPE zcl_xtt_file_raw
        EXPORTING
          iv_name    = `xtt_suite_021.xlsx`
          iv_xstring = zcl_js_fs=>read_file_x( `deps/xtt/src/demo/zxxt_demo_021-xlsx.w3mi.data.xlsx` ).
      CREATE OBJECT lo_xtt
        EXPORTING
          io_file = lo_file.
      lo_xtt->merge( iv_block_name = 'R'
                     is_block      = ls_root ).
      lo_xtt->merge( iv_block_name = 'A'
                     is_block      = lt_add ).
      lv_raw = lo_xtt->get_raw( ).
      zcl_js_fs=>write_file_x( iv_path = `data/xtt_suite_021.xlsx`
                               iv_data = lv_raw ).

      PERFORM zip_part USING lv_raw `xl/worksheets/sheet1.xml` CHANGING lv_text.
      lv_all = lv_text.
      PERFORM zip_part USING lv_raw `xl/sharedStrings.xml` CHANGING lv_text.
      CONCATENATE lv_all lv_text INTO lv_all.

      PERFORM assert_free     USING lv_all `{R-` `no {R-...} markers left`.
      PERFORM assert_free     USING lv_all `{A-` `no {A-...} markers left`.
      PERFORM assert_contains USING lv_all `String 2` `block A rows written`.
      PERFORM assert_contains USING lv_all `<f` `formulas kept in sheet`.
      PERFORM assert_valid_office USING lv_raw `valid xlsx (no duplicate attributes)`.
    CATCH cx_root INTO lx_error.
      DATA lv_msg TYPE string.
      lv_msg = |exception: { lx_error->get_text( ) }|.
      PERFORM assert USING abap_false lv_msg.
  ENDTRY.
ENDFORM.

*&---------------------------------------------------------------------*
*& 080: direction=column + tree via zcl_xtt_replace_block=>tree_create
*&---------------------------------------------------------------------*
FORM test_080_columns.
  DATA ls_root  TYPE ty_root_a.
  DATA lv_raw   TYPE xstring.
  DATA lv_text  TYPE string.
  DATA lv_all   TYPE string.
  DATA lx_error TYPE REF TO cx_root.

  WRITE / '--- 080 direction=column + tree_create (xlsx) ---'.
  TRY.
      ls_root-title = 'Suite 080'.
      DATA lt_rows TYPE ty_rand_rows.
      PERFORM fill_rand_table CHANGING lt_rows.
      ls_root-t = lt_rows.
      DATA lr_table TYPE REF TO data.
      GET REFERENCE OF ls_root-t INTO lr_table.
      ls_root-a = zcl_xtt_replace_block=>tree_create(
        it_table  = lr_table
        iv_fields = 'GROUP' ).

      PERFORM run_xtt_xlsx USING `deps/xtt/src/demo/zxxt_demo_080-xlsx.w3mi.data.xlsx`
                                 `data/xtt_suite_080.xlsx`
                                 ls_root
                           CHANGING lv_raw.

      PERFORM zip_part USING lv_raw `xl/worksheets/sheet1.xml` CHANGING lv_text.
      lv_all = lv_text.
      PERFORM zip_part USING lv_raw `xl/worksheets/sheet2.xml` CHANGING lv_text.
      CONCATENATE lv_all lv_text INTO lv_all.
      PERFORM zip_part USING lv_raw `xl/sharedStrings.xml` CHANGING lv_text.
      CONCATENATE lv_all lv_text INTO lv_all.

      PERFORM assert_free     USING lv_all `{R-` `no {R-...} markers left`.
      PERFORM assert_contains USING lv_all `GRP C` `data written`.
      PERFORM assert_contains USING lv_all `I move to the end` `static cell preserved`.
      PERFORM assert_valid_office USING lv_raw `valid xlsx (no duplicate attributes)`.
    CATCH cx_root INTO lx_error.
      DATA lv_msg TYPE string.
      lv_msg = |exception: { lx_error->get_text( ) }|.
      PERFORM assert USING abap_false lv_msg.
  ENDTRY.
ENDFORM.

*&---------------------------------------------------------------------*
*& 010: DOCX - markers broken across runs, unicode text
*&---------------------------------------------------------------------*
FORM test_010_docx.
  DATA ls_root  TYPE ty_docx_root.
  DATA lo_file  TYPE REF TO zif_xtt_file.
  DATA lo_xtt   TYPE REF TO zcl_xtt_word_docx.
  DATA lv_raw   TYPE xstring.
  DATA lv_text  TYPE string.
  DATA lx_error TYPE REF TO cx_root.

  WRITE / '--- 010 docx (word) ---'.
  TRY.
      ls_root-title  = 'Document title'.
      ls_root-text   = 'Just string әіңғүұқөһ ӘІҢҒҮҰҚӨ'.
      ls_root-int    = 3.
      ls_root-bottom = 'bottom'.

      CREATE OBJECT lo_file TYPE zcl_xtt_file_raw
        EXPORTING
          iv_name    = `xtt_suite_010.docx`
          iv_xstring = zcl_js_fs=>read_file_x( `deps/xtt/src/demo/zxxt_demo_010-docx.w3mi.data.docx` ).
      CREATE OBJECT lo_xtt
        EXPORTING
          io_file = lo_file.
      lo_xtt->merge( iv_block_name = 'R'
                     is_block      = ls_root ).
      lv_raw = lo_xtt->get_raw( ).
      zcl_js_fs=>write_file_x( iv_path = `data/xtt_suite_010.docx`
                               iv_data = lv_raw ).

      PERFORM zip_part USING lv_raw `word/document.xml` CHANGING lv_text.

      PERFORM assert_free     USING lv_text `{R-` `no {R-...} markers left (runs merged)`.
      PERFORM assert_contains USING lv_text `Document title` `{R-TITLE} replaced`.
      PERFORM assert_contains USING lv_text `әіңғүұқөһ` `unicode text written`.
      PERFORM assert_valid_office USING lv_raw `valid docx (no duplicate attributes)`.
    CATCH cx_root INTO lx_error.
      DATA lv_msg TYPE string.
      lv_msg = |exception: { lx_error->get_text( ) }|.
      PERFORM assert USING abap_false lv_msg.
  ENDTRY.
ENDFORM.

*&---------------------------------------------------------------------*
*& 110: images from a plain xstring field - {R-T-RAW;type=image}
*&---------------------------------------------------------------------*
FORM test_110_images.
  DATA ls_root  TYPE ty_icon_root.
  DATA ls_icon  TYPE ty_icon_row.
  DATA lv_gif   TYPE xstring.
  DATA lv_raw   TYPE xstring.
  DATA lv_text  TYPE string.
  DATA lv_all   TYPE string.
  DATA lv_found TYPE abap_bool.
  DATA lx_error TYPE REF TO cx_root.

  WRITE / '--- 110 images ;type=image (xlsx) ---'.
  TRY.
      ls_root-title = 'Suite 110'.
      " 1x1 red pixel GIF
      lv_gif = '47494638396101000100800000FF0000FFFFFF21F90401000000002C00000000010001000002024401003B'.
      DO 3 TIMES.
        ls_icon-id   = sy-index.
        ls_icon-name = |ICON_{ sy-index }|.
        ls_icon-raw  = lv_gif.
        APPEND ls_icon TO ls_root-t.
      ENDDO.

      PERFORM run_xtt_xlsx USING `deps/xtt/src/demo/zxxt_demo_110-xlsx.w3mi.data.xlsx`
                                 `data/xtt_suite_110.xlsx`
                                 ls_root
                           CHANGING lv_raw.

      PERFORM zip_part USING lv_raw `xl/worksheets/sheet1.xml` CHANGING lv_text.
      lv_all = lv_text.
      PERFORM zip_part USING lv_raw `xl/sharedStrings.xml` CHANGING lv_text.
      CONCATENATE lv_all lv_text INTO lv_all.

      PERFORM assert_free     USING lv_all `{R-` `no {R-...} markers left`.
      PERFORM assert_contains USING lv_all `ICON_2` `data rows written`.
      PERFORM zip_has USING lv_raw `xl/media/*` CHANGING lv_found.
      PERFORM assert USING lv_found `images embedded in xl/media/`.
      PERFORM zip_has USING lv_raw `xl/drawings/drawing*` CHANGING lv_found.
      PERFORM assert USING lv_found `drawing xml created`.
      PERFORM assert_valid_office USING lv_raw `valid xlsx (no duplicate attributes)`.
    CATCH cx_root INTO lx_error.
      DATA lv_msg TYPE string.
      lv_msg = |exception: { lx_error->get_text( ) }|.
      PERFORM assert USING abap_false lv_msg.
  ENDTRY.
ENDFORM.
