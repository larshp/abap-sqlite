* Big endian integers and varints on byte strings, see the SQLite file format.
* Offsets and lengths are in bytes. A write needs the target to have room,
* bytes outside the written range are left unchanged.
* Float64 is decoded to sign, exponent and mantissa, because type f cannot
* carry infinity, NaN or the sign of zero on every platform.
CLASS zcl_sqlite_bytes DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_float64,
             sign     TYPE i,
             exponent TYPE i,
             mantissa TYPE int8,
           END OF ty_float64.

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

    CLASS-METHODS read_varint
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
      RETURNING VALUE(rv_value) TYPE int8
      RAISING   cx_sy_range_out_of_bounds.

    CLASS-METHODS varint_length
      IMPORTING iv_data          TYPE xstring
                iv_offset        TYPE i
      RETURNING VALUE(rv_length) TYPE i
      RAISING   cx_sy_range_out_of_bounds.

    CLASS-METHODS write_varint
      IMPORTING iv_value       TYPE int8
      RETURNING VALUE(rv_data) TYPE xstring.

    CLASS-METHODS read_f64
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
      RETURNING VALUE(rs_value) TYPE ty_float64
      RAISING   cx_sy_range_out_of_bounds.

    CLASS-METHODS write_f64
      IMPORTING is_value       TYPE ty_float64
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   cx_sy_conversion_overflow.

    CLASS-METHODS f64_to_f
      IMPORTING is_value        TYPE ty_float64
      RETURNING VALUE(rv_value) TYPE f
      RAISING   cx_sy_conversion_overflow.

    CLASS-METHODS f64_from_f
      IMPORTING iv_value        TYPE f
      RETURNING VALUE(rs_value) TYPE ty_float64.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_max_u8 TYPE int8 VALUE 255.
    CONSTANTS c_max_u16 TYPE int8 VALUE 65535.
    CONSTANTS c_max_u24 TYPE int8 VALUE 16777215.
    CONSTANTS c_max_u32 TYPE int8 VALUE 4294967295.
    CONSTANTS c_max_u48 TYPE int8 VALUE 281474976710655.
    CONSTANTS c_two_pow_55 TYPE int8 VALUE 36028797018963968.
    CONSTANTS c_two_pow_56 TYPE int8 VALUE 72057594037927936.
    CONSTANTS c_two_pow_20 TYPE int8 VALUE 1048576.
    CONSTANTS c_two_pow_31 TYPE int8 VALUE 2147483648.
    CONSTANTS c_two_pow_32 TYPE int8 VALUE 4294967296.
    CONSTANTS c_two_pow_52 TYPE int8 VALUE 4503599627370496.
    CONSTANTS c_two_pow_52_f TYPE f VALUE '4.503599627370496E+15'.
    CONSTANTS c_exponent_max TYPE i VALUE 2047.
    CONSTANTS c_quiet_nan TYPE int8 VALUE 2251799813685248.

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

  METHOD write_varint.
    DATA lv_value TYPE int8.
    DATA lv_byte TYPE int8.
    DATA lv_high TYPE int8.
    DATA lv_full TYPE x LENGTH 8.
    DATA lv_hex TYPE xstring.
    DATA lv_buffer TYPE xstring.
    DATA lv_pos TYPE i.
    DATA lv_length TYPE i.
    DATA lv_rest TYPE int8.

    lv_value = iv_value.

    IF lv_value >= 0 AND lv_value < c_two_pow_56.
* one to eight bytes, seven bits each
      IF lv_value = 0.
        rv_data = '00'.
        RETURN.
      ENDIF.

      lv_buffer = '000000000000000000'.
      lv_rest = lv_value DIV 128.
      lv_length = 1.
      WHILE lv_rest > 0.
        lv_length = lv_length + 1.
        lv_rest = lv_rest DIV 128.
      ENDWHILE.
      lv_pos = 9.
      DO lv_length TIMES.
        lv_pos = lv_pos - 1.
        lv_byte = lv_value MOD 128.
        lv_value = lv_value DIV 128.
        IF sy-index > 1.
          lv_byte = lv_byte + 128.
        ENDIF.
        lv_buffer = write_u8( iv_data = lv_buffer iv_offset = lv_pos iv_value = lv_byte ).
      ENDDO.
      rv_data = lv_buffer+lv_pos(lv_length).
      RETURN.
    ENDIF.

* nine bytes: eight groups of seven bits, then all eight bits of the last byte
    lv_full = iv_value.
    lv_hex = lv_full.
    lv_high = read_u48( iv_data = lv_hex iv_offset = 0 ) * 256
              + read_u8( iv_data = lv_hex iv_offset = 6 ).

    lv_buffer = '000000000000000000'.
    lv_buffer = write_u8( iv_data = lv_buffer iv_offset = 8
                          iv_value = read_u8( iv_data = lv_hex iv_offset = 7 ) ).
    lv_pos = 8.
    DO 8 TIMES.
      lv_pos = lv_pos - 1.
      lv_byte = lv_high MOD 128 + 128.
      lv_high = lv_high DIV 128.
      lv_buffer = write_u8( iv_data = lv_buffer iv_offset = lv_pos iv_value = lv_byte ).
    ENDDO.
    rv_data = lv_buffer.
  ENDMETHOD.

  METHOD read_varint.
    DATA lv_value TYPE int8.
    DATA lv_byte TYPE int8.
    DATA lv_high TYPE int8.
    DATA lv_low TYPE int8.

    DO 8 TIMES.
      lv_byte = read_u8( iv_data = iv_data iv_offset = iv_offset + sy-index - 1 ).
      IF lv_byte < 128.
        lv_value = lv_value * 128 + lv_byte.
        rv_value = lv_value.
        RETURN.
      ENDIF.
      lv_value = lv_value * 128 + lv_byte - 128.
    ENDDO.

* nine bytes, the last one contributes all eight bits
    lv_high = lv_value.
    lv_low = read_u8( iv_data = iv_data iv_offset = iv_offset + 8 ).
    IF lv_high >= c_two_pow_55.
      rv_value = ( lv_high - c_two_pow_56 ) * 256 + lv_low.
    ELSE.
      rv_value = lv_high * 256 + lv_low.
    ENDIF.
  ENDMETHOD.

  METHOD varint_length.
    DATA lv_byte TYPE int8.

    DO 8 TIMES.
      lv_byte = read_u8( iv_data = iv_data iv_offset = iv_offset + sy-index - 1 ).
      IF lv_byte < 128.
        rv_length = sy-index.
        RETURN.
      ENDIF.
    ENDDO.

    lv_byte = read_u8( iv_data = iv_data iv_offset = iv_offset + 8 ).
    rv_length = 9.
  ENDMETHOD.

  METHOD read_f64.
    DATA lv_high TYPE int8.
    DATA lv_low TYPE int8.

    lv_high = read_u32( iv_data = iv_data iv_offset = iv_offset ).
    lv_low = read_u32( iv_data = iv_data iv_offset = iv_offset + 4 ).

    rs_value-sign = lv_high DIV c_two_pow_31.
    rs_value-exponent = ( lv_high DIV c_two_pow_20 ) MOD 2048.
    rs_value-mantissa = ( lv_high MOD c_two_pow_20 ) * c_two_pow_32 + lv_low.
  ENDMETHOD.

  METHOD write_f64.
    DATA lv_high TYPE int8.
    DATA lv_low TYPE int8.

    IF is_value-sign < 0 OR is_value-sign > 1
        OR is_value-exponent < 0 OR is_value-exponent > c_exponent_max
        OR is_value-mantissa < 0 OR is_value-mantissa >= c_two_pow_52.
      RAISE EXCEPTION TYPE cx_sy_conversion_overflow.
    ENDIF.

    lv_high = is_value-sign * c_two_pow_31
            + is_value-exponent * c_two_pow_20
            + is_value-mantissa DIV c_two_pow_32.
    lv_low = is_value-mantissa MOD c_two_pow_32.

    rv_data = '0000000000000000'.
    rv_data = write_u32( iv_data = rv_data iv_offset = 0 iv_value = lv_high ).
    rv_data = write_u32( iv_data = rv_data iv_offset = 4 iv_value = lv_low ).
  ENDMETHOD.

  METHOD f64_to_f.
    DATA lv_fraction TYPE f.
    DATA lv_mantissa TYPE f.
    DATA lv_power TYPE f.
    DATA lv_shift TYPE i.

    IF is_value-exponent = c_exponent_max.
* infinity and NaN are outside the ABAP f value range
      RAISE EXCEPTION TYPE cx_sy_conversion_overflow.
    ENDIF.

* ANORMALY: mixed int8/f arithmetic truncates in the transpiler, convert first,
* see ANORMALIES.md
    lv_mantissa = is_value-mantissa.

    IF is_value-exponent = 0.
      IF is_value-mantissa = 0.
* ABAP f has no signed zero
        rv_value = 0.
        RETURN.
      ENDIF.
* subnormal: mantissa * 2^-1074, scaled as (mantissa / 2^52) * 2^-1022
      lv_fraction = lv_mantissa / c_two_pow_52_f.
      lv_shift = -1022.
    ELSE.
      lv_fraction = 1 + lv_mantissa / c_two_pow_52_f.
      lv_shift = is_value-exponent - 1023.
    ENDIF.

    lv_power = 1.
    IF lv_shift >= 0.
      DO lv_shift TIMES.
        lv_power = lv_power * 2.
      ENDDO.
    ELSE.
      lv_shift = 0 - lv_shift.
      DO lv_shift TIMES.
        lv_power = lv_power / 2.
      ENDDO.
    ENDIF.

    IF is_value-sign = 1.
      rv_value = ( 0 - lv_fraction ) * lv_power.
    ELSE.
      rv_value = lv_fraction * lv_power.
    ENDIF.
  ENDMETHOD.

  METHOD f64_from_f.
    DATA lv_abs TYPE f.
    DATA lv_norm TYPE f.
    DATA lv_exp TYPE i.
    DATA lv_fraction TYPE f.
    DATA lv_steps TYPE i.

    IF iv_value <> iv_value.
* NaN, only reachable where f carries IEEE special values
      rs_value-exponent = c_exponent_max.
      rs_value-mantissa = c_quiet_nan.
      RETURN.
    ENDIF.

    IF iv_value < 0.
      rs_value-sign = 1.
      lv_abs = 0 - iv_value.
    ELSE.
      rs_value-sign = 0.
      lv_abs = iv_value.
    ENDIF.

    IF lv_abs = 0.
* the sign of zero is lost, ABAP f does not carry it
      RETURN.
    ENDIF.

    lv_norm = lv_abs.
    lv_exp = 0.
    WHILE lv_norm >= 2 AND lv_exp < 1024.
      lv_norm = lv_norm / 2.
      lv_exp = lv_exp + 1.
    ENDWHILE.
    IF lv_exp >= 1024.
* infinity, only reachable where f carries IEEE special values
      rs_value-exponent = c_exponent_max.
      RETURN.
    ENDIF.
    WHILE lv_norm < 1.
      lv_norm = lv_norm * 2.
      lv_exp = lv_exp - 1.
    ENDWHILE.

    IF lv_exp < -1022.
* subnormal: the mantissa is the value on the 2^-1074 grid
      rs_value-exponent = 0.
      lv_steps = lv_exp + 1074.
      DO lv_steps TIMES.
        lv_norm = lv_norm * 2.
      ENDDO.
      rs_value-mantissa = lv_norm.
      RETURN.
    ENDIF.

    rs_value-exponent = lv_exp + 1023.
    lv_fraction = lv_norm - 1.
    rs_value-mantissa = lv_fraction * c_two_pow_52_f.
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
