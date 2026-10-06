INTERFACE if_fp_pdf_object PUBLIC.
  " xtt-ci compat: see if_fp
  METHODS set_template
    IMPORTING xftdata TYPE xstring
              fillable TYPE abap_bool OPTIONAL
    RAISING   cx_fp_exception.

  METHODS set_task_renderpdf
    IMPORTING changesrestricted TYPE c OPTIONAL
              printable         TYPE abap_bool OPTIONAL
    RAISING   cx_fp_exception.

  METHODS execute
    RAISING cx_fp_exception.

  METHODS get_pdf
    EXPORTING pdfdata TYPE xstring
    RAISING   cx_fp_exception.
ENDINTERFACE.
