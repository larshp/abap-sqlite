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
    METHODS freelist_roundtrip FOR TESTING RAISING zcx_sqlite_error.
    METHODS freelist_rollback FOR TESTING RAISING zcx_sqlite_error.

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

    METHODS page_u32
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
      RETURNING VALUE(rv_value) TYPE int8.
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

    cl_abap_unit_assert=>assert_equals( act = lv_page_size
                                        exp = 4096 ).
    cl_abap_unit_assert=>assert_true( boolc( lo_pager->page_count( ) >= 3 ) ).

    TRY.
        ls_page = lo_pager->get_page( 1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_page-number
                                            exp = 1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_page-btree_offset
                                            exp = 100 ).
        cl_abap_unit_assert=>assert_equals(
          act = xstrlen( ls_page-data )
          exp = lv_page_size ).
        lv_page = lv_all+0(lv_page_size).
        cl_abap_unit_assert=>assert_equals( act = ls_page-data
                                            exp = lv_page ).

        ls_page = lo_pager->get_page( 2 ).
        cl_abap_unit_assert=>assert_equals( act = ls_page-number
                                            exp = 2 ).
        cl_abap_unit_assert=>assert_equals( act = ls_page-btree_offset
                                            exp = 0 ).
        lv_offset = lv_page_size.
        lv_page = lv_all+lv_offset(lv_page_size).
        cl_abap_unit_assert=>assert_equals( act = ls_page-data
                                            exp = lv_page ).

        ls_page = lo_pager->get_page( 3 ).
        cl_abap_unit_assert=>assert_equals( act = ls_page-number
                                            exp = 3 ).
        lv_offset = lv_page_size * 2.
        lv_page = lv_all+lv_offset(lv_page_size).
        cl_abap_unit_assert=>assert_equals( act = ls_page-data
                                            exp = lv_page ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( |page fetch failed: { lo_error->message }| ).
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
        cl_abap_unit_assert=>fail( |page fetch failed: { lo_error->message }| ).
    ENDTRY.

    ls_stats = lo_pager->stats( ).
    cl_abap_unit_assert=>assert_equals( act = ls_stats-hits
                                        exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_stats-misses
                                        exp = 5 ).
    cl_abap_unit_assert=>assert_equals( act = ls_stats-evictions
                                        exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = ls_stats-entries
                                        exp = 2 ).
  ENDMETHOD.

  METHOD invalid_page.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.

    lo_pager = open_pager( 2 ).

    TRY.
        lo_pager->get_page( 0 ).
        cl_abap_unit_assert=>fail( 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_corrupt ).
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

        lo_pager->put_page( iv_page = 2
                            iv_data = lv_modified ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->dirty_page_count( )
          exp = 1 ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->get_page( 2 )-data
          exp = lv_modified ).

* copy-on-write: the file still has the old page
        lv_file = file_data( ).
        cl_abap_unit_assert=>assert_equals(
          act = page_data( iv_data = lv_file iv_page = 2 )
          exp = lv_original ).

        lo_pager->commit( ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->dirty_page_count( )
          exp = 0 ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( |write failed: { lo_error->message }| ).
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

        lo_pager->put_page( iv_page = 2
                            iv_data = lv_modified ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->get_page( 2 )-data
          exp = lv_modified ).

        lo_pager->rollback( ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->dirty_page_count( )
          exp = 0 ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->get_page( 2 )-data
          exp = lv_original ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( |rollback failed: { lo_error->message }| ).
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

        lo_pager->put_page( iv_page = 2
                            iv_data = lv_page_two ).
        lo_pager->put_page( iv_page = 3
                            iv_data = lv_page_three ).

* cache size is 1, the dirty pages must not be evicted
        lo_pager->get_page( 1 ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->dirty_page_count( )
          exp = 2 ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->get_page( 2 )-data
          exp = lv_page_two ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->get_page( 3 )-data
          exp = lv_page_three ).

        lo_pager->commit( ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( |dirty cache test failed: { lo_error->message }| ).
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
        lo_pager->put_page( iv_page = 1
                            iv_data = lv_page ).
        lo_pager->commit( ).
        ls_pager = lo_pager->header( ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( |header commit failed: { lo_error->message }| ).
    ENDTRY.

    lv_file = file_data( ).
    TRY.
        ls_after = zcl_sqlite_header=>parse( lv_file ).
      CATCH zcx_sqlite_error INTO DATA(lo_parse_error).
        cl_abap_unit_assert=>fail( |header parse failed: { lo_parse_error->message }| ).
    ENDTRY.

    cl_abap_unit_assert=>assert_equals(
      act = ls_after-change_counter
      exp = ls_before-change_counter + 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_after-database_size
      exp = ls_before-database_size ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_after-version_valid_for
      exp = ls_after-change_counter ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_after-sqlite_version
      exp = zcl_sqlite_header=>c_sqlite_version ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_pager-change_counter
      exp = ls_after-change_counter ).
    lv_page = lv_file+200(1).
    cl_abap_unit_assert=>assert_equals(
      act = lv_page
      exp = 'AA' ).
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
        cl_abap_unit_assert=>fail( |empty commit failed: { lo_error->message }| ).
    ENDTRY.

    lv_after = file_data( ).
    cl_abap_unit_assert=>assert_equals( act = lv_after
                                        exp = lv_before ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_after-change_counter
      exp = ls_before-change_counter ).
  ENDMETHOD.

  METHOD invalid_write.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lv_page TYPE xstring.
    DATA lv_short TYPE xstring.

    lo_pager = open_writable_pager( 2 ).

    TRY.
        lv_page = lo_pager->get_page( 2 )-data.
      CATCH zcx_sqlite_error INTO DATA(lo_read_error).
        cl_abap_unit_assert=>fail( |page read failed: { lo_read_error->message }| ).
    ENDTRY.
    lv_short = lv_page+0(10).

    TRY.
        lo_pager->put_page( iv_page = 0
                            iv_data = lv_page ).
        cl_abap_unit_assert=>fail( 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_corrupt ).
    ENDTRY.

    TRY.
        lo_pager->put_page( iv_page = 2
                            iv_data = lv_short ).
        cl_abap_unit_assert=>fail( 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_size_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_size_error->code
          exp = zcx_sqlite_error=>sqlite_misuse ).
    ENDTRY.
  ENDMETHOD.

  METHOD freelist_roundtrip.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA ls_header TYPE zcl_sqlite_header=>ty_header.
    DATA ls_page TYPE zcl_sqlite_pager=>ty_page.
    DATA lv_initial TYPE i.
    DATA lv_page1 TYPE i.
    DATA lv_page2 TYPE i.
    DATA lv_page3 TYPE i.
    DATA lv_new TYPE i.
    DATA lv_allocated TYPE i.
    DATA lv_file TYPE xstring.
    DATA lv_trunk TYPE xstring.

    lo_pager = open_writable_pager( 2 ).
    lv_initial = lo_pager->page_count( ).

    TRY.
        lv_page1 = lo_pager->allocate_page( ).
        lv_page2 = lo_pager->allocate_page( ).
        lv_page3 = lo_pager->allocate_page( ).
        cl_abap_unit_assert=>assert_equals(
          act = lv_page1
          exp = lv_initial + 1
          msg = 'first appended page' ).
        cl_abap_unit_assert=>assert_equals(
          act = lv_page3
          exp = lv_initial + 3
          msg = 'third appended page' ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->page_count( )
          exp = lv_initial + 3
          msg = 'grown page count' ).

        lo_pager->free_page( lv_page1 ).
        lo_pager->free_page( lv_page2 ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->freelist_count( )
          exp = 2
          msg = 'freelist count' ).
        ls_header = lo_pager->header( ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_header-freelist_trunk
          exp = lv_page1
          msg = 'freelist trunk' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_header-freelist_pages
          exp = 2
          msg = 'freelist header count' ).

        ls_page = lo_pager->get_page( lv_page1 ).
        cl_abap_unit_assert=>assert_equals(
          act = page_u32( iv_data = ls_page-data iv_offset = 0 )
          exp = 0
          msg = 'trunk next page' ).
        cl_abap_unit_assert=>assert_equals(
          act = page_u32( iv_data = ls_page-data iv_offset = 4 )
          exp = 1
          msg = 'trunk leaf count' ).
        cl_abap_unit_assert=>assert_equals(
          act = page_u32( iv_data = ls_page-data iv_offset = 8 )
          exp = lv_page2
          msg = 'trunk leaf page' ).

        TRY.
            lo_pager->free_page( lv_page1 ).
            cl_abap_unit_assert=>fail( 'double free must fail' ).
          CATCH zcx_sqlite_error INTO DATA(lo_error).
            cl_abap_unit_assert=>assert_equals(
              act = lo_error->code
              exp = zcx_sqlite_error=>sqlite_misuse
              msg = 'double free error code' ).
        ENDTRY.

        lo_pager->commit( ).
      CATCH zcx_sqlite_error INTO DATA(lo_commit_error).
        cl_abap_unit_assert=>fail( |freelist write failed: { lo_commit_error->message }| ).
    ENDTRY.

    lv_file = file_data( ).
    ls_header = zcl_sqlite_header=>parse( lv_file ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-database_size
      exp = lv_initial + 3
      msg = 'committed page count' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-freelist_trunk
      exp = lv_page1
      msg = 'committed freelist trunk' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-freelist_pages
      exp = 2
      msg = 'committed freelist count' ).

    lv_trunk = page_data( iv_data = lv_file
                          iv_page = lv_page1 ).
    cl_abap_unit_assert=>assert_equals(
      act = page_u32( iv_data = lv_trunk iv_offset = 4 )
      exp = 1
      msg = 'committed trunk leaf count' ).
    cl_abap_unit_assert=>assert_equals(
      act = page_u32( iv_data = lv_trunk iv_offset = 8 )
      exp = lv_page2
      msg = 'committed trunk leaf page' ).

    TRY.
        lv_allocated = lo_pager->allocate_page( ).
        cl_abap_unit_assert=>assert_equals(
          act = lv_allocated
          exp = lv_page2
          msg = 'allocate from leaf' ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->freelist_count( )
          exp = 1
          msg = 'freelist after leaf' ).

        lv_allocated = lo_pager->allocate_page( ).
        cl_abap_unit_assert=>assert_equals(
          act = lv_allocated
          exp = lv_page1
          msg = 'allocate empty trunk' ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->freelist_count( )
          exp = 0
          msg = 'empty freelist' ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->header( )-freelist_trunk
          exp = 0
          msg = 'cleared trunk' ).

        lv_new = lo_pager->allocate_page( ).
        cl_abap_unit_assert=>assert_equals(
          act = lv_new
          exp = lv_initial + 4
          msg = 'append after freelist' ).

        lo_pager->free_page( lv_new ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->freelist_count( )
          exp = 1
          msg = 'new trunk count' ).
        lo_pager->commit( ).
      CATCH zcx_sqlite_error INTO DATA(lo_reuse_error).
        cl_abap_unit_assert=>fail( |freelist reuse failed: { lo_reuse_error->message }| ).
    ENDTRY.

    lv_file = file_data( ).
    ls_header = zcl_sqlite_header=>parse( lv_file ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-database_size
      exp = lv_initial + 4
      msg = 'reused page count' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-freelist_trunk
      exp = lv_new
      msg = 'new trunk after free' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-freelist_pages
      exp = 1
      msg = 'new trunk free count' ).
  ENDMETHOD.

  METHOD freelist_rollback.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lv_initial TYPE i.
    DATA lv_page TYPE i.
    DATA lv_file_before TYPE xstring.
    DATA lv_file_after TYPE xstring.

    lo_pager = open_writable_pager( 2 ).
    lv_initial = lo_pager->page_count( ).
    lv_file_before = file_data( ).

    TRY.
        lv_page = lo_pager->allocate_page( ).
        lo_pager->free_page( lv_page ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->page_count( )
          exp = lv_initial + 1
          msg = 'allocated page count' ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->freelist_count( )
          exp = 1
          msg = 'allocated freelist count' ).

        lo_pager->rollback( ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->page_count( )
          exp = lv_initial
          msg = 'rollback page count' ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->freelist_count( )
          exp = 0
          msg = 'rollback freelist count' ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->header( )-freelist_trunk
          exp = 0
          msg = 'rollback trunk' ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_pager->dirty_page_count( )
          exp = 0
          msg = 'rollback dirty pages' ).

        lo_pager->commit( ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( |freelist rollback failed: { lo_error->message }| ).
    ENDTRY.

    lv_file_after = file_data( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_file_after
      exp = lv_file_before
      msg = 'rollback leaves file unchanged' ).
  ENDMETHOD.

  METHOD open_pager.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_vfs->open( c_fixture ).

    TRY.
        ro_pager = NEW zcl_sqlite_pager(
          io_file       = lo_file
          iv_cache_size = iv_cache_size ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( |pager construction failed: { lo_error->message }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD open_writable_pager.
    DATA lo_file TYPE REF TO zif_sqlite_file.

    mo_vfs = NEW zcl_sqlite_vfs_memory( ).
    lo_file = mo_vfs->open( c_file ).

    TRY.
        lo_file->write( iv_offset = 0
                        iv_data   = fixture( ) ).
      CATCH cx_sy_range_out_of_bounds.
        cl_abap_unit_assert=>fail( 'could not seed writable pager' ).
    ENDTRY.

    TRY.
        ro_pager = NEW zcl_sqlite_pager(
          io_file       = lo_file
          iv_cache_size = iv_cache_size ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( |pager construction failed: { lo_error->message }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD file_data.
    DATA lo_file TYPE REF TO zif_sqlite_file.
    DATA ls_read TYPE zif_sqlite_file=>ty_read_result.
    DATA lv_size TYPE i.

    lo_file = mo_vfs->open( c_file ).
    lv_size = lo_file->size( ).
    TRY.
        ls_read = lo_file->read( iv_offset = 0
                                 iv_amount = lv_size ).
      CATCH cx_sy_range_out_of_bounds.
        cl_abap_unit_assert=>fail( 'could not read writable pager file' ).
    ENDTRY.
    rv_data = ls_read-data.
  ENDMETHOD.

  METHOD page_data.
    DATA lv_offset TYPE i.

    lv_offset = ( iv_page - 1 ) * c_page_size.
    rv_data = iv_data+lv_offset(c_page_size).
  ENDMETHOD.

  METHOD page_u32.
    TRY.
        rv_value = zcl_sqlite_bytes=>read_u32(
          iv_data   = iv_data
          iv_offset = iv_offset ).
      CATCH cx_sy_range_out_of_bounds.
        cl_abap_unit_assert=>fail( 'could not read freelist page' ).
    ENDTRY.
  ENDMETHOD.

  METHOD change_byte.
    TRY.
        rv_data = zcl_sqlite_bytes=>write_u8(
          iv_data   = iv_data
          iv_offset = iv_offset
          iv_value  = iv_value ).
      CATCH cx_sy_conversion_overflow cx_sy_range_out_of_bounds.
        cl_abap_unit_assert=>fail( 'could not change page byte' ).
    ENDTRY.
  ENDMETHOD.

  METHOD fixture.
    DATA lo_vfs TYPE REF TO zcl_sqlite_vfs_table.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    rv_data = lo_vfs->export( c_fixture ).
  ENDMETHOD.

ENDCLASS.
