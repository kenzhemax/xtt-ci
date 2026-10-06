CLASS zcx_eui_no_check DEFINITION PUBLIC INHERITING FROM cx_no_check CREATE PUBLIC.
  " local-abap compat for bizhuka/eui (Apache-2.0): minimal surface for xtt
  PUBLIC SECTION.
    DATA msgv1  TYPE string.
    DATA ms_msg TYPE symsg READ-ONLY.

    METHODS constructor
      IMPORTING previous TYPE REF TO cx_root OPTIONAL
                msgv1    TYPE csequence OPTIONAL
                is_msg   TYPE symsg OPTIONAL.

    CLASS-METHODS raise_sys_error
      IMPORTING iv_message TYPE csequence OPTIONAL
                io_error   TYPE REF TO cx_root OPTIONAL
      RAISING   zcx_eui_no_check.

    METHODS get_text REDEFINITION.
ENDCLASS.

CLASS zcx_eui_no_check IMPLEMENTATION.

  METHOD constructor.
    super->constructor( previous = previous ).
    me->msgv1 = msgv1.
    me->ms_msg = is_msg.
  ENDMETHOD.

  METHOD raise_sys_error.
    DATA lv_message TYPE string.
    DATA ls_msg     TYPE symsg.
    lv_message = iv_message.
    IF lv_message IS INITIAL AND io_error IS NOT INITIAL.
      lv_message = io_error->get_text( ).
    ENDIF.
    " neither text nor exception: the error is the last MESSAGE ... INTO,
    " kept as is so the logger records its message class and number
    IF lv_message IS INITIAL.
      ls_msg-msgty = sy-msgty.
      ls_msg-msgid = sy-msgid.
      ls_msg-msgno = sy-msgno.
      ls_msg-msgv1 = sy-msgv1.
      ls_msg-msgv2 = sy-msgv2.
      ls_msg-msgv3 = sy-msgv3.
      ls_msg-msgv4 = sy-msgv4.
      MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_message.
    ENDIF.
    RAISE EXCEPTION TYPE zcx_eui_no_check
      EXPORTING
        previous = io_error
        msgv1    = lv_message
        is_msg   = ls_msg.
  ENDMETHOD.

  METHOD get_text.
    result = msgv1.
    IF result IS INITIAL.
      result = super->get_text( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
