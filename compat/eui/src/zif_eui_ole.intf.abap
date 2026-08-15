INTERFACE zif_eui_ole PUBLIC.
  " local-abap compat for bizhuka/eui (Apache-2.0): the OLE surface xtt needs.
  " xtt only ever calls save_as, and only after checking the reference is bound
  " (zcl_xtt_xml_base~download). Without a SAP GUI zcl_eui_file=>open_by_ole
  " returns an unbound reference, so nothing here is ever executed - the
  " interface exists to make the ZIF_XTT~DOWNLOAD signature resolve.
  METHODS save_as
    IMPORTING iv_path       TYPE csequence
              iv_ext_format TYPE i
              iv_quit       TYPE abap_bool.
ENDINTERFACE.
