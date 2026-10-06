CLASS cl_bds_document_set DEFINITION PUBLIC CREATE PUBLIC.
  " xtt-ci compat: Business Document Service (transaction OAOR) without a
  " document store. Every lookup finds nothing, which is what xtt's callers
  " handle: zcl_xtt_file_oaor reports "file not found" (test OAOR_NO_FILE) and
  " demo 100 skips an icon it cannot load (its icons come from ICON-S_RAW here).
  PUBLIC SECTION.
    TYPE-POOLS sbdst.

    CLASS-METHODS get_info
      IMPORTING  classname           TYPE sbdst_classname
                 classtype           TYPE sbdst_classtype
                 object_key          TYPE sbdst_object_key OPTIONAL
      EXPORTING  extended_components TYPE sbdst_components2
      CHANGING   signature           TYPE sbdst_signature OPTIONAL
                 components          TYPE sbdst_components OPTIONAL
      EXCEPTIONS error
                 nothing_found
                 parameter_error.

    CLASS-METHODS get_with_table
      IMPORTING  classname  TYPE sbdst_classname
                 classtype  TYPE sbdst_classtype
                 object_key TYPE sbdst_object_key OPTIONAL
      CHANGING   content    TYPE sbdst_content
                 components TYPE sbdst_components OPTIONAL
                 signature  TYPE sbdst_signature OPTIONAL
      EXCEPTIONS error
                 nothing_found
                 parameter_error.
ENDCLASS.

CLASS cl_bds_document_set IMPLEMENTATION.

  METHOD get_info.
    CLEAR: extended_components, signature, components.
  ENDMETHOD.

  METHOD get_with_table.
    CLEAR: content, components, signature.
  ENDMETHOD.

ENDCLASS.
