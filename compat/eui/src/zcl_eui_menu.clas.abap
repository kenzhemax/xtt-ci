CLASS zcl_eui_menu DEFINITION PUBLIC CREATE PUBLIC.
  " local-abap compat for bizhuka/eui (Apache-2.0): GUI menus do not exist here
  PUBLIC SECTION.
    CLASS-METHODS can_show
      RETURNING VALUE(rv_ok) TYPE abap_bool.
ENDCLASS.

CLASS zcl_eui_menu IMPLEMENTATION.

  METHOD can_show.
    rv_ok = abap_false.
  ENDMETHOD.

ENDCLASS.
