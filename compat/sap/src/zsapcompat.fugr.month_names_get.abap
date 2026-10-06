FUNCTION month_names_get.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(LANGUAGE) TYPE  SYLANGU DEFAULT SY-LANGU
*"  EXPORTING
*"     REFERENCE(RETURN_CODE) TYPE  SYSUBRC
*"  TABLES
*"      MONTH_NAMES STRUCTURE  T247
*"  EXCEPTIONS
*"      MONTH_NAMES_NOT_FOUND
*"----------------------------------------------------------------------
* xtt-ci compat: reads T247 like SAP does. Callers pass T247 rows or
* WDR_DATE_NAV_MONTH_NAME rows, so each line is filled by field name.

  DATA lv_language TYPE sylangu.
  DATA lt_t247 TYPE STANDARD TABLE OF t247 WITH DEFAULT KEY.
  DATA ls_t247 TYPE t247.
  FIELD-SYMBOLS <ls_month> TYPE any.

  lv_language = language.
  IF lv_language IS INITIAL.
    lv_language = sy-langu.
  ENDIF.

  SELECT * FROM t247 INTO TABLE lt_t247
    WHERE spras = lv_language
    ORDER BY PRIMARY KEY.
  IF sy-subrc <> 0.
    return_code = 1.
    RAISE month_names_not_found.
  ENDIF.

  CLEAR month_names[].
  LOOP AT lt_t247 INTO ls_t247.
    APPEND INITIAL LINE TO month_names ASSIGNING <ls_month>.
    MOVE-CORRESPONDING ls_t247 TO <ls_month>.
  ENDLOOP.
  return_code = 0.

ENDFUNCTION.
