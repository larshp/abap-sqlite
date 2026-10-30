* Parser for the 4 kinds of b-tree pages, see
* https://www.sqlite.org/fileformat.html#b_tree_pages
*
* iv_offset is the start of the b-tree page header inside iv_data. It is 100 for
* page 1 and 0 for every other page. Cell offsets in the result are offsets from
* the beginning of iv_data, like they are stored in the page.
CLASS zcl_sqlite_page DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_index_interior TYPE int8 VALUE 2.
    CONSTANTS c_table_interior TYPE int8 VALUE 5.
    CONSTANTS c_index_leaf     TYPE int8 VALUE 10.
    CONSTANTS c_table_leaf     TYPE int8 VALUE 13.

    TYPES: BEGIN OF ty_freeblock,
             offset      TYPE i,
             next_offset TYPE i,
             size        TYPE i,
           END OF ty_freeblock.
    TYPES ty_freeblocks TYPE STANDARD TABLE OF ty_freeblock WITH DEFAULT KEY.
    TYPES ty_offsets TYPE STANDARD TABLE OF i WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_page,
             page_type             TYPE int8,
             first_freeblock       TYPE i,
             cell_count            TYPE i,
             cell_content_offset   TYPE i,
             fragmented_free_bytes TYPE i,
             rightmost_pointer     TYPE i,
             header_size           TYPE i,
             cell_pointer_offset   TYPE i,
             cell_offsets          TYPE ty_offsets,
             freeblocks            TYPE ty_freeblocks,
           END OF ty_page.

    CLASS-METHODS parse
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i DEFAULT 0
      RETURNING VALUE(rs_page) TYPE ty_page
      RAISING   zcx_sqlite_error.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_header_size_leaf     TYPE i VALUE 8.
    CONSTANTS c_header_size_interior TYPE i VALUE 12.
    CONSTANTS c_page_size_max        TYPE i VALUE 65536.
    CONSTANTS c_max_i                TYPE int8 VALUE 2147483647.

    CLASS-METHODS fail
      IMPORTING iv_message TYPE string
      RAISING   zcx_sqlite_error.
ENDCLASS.


CLASS zcl_sqlite_page IMPLEMENTATION.

  METHOD parse.
    DATA lv_length TYPE i.
    DATA lv_type TYPE int8.
    DATA lv_cell_start TYPE i.
    DATA lv_header_end TYPE i.
    DATA lv_cell_offset TYPE i.
    DATA lv_free TYPE i.
    DATA lv_next TYPE i.
    DATA lv_size TYPE i.
    DATA lv_iterations TYPE i.
    DATA lv_seen TYPE STANDARD TABLE OF i WITH DEFAULT KEY.
    DATA lv_seen_offset TYPE i.
    DATA ls_freeblock TYPE ty_freeblock.
    DATA lv_rightmost TYPE int8.

    lv_length = xstrlen( iv_data ).
    IF iv_offset < 0 OR iv_offset + c_header_size_leaf > lv_length.
      fail( 'b-tree page header is truncated' ).
    ENDIF.

    TRY.
        lv_type = zcl_sqlite_bytes=>read_u8(
          iv_data = iv_data iv_offset = iv_offset ).
        rs_page-first_freeblock = zcl_sqlite_bytes=>read_u16(
          iv_data = iv_data iv_offset = iv_offset + 1 ).
        rs_page-cell_count = zcl_sqlite_bytes=>read_u16(
          iv_data = iv_data iv_offset = iv_offset + 3 ).
        lv_cell_start = zcl_sqlite_bytes=>read_u16(
          iv_data = iv_data iv_offset = iv_offset + 5 ).
        rs_page-fragmented_free_bytes = zcl_sqlite_bytes=>read_u8(
          iv_data = iv_data iv_offset = iv_offset + 7 ).
      CATCH cx_sy_range_out_of_bounds.
        fail( 'b-tree page header is truncated' ).
    ENDTRY.

    IF lv_type <> c_index_interior
        AND lv_type <> c_table_interior
        AND lv_type <> c_index_leaf
        AND lv_type <> c_table_leaf.
      fail( 'unknown b-tree page type' ).
    ENDIF.
    rs_page-page_type = lv_type.

    IF lv_type = c_index_interior OR lv_type = c_table_interior.
      rs_page-header_size = c_header_size_interior.
      IF iv_offset + rs_page-header_size > lv_length.
        fail( 'b-tree page header is truncated' ).
      ENDIF.
      TRY.
          lv_rightmost = zcl_sqlite_bytes=>read_u32(
            iv_data = iv_data iv_offset = iv_offset + 8 ).
        CATCH cx_sy_range_out_of_bounds.
          fail( 'b-tree page header is truncated' ).
      ENDTRY.
      IF lv_rightmost < 1 OR lv_rightmost > c_max_i.
        fail( 'b-tree right-most pointer is invalid' ).
      ENDIF.
      rs_page-rightmost_pointer = lv_rightmost.
    ELSE.
      rs_page-header_size = c_header_size_leaf.
      rs_page-rightmost_pointer = 0.
    ENDIF.

    IF lv_cell_start = 0.
      rs_page-cell_content_offset = c_page_size_max.
    ELSE.
      rs_page-cell_content_offset = lv_cell_start.
    ENDIF.

    rs_page-cell_pointer_offset = iv_offset + rs_page-header_size.
    lv_header_end = rs_page-cell_pointer_offset + rs_page-cell_count * 2.
    IF lv_header_end > lv_length.
      fail( 'b-tree cell pointer array is truncated' ).
    ENDIF.
    IF rs_page-cell_content_offset < lv_header_end
        OR rs_page-cell_content_offset > lv_length.
      fail( 'b-tree cell content area is outside the page' ).
    ENDIF.

    DO rs_page-cell_count TIMES.
      TRY.
          lv_cell_offset = zcl_sqlite_bytes=>read_u16(
            iv_data = iv_data
            iv_offset = rs_page-cell_pointer_offset + ( sy-index - 1 ) * 2 ).
        CATCH cx_sy_range_out_of_bounds.
          fail( 'b-tree cell pointer array is truncated' ).
      ENDTRY.
      IF lv_cell_offset < rs_page-cell_content_offset
          OR lv_cell_offset >= lv_length.
        fail( 'b-tree cell pointer is outside the cell content area' ).
      ENDIF.
      APPEND lv_cell_offset TO rs_page-cell_offsets.
    ENDDO.

    lv_free = rs_page-first_freeblock.
    WHILE lv_free <> 0.
      lv_iterations = lv_iterations + 1.
      IF lv_iterations > lv_length DIV 4.
        fail( 'b-tree freeblock list is too long' ).
      ENDIF.
      IF lv_free < rs_page-cell_content_offset
          OR lv_free + 4 > lv_length.
        fail( 'b-tree freeblock is outside the cell content area' ).
      ENDIF.
      LOOP AT lv_seen INTO lv_seen_offset.
        IF lv_seen_offset = lv_free.
          fail( 'b-tree freeblock list contains a cycle' ).
        ENDIF.
      ENDLOOP.
      APPEND lv_free TO lv_seen.

      TRY.
          lv_next = zcl_sqlite_bytes=>read_u16(
            iv_data = iv_data iv_offset = lv_free ).
          lv_size = zcl_sqlite_bytes=>read_u16(
            iv_data = iv_data iv_offset = lv_free + 2 ).
        CATCH cx_sy_range_out_of_bounds.
          fail( 'b-tree freeblock is truncated' ).
      ENDTRY.
      IF lv_size < 4 OR lv_free + lv_size > lv_length.
        fail( 'b-tree freeblock size is invalid' ).
      ENDIF.

      ls_freeblock-offset = lv_free.
      ls_freeblock-next_offset = lv_next.
      ls_freeblock-size = lv_size.
      APPEND ls_freeblock TO rs_page-freeblocks.
      lv_free = lv_next.
    ENDWHILE.
  ENDMETHOD.

  METHOD fail.
    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = zcx_sqlite_error=>sqlite_corrupt
        iv_message = iv_message.
  ENDMETHOD.

ENDCLASS.
