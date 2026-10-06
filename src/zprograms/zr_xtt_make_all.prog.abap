REPORT zr_xtt_make_all.

" Runs xtt's own make_all (ZCL_XTT_OPEN_REPORT, bizhuka/xtt src/demo/): every
" demo with every one of its templates, merged on the demo data and saved to
" output/result/. Then checks that each expected file is there and not empty.
"
" Demo data comes from compat/sap/data (flight model, countries, units, icons,
" employees). The run fails on the first demo that raises an exception.

START-OF-SELECTION.
  PERFORM run.

FORM run.
  DATA lo_report    TYPE REF TO zcl_xtt_open_report.
  DATA lt_examples  TYPE zcl_xtt_open_report=>tt_examples.
  DATA ls_example   LIKE LINE OF lt_examples.
  DATA lt_templates TYPE zcl_xtt_demo=>tt_template.
  DATA ls_template  LIKE LINE OF lt_templates.
  DATA lv_error     TYPE string.
  DATA lv_file      TYPE string.
  DATA lv_path      TYPE string.
  DATA lv_content   TYPE xstring.
  DATA lv_total     TYPE i.
  DATA lv_missing   TYPE i.

  CREATE OBJECT lo_report.
  lo_report->make_all( ).

  " the same file names make_all writes
  lt_examples = lo_report->get_all_examples( ).
  LOOP AT lt_examples INTO ls_example.
    lo_report->web_get_example_meta( EXPORTING iv_ind       = ls_example-ind
                                     IMPORTING et_templates = lt_templates
                                               ev_error     = lv_error ).
    IF lv_error IS NOT INITIAL.
      WRITE / |FAIL   { ls_example-ind }: { lv_error }|.
      lv_missing = lv_missing + 1.
      CONTINUE.
    ENDIF.
    LOOP AT lt_templates INTO ls_template.
      lv_file = ls_template-objid.
      TRANSLATE lv_file TO LOWER CASE.
      REPLACE FIRST OCCURRENCE OF '-' IN lv_file WITH '.'.
      lv_path = |./output/result/{ lv_file }|.
      lv_total = lv_total + 1.

      CLEAR lv_content.
      IF zcl_js_fs=>file_exists( lv_path ) = abap_true.
        lv_content = zcl_js_fs=>read_file_x( lv_path ).
      ENDIF.
      IF lv_content IS INITIAL.
        WRITE / |FAIL   { ls_example-ind } { ls_template-objid }: no file { lv_path }|.
        lv_missing = lv_missing + 1.
      ENDIF.
    ENDLOOP.
  ENDLOOP.

  SKIP.
  WRITE / |[make_all] { lines( lt_examples ) } demos, { lv_total } templates, { lv_missing } missing|.
  IF lv_missing = 0 AND lv_total > 0.
    WRITE / 'ALL XTT DEMO TEMPLATES MERGED'.
  ENDIF.
ENDFORM.
