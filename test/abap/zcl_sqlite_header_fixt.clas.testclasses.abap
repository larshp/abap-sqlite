CLASS ltcl_header DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_empty TYPE string VALUE 'fixtures/empty.db'.
    CONSTANTS c_small TYPE string VALUE 'fixtures/small.db'.

    METHODS empty_fixture FOR TESTING.
    METHODS small_fixture FOR TESTING.
    METHODS bad_magic FOR TESTING.
    METHODS bad_page_size FOR TESTING.
    METHODS bad_text_encoding FOR TESTING.

    METHODS assert_fixture
      IMPORTING iv_name          TYPE string
                iv_database_size TYPE int8
                iv_schema_format TYPE int8.
    METHODS fixture
      IMPORTING iv_name        TYPE string
      RETURNING VALUE(rv_data) TYPE xstring.
ENDCLASS.


CLASS ltcl_header IMPLEMENTATION.

  METHOD empty_fixture.
    assert_fixture( iv_name          = c_empty
                    iv_database_size = 1
                    iv_schema_format = 0 ).
  ENDMETHOD.

  METHOD small_fixture.
    assert_fixture( iv_name          = c_small
                    iv_database_size = 2
                    iv_schema_format = 4 ).
  ENDMETHOD.

  METHOD assert_fixture.
    DATA ls_header TYPE zcl_sqlite_header=>ty_header.

    TRY.
        ls_header = zcl_sqlite_header=>parse( fixture( iv_name ) ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( |{ iv_name } parse failed: { lo_error->message }| ).
    ENDTRY.

* the expectations are the PRAGMA values written to the fixture JSON
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-page_size
      exp = 4096
      msg = |{ iv_name } page_size| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-database_size
      exp = iv_database_size
      msg = |{ iv_name } page_count| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-text_encoding
      exp = zcl_sqlite_header=>c_encoding_utf8
      msg = |{ iv_name } encoding| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-freelist_pages
      exp = 0
      msg = |{ iv_name } freelist_count| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-schema_cookie
      exp = 1
      msg = |{ iv_name } schema_version| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-schema_format
      exp = iv_schema_format
      msg = |{ iv_name } schema_format| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-user_version
      exp = 0
      msg = |{ iv_name } user_version| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-application_id
      exp = 0
      msg = |{ iv_name } application_id| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-write_version
      exp = 1
      msg = |{ iv_name } journal_mode| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-read_version
      exp = 1
      msg = |{ iv_name } journal_mode| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-largest_root_page
      exp = 0
      msg = |{ iv_name } auto_vacuum| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-incremental_vacuum
      exp = 0
      msg = |{ iv_name } auto_vacuum| ).
  ENDMETHOD.

  METHOD bad_magic.
    DATA lv_data TYPE xstring.

    TRY.
        lv_data = fixture( c_empty ).
        lv_data = zcl_sqlite_bytes=>write_u8(
          iv_data   = lv_data
          iv_offset = 0
          iv_value  = 0 ).
        zcl_sqlite_header=>parse( lv_data ).
        cl_abap_unit_assert=>fail( 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_notadb ).
      CATCH cx_sy_conversion_overflow cx_sy_range_out_of_bounds.
        cl_abap_unit_assert=>fail( 'could not modify fixture' ).
    ENDTRY.
  ENDMETHOD.

  METHOD bad_page_size.
    DATA lv_data TYPE xstring.

    TRY.
        lv_data = fixture( c_empty ).
        lv_data = zcl_sqlite_bytes=>write_u16(
          iv_data   = lv_data
          iv_offset = 16
          iv_value  = 1000 ).
        zcl_sqlite_header=>parse( lv_data ).
        cl_abap_unit_assert=>fail( 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_notadb ).
      CATCH cx_sy_conversion_overflow cx_sy_range_out_of_bounds.
        cl_abap_unit_assert=>fail( 'could not modify fixture' ).
    ENDTRY.
  ENDMETHOD.

  METHOD bad_text_encoding.
    DATA lv_data TYPE xstring.

    TRY.
        lv_data = fixture( c_empty ).
        lv_data = zcl_sqlite_bytes=>write_u32(
          iv_data   = lv_data
          iv_offset = 56
          iv_value  = 4 ).
        zcl_sqlite_header=>parse( lv_data ).
        cl_abap_unit_assert=>fail( 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_corrupt ).
      CATCH cx_sy_conversion_overflow cx_sy_range_out_of_bounds.
        cl_abap_unit_assert=>fail( 'could not modify fixture' ).
    ENDTRY.
  ENDMETHOD.

  METHOD fixture.
    DATA lo_vfs TYPE REF TO zcl_sqlite_vfs_table.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    rv_data = lo_vfs->export( iv_name ).
  ENDMETHOD.

ENDCLASS.
