* UTF-8 text conversion, the text encoding used by the SQLite files here.
* The conversions use CL_ABAP_CONV_CODEPAGE, so they behave the same on the
* transpiler and on a real SAP system.
CLASS zcl_sqlite_utf8 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS encode
      IMPORTING iv_text        TYPE string
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   cx_sy_conversion_codepage.

    CLASS-METHODS decode
      IMPORTING iv_data        TYPE xstring
      RETURNING VALUE(rv_text) TYPE string
      RAISING   cx_sy_conversion_codepage.

    CLASS-METHODS byte_length
      IMPORTING iv_text          TYPE string
      RETURNING VALUE(rv_length) TYPE i
      RAISING   cx_sy_conversion_codepage.

  PRIVATE SECTION.
    CLASS-DATA go_out TYPE REF TO if_abap_conv_out.
    CLASS-DATA go_in TYPE REF TO if_abap_conv_in.
ENDCLASS.


CLASS zcl_sqlite_utf8 IMPLEMENTATION.

  METHOD encode.
    IF go_out IS INITIAL.
      go_out = cl_abap_conv_codepage=>create_out( codepage = 'UTF-8' ).
    ENDIF.
    rv_data = go_out->convert( iv_text ).
  ENDMETHOD.

  METHOD decode.
    IF go_in IS INITIAL.
      go_in = cl_abap_conv_codepage=>create_in( codepage = 'UTF-8' ).
    ENDIF.
    rv_text = go_in->convert( iv_data ).
  ENDMETHOD.

  METHOD byte_length.
    rv_length = xstrlen( encode( iv_text ) ).
  ENDMETHOD.

ENDCLASS.
