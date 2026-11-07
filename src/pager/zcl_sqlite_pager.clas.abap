* Read-only page access for an SQLite database file.
*
* Pages are numbered from 1. Page 1 contains the 100-byte database header, so
* its b-tree page starts at btree_offset = 100. All pages are returned in full,
* including the header bytes on page 1.
CLASS zcl_sqlite_pager DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_default_cache_size TYPE i VALUE 10.

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

    METHODS fail
      IMPORTING iv_code    TYPE i
                iv_message TYPE string
      RAISING   zcx_sqlite_error.

    METHODS put_cache
      IMPORTING is_entry TYPE ty_cache_entry.

    METHODS evict_lru.
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
    DATA ls_entry TYPE ty_cache_entry.
    DATA ls_read TYPE zif_sqlite_file=>ty_read_result.
    DATA lv_offset TYPE i.

    IF iv_page < 1 OR iv_page > mv_page_count.
      fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'page number is outside the database' ).
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
    lv_offset = ( iv_page - 1 ) * mv_page_size.
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

  METHOD put_cache.
* ANORMALY: hashed MODIFY TABLE updates by full row content, delete+insert
    DELETE mt_cache WHERE number = is_entry-number.
    INSERT is_entry INTO TABLE mt_cache.
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

  METHOD fail.
    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = iv_code
        iv_message = iv_message.
  ENDMETHOD.

ENDCLASS.
