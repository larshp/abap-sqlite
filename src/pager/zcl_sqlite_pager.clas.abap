* Page access for an SQLite database file.
*
* Pages are numbered from 1. Page 1 contains the 100-byte database header, so
* its b-tree page starts at btree_offset = 100. All pages are returned in full,
* including the header bytes on page 1.
*
* Writes are copy-on-write: put_page keeps the new page in memory, so the file
* is untouched until commit. Commit writes the dirty pages and updates the
* header fields, rollback drops them. This is journal_mode=MEMORY, with the
* ABAP LUW providing durability, see D3 in PLAN.md.
CLASS zcl_sqlite_pager DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_default_cache_size TYPE i VALUE 10.
    CONSTANTS c_max_change_counter TYPE int8 VALUE 4294967295.

    TYPES: BEGIN OF ty_page,
             number       TYPE i,
             data         TYPE xstring,
             btree_offset TYPE i,
           END OF ty_page.

    TYPES: BEGIN OF ty_stats,
             hits      TYPE i,
             misses    TYPE i,
             evictions TYPE i,
             entries   TYPE i,
           END OF ty_stats.

    METHODS constructor
      IMPORTING io_file       TYPE REF TO zif_sqlite_file
                iv_cache_size TYPE i DEFAULT c_default_cache_size
      RAISING   zcx_sqlite_error.

    METHODS get_page
      IMPORTING iv_page        TYPE i
      RETURNING VALUE(rs_page) TYPE ty_page
      RAISING   zcx_sqlite_error.

* stage a full page in memory, the file is not changed before commit
    METHODS put_page
      IMPORTING iv_page TYPE i
                iv_data TYPE xstring
      RAISING   zcx_sqlite_error.

* take a page from the freelist or append a zero page, the page is dirty
    METHODS allocate_page
      RETURNING VALUE(rv_page) TYPE i
      RAISING   zcx_sqlite_error.

* put a page on the first freelist trunk or create a new trunk
    METHODS free_page
      IMPORTING iv_page TYPE i
      RAISING   zcx_sqlite_error.

    METHODS freelist_count
      RETURNING VALUE(rv_count) TYPE i.

    METHODS commit
      RAISING zcx_sqlite_error.

    METHODS rollback.

    METHODS dirty_page_count
      RETURNING VALUE(rv_count) TYPE i.

    METHODS page_size
      RETURNING VALUE(rv_page_size) TYPE i.

    METHODS page_count
      RETURNING VALUE(rv_page_count) TYPE i.

    METHODS header
      RETURNING VALUE(rs_header) TYPE zcl_sqlite_header=>ty_header.

    METHODS stats
      RETURNING VALUE(rs_stats) TYPE ty_stats.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_cache_entry,
             number       TYPE i,
             data         TYPE xstring,
             btree_offset TYPE i,
             last_used    TYPE i,
           END OF ty_cache_entry.
    TYPES ty_cache TYPE HASHED TABLE OF ty_cache_entry WITH UNIQUE KEY number.

    TYPES: BEGIN OF ty_dirty_page,
             number       TYPE i,
             data         TYPE xstring,
             btree_offset TYPE i,
           END OF ty_dirty_page.
    TYPES ty_dirty TYPE HASHED TABLE OF ty_dirty_page WITH UNIQUE KEY number.

    DATA mo_file TYPE REF TO zif_sqlite_file.
    DATA mv_header TYPE zcl_sqlite_header=>ty_header.
    DATA mv_page_size TYPE i.
    DATA mv_page_count TYPE i.
    DATA mv_cache_size TYPE i.
    DATA mv_tick TYPE i.
    DATA mv_hits TYPE i.
    DATA mv_misses TYPE i.
    DATA mv_evictions TYPE i.
    DATA mt_cache TYPE ty_cache.
* dirty pages live outside the cache, an eviction must never lose a write
    DATA mt_dirty TYPE ty_dirty.

* allocation changes the header and page count, keep their committed values
    DATA mv_snapshot_valid TYPE abap_bool.
    DATA mv_snapshot_header TYPE zcl_sqlite_header=>ty_header.
    DATA mv_snapshot_page_count TYPE i.

    METHODS ensure_snapshot.

    METHODS zero_page
      RETURNING VALUE(rv_data) TYPE xstring.

    METHODS zero_and_put
      IMPORTING iv_page TYPE i
      RAISING   zcx_sqlite_error.

    METHODS max_freelist_leaves
      RETURNING VALUE(rv_count) TYPE i.

    METHODS page_u32
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
      RETURNING VALUE(rv_value) TYPE int8
      RAISING   zcx_sqlite_error.

    METHODS set_page_u32
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE int8
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS check_free_page_number
      IMPORTING iv_page TYPE i
      RAISING   zcx_sqlite_error.

    METHODS is_free_page
      IMPORTING iv_page        TYPE i
      RETURNING VALUE(rv_free) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS fail
      IMPORTING iv_code    TYPE i
                iv_message TYPE string
      RAISING   zcx_sqlite_error.

    METHODS put_cache
      IMPORTING is_entry TYPE ty_cache_entry.

    METHODS evict_lru.

    METHODS page_offset
      IMPORTING iv_page          TYPE i
      RETURNING VALUE(rv_offset) TYPE i.

    METHODS next_change_counter
      RETURNING VALUE(rv_counter) TYPE int8.
ENDCLASS.


CLASS zcl_sqlite_pager IMPLEMENTATION.

  METHOD constructor.
    DATA lv_size TYPE i.
    DATA ls_read TYPE zif_sqlite_file=>ty_read_result.

    IF io_file IS NOT BOUND.
      fail( iv_code = zcx_sqlite_error=>sqlite_misuse
            iv_message = 'pager needs a file' ).
    ENDIF.
    IF iv_cache_size < 1.
      fail( iv_code = zcx_sqlite_error=>sqlite_misuse
            iv_message = 'pager cache size must be positive' ).
    ENDIF.

    mo_file = io_file.
    mv_cache_size = iv_cache_size.

    lv_size = io_file->size( ).
    IF lv_size < zcl_sqlite_header=>c_header_size.
      fail( iv_code = zcx_sqlite_error=>sqlite_notadb
            iv_message = 'SQLite file is shorter than its header' ).
    ENDIF.

    TRY.
        ls_read = io_file->read(
          iv_offset = 0
          iv_amount = zcl_sqlite_header=>c_header_size ).
      CATCH cx_sy_range_out_of_bounds.
        fail( iv_code = zcx_sqlite_error=>sqlite_notadb
              iv_message = 'SQLite file is shorter than its header' ).
    ENDTRY.
    IF ls_read-short = abap_true.
      fail( iv_code = zcx_sqlite_error=>sqlite_notadb
            iv_message = 'SQLite file is shorter than its header' ).
    ENDIF.

    mv_header = zcl_sqlite_header=>parse( ls_read-data ).
    mv_page_size = mv_header-page_size.
    IF lv_size MOD mv_page_size <> 0.
      fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'SQLite file size is not a multiple of the page size' ).
    ENDIF.
    mv_page_count = lv_size DIV mv_page_size.
    IF mv_page_count < 1.
      fail( iv_code = zcx_sqlite_error=>sqlite_notadb
            iv_message = 'SQLite file has no pages' ).
    ENDIF.
  ENDMETHOD.

  METHOD get_page.
    DATA ls_dirty TYPE ty_dirty_page.
    DATA ls_entry TYPE ty_cache_entry.
    DATA ls_read TYPE zif_sqlite_file=>ty_read_result.
    DATA lv_offset TYPE i.

    IF iv_page < 1 OR iv_page > mv_page_count.
      fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'page number is outside the database' ).
    ENDIF.

    READ TABLE mt_dirty INTO ls_dirty WITH KEY number = iv_page.
    IF sy-subrc = 0.
      mv_hits = mv_hits + 1.
      rs_page-number = ls_dirty-number.
      rs_page-data = ls_dirty-data.
      rs_page-btree_offset = ls_dirty-btree_offset.
      RETURN.
    ENDIF.

    READ TABLE mt_cache INTO ls_entry WITH KEY number = iv_page.
    IF sy-subrc = 0.
      mv_hits = mv_hits + 1.
      mv_tick = mv_tick + 1.
      ls_entry-last_used = mv_tick.
      put_cache( ls_entry ).
      rs_page-number = ls_entry-number.
      rs_page-data = ls_entry-data.
      rs_page-btree_offset = ls_entry-btree_offset.
      RETURN.
    ENDIF.

    mv_misses = mv_misses + 1.
    lv_offset = page_offset( iv_page ).
    TRY.
        ls_read = mo_file->read(
          iv_offset = lv_offset
          iv_amount = mv_page_size ).
      CATCH cx_sy_range_out_of_bounds.
        fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'page could not be read' ).
    ENDTRY.
    IF ls_read-short = abap_true.
      fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'page is shorter than the page size' ).
    ENDIF.

    IF lines( mt_cache ) >= mv_cache_size.
      evict_lru( ).
    ENDIF.

    mv_tick = mv_tick + 1.
    ls_entry-number = iv_page.
    ls_entry-data = ls_read-data.
    ls_entry-last_used = mv_tick.
    IF iv_page = 1.
      ls_entry-btree_offset = zcl_sqlite_header=>c_header_size.
    ELSE.
      ls_entry-btree_offset = 0.
    ENDIF.
    put_cache( ls_entry ).

    rs_page-number = ls_entry-number.
    rs_page-data = ls_entry-data.
    rs_page-btree_offset = ls_entry-btree_offset.
  ENDMETHOD.

  METHOD put_page.
    DATA ls_dirty TYPE ty_dirty_page.

    IF iv_page < 1 OR iv_page > mv_page_count.
      fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'page number is outside the database' ).
    ENDIF.
    IF xstrlen( iv_data ) <> mv_page_size.
      fail( iv_code = zcx_sqlite_error=>sqlite_misuse
            iv_message = 'page data does not match the page size' ).
    ENDIF.

    ensure_snapshot( ).

* copy-on-write: drop the clean cached copy and keep the new page in mt_dirty
    DELETE mt_cache WHERE number = iv_page.
    ls_dirty-number = iv_page.
    ls_dirty-data = iv_data.
    IF iv_page = 1.
      ls_dirty-btree_offset = zcl_sqlite_header=>c_header_size.
    ELSE.
      ls_dirty-btree_offset = 0.
    ENDIF.
    DELETE mt_dirty WHERE number = iv_page.
    INSERT ls_dirty INTO TABLE mt_dirty.
  ENDMETHOD.

  METHOD allocate_page.
    DATA ls_trunk  TYPE ty_page.
    DATA lv_trunk  TYPE int8.
    DATA lv_next   TYPE int8.
    DATA lv_leaves TYPE int8.
    DATA lv_leaf   TYPE int8.
    DATA lv_index  TYPE i.

    ensure_snapshot( ).

    lv_trunk = mv_header-freelist_trunk.
    IF lv_trunk = 0.
      mv_page_count = mv_page_count + 1.
      rv_page = mv_page_count.
      zero_and_put( rv_page ).
      RETURN.
    ENDIF.

    IF mv_header-freelist_pages < 1.
      fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'freelist trunk has no free page count' ).
    ENDIF.

    check_free_page_number( CONV i( lv_trunk ) ).
    ls_trunk = get_page( CONV i( lv_trunk ) ).
    lv_leaves = page_u32( iv_data = ls_trunk-data iv_offset = 4 ).
    IF lv_leaves < 0
        OR lv_leaves > CONV int8( max_freelist_leaves( ) ).
      fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'freelist trunk leaf count is invalid' ).
    ENDIF.

    IF lv_leaves > 0.
      lv_index = CONV i( lv_leaves ) - 1.
      lv_leaf = page_u32(
        iv_data = ls_trunk-data
        iv_offset = 8 + lv_index * 4 ).
      check_free_page_number( CONV i( lv_leaf ) ).

      ls_trunk-data = set_page_u32(
        iv_data = ls_trunk-data
        iv_offset = 4
        iv_value = lv_leaves - 1 ).
      put_page( iv_page = CONV i( lv_trunk ) iv_data = ls_trunk-data ).

      rv_page = CONV i( lv_leaf ).
    ELSE.
      lv_next = page_u32( iv_data = ls_trunk-data iv_offset = 0 ).
      IF lv_next <> 0.
        check_free_page_number( CONV i( lv_next ) ).
      ENDIF.

      mv_header-freelist_trunk = lv_next.
      rv_page = CONV i( lv_trunk ).
    ENDIF.

    mv_header-freelist_pages = mv_header-freelist_pages - 1.
    zero_and_put( rv_page ).
  ENDMETHOD.

  METHOD free_page.
    DATA ls_trunk  TYPE ty_page.
    DATA lv_trunk  TYPE int8.
    DATA lv_leaves TYPE int8.
    DATA lv_data   TYPE xstring.

    IF iv_page < 2 OR iv_page > mv_page_count.
      fail( iv_code = zcx_sqlite_error=>sqlite_misuse
            iv_message = 'page to free is outside the database' ).
    ENDIF.
    IF is_free_page( iv_page ) = abap_true.
      fail( iv_code = zcx_sqlite_error=>sqlite_misuse
            iv_message = 'page is already on the freelist' ).
    ENDIF.

    ensure_snapshot( ).
    lv_trunk = mv_header-freelist_trunk.
    IF lv_trunk = 0.
      lv_data = zero_page( ).
      lv_data = set_page_u32( iv_data = lv_data iv_offset = 0 iv_value = 0 ).
      lv_data = set_page_u32( iv_data = lv_data iv_offset = 4 iv_value = 0 ).
      put_page( iv_page = iv_page iv_data = lv_data ).

      mv_header-freelist_trunk = CONV int8( iv_page ).
      mv_header-freelist_pages = mv_header-freelist_pages + 1.
      RETURN.
    ENDIF.

    check_free_page_number( CONV i( lv_trunk ) ).
    ls_trunk = get_page( CONV i( lv_trunk ) ).
    lv_leaves = page_u32( iv_data = ls_trunk-data iv_offset = 4 ).
    IF lv_leaves < 0
        OR lv_leaves > CONV int8( max_freelist_leaves( ) ).
      fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'freelist trunk leaf count is invalid' ).
    ENDIF.

    IF lv_leaves < CONV int8( max_freelist_leaves( ) ).
      ls_trunk-data = set_page_u32(
        iv_data = ls_trunk-data
        iv_offset = 8 + CONV i( lv_leaves ) * 4
        iv_value = CONV int8( iv_page ) ).
      ls_trunk-data = set_page_u32(
        iv_data = ls_trunk-data
        iv_offset = 4
        iv_value = lv_leaves + 1 ).
      put_page( iv_page = CONV i( lv_trunk ) iv_data = ls_trunk-data ).
      zero_and_put( iv_page ).
    ELSE.
      lv_data = zero_page( ).
      lv_data = set_page_u32( iv_data = lv_data iv_offset = 0 iv_value = lv_trunk ).
      lv_data = set_page_u32( iv_data = lv_data iv_offset = 4 iv_value = 0 ).
      put_page( iv_page = iv_page iv_data = lv_data ).

      mv_header-freelist_trunk = CONV int8( iv_page ).
    ENDIF.

    mv_header-freelist_pages = mv_header-freelist_pages + 1.
  ENDMETHOD.

  METHOD freelist_count.
    rv_count = mv_header-freelist_pages.
  ENDMETHOD.

  METHOD commit.
    DATA ls_dirty TYPE ty_dirty_page.
    DATA ls_header TYPE zcl_sqlite_header=>ty_header.
    DATA lv_page_one TYPE xstring.
    DATA lv_offset TYPE i.

    IF lines( mt_dirty ) = 0.
      CLEAR mv_snapshot_valid.
      RETURN.
    ENDIF.

    ls_header = mv_header.
    ls_header-change_counter = next_change_counter( ).
    ls_header-database_size = mv_page_count.
    ls_header-version_valid_for = ls_header-change_counter.
    ls_header-sqlite_version = zcl_sqlite_header=>c_sqlite_version.

* page 1 carries the header, write it last so a partial flush never publishes it
    lv_page_one = get_page( 1 )-data.
    lv_page_one = zcl_sqlite_header=>patch(
      iv_data   = lv_page_one
      is_header = ls_header ).

    LOOP AT mt_dirty INTO ls_dirty.
      IF ls_dirty-number = 1.
        CONTINUE.
      ENDIF.
      lv_offset = page_offset( ls_dirty-number ).
      TRY.
          mo_file->write( iv_offset = lv_offset iv_data = ls_dirty-data ).
        CATCH cx_sy_range_out_of_bounds.
          fail( iv_code = zcx_sqlite_error=>sqlite_ioerr
                iv_message = 'dirty page could not be written' ).
      ENDTRY.
    ENDLOOP.

    TRY.
        mo_file->write( iv_offset = 0 iv_data = lv_page_one ).
      CATCH cx_sy_range_out_of_bounds.
        fail( iv_code = zcx_sqlite_error=>sqlite_ioerr
              iv_message = 'database header could not be written' ).
    ENDTRY.
    mo_file->sync( ).

    mv_header = ls_header.
    CLEAR mt_dirty.
    CLEAR mv_snapshot_valid.
* the cached page 1 has the old header bytes
    DELETE mt_cache WHERE number = 1.
  ENDMETHOD.

  METHOD rollback.
    IF mv_snapshot_valid = abap_true.
      mv_header = mv_snapshot_header.
      mv_page_count = mv_snapshot_page_count.
      CLEAR mv_snapshot_valid.
    ENDIF.
    CLEAR mt_dirty.
  ENDMETHOD.

  METHOD dirty_page_count.
    rv_count = lines( mt_dirty ).
  ENDMETHOD.

  METHOD page_size.
    rv_page_size = mv_page_size.
  ENDMETHOD.

  METHOD page_count.
    rv_page_count = mv_page_count.
  ENDMETHOD.

  METHOD header.
    rs_header = mv_header.
  ENDMETHOD.

  METHOD stats.
    rs_stats-hits = mv_hits.
    rs_stats-misses = mv_misses.
    rs_stats-evictions = mv_evictions.
    rs_stats-entries = lines( mt_cache ).
  ENDMETHOD.

  METHOD page_offset.
    rv_offset = ( iv_page - 1 ) * mv_page_size.
  ENDMETHOD.

  METHOD next_change_counter.
    rv_counter = mv_header-change_counter + 1.
    IF rv_counter > c_max_change_counter.
      rv_counter = 1.
    ENDIF.
  ENDMETHOD.

  METHOD put_cache.
    MODIFY TABLE mt_cache FROM is_entry.
    IF sy-subrc <> 0.
      INSERT is_entry INTO TABLE mt_cache.
    ENDIF.
  ENDMETHOD.

  METHOD evict_lru.
    DATA ls_entry TYPE ty_cache_entry.
    DATA ls_oldest TYPE ty_cache_entry.
    DATA lv_found TYPE abap_bool.

    LOOP AT mt_cache INTO ls_entry.
      IF lv_found = abap_false OR ls_entry-last_used < ls_oldest-last_used.
        ls_oldest = ls_entry.
        lv_found = abap_true.
      ENDIF.
    ENDLOOP.
    IF lv_found = abap_true.
      DELETE mt_cache WHERE number = ls_oldest-number.
      mv_evictions = mv_evictions + 1.
    ENDIF.
  ENDMETHOD.

  METHOD ensure_snapshot.
    IF mv_snapshot_valid = abap_false.
      mv_snapshot_header = mv_header.
      mv_snapshot_page_count = mv_page_count.
      mv_snapshot_valid = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD zero_page.
    rv_data = repeat( val = '00' occ = mv_page_size ).
  ENDMETHOD.

  METHOD zero_and_put.
    DATA lv_data TYPE xstring.

    lv_data = zero_page( ).
    put_page( iv_page = iv_page iv_data = lv_data ).
  ENDMETHOD.

  METHOD max_freelist_leaves.
    rv_count = ( mv_page_size - CONV i( mv_header-reserved_bytes ) ) DIV 4 - 2.
  ENDMETHOD.

  METHOD page_u32.
    TRY.
        rv_value = zcl_sqlite_bytes=>read_u32(
          iv_data   = iv_data
          iv_offset = iv_offset ).
      CATCH cx_sy_range_out_of_bounds.
        fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'freelist page is truncated' ).
    ENDTRY.
  ENDMETHOD.

  METHOD set_page_u32.
    TRY.
        rv_data = zcl_sqlite_bytes=>write_u32(
          iv_data   = iv_data
          iv_offset = iv_offset
          iv_value  = iv_value ).
      CATCH cx_sy_conversion_overflow cx_sy_range_out_of_bounds.
        fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'freelist page could not be written' ).
    ENDTRY.
  ENDMETHOD.

  METHOD check_free_page_number.
    IF iv_page < 2 OR iv_page > mv_page_count.
      fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'freelist page number is outside the database' ).
    ENDIF.
  ENDMETHOD.

  METHOD is_free_page.
    DATA ls_trunk  TYPE ty_page.
    DATA lv_trunk  TYPE int8.
    DATA lv_next   TYPE int8.
    DATA lv_leaves TYPE int8.
    DATA lv_leaf   TYPE int8.
    DATA lv_index  TYPE i.
    DATA lv_loops  TYPE i.

    lv_trunk = mv_header-freelist_trunk.
    WHILE lv_trunk <> 0.
      check_free_page_number( CONV i( lv_trunk ) ).
      IF lv_trunk = iv_page.
        rv_free = abap_true.
        RETURN.
      ENDIF.

      lv_loops = lv_loops + 1.
      IF lv_loops > mv_page_count.
        fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'freelist trunk chain contains a cycle' ).
      ENDIF.

      ls_trunk = get_page( CONV i( lv_trunk ) ).
      lv_leaves = page_u32( iv_data = ls_trunk-data iv_offset = 4 ).
      IF lv_leaves < 0
          OR lv_leaves > CONV int8( max_freelist_leaves( ) ).
        fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'freelist trunk leaf count is invalid' ).
      ENDIF.

      lv_index = 0.
      WHILE lv_index < lv_leaves.
        lv_leaf = page_u32(
          iv_data = ls_trunk-data
          iv_offset = 8 + lv_index * 4 ).
        check_free_page_number( CONV i( lv_leaf ) ).
        IF lv_leaf = iv_page.
          rv_free = abap_true.
          RETURN.
        ENDIF.
        lv_index = lv_index + 1.
      ENDWHILE.

      lv_next = page_u32( iv_data = ls_trunk-data iv_offset = 0 ).
      lv_trunk = lv_next.
    ENDWHILE.
  ENDMETHOD.

  METHOD fail.
    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = iv_code
        iv_message = iv_message.
  ENDMETHOD.

ENDCLASS.
