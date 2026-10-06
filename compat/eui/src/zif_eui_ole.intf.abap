INTERFACE zif_eui_ole PUBLIC.
  " local-abap compat for bizhuka/eui (Apache-2.0): the OLE surface xtt needs.
  " Without a SAP GUI zcl_eui_file=>open_by_ole returns an unbound reference
  " and zcl_eui_file->mo_ole stays unbound, so nothing here is ever executed:
  " xtt (zcl_xtt_xml_base~download, save_as) and its demo 070 (mv_ole_app,
  " call_method, get/set_property) check the reference first. The interface
  " exists to make those calls resolve.
  DATA mv_ole_app TYPE ole2_object READ-ONLY.

  METHODS call_method
    IMPORTING io_object        TYPE ole2_object OPTIONAL
              iv_method        TYPE csequence
              iv_param1        TYPE any OPTIONAL
              iv_param2        TYPE any OPTIONAL
              iv_param3        TYPE any OPTIONAL
              iv_param4        TYPE any OPTIONAL
              iv_param5        TYPE any OPTIONAL
              iv_param6        TYPE any OPTIONAL
              iv_param7        TYPE any OPTIONAL
    RETURNING VALUE(ro_result) TYPE ole2_object.

  METHODS get_property
    IMPORTING io_object        TYPE ole2_object OPTIONAL
              iv_prop          TYPE csequence
    RETURNING VALUE(ro_result) TYPE ole2_object.

  METHODS set_property
    IMPORTING io_object TYPE ole2_object OPTIONAL
              iv_prop   TYPE csequence
              iv_value  TYPE any.

  METHODS save_as
    IMPORTING iv_path       TYPE csequence
              iv_ext_format TYPE i
              iv_quit       TYPE abap_bool.
ENDINTERFACE.
