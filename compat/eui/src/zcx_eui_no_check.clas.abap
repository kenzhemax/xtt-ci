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
    lv_message = iv_message.
    IF lv_message IS INITIAL AND io_error IS NOT INITIAL.
      lv_message = io_error->get_text( ).
    ENDIF.
    RAISE EXCEPTION TYPE zcx_eui_no_check
      EXPORTING
        previous = io_error
        msgv1    = lv_message.
  ENDMETHOD.

  METHOD get_text.
    result = msgv1.
    IF result IS INITIAL.
      result = super->get_text( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
