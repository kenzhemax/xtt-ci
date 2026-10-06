INTERFACE if_fp PUBLIC.
  " xtt-ci compat: Adobe Forms (FP) entry point, only what zcl_xtt_pdf
  " declares. On open-abap zcl_xtt_pdf returns the merged XDP itself
  " (sy-saprl = 'OPEN') and never renders a PDF, so nothing here runs.
  METHODS create_pdf_object
    IMPORTING connection    TYPE string OPTIONAL
    RETURNING VALUE(result) TYPE REF TO if_fp_pdf_object
    RAISING   cx_fp_exception.
ENDINTERFACE.
