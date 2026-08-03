CLASS zcl_eui_logger DEFINITION PUBLIC CREATE PUBLIC.
  " local-abap compat for bizhuka/eui (Apache-2.0): message collector with the
  " API surface the xtt core uses. GUI popups become WRITE output.
  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF mc_msg_types,
        all     TYPE string VALUE 'EAXWIS',
        error   TYPE string VALUE 'EAX',
        warning TYPE string VALUE 'W',
      END OF mc_msg_types.

    CONSTANTS:
      BEGIN OF mc_profile,
        popup      TYPE i VALUE 1,
        no_tree    TYPE i VALUE 2,
        standard   TYPE i VALUE 3,
        single_msg TYPE i VALUE 4,
      END OF mc_profile.

    " add message from sy fields (iv_syst path) or explicit symsg
    METHODS add
      IMPORTING iv_msgty TYPE csequence OPTIONAL
                is_msg   TYPE symsg OPTIONAL.

    METHODS add_text
      IMPORTING iv_text  TYPE csequence
                iv_msgty TYPE csequence DEFAULT 'E'.

    METHODS add_exception
      IMPORTING io_exception TYPE REF TO cx_root
                iv_msgty     TYPE csequence DEFAULT 'E'.

    METHODS add_batch
      IMPORTING it_messages TYPE sfb_t_bal_s_msg.

    METHODS get_messages
      RETURNING VALUE(rt_messages) TYPE sfb_t_bal_s_msg.

    " suppress a specific message (used by docx->html delegation)
    METHODS skip
      IMPORTING iv_msgid TYPE csequence
                iv_msgno TYPE any
                iv_msgty TYPE csequence OPTIONAL.

    METHODS has_messages
      IMPORTING iv_msg_types  TYPE csequence DEFAULT mc_msg_types-all
      RETURNING VALUE(rv_has) TYPE abap_bool.

    METHODS show
      IMPORTING iv_profile TYPE i DEFAULT mc_profile-standard
                is_profile TYPE bal_s_prof OPTIONAL.

    METHODS show_as_button
      IMPORTING is_profile TYPE bal_s_prof OPTIONAL.

    METHODS clear.
  PRIVATE SECTION.
    TYPES: BEGIN OF ts_skip,
             msgid TYPE symsgid,
             msgno TYPE symsgno,
           END OF ts_skip.
    DATA mt_messages TYPE sfb_t_bal_s_msg.
    DATA mt_skip     TYPE STANDARD TABLE OF ts_skip WITH DEFAULT KEY.

    METHODS is_skipped
      IMPORTING is_msg            TYPE bal_s_msg
      RETURNING VALUE(rv_skipped) TYPE abap_bool.
ENDCLASS.

CLASS zcl_eui_logger IMPLEMENTATION.

  METHOD add.
    DATA ls_msg TYPE bal_s_msg.
    IF is_msg IS NOT INITIAL.
      ls_msg-msgty = is_msg-msgty.
      ls_msg-msgid = is_msg-msgid.
      ls_msg-msgno = is_msg-msgno.
      ls_msg-msgv1 = is_msg-msgv1.
      ls_msg-msgv2 = is_msg-msgv2.
      ls_msg-msgv3 = is_msg-msgv3.
      ls_msg-msgv4 = is_msg-msgv4.
    ELSE.
      ls_msg-msgty = sy-msgty.
      ls_msg-msgid = sy-msgid.
      ls_msg-msgno = sy-msgno.
      ls_msg-msgv1 = sy-msgv1.
      ls_msg-msgv2 = sy-msgv2.
      ls_msg-msgv3 = sy-msgv3.
      ls_msg-msgv4 = sy-msgv4.
    ENDIF.
    IF iv_msgty IS NOT INITIAL.
      ls_msg-msgty = iv_msgty.
    ENDIF.
    IF is_skipped( ls_msg ) = abap_false.
      APPEND ls_msg TO mt_messages.
    ENDIF.
  ENDMETHOD.

  METHOD add_text.
    DATA ls_msg  TYPE bal_s_msg.
    DATA lv_text TYPE string.
    DATA lv_len  TYPE i.
    ls_msg-msgty = iv_msgty.
    ls_msg-msgid = 'ZLOCAL'.
    ls_msg-msgno = '000'.
    lv_text = iv_text.
    " spread long texts over msgv1..msgv4 (50 chars each)
    lv_len = strlen( lv_text ).
    IF lv_len > 0.
      ls_msg-msgv1 = lv_text.
    ENDIF.
    IF lv_len > 50.
      ls_msg-msgv2 = lv_text+50.
    ENDIF.
    IF lv_len > 100.
      ls_msg-msgv3 = lv_text+100.
    ENDIF.
    IF lv_len > 150.
      ls_msg-msgv4 = lv_text+150.
    ENDIF.
    IF is_skipped( ls_msg ) = abap_false.
      APPEND ls_msg TO mt_messages.
    ENDIF.
  ENDMETHOD.

  METHOD add_exception.
    add_text( iv_text  = io_exception->get_text( )
              iv_msgty = iv_msgty ).
  ENDMETHOD.

  METHOD add_batch.
    DATA ls_msg TYPE bal_s_msg.
    LOOP AT it_messages INTO ls_msg.
      IF is_skipped( ls_msg ) = abap_false.
        APPEND ls_msg TO mt_messages.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_messages.
    rt_messages = mt_messages.
  ENDMETHOD.

  METHOD skip.
    DATA ls_skip TYPE ts_skip.
    ls_skip-msgid = iv_msgid.
    ls_skip-msgno = iv_msgno.
    APPEND ls_skip TO mt_skip.
    " and drop already collected ones
    DELETE mt_messages WHERE msgid = ls_skip-msgid AND msgno = ls_skip-msgno.
  ENDMETHOD.

  METHOD is_skipped.
    READ TABLE mt_skip TRANSPORTING NO FIELDS
      WITH KEY msgid = is_msg-msgid msgno = is_msg-msgno.
    rv_skipped = boolc( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD has_messages.
    DATA ls_msg TYPE bal_s_msg.
    DATA lv_ty  TYPE string.
    LOOP AT mt_messages INTO ls_msg.
      lv_ty = ls_msg-msgty.
      IF iv_msg_types CS lv_ty.
        rv_has = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD show.
    DATA ls_msg TYPE bal_s_msg.
    LOOP AT mt_messages INTO ls_msg.
      WRITE / |[xtt log { ls_msg-msgty }] { ls_msg-msgid } { ls_msg-msgno }: { ls_msg-msgv1 }{ ls_msg-msgv2 }{ ls_msg-msgv3 }{ ls_msg-msgv4 }|.
    ENDLOOP.
  ENDMETHOD.

  METHOD show_as_button.
    RETURN. " GUI toolbar button - not available here
  ENDMETHOD.

  METHOD clear.
    CLEAR mt_messages.
  ENDMETHOD.

ENDCLASS.
