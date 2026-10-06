CLASS cl_fp DEFINITION PUBLIC FINAL CREATE PRIVATE.
  " xtt-ci compat: see if_fp. There is no Adobe Document Services here,
  " get_reference returns nothing.
  PUBLIC SECTION.
    CLASS-METHODS get_reference
      RETURNING VALUE(result) TYPE REF TO if_fp.
ENDCLASS.

CLASS cl_fp IMPLEMENTATION.
  METHOD get_reference.
    CLEAR result.
  ENDMETHOD.
ENDCLASS.
