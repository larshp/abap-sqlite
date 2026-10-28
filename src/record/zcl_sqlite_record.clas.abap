* Decoder for SQLite records, see
* https://www.sqlite.org/fileformat.html#record_format
*
* The input is one complete record payload. Overflow reassembly happens before
* this class is called.
CLASS zcl_sqlite_record DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_values TYPE STANDARD TABLE OF REF TO zcl_sqlite_value
      WITH DEFAULT KEY.

    CLASS-METHODS decode
      IMPORTING iv_data          TYPE xstring
      RETURNING VALUE(rt_values) TYPE ty_values
      RAISING   zcx_sqlite_error.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES ty_serial_types TYPE STANDARD TABLE OF int8 WITH DEFAULT KEY.

    CONSTANTS c_two_pow_7  TYPE int8 VALUE 128.
    CONSTANTS c_two_pow_8  TYPE int8 VALUE 256.
    CONSTANTS c_two_pow_15 TYPE int8 VALUE 32768.
    CONSTANTS c_two_pow_16 TYPE int8 VALUE 65536.
    CONSTANTS c_two_pow_23 TYPE int8 VALUE 8388608.
    CONSTANTS c_two_pow_24 TYPE int8 VALUE 16777216.
    CONSTANTS c_two_pow_31 TYPE int8 VALUE 2147483648.
    CONSTANTS c_two_pow_32 TYPE int8 VALUE 4294967296.
    CONSTANTS c_two_pow_47 TYPE int8 VALUE 140737488355328.
    CONSTANTS c_two_pow_48 TYPE int8 VALUE 281474976710656.

    CLASS-METHODS parse_header
      IMPORTING iv_data                TYPE xstring
      EXPORTING ev_header_end          TYPE i
      RETURNING VALUE(rt_serial_types) TYPE ty_serial_types
      RAISING   zcx_sqlite_error.

    CLASS-METHODS decode_body
      IMPORTING iv_data          TYPE xstring
                iv_header_end    TYPE i
                it_serial_types  TYPE ty_serial_types
      RETURNING VALUE(rt_values) TYPE ty_values
      RAISING   zcx_sqlite_error.

    CLASS-METHODS decode_value
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
                iv_length       TYPE i
                iv_serial_type  TYPE int8
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS decode_real
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
      RETURNING VALUE(rv_value) TYPE f
      RAISING   zcx_sqlite_error.

    CLASS-METHODS decode_text
      IMPORTING iv_data        TYPE xstring
      RETURNING VALUE(rv_text) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS serial_length
      IMPORTING iv_serial_type   TYPE int8
      RETURNING VALUE(rv_length) TYPE int8
      RAISING   zcx_sqlite_error.

    CLASS-METHODS decode_integer
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
                iv_length       TYPE i
      RETURNING VALUE(rv_value) TYPE int8
      RAISING   zcx_sqlite_error.

    CLASS-METHODS fail
      IMPORTING iv_message TYPE string
      RAISING   zcx_sqlite_error.
ENDCLASS.


CLASS zcl_sqlite_record IMPLEMENTATION.

  METHOD decode.
    DATA lt_serial_types TYPE ty_serial_types.
    DATA lv_header_end TYPE i.

    lt_serial_types = parse_header(
      EXPORTING iv_data = iv_data
      IMPORTING ev_header_end = lv_header_end ).
    rt_values = decode_body(
      iv_data = iv_data
      iv_header_end = lv_header_end
      it_serial_types = lt_serial_types ).
  ENDMETHOD.

  METHOD parse_header.
    DATA lv_data_length TYPE i.
    DATA lv_header_size TYPE int8.
    DATA lv_header_varint TYPE i.
    DATA lv_header_pos TYPE i.
    DATA lv_serial_type TYPE int8.
    DATA lv_serial_varint TYPE i.

    lv_data_length = xstrlen( iv_data ).
    IF lv_data_length = 0.
      fail( 'record is empty' ).
    ENDIF.

    TRY.
        lv_header_size = zcl_sqlite_bytes=>read_varint(
          iv_data = iv_data iv_offset = 0 ).
        lv_header_varint = zcl_sqlite_bytes=>varint_length(
          iv_data = iv_data iv_offset = 0 ).
      CATCH cx_sy_range_out_of_bounds.
        fail( 'record header is truncated' ).
    ENDTRY.

    IF lv_header_size < lv_header_varint
        OR lv_header_size > lv_data_length.
      fail( 'record header length is invalid' ).
    ENDIF.
    ev_header_end = lv_header_size.

    lv_header_pos = lv_header_varint.
    WHILE lv_header_pos < ev_header_end.
      TRY.
          lv_serial_type = zcl_sqlite_bytes=>read_varint(
            iv_data = iv_data iv_offset = lv_header_pos ).
          lv_serial_varint = zcl_sqlite_bytes=>varint_length(
            iv_data = iv_data iv_offset = lv_header_pos ).
        CATCH cx_sy_range_out_of_bounds.
          fail( 'record serial type is truncated' ).
      ENDTRY.
      IF lv_serial_type < 0.
        fail( 'record serial type is invalid' ).
      ENDIF.
      IF lv_header_pos + lv_serial_varint > ev_header_end.
        fail( 'record serial type crosses the header boundary' ).
      ENDIF.
      APPEND lv_serial_type TO rt_serial_types.
      lv_header_pos = lv_header_pos + lv_serial_varint.
    ENDWHILE.
  ENDMETHOD.

  METHOD decode_body.
    DATA lv_data_length TYPE i.
    DATA lv_body_pos TYPE i.
    DATA lv_serial_type TYPE int8.
    DATA lv_length_i8 TYPE int8.
    DATA lv_length TYPE i.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lv_data_length = xstrlen( iv_data ).
    lv_body_pos = iv_header_end.
    LOOP AT it_serial_types INTO lv_serial_type.
      lv_length_i8 = serial_length( lv_serial_type ).
      IF lv_length_i8 > lv_data_length - lv_body_pos.
        fail( 'record value is truncated' ).
      ENDIF.
      lv_length = lv_length_i8.
      lo_value = decode_value(
        iv_data = iv_data
        iv_offset = lv_body_pos
        iv_length = lv_length
        iv_serial_type = lv_serial_type ).
      APPEND lo_value TO rt_values.
      lv_body_pos = lv_body_pos + lv_length.
    ENDLOOP.
  ENDMETHOD.

  METHOD decode_value.
    DATA lv_piece TYPE xstring.
    DATA lv_empty_blob TYPE xstring.
    DATA lv_empty_text TYPE string.

    IF iv_serial_type = 0.
      ro_value = zcl_sqlite_value=>null( ).
    ELSEIF iv_serial_type <= 6.
      ro_value = zcl_sqlite_value=>integer( decode_integer(
        iv_data = iv_data
        iv_offset = iv_offset
        iv_length = iv_length ) ).
    ELSEIF iv_serial_type = 7.
      ro_value = zcl_sqlite_value=>real( decode_real(
        iv_data = iv_data
        iv_offset = iv_offset ) ).
    ELSEIF iv_serial_type = 8.
      ro_value = zcl_sqlite_value=>integer( 0 ).
    ELSEIF iv_serial_type = 9.
      ro_value = zcl_sqlite_value=>integer( 1 ).
    ELSEIF iv_serial_type = 12.
      ro_value = zcl_sqlite_value=>blob( lv_empty_blob ).
    ELSEIF iv_serial_type = 13.
      ro_value = zcl_sqlite_value=>text( lv_empty_text ).
    ELSE.
      lv_piece = iv_data+iv_offset(iv_length).
      IF iv_serial_type MOD 2 = 0.
        ro_value = zcl_sqlite_value=>blob( lv_piece ).
      ELSE.
        ro_value = zcl_sqlite_value=>text( decode_text( lv_piece ) ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD decode_real.
    DATA ls_float TYPE zcl_sqlite_bytes=>ty_float64.

    TRY.
        ls_float = zcl_sqlite_bytes=>read_f64(
          iv_data = iv_data iv_offset = iv_offset ).
        rv_value = zcl_sqlite_bytes=>f64_to_f( ls_float ).
      CATCH cx_sy_range_out_of_bounds.
        fail( 'record real value is truncated' ).
      CATCH cx_sy_conversion_overflow.
        fail( 'record real value is out of range' ).
    ENDTRY.
  ENDMETHOD.

  METHOD decode_text.
    TRY.
        rv_text = zcl_sqlite_utf8=>decode( iv_data ).
      CATCH cx_sy_conversion_codepage.
        fail( 'record text is not valid UTF-8' ).
    ENDTRY.
  ENDMETHOD.

  METHOD serial_length.
    CASE iv_serial_type.
      WHEN 0.
        rv_length = 0.
      WHEN 1.
        rv_length = 1.
      WHEN 2.
        rv_length = 2.
      WHEN 3.
        rv_length = 3.
      WHEN 4.
        rv_length = 4.
      WHEN 5.
        rv_length = 6.
      WHEN 6.
        rv_length = 8.
      WHEN 7.
        rv_length = 8.
      WHEN 8.
        rv_length = 0.
      WHEN 9.
        rv_length = 0.
      WHEN 10.
        fail( 'record has a reserved serial type' ).
      WHEN 11.
        fail( 'record has a reserved serial type' ).
      WHEN 12.
        rv_length = 0.
      WHEN 13.
        rv_length = 0.
      WHEN OTHERS.
        IF iv_serial_type MOD 2 = 0.
          rv_length = ( iv_serial_type - 12 ) DIV 2.
        ELSE.
          rv_length = ( iv_serial_type - 13 ) DIV 2.
        ENDIF.
    ENDCASE.
  ENDMETHOD.

  METHOD decode_integer.
    DATA lv_unsigned TYPE int8.
    DATA lv_limit TYPE int8.
    DATA lv_modulus TYPE int8.

    TRY.
        CASE iv_length.
          WHEN 1.
            lv_unsigned = zcl_sqlite_bytes=>read_u8(
              iv_data = iv_data iv_offset = iv_offset ).
            lv_limit = c_two_pow_7.
            lv_modulus = c_two_pow_8.
          WHEN 2.
            lv_unsigned = zcl_sqlite_bytes=>read_u16(
              iv_data = iv_data iv_offset = iv_offset ).
            lv_limit = c_two_pow_15.
            lv_modulus = c_two_pow_16.
          WHEN 3.
            lv_unsigned = zcl_sqlite_bytes=>read_u24(
              iv_data = iv_data iv_offset = iv_offset ).
            lv_limit = c_two_pow_23.
            lv_modulus = c_two_pow_24.
          WHEN 4.
            lv_unsigned = zcl_sqlite_bytes=>read_u32(
              iv_data = iv_data iv_offset = iv_offset ).
            lv_limit = c_two_pow_31.
            lv_modulus = c_two_pow_32.
          WHEN 6.
            lv_unsigned = zcl_sqlite_bytes=>read_u48(
              iv_data = iv_data iv_offset = iv_offset ).
            lv_limit = c_two_pow_47.
            lv_modulus = c_two_pow_48.
          WHEN 8.
            rv_value = zcl_sqlite_bytes=>read_i64(
              iv_data = iv_data iv_offset = iv_offset ).
            RETURN.
          WHEN OTHERS.
            fail( 'record integer length is invalid' ).
        ENDCASE.
      CATCH cx_sy_range_out_of_bounds.
        fail( 'record integer is truncated' ).
    ENDTRY.

    IF lv_unsigned >= lv_limit.
      rv_value = lv_unsigned - lv_modulus.
    ELSE.
      rv_value = lv_unsigned.
    ENDIF.
  ENDMETHOD.

  METHOD fail.
    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = zcx_sqlite_error=>sqlite_corrupt
        iv_message = iv_message.
  ENDMETHOD.

ENDCLASS.
