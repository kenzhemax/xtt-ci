CLASS zcl_eui_conv DEFINITION PUBLIC FINAL CREATE PUBLIC.
  " local-abap compat for bizhuka/eui (Apache-2.0): conversion helpers used by
  " the xtt core. Original: https://github.com/bizhuka/eui
  PUBLIC SECTION.
    TYPES abap_encoding TYPE c LENGTH 20.

    CONSTANTS:
      BEGIN OF mc_encoding,
        win_1251 TYPE abap_encoding VALUE '1504',
        utf_8    TYPE abap_encoding VALUE '4110',
        utf_16be TYPE abap_encoding VALUE '4102',
        utf_16le TYPE abap_encoding VALUE '4103',
      END OF mc_encoding.

    CLASS-METHODS string_to_xstring
      IMPORTING iv_string          TYPE string
                iv_encoding        TYPE abap_encoding DEFAULT mc_encoding-utf_8
      RETURNING VALUE(rv_xstring)  TYPE xstring.

    CLASS-METHODS xstring_to_string
      IMPORTING iv_xstring       TYPE xstring
                iv_encoding      TYPE abap_encoding DEFAULT mc_encoding-utf_8
      RETURNING VALUE(rv_string) TYPE string.

    CLASS-METHODS string_to_text_table
      IMPORTING iv_string TYPE string
      EXPORTING et_text   TYPE STANDARD TABLE
                ev_length TYPE i.

    CLASS-METHODS xstring_to_binary
      IMPORTING iv_xstring TYPE xstring
      EXPORTING ev_length  TYPE i
                et_table   TYPE solix_tab.

    CLASS-METHODS xstring_to_base64
      IMPORTING iv_xstring       TYPE xstring
      RETURNING VALUE(rv_base64) TYPE string.

    CLASS-METHODS xml_to_str
      IMPORTING io_doc  TYPE REF TO if_ixml_document
      EXPORTING ev_str  TYPE string
                ev_xstr TYPE xstring.

    CLASS-METHODS str_to_xml
      IMPORTING iv_str        TYPE string OPTIONAL
                iv_xstr       TYPE xstring OPTIONAL
      RETURNING VALUE(ro_doc) TYPE REF TO if_ixml_document.

    CLASS-METHODS xml_from_zip
      IMPORTING io_zip    TYPE REF TO cl_abap_zip
                iv_name   TYPE csequence
      EXPORTING eo_xmldoc TYPE REF TO if_ixml_document
                ev_sdoc   TYPE string.

    CLASS-METHODS xml_to_zip
      IMPORTING io_zip    TYPE REF TO cl_abap_zip
                iv_name   TYPE string
                iv_xdoc   TYPE xstring OPTIONAL
                iv_sdoc   TYPE string OPTIONAL
                io_xmldoc TYPE REF TO if_ixml_document OPTIONAL.

    CLASS-METHODS guid_create
      RETURNING VALUE(rv_guid) TYPE sysuuid_c32.

    CLASS-METHODS assert_equals
      IMPORTING exp                     TYPE any
                act                     TYPE any
                msg                     TYPE csequence OPTIONAL
                level                   TYPE any OPTIONAL
                tol                     TYPE f OPTIONAL
                quit                    TYPE any OPTIONAL
                ignore_hash_sequence    TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(assertion_failed) TYPE abap_bool.
ENDCLASS.

CLASS zcl_eui_conv IMPLEMENTATION.

  METHOD string_to_xstring.
    DATA lo_conv TYPE REF TO cl_abap_conv_out_ce.
    lo_conv = cl_abap_conv_out_ce=>create( ).
    lo_conv->convert( EXPORTING data   = iv_string
                      IMPORTING buffer = rv_xstring ).
  ENDMETHOD.

  METHOD xstring_to_string.
    DATA lo_conv TYPE REF TO cl_abap_conv_in_ce.
    lo_conv = cl_abap_conv_in_ce=>create( input = iv_xstring ).
    lo_conv->read( IMPORTING data = rv_string ).
  ENDMETHOD.

  METHOD string_to_text_table.
    DATA lv_string TYPE string.
    lv_string = iv_string.
    CLEAR et_text.
    ev_length = strlen( lv_string ).
    SPLIT lv_string AT cl_abap_char_utilities=>newline INTO TABLE et_text.
  ENDMETHOD.

  METHOD xstring_to_binary.
    DATA ls_line   TYPE solix.
    DATA lv_offset TYPE i.
    DATA lv_left   TYPE i.
    DATA lv_chunk  TYPE i.

    CLEAR et_table.
    ev_length = xstrlen( iv_xstring ).
    lv_offset = 0.
    WHILE lv_offset < ev_length.
      lv_left = ev_length - lv_offset.
      IF lv_left > 255.
        lv_chunk = 255.
      ELSE.
        lv_chunk = lv_left.
      ENDIF.
      CLEAR ls_line.
      ls_line-line = iv_xstring+lv_offset(lv_chunk).
      APPEND ls_line TO et_table.
      lv_offset = lv_offset + lv_chunk.
    ENDWHILE.
  ENDMETHOD.

  METHOD xstring_to_base64.
    WRITE '@KERNEL rv_base64.set(Buffer.from(iv_xstring.get(), "hex").toString("base64"));'.
  ENDMETHOD.

  METHOD xml_to_str.
    DATA li_ixml     TYPE REF TO if_ixml.
    DATA li_ostream  TYPE REF TO if_ixml_ostream.
    DATA li_renderer TYPE REF TO if_ixml_renderer.
    DATA li_factory  TYPE REF TO if_ixml_stream_factory.
    DATA lv_str      TYPE string.

    li_ixml = cl_ixml=>create( ).
    li_factory = li_ixml->create_stream_factory( ).
    li_ostream = li_factory->create_ostream_cstring( string = lv_str ).
    li_renderer = li_ixml->create_renderer( ostream  = li_ostream
                                            document = io_doc ).
    li_renderer->render( ).

    IF ev_str IS REQUESTED.
      ev_str = lv_str.
    ENDIF.
    IF ev_xstr IS REQUESTED.
      ev_xstr = string_to_xstring( lv_str ).
    ENDIF.
  ENDMETHOD.

  METHOD str_to_xml.
    DATA li_ixml    TYPE REF TO if_ixml.
    DATA li_factory TYPE REF TO if_ixml_stream_factory.
    DATA li_istream TYPE REF TO if_ixml_istream.
    DATA li_parser  TYPE REF TO if_ixml_parser.
    DATA lv_str     TYPE string.

    lv_str = iv_str.
    IF lv_str IS INITIAL AND iv_xstr IS NOT INITIAL.
      lv_str = xstring_to_string( iv_xstr ).
    ENDIF.

    li_ixml = cl_ixml=>create( ).
    ro_doc = li_ixml->create_document( ).
    li_factory = li_ixml->create_stream_factory( ).
    li_istream = li_factory->create_istream_string( lv_str ).
    li_parser = li_ixml->create_parser( document       = ro_doc
                                        istream        = li_istream
                                        stream_factory = li_factory ).
    li_parser->parse( ).
  ENDMETHOD.

  METHOD xml_from_zip.
    DATA lv_content TYPE xstring.
    DATA lv_name    TYPE string.

    lv_name = iv_name.
    io_zip->get( EXPORTING name    = lv_name
                 IMPORTING content = lv_content
                 EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF ev_sdoc IS REQUESTED.
      ev_sdoc = xstring_to_string( lv_content ).
    ENDIF.
    IF eo_xmldoc IS REQUESTED.
      eo_xmldoc = str_to_xml( iv_xstr = lv_content ).
    ENDIF.
  ENDMETHOD.

  METHOD xml_to_zip.
    DATA lv_content TYPE xstring.

    IF iv_xdoc IS NOT INITIAL.
      lv_content = iv_xdoc.
    ELSEIF iv_sdoc IS NOT INITIAL.
      lv_content = string_to_xstring( iv_sdoc ).
    ELSEIF io_xmldoc IS NOT INITIAL.
      xml_to_str( EXPORTING io_doc  = io_xmldoc
                  IMPORTING ev_xstr = lv_content ).
    ENDIF.

    io_zip->delete( EXPORTING name = iv_name EXCEPTIONS OTHERS = 1 ). "#EC CI_SUBRC
    io_zip->add( name    = iv_name
                 content = lv_content ).
  ENDMETHOD.

  METHOD guid_create.
    rv_guid = cl_system_uuid=>create_uuid_c32_static( ).
  ENDMETHOD.

  METHOD assert_equals.
    cl_abap_unit_assert=>assert_equals( act = act
                                        exp = exp
                                        msg = msg ).
  ENDMETHOD.

ENDCLASS.
