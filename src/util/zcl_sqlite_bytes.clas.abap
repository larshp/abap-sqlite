* Big endian integer access on byte strings, see the SQLite file format.
* Offsets and lengths are in bytes. A write needs the target to have room,
* bytes outside the written range are left unchanged.
CLASS zcl_sqlite_bytes DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS read_u8
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
      RETURNING VALUE(rv_value) TYPE int8
      RAISING   cx_sy_range_out_of_bounds.

    CLASS-METHODS read_u16
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
      RETURNING VALUE(rv_value) TYPE int8
      RAISING   cx_sy_range_out_of_bounds.

    CLASS-METHODS read_u24
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
      RETURNING VALUE(rv_value) TYPE int8
      RAISING   cx_sy_range_out_of_bounds.

    CLASS-METHODS read_u32
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
      RETURNING VALUE(rv_value) TYPE int8
      RAISING   cx_sy_range_out_of_bounds.

    CLASS-METHODS read_u48
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
      RETURNING VALUE(rv_value) TYPE int8
      RAISING   cx_sy_range_out_of_bounds.

    CLASS-METHODS read_i64
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
      RETURNING VALUE(rv_value) TYPE int8
      RAISING   cx_sy_range_out_of_bounds.

    CLASS-METHODS write_u8
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE int8
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   cx_sy_range_out_of_bounds
                cx_sy_conversion_overflow.

    CLASS-METHODS write_u16
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE int8
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   cx_sy_range_out_of_bounds
                cx_sy_conversion_overflow.

    CLASS-METHODS write_u24
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE int8
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   cx_sy_range_out_of_bounds
                cx_sy_conversion_overflow.

    CLASS-METHODS write_u32
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE int8
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   cx_sy_range_out_of_bounds
                cx_sy_conversion_overflow.

    CLASS-METHODS write_u48
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE int8
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   cx_sy_range_out_of_bounds
                cx_sy_conversion_overflow.

    CLASS-METHODS write_i64
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE int8
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   cx_sy_range_out_of_bounds.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_max_u8 TYPE int8 VALUE 255.
    CONSTANTS c_max_u16 TYPE int8 VALUE 65535.
    CONSTANTS c_max_u24 TYPE int8 VALUE 16777215.
    CONSTANTS c_max_u32 TYPE int8 VALUE 4294967295.
    CONSTANTS c_max_u48 TYPE int8 VALUE 281474976710655.

    CLASS-METHODS read_bytes
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
                iv_length       TYPE i
      RETURNING VALUE(rv_value) TYPE int8
      RAISING   cx_sy_range_out_of_bounds.

    CLASS-METHODS write_bytes
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE int8
                iv_length      TYPE i
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   cx_sy_range_out_of_bounds.

    CLASS-METHODS check_unsigned
      IMPORTING iv_value TYPE int8
                iv_max   TYPE int8
      RAISING   cx_sy_conversion_overflow.

    CLASS-METHODS check_bounds
      IMPORTING iv_data   TYPE xstring
                iv_offset TYPE i
                iv_length TYPE i
      RAISING   cx_sy_range_out_of_bounds.
ENDCLASS.


CLASS zcl_sqlite_bytes IMPLEMENTATION.

  METHOD read_u8.
    rv_value = read_bytes( iv_data = iv_data iv_offset = iv_offset iv_length = 1 ).
  ENDMETHOD.

  METHOD read_u16.
    rv_value = read_bytes( iv_data = iv_data iv_offset = iv_offset iv_length = 2 ).
  ENDMETHOD.

  METHOD read_u24.
    rv_value = read_bytes( iv_data = iv_data iv_offset = iv_offset iv_length = 3 ).
  ENDMETHOD.

  METHOD read_u32.
    rv_value = read_bytes( iv_data = iv_data iv_offset = iv_offset iv_length = 4 ).
  ENDMETHOD.

  METHOD read_u48.
    rv_value = read_bytes( iv_data = iv_data iv_offset = iv_offset iv_length = 6 ).
  ENDMETHOD.

  METHOD read_i64.
    rv_value = read_bytes( iv_data = iv_data iv_offset = iv_offset iv_length = 8 ).
  ENDMETHOD.

  METHOD write_u8.
    check_unsigned( iv_value = iv_value iv_max = c_max_u8 ).
    rv_data = write_bytes( iv_data = iv_data iv_offset = iv_offset
                           iv_value = iv_value iv_length = 1 ).
  ENDMETHOD.

  METHOD write_u16.
    check_unsigned( iv_value = iv_value iv_max = c_max_u16 ).
    rv_data = write_bytes( iv_data = iv_data iv_offset = iv_offset
                           iv_value = iv_value iv_length = 2 ).
  ENDMETHOD.

  METHOD write_u24.
    check_unsigned( iv_value = iv_value iv_max = c_max_u24 ).
    rv_data = write_bytes( iv_data = iv_data iv_offset = iv_offset
                           iv_value = iv_value iv_length = 3 ).
  ENDMETHOD.

  METHOD write_u32.
    check_unsigned( iv_value = iv_value iv_max = c_max_u32 ).
    rv_data = write_bytes( iv_data = iv_data iv_offset = iv_offset
                           iv_value = iv_value iv_length = 4 ).
  ENDMETHOD.

  METHOD write_u48.
    check_unsigned( iv_value = iv_value iv_max = c_max_u48 ).
    rv_data = write_bytes( iv_data = iv_data iv_offset = iv_offset
                           iv_value = iv_value iv_length = 6 ).
  ENDMETHOD.

  METHOD write_i64.
    rv_data = write_bytes( iv_data = iv_data iv_offset = iv_offset
                           iv_value = iv_value iv_length = 8 ).
  ENDMETHOD.

  METHOD read_bytes.
    DATA lv_bytes TYPE xstring.

    check_bounds( iv_data = iv_data iv_offset = iv_offset iv_length = iv_length ).
    lv_bytes = iv_data+iv_offset(iv_length).
    rv_value = lv_bytes.
  ENDMETHOD.

  METHOD write_bytes.
    DATA lv_full TYPE x LENGTH 8.
    DATA lv_hex TYPE xstring.
    DATA lv_start TYPE i.
    DATA lv_tail TYPE i.
    DATA lv_before TYPE xstring.
    DATA lv_after TYPE xstring.

    check_bounds( iv_data = iv_data iv_offset = iv_offset iv_length = iv_length ).

    lv_full = iv_value.
    lv_hex = lv_full.
    lv_start = 8 - iv_length.
    lv_hex = lv_hex+lv_start(iv_length).

* ANORMALY: xstring+off(len) in writer position with a variable offset/length
* is rejected by abaplint and the transpiler, see ANORMALIES.md. Glue the
* three parts instead.
    lv_before = iv_data+0(iv_offset).
    lv_tail = iv_offset + iv_length.
    IF lv_tail < xstrlen( iv_data ).
      lv_after = iv_data+lv_tail.
    ENDIF.
    rv_data = lv_before && lv_hex && lv_after.
  ENDMETHOD.

  METHOD check_unsigned.
    IF iv_value < 0 OR iv_value > iv_max.
      RAISE EXCEPTION TYPE cx_sy_conversion_overflow.
    ENDIF.
  ENDMETHOD.

  METHOD check_bounds.
    IF iv_offset < 0 OR iv_offset + iv_length > xstrlen( iv_data ).
      RAISE EXCEPTION TYPE cx_sy_range_out_of_bounds.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
