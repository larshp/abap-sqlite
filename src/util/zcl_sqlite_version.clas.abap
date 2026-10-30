CLASS zcl_sqlite_version DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_version TYPE string VALUE '0.1.0'.

    CLASS-METHODS get
      RETURNING
        VALUE(rv_version) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_sqlite_version IMPLEMENTATION.
  METHOD get.
    rv_version = c_version.
  ENDMETHOD.
ENDCLASS.
