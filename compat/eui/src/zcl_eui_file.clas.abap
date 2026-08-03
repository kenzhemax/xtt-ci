CLASS zcl_eui_file DEFINITION PUBLIC CREATE PUBLIC.
  " local-abap compat for bizhuka/eui (Apache-2.0): file output without SAP GUI.
  " download/to_app_server write via zcl_js_fs, open/show are no-ops here.
  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF mc_extension,
        xlsx TYPE string VALUE 'xlsx',
        csv  TYPE string VALUE 'csv',
        docx TYPE string VALUE 'docx',
        html TYPE string VALUE 'html',
        pdf  TYPE string VALUE 'pdf',
      END OF mc_extension.

    DATA mv_xstring TYPE xstring READ-ONLY.

    METHODS constructor
      IMPORTING iv_file_name TYPE csequence OPTIONAL
                iv_xstring   TYPE xstring OPTIONAL.

    METHODS download
      IMPORTING iv_full_path         TYPE csequence OPTIONAL
                iv_save_dialog       TYPE abap_bool DEFAULT abap_false
                iv_window_title      TYPE csequence OPTIONAL
                iv_default_extension TYPE string OPTIONAL
                iv_default_filename  TYPE string OPTIONAL
                iv_file_filter       TYPE string OPTIONAL
                iv_filetype          TYPE char10 DEFAULT 'BIN'
      RETURNING VALUE(ro_file)       TYPE REF TO zcl_eui_file
      RAISING   zcx_eui_exception.

    METHODS to_app_server
      IMPORTING iv_full_path TYPE csequence
                iv_overwrite TYPE abap_bool DEFAULT abap_true
      RAISING   zcx_eui_exception.

    METHODS get_full_path
      RETURNING VALUE(rv_full_path) TYPE string.

    METHODS open
      RAISING zcx_eui_exception.

    METHODS open_by_ole
      IMPORTING iv_visible TYPE abap_bool DEFAULT abap_true
      CHANGING  cv_ole_app TYPE any OPTIONAL
                cv_ole_doc TYPE any OPTIONAL
      RAISING   zcx_eui_exception.

    METHODS show
      IMPORTING io_handler TYPE REF TO object OPTIONAL
      RAISING   zcx_eui_exception.

    CLASS-METHODS split_file_path
      IMPORTING iv_fullpath   TYPE csequence
      EXPORTING ev_path       TYPE csequence
                ev_filename   TYPE csequence
                ev_file_noext TYPE csequence
                ev_extension  TYPE csequence.

    CLASS-METHODS file_exist
      IMPORTING iv_full_path    TYPE csequence
      RETURNING VALUE(rv_exist) TYPE abap_bool.
  PRIVATE SECTION.
    DATA mv_file_name TYPE string.
    DATA mv_full_path TYPE string.
ENDCLASS.

CLASS zcl_eui_file IMPLEMENTATION.

  METHOD constructor.
    mv_file_name = iv_file_name.
    mv_xstring = iv_xstring.
  ENDMETHOD.

  METHOD download.
    DATA lv_path TYPE string.
    lv_path = iv_full_path.
    IF lv_path IS INITIAL.
      lv_path = |data/{ mv_file_name }|.
    ENDIF.
    zcl_js_fs=>write_file_x( iv_path = lv_path
                             iv_data = mv_xstring ).
    mv_full_path = lv_path.
    ro_file = me.
  ENDMETHOD.

  METHOD to_app_server.
    DATA lv_path TYPE string.
    lv_path = iv_full_path.
    zcl_js_fs=>write_file_x( iv_path = lv_path
                             iv_data = mv_xstring ).
    mv_full_path = lv_path.
  ENDMETHOD.

  METHOD get_full_path.
    rv_full_path = mv_full_path.
  ENDMETHOD.

  METHOD open.
    " no GUI here: the file is already on disk under mv_full_path
    RETURN.
  ENDMETHOD.

  METHOD open_by_ole.
    " no OLE without SAP GUI - intentionally a no-op
    RETURN.
  ENDMETHOD.

  METHOD show.
    " inplace display is not available - file stays on disk
    RETURN.
  ENDMETHOD.

  METHOD split_file_path.
    DATA lv_full TYPE string.
    DATA lv_len  TYPE i.
    DATA lv_idx  TYPE i.
    DATA lv_char TYPE c LENGTH 1.
    DATA lv_name TYPE string.
    DATA lv_dot  TYPE i.

    lv_full = iv_fullpath.
    CLEAR: ev_path, ev_filename, ev_file_noext, ev_extension.

    " path / filename
    lv_name = lv_full.
    lv_len = strlen( lv_full ).
    lv_idx = lv_len.
    WHILE lv_idx > 0.
      lv_idx = lv_idx - 1.
      lv_char = lv_full+lv_idx(1).
      IF lv_char = '/' OR lv_char = '\'.
        DATA lv_off TYPE i.
        lv_off = lv_idx + 1.
        ev_path = lv_full(lv_off).
        lv_name = lv_full+lv_off.
        EXIT.
      ENDIF.
    ENDWHILE.
    ev_filename = lv_name.

    " extension
    ev_file_noext = lv_name.
    lv_len = strlen( lv_name ).
    lv_idx = lv_len.
    WHILE lv_idx > 0.
      lv_idx = lv_idx - 1.
      lv_char = lv_name+lv_idx(1).
      IF lv_char = '.'.
        lv_dot = lv_idx + 1.
        ev_extension = lv_name+lv_dot.
        ev_file_noext = lv_name(lv_idx).
        EXIT.
      ENDIF.
    ENDWHILE.
  ENDMETHOD.

  METHOD file_exist.
    DATA lv_path TYPE string.
    lv_path = iv_full_path.
    rv_exist = zcl_js_fs=>file_exists( lv_path ).
  ENDMETHOD.

ENDCLASS.
