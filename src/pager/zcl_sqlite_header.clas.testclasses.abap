CLASS ltcl_header DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS all_fields FOR TESTING.
    METHODS page_size_65536 FOR TESTING.
    METHODS short_header FOR TESTING.

    METHODS build_header
      RETURNING VALUE(rv_data) TYPE xstring.
ENDCLASS.


CLASS ltcl_header IMPLEMENTATION.

  METHOD all_fields.
    DATA ls_header TYPE zcl_sqlite_header=>ty_header.

    TRY.
        ls_header = zcl_sqlite_header=>parse( build_header( ) ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( |synthetic header parse failed: { lo_error->message }| ).
    ENDTRY.

    cl_abap_unit_assert=>assert_equals( act = ls_header-page_size
                                        exp = 1024 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-write_version
                                        exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-read_version
                                        exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-reserved_bytes
                                        exp = 7 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-max_payload_fraction
                                        exp = 64 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-min_payload_fraction
                                        exp = 32 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-leaf_payload_fraction
                                        exp = 32 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-change_counter
                                        exp = 123456 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-database_size
                                        exp = 42 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-freelist_trunk
                                        exp = 41 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-freelist_pages
                                        exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-schema_cookie
                                        exp = 987 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-schema_format
                                        exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-default_cache_size
                                        exp = 17 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-largest_root_page
                                        exp = 42 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-text_encoding
                                        exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-user_version
                                        exp = 55 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-incremental_vacuum
                                        exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-application_id
                                        exp = 987654 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-version_valid_for
                                        exp = 123456 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-sqlite_version
                                        exp = 3054000 ).
  ENDMETHOD.

  METHOD page_size_65536.
    DATA lv_data TYPE xstring.
    DATA ls_header TYPE zcl_sqlite_header=>ty_header.

    TRY.
        lv_data = zcl_sqlite_bytes=>write_u16(
          iv_data   = build_header( )
          iv_offset = 16
          iv_value  = 1 ).
        ls_header = zcl_sqlite_header=>parse( lv_data ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_header-page_size
          exp = 65536 ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( |parse failed: { lo_error->message }| ).
      CATCH cx_sy_conversion_overflow cx_sy_range_out_of_bounds.
        cl_abap_unit_assert=>fail( 'could not build header' ).
    ENDTRY.
  ENDMETHOD.

  METHOD short_header.
    TRY.
        zcl_sqlite_header=>parse( zcl_sqlite_header=>c_magic ).
        cl_abap_unit_assert=>fail( 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_notadb ).
    ENDTRY.
  ENDMETHOD.

  METHOD build_header.
    DATA lv_header TYPE xstring.
    DATA lv_zeros TYPE xstring.

    lv_zeros = repeat( val = '00'
                       occ = 84 ).
    TRY.
        lv_header = zcl_sqlite_header=>c_magic && lv_zeros.
        lv_header = zcl_sqlite_bytes=>write_u16(
          iv_data   = lv_header
          iv_offset = 16
          iv_value  = 1024 ).
        lv_header = zcl_sqlite_bytes=>write_u8(
          iv_data   = lv_header
          iv_offset = 18
          iv_value  = 2 ).
        lv_header = zcl_sqlite_bytes=>write_u8(
          iv_data   = lv_header
          iv_offset = 19
          iv_value  = 2 ).
        lv_header = zcl_sqlite_bytes=>write_u8(
          iv_data   = lv_header
          iv_offset = 20
          iv_value  = 7 ).
        lv_header = zcl_sqlite_bytes=>write_u8(
          iv_data   = lv_header
          iv_offset = 21
          iv_value  = 64 ).
        lv_header = zcl_sqlite_bytes=>write_u8(
          iv_data   = lv_header
          iv_offset = 22
          iv_value  = 32 ).
        lv_header = zcl_sqlite_bytes=>write_u8(
          iv_data   = lv_header
          iv_offset = 23
          iv_value  = 32 ).
        lv_header = zcl_sqlite_bytes=>write_u32(
          iv_data   = lv_header
          iv_offset = 24
          iv_value  = 123456 ).
        lv_header = zcl_sqlite_bytes=>write_u32(
          iv_data   = lv_header
          iv_offset = 28
          iv_value  = 42 ).
        lv_header = zcl_sqlite_bytes=>write_u32(
          iv_data   = lv_header
          iv_offset = 32
          iv_value  = 41 ).
        lv_header = zcl_sqlite_bytes=>write_u32(
          iv_data   = lv_header
          iv_offset = 36
          iv_value  = 3 ).
        lv_header = zcl_sqlite_bytes=>write_u32(
          iv_data   = lv_header
          iv_offset = 40
          iv_value  = 987 ).
        lv_header = zcl_sqlite_bytes=>write_u32(
          iv_data   = lv_header
          iv_offset = 44
          iv_value  = 4 ).
        lv_header = zcl_sqlite_bytes=>write_u32(
          iv_data   = lv_header
          iv_offset = 48
          iv_value  = 17 ).
        lv_header = zcl_sqlite_bytes=>write_u32(
          iv_data   = lv_header
          iv_offset = 52
          iv_value  = 42 ).
        lv_header = zcl_sqlite_bytes=>write_u32(
          iv_data   = lv_header
          iv_offset = 56
          iv_value  = 2 ).
        lv_header = zcl_sqlite_bytes=>write_u32(
          iv_data   = lv_header
          iv_offset = 60
          iv_value  = 55 ).
        lv_header = zcl_sqlite_bytes=>write_u32(
          iv_data   = lv_header
          iv_offset = 64
          iv_value  = 2 ).
        lv_header = zcl_sqlite_bytes=>write_u32(
          iv_data   = lv_header
          iv_offset = 68
          iv_value  = 987654 ).
        lv_header = zcl_sqlite_bytes=>write_u32(
          iv_data   = lv_header
          iv_offset = 92
          iv_value  = 123456 ).
        lv_header = zcl_sqlite_bytes=>write_u32(
          iv_data   = lv_header
          iv_offset = 96
          iv_value  = 3054000 ).
      CATCH cx_sy_conversion_overflow cx_sy_range_out_of_bounds.
        cl_abap_unit_assert=>fail( 'could not build header' ).
    ENDTRY.
    rv_data = lv_header.
  ENDMETHOD.

ENDCLASS.
