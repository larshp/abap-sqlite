* Writer for SQLite table b-tree leaves, see
* https://www.sqlite.org/fileformat.html#b_tree_pages
*
* M5.4 inserts into a leaf that still has free space. Interior pages are
* traversed but not modified; page splits and overflow payloads come later.
CLASS zcl_sqlite_btree_writer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_pager     TYPE REF TO zcl_sqlite_pager
                iv_root_page TYPE i
      RAISING   zcx_sqlite_error.

    METHODS insert_row
      IMPORTING iv_rowid   TYPE int8
                iv_payload TYPE xstring
      RAISING   zcx_sqlite_error.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_table_leaf_overhead TYPE int8 VALUE 35.
    CONSTANTS c_max_fragmented     TYPE i VALUE 255.

    TYPES: BEGIN OF ty_target,
             page_number TYPE i,
             data        TYPE xstring,
             page        TYPE zcl_sqlite_page=>ty_page,
           END OF ty_target.

    DATA mo_pager       TYPE REF TO zcl_sqlite_pager.
    DATA mv_root_page   TYPE i.
    DATA mv_usable_size TYPE i.

    METHODS find_leaf
      IMPORTING iv_rowid         TYPE int8
      RETURNING VALUE(rs_target) TYPE ty_target
      RAISING   zcx_sqlite_error.

    METHODS build_cell
      IMPORTING iv_rowid       TYPE int8
                iv_payload     TYPE xstring
      RETURNING VALUE(rv_cell) TYPE xstring.

    METHODS insert_into_leaf
      IMPORTING iv_rowid       TYPE int8
                iv_cell        TYPE xstring
                is_target      TYPE ty_target
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS cell_rowid
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
      RETURNING VALUE(rv_rowid) TYPE int8
      RAISING   zcx_sqlite_error.

    METHODS read_u32
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
      RETURNING VALUE(rv_value) TYPE int8
      RAISING   zcx_sqlite_error.

    METHODS set_u8
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE int8
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS set_u16
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE int8
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS splice
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE xstring
      RETURNING VALUE(rv_data) TYPE xstring.

    METHODS fail
      IMPORTING iv_code    TYPE i
                iv_message TYPE string
      RAISING   zcx_sqlite_error.
ENDCLASS.


CLASS zcl_sqlite_btree_writer IMPLEMENTATION.

  METHOD constructor.
    DATA ls_header TYPE zcl_sqlite_header=>ty_header.

    IF io_pager IS NOT BOUND OR iv_root_page < 1.
      fail( iv_code    = zcx_sqlite_error=>sqlite_misuse
            iv_message = 'b-tree writer needs a pager and a root page' ).
    ENDIF.

    mo_pager = io_pager.
    mv_root_page = iv_root_page.
    ls_header = io_pager->header( ).
    mv_usable_size = ls_header-page_size - ls_header-reserved_bytes.
    IF mv_usable_size < zcl_sqlite_btree=>c_min_usable_size.
      fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'b-tree writer usable page size is too small' ).
    ENDIF.
  ENDMETHOD.

  METHOD insert_row.
    DATA lv_payload_length TYPE int8.
    DATA lv_max_payload TYPE int8.
    DATA lv_cell TYPE xstring.
    DATA lv_data TYPE xstring.
    DATA ls_target TYPE ty_target.

    lv_payload_length = xstrlen( iv_payload ).
    lv_max_payload = mv_usable_size - c_table_leaf_overhead.
    IF lv_payload_length > lv_max_payload.
      fail( iv_code    = zcx_sqlite_error=>sqlite_toobig
            iv_message = 'table leaf payload needs overflow pages' ).
    ENDIF.

    ls_target = find_leaf( iv_rowid ).
    lv_cell = build_cell( iv_rowid   = iv_rowid
                          iv_payload = iv_payload ).
    lv_data = insert_into_leaf( iv_rowid  = iv_rowid
                                iv_cell   = lv_cell
                                is_target = ls_target ).
    mo_pager->put_page( iv_page = ls_target-page_number
                        iv_data = lv_data ).
  ENDMETHOD.

  METHOD find_leaf.
    DATA lv_page TYPE i.
    DATA lv_child TYPE i.
    DATA lv_child_i8 TYPE int8.
    DATA lv_key TYPE int8.
    DATA lv_iterations TYPE i.
    DATA lv_offset TYPE i.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.

    lv_page = mv_root_page.
    WHILE lv_page > 0.
      lv_iterations = lv_iterations + 1.
      IF lv_iterations > mo_pager->page_count( ).
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'b-tree is deeper than the file' ).
      ENDIF.

      ls_raw = mo_pager->get_page( lv_page ).
      ls_page = zcl_sqlite_page=>parse(
        iv_data   = ls_raw-data
        iv_offset = ls_raw-btree_offset ).

      CASE ls_page-page_type.
        WHEN zcl_sqlite_page=>c_table_leaf.
          rs_target-page_number = lv_page.
          rs_target-data = ls_raw-data.
          rs_target-page = ls_page.
          RETURN.
        WHEN zcl_sqlite_page=>c_table_interior.
          IF ls_page-cell_count = 0.
            fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
                  iv_message = 'table interior page has no cells' ).
          ENDIF.

          lv_child = ls_page-rightmost_pointer.
          LOOP AT ls_page-cell_offsets INTO lv_offset.
            TRY.
                lv_key = zcl_sqlite_bytes=>read_varint(
                  iv_data   = ls_raw-data
                  iv_offset = lv_offset + 4 ).
              CATCH cx_sy_range_out_of_bounds.
                fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
                      iv_message = 'table interior key is truncated' ).
            ENDTRY.

            IF iv_rowid <= lv_key.
              lv_child_i8 = read_u32( iv_data   = ls_raw-data
                                      iv_offset = lv_offset ).
              lv_child = lv_child_i8.
              EXIT.
            ENDIF.
          ENDLOOP.

          IF lv_child < 1.
            fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
                  iv_message = 'b-tree child page number is invalid' ).
          ENDIF.
          lv_page = lv_child.
        WHEN OTHERS.
          fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
                iv_message = 'writer found a non-table b-tree page' ).
      ENDCASE.
    ENDWHILE.

    fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
          iv_message = 'b-tree child page number is invalid' ).
  ENDMETHOD.

  METHOD build_cell.
    DATA lv_payload_length TYPE int8.
    DATA lv_payload_varint TYPE xstring.
    DATA lv_rowid_varint TYPE xstring.

    lv_payload_length = xstrlen( iv_payload ).
    lv_payload_varint = zcl_sqlite_bytes=>write_varint( lv_payload_length ).
    lv_rowid_varint = zcl_sqlite_bytes=>write_varint( iv_rowid ).

    rv_cell = lv_payload_varint && lv_rowid_varint && iv_payload.
  ENDMETHOD.

  METHOD insert_into_leaf.
    DATA lv_data TYPE xstring.
    DATA lv_cell_length TYPE i.
    DATA lv_cell_count TYPE i.
    DATA lv_content_start TYPE i.
    DATA lv_pointer_end TYPE i.
    DATA lv_insert_index TYPE i.
    DATA lv_cell_offset TYPE i.
    DATA lv_cell_position TYPE i.
    DATA lv_rowid TYPE int8.
    DATA lv_first_free TYPE i.
    DATA lv_free_offset TYPE i.
    DATA lv_free_next TYPE i.
    DATA lv_free_size TYPE i.
    DATA lv_free_previous TYPE i.
    DATA lv_previous_offset TYPE i.
    DATA lv_free_found TYPE abap_bool.
    DATA lv_remainder TYPE i.
    DATA lv_new_free_offset TYPE i.
    DATA lv_fragmented TYPE i.
    DATA lv_new_content TYPE i.
    DATA lv_stored_content TYPE int8.
    DATA lv_index TYPE i.
    DATA ls_freeblock TYPE zcl_sqlite_page=>ty_freeblock.

    lv_data = is_target-data.
    lv_cell_length = xstrlen( iv_cell ).
    lv_cell_count = is_target-page-cell_count.
    lv_content_start = is_target-page-cell_content_offset.
    IF lv_content_start > xstrlen( lv_data ).
      lv_content_start = mv_usable_size.
    ENDIF.
    lv_fragmented = is_target-page-fragmented_free_bytes.
    lv_first_free = is_target-page-first_freeblock.

* find the sorted position first, so duplicate rowids never look like "full"
    lv_insert_index = lv_cell_count + 1.
    LOOP AT is_target-page-cell_offsets INTO lv_cell_offset.
      lv_rowid = cell_rowid( iv_data   = lv_data
                             iv_offset = lv_cell_offset ).
      IF lv_rowid = iv_rowid.
        fail( iv_code    = zcx_sqlite_error=>sqlite_constraint
              iv_message = 'table rowid already exists' ).
      ELSEIF iv_rowid < lv_rowid.
        lv_insert_index = sy-tabix.
        EXIT.
      ENDIF.
    ENDLOOP.

    lv_pointer_end = is_target-page-cell_pointer_offset + ( lv_cell_count + 1 ) * 2.
    IF lv_pointer_end > lv_content_start.
      fail( iv_code    = zcx_sqlite_error=>sqlite_full
            iv_message = 'b-tree leaf has no room for another cell pointer' ).
    ENDIF.

* prefer a freeblock, then take space from the gap below the cell content
    LOOP AT is_target-page-freeblocks INTO ls_freeblock.
      IF ls_freeblock-size >= lv_cell_length.
        lv_remainder = ls_freeblock-size - lv_cell_length.
        IF lv_remainder = 0
            OR lv_remainder >= 4
            OR lv_fragmented + lv_remainder <= c_max_fragmented.
          lv_free_offset = ls_freeblock-offset.
          lv_free_next = ls_freeblock-next_offset.
          lv_free_size = ls_freeblock-size.
          lv_free_previous = lv_previous_offset.
          lv_free_found = abap_true.
          EXIT.
        ENDIF.
      ENDIF.
      lv_previous_offset = ls_freeblock-offset.
    ENDLOOP.

    IF lv_free_found = abap_true.
      lv_cell_position = lv_free_offset.
      lv_remainder = lv_free_size - lv_cell_length.
      IF lv_remainder >= 4.
* the cell takes the beginning, the rest stays a freeblock
        lv_new_free_offset = lv_free_offset + lv_cell_length.
        IF lv_free_previous = 0.
          lv_first_free = lv_new_free_offset.
        ELSE.
          lv_data = set_u16( iv_data   = lv_data
                             iv_offset = lv_free_previous
                             iv_value  = CONV int8( lv_new_free_offset ) ).
        ENDIF.
        lv_data = set_u16( iv_data   = lv_data
                           iv_offset = lv_new_free_offset
                           iv_value  = CONV int8( lv_free_next ) ).
        lv_data = set_u16( iv_data   = lv_data
                           iv_offset = lv_new_free_offset + 2
                           iv_value  = CONV int8( lv_remainder ) ).
      ELSE.
* too small for a freeblock header, count the rest as fragmentation
        lv_fragmented = lv_fragmented + lv_remainder.
        IF lv_free_previous = 0.
          lv_first_free = lv_free_next.
        ELSE.
          lv_data = set_u16( iv_data   = lv_data
                             iv_offset = lv_free_previous
                             iv_value  = CONV int8( lv_free_next ) ).
        ENDIF.
      ENDIF.
    ELSE.
      lv_new_content = lv_content_start - lv_cell_length.
      IF lv_new_content < lv_pointer_end.
        fail( iv_code    = zcx_sqlite_error=>sqlite_full
              iv_message = 'b-tree leaf has no free space' ).
      ENDIF.
      lv_cell_position = lv_new_content.
      lv_content_start = lv_new_content.
    ENDIF.

    lv_data = splice( iv_data   = lv_data
                      iv_offset = lv_cell_position
                      iv_value  = iv_cell ).

* make room in the cell pointer array by shifting the later pointers right
    lv_index = lv_cell_count.
    WHILE lv_index >= lv_insert_index.
      READ TABLE is_target-page-cell_offsets INTO lv_cell_offset INDEX lv_index.
      IF sy-subrc <> 0.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'b-tree cell pointer is missing' ).
      ENDIF.
      lv_data = set_u16(
        iv_data   = lv_data
        iv_offset = is_target-page-cell_pointer_offset + lv_index * 2
        iv_value  = CONV int8( lv_cell_offset ) ).
      lv_index = lv_index - 1.
    ENDWHILE.

    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = is_target-page-cell_pointer_offset + ( lv_insert_index - 1 ) * 2
      iv_value  = CONV int8( lv_cell_position ) ).

    lv_cell_count = lv_cell_count + 1.
    lv_stored_content = lv_content_start.
    IF lv_stored_content = 65536.
      lv_stored_content = 0.
    ENDIF.

    lv_data = set_u16( iv_data   = lv_data
                       iv_offset = is_target-page-cell_pointer_offset - 7
                       iv_value  = CONV int8( lv_first_free ) ).
    lv_data = set_u16( iv_data   = lv_data
                       iv_offset = is_target-page-cell_pointer_offset - 5
                       iv_value  = CONV int8( lv_cell_count ) ).
    lv_data = set_u16( iv_data   = lv_data
                       iv_offset = is_target-page-cell_pointer_offset - 3
                       iv_value  = lv_stored_content ).
    lv_data = set_u8( iv_data   = lv_data
                      iv_offset = is_target-page-cell_pointer_offset - 1
                      iv_value  = CONV int8( lv_fragmented ) ).

    rv_data = lv_data.
  ENDMETHOD.

  METHOD cell_rowid.
    DATA lv_payload_length TYPE int8.
    DATA lv_rowid_offset TYPE i.

    TRY.
        lv_payload_length = zcl_sqlite_bytes=>read_varint(
          iv_data   = iv_data
          iv_offset = iv_offset ).
        lv_rowid_offset = iv_offset + zcl_sqlite_bytes=>varint_length(
          iv_data   = iv_data
          iv_offset = iv_offset ).
        rv_rowid = zcl_sqlite_bytes=>read_varint(
          iv_data   = iv_data
          iv_offset = lv_rowid_offset ).
      CATCH cx_sy_range_out_of_bounds.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'table leaf cell header is truncated' ).
    ENDTRY.

    IF lv_payload_length < 0.
      fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'table leaf payload size is negative' ).
    ENDIF.
  ENDMETHOD.

  METHOD read_u32.
    TRY.
        rv_value = zcl_sqlite_bytes=>read_u32(
          iv_data   = iv_data
          iv_offset = iv_offset ).
      CATCH cx_sy_range_out_of_bounds.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'b-tree child pointer is truncated' ).
    ENDTRY.
  ENDMETHOD.

  METHOD set_u8.
    TRY.
        rv_data = zcl_sqlite_bytes=>write_u8(
          iv_data   = iv_data
          iv_offset = iv_offset
          iv_value  = iv_value ).
      CATCH cx_sy_range_out_of_bounds cx_sy_conversion_overflow.
        fail( iv_code    = zcx_sqlite_error=>sqlite_internal
              iv_message = 'b-tree page byte could not be written' ).
    ENDTRY.
  ENDMETHOD.

  METHOD set_u16.
    TRY.
        rv_data = zcl_sqlite_bytes=>write_u16(
          iv_data   = iv_data
          iv_offset = iv_offset
          iv_value  = iv_value ).
      CATCH cx_sy_range_out_of_bounds cx_sy_conversion_overflow.
        fail( iv_code    = zcx_sqlite_error=>sqlite_internal
              iv_message = 'b-tree page offset could not be written' ).
    ENDTRY.
  ENDMETHOD.

  METHOD splice.
    DATA lv_before TYPE xstring.
    DATA lv_after TYPE xstring.
    DATA lv_tail TYPE i.

    lv_before = iv_data+0(iv_offset).
    lv_tail = iv_offset + xstrlen( iv_value ).
    IF lv_tail < xstrlen( iv_data ).
      lv_after = iv_data+lv_tail.
    ENDIF.
    rv_data = lv_before && iv_value && lv_after.
  ENDMETHOD.

  METHOD fail.
    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = iv_code
        iv_message = iv_message.
  ENDMETHOD.

ENDCLASS.
