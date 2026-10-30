* A dynamically typed SQLite value. Instances are created through the static
* factory methods and are read-only afterwards.
CLASS zcl_sqlite_value DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CONSTANTS c_null    TYPE i VALUE 0.
    CONSTANTS c_integer TYPE i VALUE 1.
    CONSTANTS c_real    TYPE i VALUE 2.
    CONSTANTS c_text    TYPE i VALUE 3.
    CONSTANTS c_blob    TYPE i VALUE 4.

    CLASS-METHODS null
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value.

    CLASS-METHODS integer
      IMPORTING iv_value        TYPE int8
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value.

    CLASS-METHODS real
      IMPORTING iv_value        TYPE f
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value.

    CLASS-METHODS text
      IMPORTING iv_value        TYPE string
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value.

    CLASS-METHODS blob
      IMPORTING iv_value        TYPE xstring
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value.

    METHODS value_type
      RETURNING VALUE(rv_type) TYPE i.

    METHODS is_null
      RETURNING VALUE(rv_is_null) TYPE abap_bool.

    METHODS as_integer
      RETURNING VALUE(rv_value) TYPE int8.

    METHODS as_real
      RETURNING VALUE(rv_value) TYPE f.

    METHODS as_text
      RETURNING VALUE(rv_text) TYPE string.

    METHODS as_blob
      RETURNING VALUE(rv_blob) TYPE xstring.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mv_type TYPE i.
    DATA mv_integer TYPE int8.
    DATA mv_real TYPE f.
    DATA mv_text TYPE string.
    DATA mv_blob TYPE xstring.

    METHODS constructor.
ENDCLASS.


CLASS zcl_sqlite_value IMPLEMENTATION.

  METHOD null.
    ro_value = NEW zcl_sqlite_value( ).
    ro_value->mv_type = c_null.
  ENDMETHOD.

  METHOD integer.
    ro_value = NEW zcl_sqlite_value( ).
    ro_value->mv_type = c_integer.
    ro_value->mv_integer = iv_value.
  ENDMETHOD.

  METHOD real.
    ro_value = NEW zcl_sqlite_value( ).
    ro_value->mv_type = c_real.
    ro_value->mv_real = iv_value.
  ENDMETHOD.

  METHOD text.
    ro_value = NEW zcl_sqlite_value( ).
    ro_value->mv_type = c_text.
    ro_value->mv_text = iv_value.
  ENDMETHOD.

  METHOD blob.
    ro_value = NEW zcl_sqlite_value( ).
    ro_value->mv_type = c_blob.
    ro_value->mv_blob = iv_value.
  ENDMETHOD.

  METHOD value_type.
    rv_type = mv_type.
  ENDMETHOD.

  METHOD is_null.
    rv_is_null = boolc( mv_type = c_null ).
  ENDMETHOD.

  METHOD as_integer.
    rv_value = mv_integer.
  ENDMETHOD.

  METHOD as_real.
    rv_value = mv_real.
  ENDMETHOD.

  METHOD as_text.
    rv_text = mv_text.
  ENDMETHOD.

  METHOD as_blob.
    rv_blob = mv_blob.
  ENDMETHOD.

  METHOD constructor.
  ENDMETHOD.

ENDCLASS.
