CLASS ltcl_pager DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_fixture TYPE string VALUE 'fixtures/three_pages.db'.

    METHODS fetch_pages FOR TESTING.
    METHODS cache_lru FOR TESTING.
    METHODS invalid_page FOR TESTING.

    METHODS open_pager
      IMPORTING iv_cache_size   TYPE i
      RETURNING VALUE(ro_pager) TYPE REF TO zcl_sqlite_pager.
    METHODS fixture
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

  METHOD fixture.
    DATA lo_vfs TYPE REF TO zcl_sqlite_vfs_table.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    rv_data = lo_vfs->export( c_fixture ).
  ENDMETHOD.

ENDCLASS.
