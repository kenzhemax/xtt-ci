CLASS zcl_eui_file_io DEFINITION PUBLIC FINAL CREATE PUBLIC.
  " local-abap compat for bizhuka/eui (Apache-2.0): column letter conversions
  PUBLIC SECTION.
    CLASS-METHODS column_2_int
      IMPORTING VALUE(iv_column) TYPE csequence
      RETURNING VALUE(rv_column) TYPE i.

    CLASS-METHODS int_2_column
      IMPORTING VALUE(iv_column) TYPE i
      RETURNING VALUE(rv_column) TYPE char3
      RAISING   zcx_eui_exception.
ENDCLASS.

CLASS zcl_eui_file_io IMPLEMENTATION.

  METHOD column_2_int.
    DATA lv_len  TYPE i.
    DATA lv_off  TYPE i.
    DATA lv_char TYPE c LENGTH 1.
    DATA lv_pos  TYPE i.
    DATA lv_up   TYPE string.

    lv_up = iv_column.
    TRANSLATE lv_up TO UPPER CASE.
    CONDENSE lv_up NO-GAPS.
    lv_len = strlen( lv_up ).
    lv_off = 0.
    WHILE lv_off < lv_len.
      lv_char = lv_up+lv_off(1).
      IF lv_char CA '0123456789'.
        EXIT.
      ENDIF.
      lv_pos = sy-fdpos. " not used, avoid warnings
      FIND lv_char IN sy-abcde MATCH OFFSET lv_pos.
      rv_column = rv_column * 26 + lv_pos + 1.
      lv_off = lv_off + 1.
    ENDWHILE.
  ENDMETHOD.

  METHOD int_2_column.
    DATA lv_int TYPE i.
    DATA lv_mod TYPE i.
    DATA lv_chr TYPE c LENGTH 1.

    IF iv_column <= 0 OR iv_column > 16384.
      zcx_eui_exception=>raise_sys_error( iv_message = |wrong column { iv_column }| ).
    ENDIF.

    lv_int = iv_column.
    WHILE lv_int > 0.
      lv_mod = ( lv_int - 1 ) MOD 26.
      lv_chr = sy-abcde+lv_mod(1).
      CONCATENATE lv_chr rv_column INTO rv_column.
      lv_int = ( lv_int - 1 ) DIV 26.
    ENDWHILE.
  ENDMETHOD.

ENDCLASS.
