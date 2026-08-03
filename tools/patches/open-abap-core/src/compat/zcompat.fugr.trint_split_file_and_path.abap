FUNCTION trint_split_file_and_path.
* compat implementation for the standard SAP module:
* splits "xl/workbook.xml" into stripped_name = "workbook.xml", file_path = "xl/"

  DATA lv_full TYPE string.
  DATA lv_len  TYPE i.
  DATA lv_idx  TYPE i.
  DATA lv_off  TYPE i.
  DATA lv_char TYPE c LENGTH 1.

  lv_full = full_name.
  stripped_name = lv_full.
  CLEAR file_path.

  lv_len = strlen( lv_full ).
  lv_idx = lv_len.
  WHILE lv_idx > 0.
    lv_idx = lv_idx - 1.
    lv_char = lv_full+lv_idx(1).
    IF lv_char = '/' OR lv_char = '\'.
      lv_off = lv_idx + 1.
      file_path = lv_full(lv_off).
      stripped_name = lv_full+lv_off.
      RETURN.
    ENDIF.
  ENDWHILE.

ENDFUNCTION.
