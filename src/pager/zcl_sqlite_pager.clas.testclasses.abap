CLASS ltcl_pager DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_fixture TYPE string VALUE 'fixtures/three_pages.db'.
    CONSTANTS c_file TYPE string VALUE 'm5_1_pager.db'.
    CONSTANTS c_page_size TYPE i VALUE 4096.

    DATA mo_vfs TYPE REF TO zif_sqlite_vfs.

    METHODS fetch_pages FOR TESTING.
    METHODS cache_lru FOR TESTING.
    METHODS invalid_page FOR TESTING.
    METHODS write_commit FOR TESTING.
    METHODS write_rollback FOR TESTING.
    METHODS dirty_survives_cache FOR TESTING.
    METHODS header_maintenance FOR TESTING.
    METHODS commit_without_changes FOR TESTING.
    METHODS invalid_write FOR TESTING.

    METHODS open_pager
      IMPORTING iv_cache_size   TYPE i
      RETURNING VALUE(ro_pager) TYPE REF TO zcl_sqlite_pager.
    METHODS open_writable_pager
      IMPORTING iv_cache_size   TYPE i
      RETURNING VALUE(ro_pager) TYPE REF TO zcl_sqlite_pager.
    METHODS fixture
      RETURNING VALUE(rv_data) TYPE xstring.
    METHODS file_data
      RETURNING VALUE(rv_data) TYPE xstring.
    METHODS page_data
      IMPORTING iv_data        TYPE xstring
                iv_page        TYPE i
      RETURNING VALUE(rv_data) TYPE xstring.
    METHODS change_byte
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE int8
      RETURNING VALUE(rv_data) TYPE xstring.
ENDCLASS.


CLASS ltcl_pager IMPLEMENTATION.

  METHOD fetch_pages.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA ls_page TYPE zcl_sqlite_pager=>ty_page.
    DATA lv_all TYPE xstring.
    DATA lv_page TYPE xstring.
    DATA lv_page_size TYPE i.
    DATA lv_offset TYPE i.

    lo_pager = open_pager( 2 ).
    lv_all = fixture( ).
    lv_page_size = lo_pager->page_size( ).

    cl_abap_unit_assert=>assert_equals( act = lv_page_size exp = 4096 ).
    cl_abap_unit_assert=>assert_true( act = boolc( lo_pager->page_count( ) >= 3 ) ).

    TRY.
        ls_page = lo_pager->get_page( 1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_page-number exp = 1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_page-btree_offset exp = 100 ).
        cl_abap_unit_assert=>assert_equals(
          act = xstrlen( ls_page-data ) exp = lv_page_size ).
        lv_page = lv_all+0(lv_page_size).
        cl_abap_unit_assert=>assert_equals( act = ls_page-data exp = lv_page ).

        ls_page = lo_pager->get_page( 2 ).
        cl_abap_unit_assert=>assert_equals( act = ls_page-number exp = 2 ).
        cl_abap_unit_assert=>assert_equals( act = ls_page-btree_offset exp = 0 ).
        lv_offset = lv_page_size.
        lv_page = lv_all+lv_offset(lv_page_size).
        cl_abap_unit_assert=>assert_equals( act = ls_page-data exp = lv_page ).

        ls_page = lo_pager->get_page( 3 ).
        cl_abap_unit_assert=>assert_equals( act = ls_page-number exp = 3 ).
        lv_offset = lv_page_size * 2.
        lv_page = lv_all+lv_offset(lv_page_size).
        cl_abap_unit_assert=>assert_equals( act = ls_page-data exp = lv_page ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |page fetch failed: { lo_error->message }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD cache_lru.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA ls_stats TYPE zcl_sqlite_pager=>ty_stats.

    lo_pager = open_pager( 2 ).

    TRY.
        lo_pager->get_page( 1 ).
        lo_pager->get_page( 2 ).
        lo_pager->get_page( 1 ).
        lo_pager->get_page( 3 ).
        lo_pager->get_page( 2 ).
        lo_pager->get_page( 1 ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |page fetch failed: { lo_error->message }| ).
    ENDTRY.

    ls_stats = lo_pager->stats( ).
    cl_abap_unit_assert=>assert_equals( act = ls_stats-hits exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_stats-misses exp = 5 ).
    cl_abap_unit_assert=>assert_equals( act = ls_stats-evictions exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = ls_stats-entries exp = 2 ).
  ENDMETHOD.

  METHOD invalid_page.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.

    lo_pager = open_pager( 2 ).

    TRY.
        lo_pager->get_page( 0 ).
        cl_abap_unit_assert=>fail( msg = 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code exp = zcx_sqlite_error=>sqlite_corrupt ).
    ENDTRY.
  ENDMETHOD.

  METHOD write_commit.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lv_original TYPE xstring.
    DATA lv_modified TYPE xstring.
    DATA lv_file TYPE xstring.

    lo_pager = open_writable_pager( 2 ).

    TRY.
        lv_original = lo_pager->get_page( 2 )-data.
        lv_modified = change_byte(
          iv_data   = lv_original
          iv_offset = 0
          iv_value  = 170 ).

        lo_pager->put_page( iv_page = 2 iv_data = lv_modified ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->dirty_page_count( ) exp = 1 ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->get_page( 2 )-data exp = lv_modified ).

* copy-on-write: the file still has the old page
        lv_file = file_data( ).
        cl_abap_unit_assert=>assert_equals(
          act = page_data( iv_data = lv_file iv_page = 2 )
          exp = lv_original ).

        lo_pager->commit( ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->dirty_page_count( ) exp = 0 ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |write failed: { lo_error->message }| ).
    ENDTRY.

    lv_file = file_data( ).
    cl_abap_unit_assert=>assert_equals(
      act = page_data( iv_data = lv_file iv_page = 2 )
      exp = lv_modified ).
  ENDMETHOD.

  METHOD write_rollback.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lv_original TYPE xstring.
    DATA lv_modified TYPE xstring.
    DATA lv_file TYPE xstring.

    lo_pager = open_writable_pager( 2 ).

    TRY.
        lv_original = lo_pager->get_page( 2 )-data.
        lv_modified = change_byte(
          iv_data   = lv_original
          iv_offset = 10
          iv_value  = 187 ).

        lo_pager->put_page( iv_page = 2 iv_data = lv_modified ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->get_page( 2 )-data exp = lv_modified ).

        lo_pager->rollback( ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->dirty_page_count( ) exp = 0 ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->get_page( 2 )-data exp = lv_original ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |rollback failed: { lo_error->message }| ).
    ENDTRY.

    lv_file = file_data( ).
    cl_abap_unit_assert=>assert_equals(
      act = page_data( iv_data = lv_file iv_page = 2 )
      exp = lv_original ).
  ENDMETHOD.

  METHOD dirty_survives_cache.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lv_page_two TYPE xstring.
    DATA lv_page_three TYPE xstring.
    DATA lv_file TYPE xstring.

    lo_pager = open_writable_pager( 1 ).

    TRY.
        lv_page_two = change_byte(
          iv_data   = lo_pager->get_page( 2 )-data
          iv_offset = 0
          iv_value  = 17 ).
        lv_page_three = change_byte(
          iv_data   = lo_pager->get_page( 3 )-data
          iv_offset = 0
          iv_value  = 34 ).

        lo_pager->put_page( iv_page = 2 iv_data = lv_page_two ).
        lo_pager->put_page( iv_page = 3 iv_data = lv_page_three ).

* cache size is 1, the dirty pages must not be evicted
        lo_pager->get_page( 1 ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->dirty_page_count( ) exp = 2 ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->get_page( 2 )-data exp = lv_page_two ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->get_page( 3 )-data exp = lv_page_three ).

        lo_pager->commit( ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |dirty cache test failed: { lo_error->message }| ).
    ENDTRY.

    lv_file = file_data( ).
    cl_abap_unit_assert=>assert_equals(
      act = page_data( iv_data = lv_file iv_page = 2 )
      exp = lv_page_two ).
    cl_abap_unit_assert=>assert_equals(
      act = page_data( iv_data = lv_file iv_page = 3 )
      exp = lv_page_three ).
  ENDMETHOD.

  METHOD header_maintenance.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA ls_before TYPE zcl_sqlite_header=>ty_header.
    DATA ls_after TYPE zcl_sqlite_header=>ty_header.
    DATA ls_pager TYPE zcl_sqlite_header=>ty_header.
    DATA lv_page TYPE xstring.
    DATA lv_file TYPE xstring.

    lo_pager = open_writable_pager( 2 ).
    TRY.
        ls_before = zcl_sqlite_header=>parse( file_data( ) ).
        lv_page = change_byte(
          iv_data   = lo_pager->get_page( 1 )-data
          iv_offset = 200
          iv_value  = 170 ).
        lo_pager->put_page( iv_page = 1 iv_data = lv_page ).
        lo_pager->commit( ).
        ls_pager = lo_pager->header( ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |header commit failed: { lo_error->message }| ).
    ENDTRY.

    lv_file = file_data( ).
    TRY.
        ls_after = zcl_sqlite_header=>parse( lv_file ).
      CATCH zcx_sqlite_error INTO DATA(lo_parse_error).
        cl_abap_unit_assert=>fail( msg = |header parse failed: { lo_parse_error->message }| ).
    ENDTRY.

    cl_abap_unit_assert=>assert_equals(
      act = ls_after-change_counter exp = ls_before-change_counter + 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_after-database_size exp = ls_before-database_size ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_after-version_valid_for exp = ls_after-change_counter ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_after-sqlite_version
      exp = zcl_sqlite_header=>c_sqlite_version ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_pager-change_counter exp = ls_after-change_counter ).
    lv_page = lv_file+200(1).
    cl_abap_unit_assert=>assert_equals(
      act = lv_page exp = 'AA' ).
  ENDMETHOD.

  METHOD commit_without_changes.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA ls_before TYPE zcl_sqlite_header=>ty_header.
    DATA ls_after TYPE zcl_sqlite_header=>ty_header.
    DATA lv_before TYPE xstring.
    DATA lv_after TYPE xstring.

    lo_pager = open_writable_pager( 2 ).
    lv_before = file_data( ).

    TRY.
        lo_pager->commit( ).
        ls_before = zcl_sqlite_header=>parse( lv_before ).
        ls_after = zcl_sqlite_header=>parse( file_data( ) ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |empty commit failed: { lo_error->message }| ).
    ENDTRY.

    lv_after = file_data( ).
    cl_abap_unit_assert=>assert_equals( act = lv_after exp = lv_before ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_after-change_counter exp = ls_before-change_counter ).
  ENDMETHOD.

  METHOD invalid_write.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lv_page TYPE xstring.
    DATA lv_short TYPE xstring.

    lo_pager = open_writable_pager( 2 ).

    TRY.
        lv_page = lo_pager->get_page( 2 )-data.
      CATCH zcx_sqlite_error INTO DATA(lo_read_error).
        cl_abap_unit_assert=>fail( msg = |page read failed: { lo_read_error->message }| ).
    ENDTRY.
    lv_short = lv_page+0(10).

    TRY.
        lo_pager->put_page( iv_page = 0 iv_data = lv_page ).
        cl_abap_unit_assert=>fail( msg = 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code exp = zcx_sqlite_error=>sqlite_corrupt ).
    ENDTRY.

    TRY.
        lo_pager->put_page( iv_page = 2 iv_data = lv_short ).
        cl_abap_unit_assert=>fail( msg = 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_size_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_size_error->code exp = zcx_sqlite_error=>sqlite_misuse ).
    ENDTRY.
  ENDMETHOD.

  METHOD open_pager.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_vfs->open( c_fixture ).

    TRY.
        ro_pager = NEW zcl_sqlite_pager(
          io_file = lo_file
          iv_cache_size = iv_cache_size ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |pager construction failed: { lo_error->message }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD open_writable_pager.
    DATA lo_file TYPE REF TO zif_sqlite_file.

    mo_vfs = NEW zcl_sqlite_vfs_memory( ).
    lo_file = mo_vfs->open( c_file ).

    TRY.
        lo_file->write( iv_offset = 0 iv_data = fixture( ) ).
      CATCH cx_sy_range_out_of_bounds.
        cl_abap_unit_assert=>fail( msg = 'could not seed writable pager' ).
    ENDTRY.

    TRY.
        ro_pager = NEW zcl_sqlite_pager(
          io_file = lo_file
          iv_cache_size = iv_cache_size ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |pager construction failed: { lo_error->message }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD file_data.
    DATA lo_file TYPE REF TO zif_sqlite_file.
    DATA ls_read TYPE zif_sqlite_file=>ty_read_result.
    DATA lv_size TYPE i.

    lo_file = mo_vfs->open( c_file ).
    lv_size = lo_file->size( ).
    TRY.
        ls_read = lo_file->read( iv_offset = 0 iv_amount = lv_size ).
      CATCH cx_sy_range_out_of_bounds.
        cl_abap_unit_assert=>fail( msg = 'could not read writable pager file' ).
    ENDTRY.
    rv_data = ls_read-data.
  ENDMETHOD.

  METHOD page_data.
    DATA lv_offset TYPE i.

    lv_offset = ( iv_page - 1 ) * c_page_size.
    rv_data = iv_data+lv_offset(c_page_size).
  ENDMETHOD.

  METHOD change_byte.
    TRY.
        rv_data = zcl_sqlite_bytes=>write_u8(
          iv_data   = iv_data
          iv_offset = iv_offset
          iv_value  = iv_value ).
      CATCH cx_sy_conversion_overflow cx_sy_range_out_of_bounds.
        cl_abap_unit_assert=>fail( msg = 'could not change page byte' ).
    ENDTRY.
  ENDMETHOD.

  METHOD fixture.
    DATA lo_vfs TYPE REF TO zcl_sqlite_vfs_table.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    rv_data = lo_vfs->export( c_fixture ).
  ENDMETHOD.

ENDCLASS.
