CLASS zcx_eui_exception DEFINITION PUBLIC INHERITING FROM cx_static_check CREATE PUBLIC.
  " local-abap compat for bizhuka/eui (Apache-2.0): minimal exception surface
  " used by the xtt core. Original: https://github.com/bizhuka/eui
  PUBLIC SECTION.
    DATA msgv1 TYPE string.
    DATA msgv2 TYPE string.
    DATA msgv3 TYPE string.
    DATA msgv4 TYPE string.

    METHODS constructor
      IMPORTING previous TYPE REF TO cx_root OPTIONAL
                msgv1    TYPE csequence OPTIONAL
                msgv2    TYPE csequence OPTIONAL
                msgv3    TYPE csequence OPTIONAL
                msgv4    TYPE csequence OPTIONAL.

    CLASS-METHODS raise_sys_error
      IMPORTING iv_message TYPE csequence OPTIONAL
                io_error   TYPE REF TO cx_root OPTIONAL
      RAISING   zcx_eui_exception.

    CLASS-METHODS raise_dump
      IMPORTING iv_message TYPE csequence OPTIONAL
                io_error   TYPE REF TO cx_root OPTIONAL.

    METHODS get_text REDEFINITION.
ENDCLASS.

CLASS zcx_eui_exception IMPLEMENTATION.

  METHOD constructor.
    super->constructor( previous = previous ).
    me->msgv1 = msgv1.
    me->msgv2 = msgv2.
    me->msgv3 = msgv3.
    me->msgv4 = msgv4.
  ENDMETHOD.

  METHOD raise_sys_error.
    DATA lv_message TYPE string.
    lv_message = iv_message.
    IF lv_message IS INITIAL AND io_error IS NOT INITIAL.
      lv_message = io_error->get_text( ).
    ENDIF.
    RAISE EXCEPTION TYPE zcx_eui_exception
      EXPORTING
        previous = io_error
        msgv1    = lv_message.
  ENDMETHOD.

  METHOD raise_dump.
    DATA lv_message TYPE string.
    lv_message = iv_message.
    IF lv_message IS INITIAL AND io_error IS NOT INITIAL.
      lv_message = io_error->get_text( ).
    ENDIF.
    WRITE / |zcx_eui_exception=>raise_dump: { lv_message }|.
    ASSERT 1 = 2.
  ENDMETHOD.

  METHOD get_text.
    result = |{ msgv1 } { msgv2 } { msgv3 } { msgv4 }|.
    CONDENSE result.
    IF result IS INITIAL.
      result = super->get_text( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
