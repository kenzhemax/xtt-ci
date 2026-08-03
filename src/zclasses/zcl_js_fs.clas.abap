CLASS zcl_js_fs DEFINITION PUBLIC FINAL CREATE PUBLIC.
  " Thin bridge to node:fs via the transpiler's @KERNEL mechanism.
  " On a real SAP system this class would be reimplemented (GUI_UPLOAD etc.).
  PUBLIC SECTION.
    CLASS-METHODS write_file
      IMPORTING iv_path TYPE string
                iv_data TYPE string.

    CLASS-METHODS read_file
      IMPORTING iv_path        TYPE string
      RETURNING VALUE(rv_data) TYPE string.

    CLASS-METHODS file_exists
      IMPORTING iv_path          TYPE string
      RETURNING VALUE(rv_exists) TYPE abap_bool.

    " binary variants: xstring <-> file (xlsx, zip, images...)
    CLASS-METHODS write_file_x
      IMPORTING iv_path TYPE string
                iv_data TYPE xstring.

    CLASS-METHODS read_file_x
      IMPORTING iv_path        TYPE string
      RETURNING VALUE(rv_data) TYPE xstring.
ENDCLASS.

CLASS zcl_js_fs IMPLEMENTATION.

  METHOD write_file.
    WRITE '@KERNEL const fs = await import("node:fs");'.
    WRITE '@KERNEL const path = await import("node:path");'.
    WRITE '@KERNEL fs.mkdirSync(path.dirname(iv_path.get()), {recursive: true});'.
    WRITE '@KERNEL fs.writeFileSync(iv_path.get(), iv_data.get());'.
  ENDMETHOD.

  METHOD read_file.
    WRITE '@KERNEL const fs = await import("node:fs");'.
    WRITE '@KERNEL rv_data.set(fs.readFileSync(iv_path.get(), "utf8"));'.
  ENDMETHOD.

  METHOD file_exists.
    WRITE '@KERNEL const fs = await import("node:fs");'.
    WRITE '@KERNEL rv_exists.set(fs.existsSync(iv_path.get()) ? "X" : " ");'.
  ENDMETHOD.

  METHOD write_file_x.
    " xstring is represented as a hex string in the runtime
    WRITE '@KERNEL const fs = await import("node:fs");'.
    WRITE '@KERNEL const path = await import("node:path");'.
    WRITE '@KERNEL fs.mkdirSync(path.dirname(iv_path.get()), {recursive: true});'.
    WRITE '@KERNEL fs.writeFileSync(iv_path.get(), Buffer.from(iv_data.get().toLowerCase(), "hex"));'.
  ENDMETHOD.

  METHOD read_file_x.
    WRITE '@KERNEL const fs = await import("node:fs");'.
    WRITE '@KERNEL rv_data.set(fs.readFileSync(iv_path.get()).toString("hex").toUpperCase());'.
  ENDMETHOD.

ENDCLASS.
