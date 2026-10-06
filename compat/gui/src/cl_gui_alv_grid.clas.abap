CLASS cl_gui_alv_grid DEFINITION PUBLIC CREATE PUBLIC.
  " xtt-ci compat: just the event xtt's demo base class registers a handler
  " for. No grid is ever created here. (localABAP gets the full class from
  " open-abap-gui and does not use compat/gui.)
  PUBLIC SECTION.
    EVENTS user_command
      EXPORTING
        VALUE(e_ucomm) TYPE sy-ucomm OPTIONAL.
ENDCLASS.

CLASS cl_gui_alv_grid IMPLEMENTATION.
ENDCLASS.
