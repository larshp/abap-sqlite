* Writer for SQLite table b-trees, see
* https://www.sqlite.org/fileformat.html#b_tree_pages
*
* Inserts descend to a leaf and split pages on the way back up. Large payloads
* are stored in overflow page chains. The root page number never changes: when
* the root splits, its contents move to two new child pages and the root
* becomes a table interior page.
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

    METHODS delete_row
      IMPORTING iv_rowid TYPE int8
      RAISING   zcx_sqlite_error.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_max_fragmented          TYPE i VALUE 255.
    CONSTANTS c_leaf_header_size        TYPE i VALUE 8.
    CONSTANTS c_interior_header_size    TYPE i VALUE 12.

    TYPES: BEGIN OF ty_overflow,
             page  TYPE i,
             chunk TYPE xstring,
           END OF ty_overflow.
    TYPES ty_overflows TYPE STANDARD TABLE OF ty_overflow WITH DEFAULT KEY.
    TYPES ty_pages TYPE STANDARD TABLE OF i WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_split,
             split        TYPE abap_bool,
             promoted_key TYPE int8,
             right_page   TYPE i,
           END OF ty_split.

    TYPES: BEGIN OF ty_leaf_cell,
             rowid TYPE int8,
             data  TYPE xstring,
           END OF ty_leaf_cell.
    TYPES ty_leaf_cells TYPE STANDARD TABLE OF ty_leaf_cell WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_interior_cell,
             key   TYPE int8,
             child TYPE i,
             data  TYPE xstring,
           END OF ty_interior_cell.
    TYPES ty_interior_cells TYPE STANDARD TABLE OF ty_interior_cell WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_delete_result,
             found     TYPE abap_bool,
             empty     TYPE abap_bool,
             max_rowid TYPE int8,
           END OF ty_delete_result.

    DATA mo_pager       TYPE REF TO zcl_sqlite_pager.
    DATA mv_root_page   TYPE i.
    DATA mv_page_size   TYPE i.
    DATA mv_usable_size TYPE i.

    METHODS insert_page
      IMPORTING iv_page         TYPE i
                iv_rowid        TYPE int8
                iv_cell         TYPE xstring
      RETURNING VALUE(rs_split) TYPE ty_split
      RAISING   zcx_sqlite_error.

    METHODS delete_page
      IMPORTING iv_page          TYPE i
                iv_rowid         TYPE int8
      RETURNING VALUE(rs_result) TYPE ty_delete_result
      RAISING   zcx_sqlite_error.

    METHODS delete_leaf_page
      IMPORTING iv_page          TYPE i
                is_raw           TYPE zcl_sqlite_pager=>ty_page
                is_page          TYPE zcl_sqlite_page=>ty_page
                iv_rowid         TYPE int8
      RETURNING VALUE(rs_result) TYPE ty_delete_result
      RAISING   zcx_sqlite_error.

    METHODS remove_interior_child
      IMPORTING iv_page          TYPE i
                is_raw           TYPE zcl_sqlite_pager=>ty_page
                is_page          TYPE zcl_sqlite_page=>ty_page
                iv_child_page    TYPE i
                iv_child_index   TYPE i
      RETURNING VALUE(rs_result) TYPE ty_delete_result
      RAISING   zcx_sqlite_error.

    METHODS set_interior_key
      IMPORTING iv_page          TYPE i
                is_raw           TYPE zcl_sqlite_pager=>ty_page
                is_page          TYPE zcl_sqlite_page=>ty_page
                iv_child_index   TYPE i
                iv_key           TYPE int8
      RETURNING VALUE(rs_result) TYPE ty_delete_result
      RAISING   zcx_sqlite_error.

    METHODS collapse_page
      IMPORTING iv_page          TYPE i
                is_raw           TYPE zcl_sqlite_pager=>ty_page
                iv_child_page    TYPE i
      RETURNING VALUE(rs_result) TYPE ty_delete_result
      RAISING   zcx_sqlite_error.

    METHODS subtree_max
      IMPORTING iv_page         TYPE i
      RETURNING VALUE(rv_rowid) TYPE int8
      RAISING   zcx_sqlite_error.

    METHODS free_overflow_chain
      IMPORTING iv_first_page TYPE i
      RAISING   zcx_sqlite_error.

    METHODS insert_leaf_page
      IMPORTING iv_page         TYPE i
                is_raw          TYPE zcl_sqlite_pager=>ty_page
                is_page         TYPE zcl_sqlite_page=>ty_page
                iv_rowid        TYPE int8
                iv_cell         TYPE xstring
      RETURNING VALUE(rs_split) TYPE ty_split
      RAISING   zcx_sqlite_error.

    METHODS insert_interior_page
      IMPORTING iv_page         TYPE i
                is_raw          TYPE zcl_sqlite_pager=>ty_page
                is_page         TYPE zcl_sqlite_page=>ty_page
                iv_child        TYPE i
                iv_child_index  TYPE i
                iv_promoted_key TYPE int8
                iv_right_page   TYPE i
      RETURNING VALUE(rs_split) TYPE ty_split
      RAISING   zcx_sqlite_error.

    METHODS find_child
      IMPORTING is_raw         TYPE zcl_sqlite_pager=>ty_page
                is_page        TYPE zcl_sqlite_page=>ty_page
                iv_rowid       TYPE int8
      EXPORTING ev_child       TYPE i
                ev_child_index TYPE i
      RAISING   zcx_sqlite_error.

    METHODS build_cell
      IMPORTING iv_rowid   TYPE int8
                iv_payload TYPE xstring
      EXPORTING ev_cell    TYPE xstring
                et_pages   TYPE ty_pages
      RAISING   zcx_sqlite_error.

    METHODS insert_into_leaf
      IMPORTING iv_rowid       TYPE int8
                iv_cell        TYPE xstring
                is_target      TYPE zcl_sqlite_page=>ty_page
                iv_data        TYPE xstring
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS read_leaf_cells
      IMPORTING is_raw          TYPE zcl_sqlite_pager=>ty_page
                is_page         TYPE zcl_sqlite_page=>ty_page
      RETURNING VALUE(rt_cells) TYPE ty_leaf_cells
      RAISING   zcx_sqlite_error.

    METHODS read_interior_cells
      IMPORTING is_raw          TYPE zcl_sqlite_pager=>ty_page
                is_page         TYPE zcl_sqlite_page=>ty_page
      RETURNING VALUE(rt_cells) TYPE ty_interior_cells
      RAISING   zcx_sqlite_error.

    METHODS split_leaf_cells
      IMPORTING it_cells        TYPE ty_leaf_cells
      EXPORTING ev_left_count   TYPE i
                ev_promoted_key TYPE int8
      RAISING   zcx_sqlite_error.

    METHODS split_interior_cells
      IMPORTING it_cells         TYPE ty_interior_cells
      EXPORTING ev_promote_index TYPE i
                ev_promoted_key  TYPE int8
      RAISING   zcx_sqlite_error.

    METHODS build_leaf_page
      IMPORTING it_cells       TYPE ty_leaf_cells
                iv_offset      TYPE i
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS build_interior_page
      IMPORTING it_cells       TYPE ty_interior_cells
                iv_rightmost   TYPE i
                iv_offset      TYPE i
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS build_interior_cell
      IMPORTING iv_child       TYPE i
                iv_key         TYPE int8
      RETURNING VALUE(rv_cell) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS build_root_interior
      IMPORTING is_raw          TYPE zcl_sqlite_pager=>ty_page
                iv_left_page    TYPE i
                iv_promoted_key TYPE int8
                iv_right_page   TYPE i
      RETURNING VALUE(rv_data)  TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS preserve_header
      IMPORTING iv_data        TYPE xstring
                is_raw         TYPE zcl_sqlite_pager=>ty_page
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

    METHODS set_u32
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE int8
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS zero_page
      RETURNING VALUE(rv_data) TYPE xstring.

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
    mv_page_size = CONV i( ls_header-page_size ).
    mv_usable_size = mv_page_size - CONV i( ls_header-reserved_bytes ).
    IF mv_usable_size < zcl_sqlite_btree=>c_min_usable_size.
      fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'b-tree writer usable page size is too small' ).
    ENDIF.
  ENDMETHOD.

  METHOD insert_row.
    DATA lv_cell TYPE xstring.
    DATA lt_pages TYPE ty_pages.
    DATA lv_page TYPE i.

    build_cell(
      EXPORTING
        iv_rowid   = iv_rowid
        iv_payload = iv_payload
      IMPORTING
        ev_cell    = lv_cell
        et_pages   = lt_pages ).

    TRY.
        insert_page( iv_page  = mv_root_page
                     iv_rowid = iv_rowid
                     iv_cell  = lv_cell ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
* the row was not written, release the overflow chain again
        LOOP AT lt_pages INTO lv_page.
          mo_pager->free_page( lv_page ).
        ENDLOOP.
        RAISE EXCEPTION lo_error.
    ENDTRY.
  ENDMETHOD.

  METHOD delete_row.
    delete_page( iv_page  = mv_root_page
                 iv_rowid = iv_rowid ).
  ENDMETHOD.

  METHOD delete_page.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA ls_child TYPE ty_delete_result.
    DATA lv_child TYPE i.
    DATA lv_child_index TYPE i.
    DATA lv_child_is_rightmost TYPE abap_bool.

    ls_raw = mo_pager->get_page( iv_page ).
    ls_page = zcl_sqlite_page=>parse(
      iv_data   = ls_raw-data
      iv_offset = ls_raw-btree_offset ).

    CASE ls_page-page_type.
      WHEN zcl_sqlite_page=>c_table_leaf.
        rs_result = delete_leaf_page(
          iv_page  = iv_page
          is_raw   = ls_raw
          is_page  = ls_page
          iv_rowid = iv_rowid ).
      WHEN zcl_sqlite_page=>c_table_interior.
        find_child(
          EXPORTING
            is_raw         = ls_raw
            is_page        = ls_page
            iv_rowid       = iv_rowid
          IMPORTING
            ev_child       = lv_child
            ev_child_index = lv_child_index ).

        lv_child_is_rightmost = boolc(
          lv_child = ls_page-rightmost_pointer ).

        ls_child = delete_page(
          iv_page  = lv_child
          iv_rowid = iv_rowid ).
        IF ls_child-found = abap_false.
          RETURN.
        ENDIF.

        rs_result-found = abap_true.
        IF lv_child_is_rightmost = abap_true.
          lv_child_index = ls_page-cell_count + 1.
        ELSE.
          lv_child_index = lv_child_index + 1.
        ENDIF.
        IF ls_child-empty = abap_true.
          rs_result = remove_interior_child(
            iv_page        = iv_page
            is_raw         = ls_raw
            is_page        = ls_page
            iv_child_page  = lv_child
            iv_child_index = lv_child_index ).
        ELSEIF lv_child_is_rightmost = abap_false.
          rs_result = set_interior_key(
            iv_page        = iv_page
            is_raw         = ls_raw
            is_page        = ls_page
            iv_child_index = lv_child_index
            iv_key         = ls_child-max_rowid ).
        ELSE.
          rs_result-empty = abap_false.
          rs_result-max_rowid = ls_child-max_rowid.
        ENDIF.
      WHEN OTHERS.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'writer found a non-table b-tree page' ).
    ENDCASE.
  ENDMETHOD.

  METHOD delete_leaf_page.
    DATA lt_cells TYPE ty_leaf_cells.
    DATA lt_remaining TYPE ty_leaf_cells.
    DATA ls_cell TYPE ty_leaf_cell.
    DATA lv_payload_length TYPE int8.
    DATA lv_local_size TYPE int8.
    DATA lv_first_overflow TYPE int8.
    DATA lv_offset TYPE i.
    DATA lv_data TYPE xstring.

    lt_cells = read_leaf_cells( is_raw  = is_raw
                                is_page = is_page ).
    LOOP AT lt_cells INTO ls_cell.
      IF ls_cell-rowid = iv_rowid.
        rs_result-found = abap_true.
        TRY.
            lv_payload_length = zcl_sqlite_bytes=>read_varint(
              iv_data   = ls_cell-data
              iv_offset = 0 ).
          CATCH cx_sy_range_out_of_bounds.
            fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
                  iv_message = 'table leaf cell header is truncated' ).
        ENDTRY.
        lv_local_size = zcl_sqlite_btree=>local_payload_size(
          iv_payload_size = lv_payload_length
          iv_usable_size  = mv_usable_size ).
        IF lv_payload_length > lv_local_size.
          IF xstrlen( ls_cell-data ) < 4.
            fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
                  iv_message = 'overflow pointer is missing' ).
          ENDIF.
          lv_offset = xstrlen( ls_cell-data ) - 4.
          lv_first_overflow = read_u32(
            iv_data   = ls_cell-data
            iv_offset = lv_offset ).
        ENDIF.
      ELSE.
        APPEND ls_cell TO lt_remaining.
      ENDIF.
    ENDLOOP.

    IF rs_result-found = abap_false.
      RETURN.
    ENDIF.

    lv_data = build_leaf_page(
      it_cells  = lt_remaining
      iv_offset = is_raw-btree_offset ).
    lv_data = preserve_header( iv_data = lv_data
                               is_raw  = is_raw ).
    mo_pager->put_page( iv_page = iv_page
                        iv_data = lv_data ).

    rs_result-empty = boolc( lines( lt_remaining ) = 0 ).
    IF rs_result-empty = abap_false.
      READ TABLE lt_remaining INTO ls_cell INDEX lines( lt_remaining ).
      rs_result-max_rowid = ls_cell-rowid.
    ENDIF.

    IF lv_first_overflow > 0.
      free_overflow_chain( CONV i( lv_first_overflow ) ).
    ENDIF.
  ENDMETHOD.

  METHOD remove_interior_child.
    DATA lt_cells TYPE ty_interior_cells.
    DATA ls_cell TYPE ty_interior_cell.
    DATA lv_rightmost TYPE i.
    DATA lv_new_rightmost TYPE i.
    DATA lv_count TYPE i.
    DATA lv_data TYPE xstring.

    lt_cells = read_interior_cells( is_raw  = is_raw
                                    is_page = is_page ).
    lv_count = lines( lt_cells ).
    lv_rightmost = is_page-rightmost_pointer.
    lv_new_rightmost = lv_rightmost.

    IF iv_child_index <= lv_count.
      READ TABLE lt_cells INTO ls_cell INDEX iv_child_index.
      IF ls_cell-child <> iv_child_page.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'interior child pointer does not match' ).
      ENDIF.
      DELETE lt_cells INDEX iv_child_index.
    ELSEIF iv_child_index = lv_count + 1.
      READ TABLE lt_cells INTO ls_cell INDEX lv_count.
      lv_new_rightmost = ls_cell-child.
      DELETE lt_cells INDEX lv_count.
    ELSE.
      fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'interior child index is out of range' ).
    ENDIF.

    IF lines( lt_cells ) = 0.
      rs_result = collapse_page(
        iv_page       = iv_page
        is_raw        = is_raw
        iv_child_page = lv_new_rightmost ).
      IF iv_child_page <> lv_new_rightmost.
        mo_pager->free_page( iv_child_page ).
      ENDIF.
      RETURN.
    ENDIF.

    lv_data = build_interior_page(
      it_cells     = lt_cells
      iv_rightmost = lv_new_rightmost
      iv_offset    = is_raw-btree_offset ).
    lv_data = preserve_header( iv_data = lv_data
                               is_raw  = is_raw ).
    mo_pager->put_page( iv_page = iv_page
                        iv_data = lv_data ).
    mo_pager->free_page( iv_child_page ).

    rs_result-found = abap_true.
    rs_result-empty = abap_false.
    rs_result-max_rowid = subtree_max( lv_new_rightmost ).
  ENDMETHOD.

  METHOD set_interior_key.
    DATA lt_cells TYPE ty_interior_cells.
    DATA ls_cell TYPE ty_interior_cell.
    DATA lv_data TYPE xstring.

    lt_cells = read_interior_cells( is_raw  = is_raw
                                    is_page = is_page ).
    READ TABLE lt_cells INTO ls_cell INDEX iv_child_index.
    IF sy-subrc <> 0.
      fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'interior key index is out of range' ).
    ENDIF.
    ls_cell-key = iv_key.
    ls_cell-data = build_interior_cell(
      iv_child = ls_cell-child
      iv_key   = iv_key ).
    MODIFY lt_cells FROM ls_cell INDEX iv_child_index.

    lv_data = build_interior_page(
      it_cells     = lt_cells
      iv_rightmost = is_page-rightmost_pointer
      iv_offset    = is_raw-btree_offset ).
    lv_data = preserve_header( iv_data = lv_data
                               is_raw  = is_raw ).
    mo_pager->put_page( iv_page = iv_page
                        iv_data = lv_data ).

    rs_result-found = abap_true.
    rs_result-empty = abap_false.
    rs_result-max_rowid = subtree_max( is_page-rightmost_pointer ).
  ENDMETHOD.

  METHOD collapse_page.
    DATA ls_child_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_child_page TYPE zcl_sqlite_page=>ty_page.
    DATA lt_leaf_cells TYPE ty_leaf_cells.
    DATA lt_interior_cells TYPE ty_interior_cells.
    DATA ls_leaf_cell TYPE ty_leaf_cell.
    DATA lv_data TYPE xstring.

    ls_child_raw = mo_pager->get_page( iv_child_page ).
    ls_child_page = zcl_sqlite_page=>parse(
      iv_data   = ls_child_raw-data
      iv_offset = ls_child_raw-btree_offset ).

    CASE ls_child_page-page_type.
      WHEN zcl_sqlite_page=>c_table_leaf.
        lt_leaf_cells = read_leaf_cells(
          is_raw  = ls_child_raw
          is_page = ls_child_page ).
        lv_data = build_leaf_page(
          it_cells  = lt_leaf_cells
          iv_offset = is_raw-btree_offset ).
        rs_result-empty = boolc( lines( lt_leaf_cells ) = 0 ).
        IF rs_result-empty = abap_false.
          READ TABLE lt_leaf_cells INTO ls_leaf_cell
            INDEX lines( lt_leaf_cells ).
          rs_result-max_rowid = ls_leaf_cell-rowid.
        ENDIF.
      WHEN zcl_sqlite_page=>c_table_interior.
        lt_interior_cells = read_interior_cells(
          is_raw  = ls_child_raw
          is_page = ls_child_page ).
        lv_data = build_interior_page(
          it_cells     = lt_interior_cells
          iv_rightmost = ls_child_page-rightmost_pointer
          iv_offset    = is_raw-btree_offset ).
        rs_result-empty = abap_false.
      WHEN OTHERS.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'collapse found a non-table b-tree page' ).
    ENDCASE.

    lv_data = preserve_header( iv_data = lv_data
                               is_raw  = is_raw ).
    mo_pager->put_page( iv_page = iv_page
                        iv_data = lv_data ).
    mo_pager->free_page( iv_child_page ).

    rs_result-found = abap_true.
    IF ls_child_page-page_type = zcl_sqlite_page=>c_table_interior.
      rs_result-max_rowid = subtree_max( iv_page ).
    ENDIF.
  ENDMETHOD.

  METHOD subtree_max.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA ls_cell TYPE ty_leaf_cell.
    DATA lt_cells TYPE ty_leaf_cells.
    DATA lv_page TYPE i.
    DATA lv_iterations TYPE i.

    lv_page = iv_page.
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
          lt_cells = read_leaf_cells( is_raw  = ls_raw
                                      is_page = ls_page ).
          IF lines( lt_cells ) = 0.
            RETURN.
          ENDIF.
          READ TABLE lt_cells INTO ls_cell INDEX lines( lt_cells ).
          rv_rowid = ls_cell-rowid.
          RETURN.
        WHEN zcl_sqlite_page=>c_table_interior.
          lv_page = ls_page-rightmost_pointer.
        WHEN OTHERS.
          fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
                iv_message = 'subtree maximum found a non-table page' ).
      ENDCASE.
    ENDWHILE.

    fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
          iv_message = 'b-tree child page number is invalid' ).
  ENDMETHOD.

  METHOD free_overflow_chain.
    DATA lt_seen TYPE ty_pages.
    DATA lv_page TYPE i.
    DATA lv_next TYPE i.
    DATA lv_iterations TYPE i.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.

    lv_page = iv_first_page.
    WHILE lv_page <> 0.
      lv_iterations = lv_iterations + 1.
      IF lv_iterations > mo_pager->page_count( ).
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'overflow chain contains a cycle' ).
      ENDIF.
      READ TABLE lt_seen TRANSPORTING NO FIELDS
        WITH KEY table_line = lv_page.
      IF sy-subrc = 0.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'overflow chain contains a cycle' ).
      ENDIF.
      APPEND lv_page TO lt_seen.

      ls_raw = mo_pager->get_page( lv_page ).
      lv_next = CONV i( read_u32(
        iv_data   = ls_raw-data
        iv_offset = 0 ) ).
      mo_pager->free_page( lv_page ).
      lv_page = lv_next.
    ENDWHILE.
  ENDMETHOD.

  METHOD insert_page.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA lv_child TYPE i.
    DATA lv_child_index TYPE i.
    DATA ls_child_split TYPE ty_split.

    ls_raw = mo_pager->get_page( iv_page ).
    ls_page = zcl_sqlite_page=>parse(
      iv_data   = ls_raw-data
      iv_offset = ls_raw-btree_offset ).

    CASE ls_page-page_type.
      WHEN zcl_sqlite_page=>c_table_leaf.
        rs_split = insert_leaf_page(
          iv_page  = iv_page
          is_raw   = ls_raw
          is_page  = ls_page
          iv_rowid = iv_rowid
          iv_cell  = iv_cell ).
      WHEN zcl_sqlite_page=>c_table_interior.
        find_child(
          EXPORTING
            is_raw         = ls_raw
            is_page        = ls_page
            iv_rowid       = iv_rowid
          IMPORTING
            ev_child       = lv_child
            ev_child_index = lv_child_index ).

        ls_child_split = insert_page(
          iv_page  = lv_child
          iv_rowid = iv_rowid
          iv_cell  = iv_cell ).
        IF ls_child_split-split = abap_false.
          RETURN.
        ENDIF.

        rs_split = insert_interior_page(
          iv_page         = iv_page
          is_raw          = ls_raw
          is_page         = ls_page
          iv_child        = lv_child
          iv_child_index  = lv_child_index
          iv_promoted_key = ls_child_split-promoted_key
          iv_right_page   = ls_child_split-right_page ).
      WHEN OTHERS.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'writer found a non-table b-tree page' ).
    ENDCASE.
  ENDMETHOD.

  METHOD insert_leaf_page.
    DATA lv_data TYPE xstring.
    DATA lt_cells TYPE ty_leaf_cells.
    DATA lt_left TYPE ty_leaf_cells.
    DATA lt_right TYPE ty_leaf_cells.
    DATA ls_cell TYPE ty_leaf_cell.
    DATA ls_new TYPE ty_leaf_cell.
    DATA lv_insert_index TYPE i.
    DATA lv_left_count TYPE i.
    DATA lv_promoted_key TYPE int8.
    DATA lv_left_page TYPE i.
    DATA lv_right_page TYPE i.
    DATA lv_left_data TYPE xstring.
    DATA lv_right_data TYPE xstring.

    TRY.
        lv_data = insert_into_leaf(
          iv_rowid  = iv_rowid
          iv_cell   = iv_cell
          is_target = is_page
          iv_data   = is_raw-data ).
        mo_pager->put_page( iv_page = iv_page
                            iv_data = lv_data ).
        RETURN.
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        IF lo_error->code <> zcx_sqlite_error=>sqlite_full.
          RAISE EXCEPTION lo_error.
        ENDIF.
    ENDTRY.

* the leaf is full, rebuild it with the new cell and split the cell list
    lt_cells = read_leaf_cells( is_raw  = is_raw
                                is_page = is_page ).
    ls_new-rowid = iv_rowid.
    ls_new-data = iv_cell.
    lv_insert_index = lines( lt_cells ) + 1.
    LOOP AT lt_cells INTO ls_cell.
      IF ls_cell-rowid = iv_rowid.
        fail( iv_code    = zcx_sqlite_error=>sqlite_constraint
              iv_message = 'table rowid already exists' ).
      ELSEIF iv_rowid < ls_cell-rowid.
        lv_insert_index = sy-tabix.
        EXIT.
      ENDIF.
    ENDLOOP.
    INSERT ls_new INTO lt_cells INDEX lv_insert_index.

    split_leaf_cells(
      EXPORTING
        it_cells        = lt_cells
      IMPORTING
        ev_left_count   = lv_left_count
        ev_promoted_key = lv_promoted_key ).

    LOOP AT lt_cells INTO ls_cell.
      IF sy-tabix <= lv_left_count.
        APPEND ls_cell TO lt_left.
      ELSE.
        APPEND ls_cell TO lt_right.
      ENDIF.
    ENDLOOP.

    lv_left_data = build_leaf_page( it_cells  = lt_left
                                    iv_offset = 0 ).
    lv_right_data = build_leaf_page( it_cells  = lt_right
                                     iv_offset = 0 ).

    IF iv_page = mv_root_page.
      lv_left_page = mo_pager->allocate_page( ).
      lv_right_page = mo_pager->allocate_page( ).
      mo_pager->put_page( iv_page = lv_left_page
                          iv_data = lv_left_data ).
      mo_pager->put_page( iv_page = lv_right_page
                          iv_data = lv_right_data ).
      lv_data = build_root_interior(
        is_raw          = is_raw
        iv_left_page    = lv_left_page
        iv_promoted_key = lv_promoted_key
        iv_right_page   = lv_right_page ).
      mo_pager->put_page( iv_page = iv_page
                          iv_data = lv_data ).
      RETURN.
    ENDIF.

    lv_right_page = mo_pager->allocate_page( ).
    mo_pager->put_page( iv_page = iv_page
                        iv_data = lv_left_data ).
    mo_pager->put_page( iv_page = lv_right_page
                        iv_data = lv_right_data ).
    rs_split-split = abap_true.
    rs_split-promoted_key = lv_promoted_key.
    rs_split-right_page = lv_right_page.
  ENDMETHOD.

  METHOD insert_interior_page.
    DATA lt_cells TYPE ty_interior_cells.
    DATA lt_left TYPE ty_interior_cells.
    DATA lt_right TYPE ty_interior_cells.
    DATA ls_cell TYPE ty_interior_cell.
    DATA lv_old_key TYPE int8.
    DATA lv_rightmost TYPE i.
    DATA lv_left_rightmost TYPE i.
    DATA lv_index TYPE i.
    DATA lv_required TYPE i.
    DATA lv_data TYPE xstring.
    DATA lv_promote_index TYPE i.
    DATA lv_promoted_key TYPE int8.
    DATA lv_left_page TYPE i.
    DATA lv_right_page TYPE i.
    DATA lv_left_data TYPE xstring.
    DATA lv_right_data TYPE xstring.

    lt_cells = read_interior_cells( is_raw  = is_raw
                                    is_page = is_page ).
    lv_rightmost = is_page-rightmost_pointer.

    IF iv_child_index < is_page-cell_count.
      lv_index = iv_child_index + 1.
      READ TABLE lt_cells INTO ls_cell INDEX lv_index.
      IF sy-subrc <> 0 OR ls_cell-child <> iv_child.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'table interior child pointer does not match' ).
      ENDIF.
      lv_old_key = ls_cell-key.
      ls_cell-key = iv_promoted_key.
      ls_cell-data = build_interior_cell( iv_child = iv_child
                                          iv_key   = iv_promoted_key ).
      MODIFY lt_cells FROM ls_cell INDEX lv_index.

      ls_cell-child = iv_right_page.
      ls_cell-key = lv_old_key.
      ls_cell-data = build_interior_cell( iv_child = iv_right_page
                                          iv_key   = lv_old_key ).
      lv_index = lv_index + 1.
      INSERT ls_cell INTO lt_cells INDEX lv_index.
    ELSE.
      ls_cell-child = iv_child.
      ls_cell-key = iv_promoted_key.
      ls_cell-data = build_interior_cell( iv_child = iv_child
                                          iv_key   = iv_promoted_key ).
      APPEND ls_cell TO lt_cells.
      lv_rightmost = iv_right_page.
    ENDIF.

    lv_required = c_interior_header_size + lines( lt_cells ) * 2.
    LOOP AT lt_cells INTO ls_cell.
      lv_required = lv_required + xstrlen( ls_cell-data ).
    ENDLOOP.

    IF lv_required <= mv_usable_size.
      lv_data = build_interior_page(
        it_cells     = lt_cells
        iv_rightmost = lv_rightmost
        iv_offset    = is_raw-btree_offset ).
      lv_data = preserve_header( iv_data = lv_data
                                 is_raw  = is_raw ).
      mo_pager->put_page( iv_page = iv_page
                          iv_data = lv_data ).
      RETURN.
    ENDIF.

    split_interior_cells(
      EXPORTING
        it_cells         = lt_cells
      IMPORTING
        ev_promote_index = lv_promote_index
        ev_promoted_key  = lv_promoted_key ).

    LOOP AT lt_cells INTO ls_cell.
      IF sy-tabix < lv_promote_index.
        APPEND ls_cell TO lt_left.
      ELSEIF sy-tabix = lv_promote_index.
        lv_left_rightmost = ls_cell-child.
      ELSE.
        APPEND ls_cell TO lt_right.
      ENDIF.
    ENDLOOP.

    lv_left_data = build_interior_page(
      it_cells     = lt_left
      iv_rightmost = lv_left_rightmost
      iv_offset    = 0 ).
    lv_right_data = build_interior_page(
      it_cells     = lt_right
      iv_rightmost = lv_rightmost
      iv_offset    = 0 ).

    IF iv_page = mv_root_page.
      lv_left_page = mo_pager->allocate_page( ).
      lv_right_page = mo_pager->allocate_page( ).
      mo_pager->put_page( iv_page = lv_left_page
                          iv_data = lv_left_data ).
      mo_pager->put_page( iv_page = lv_right_page
                          iv_data = lv_right_data ).
      lv_data = build_root_interior(
        is_raw          = is_raw
        iv_left_page    = lv_left_page
        iv_promoted_key = lv_promoted_key
        iv_right_page   = lv_right_page ).
      mo_pager->put_page( iv_page = iv_page
                          iv_data = lv_data ).
      RETURN.
    ENDIF.

    lv_right_page = mo_pager->allocate_page( ).
    mo_pager->put_page( iv_page = iv_page
                        iv_data = lv_left_data ).
    mo_pager->put_page( iv_page = lv_right_page
                        iv_data = lv_right_data ).
    rs_split-split = abap_true.
    rs_split-promoted_key = lv_promoted_key.
    rs_split-right_page = lv_right_page.
  ENDMETHOD.

  METHOD find_child.
    DATA lv_offset TYPE i.
    DATA lv_key TYPE int8.
    DATA lv_child TYPE int8.

    IF is_page-cell_count = 0.
      fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'table interior page has no cells' ).
    ENDIF.

    ev_child = is_page-rightmost_pointer.
    ev_child_index = is_page-cell_count.
    LOOP AT is_page-cell_offsets INTO lv_offset.
      TRY.
          lv_key = zcl_sqlite_bytes=>read_varint(
            iv_data   = is_raw-data
            iv_offset = lv_offset + 4 ).
        CATCH cx_sy_range_out_of_bounds.
          fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
                iv_message = 'table interior key is truncated' ).
      ENDTRY.

      IF iv_rowid <= lv_key.
        lv_child = read_u32( iv_data   = is_raw-data
                             iv_offset = lv_offset ).
        ev_child = CONV i( lv_child ).
        ev_child_index = sy-tabix - 1.
        RETURN.
      ENDIF.
    ENDLOOP.

    IF ev_child < 1.
      fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'b-tree child page number is invalid' ).
    ENDIF.
  ENDMETHOD.

  METHOD build_cell.
    DATA lv_payload_length TYPE int8.
    DATA lv_local_size TYPE int8.
    DATA lv_local_length TYPE i.
    DATA lv_remaining TYPE int8.
    DATA lv_offset TYPE i.
    DATA lv_max_chunk TYPE int8.
    DATA lv_chunk_size TYPE int8.
    DATA lv_chunk_length TYPE i.
    DATA lv_first_page TYPE i.
    DATA lv_next_page TYPE i.
    DATA lv_index TYPE i.
    DATA lv_pointer TYPE xstring.
    DATA lv_pointer_data TYPE xstring.
    DATA lv_page_data TYPE xstring.
    DATA lv_payload_varint TYPE xstring.
    DATA lv_rowid_varint TYPE xstring.
    DATA lt_overflows TYPE ty_overflows.
    DATA ls_overflow TYPE ty_overflow.
    DATA ls_next TYPE ty_overflow.

    CLEAR et_pages.
    lv_payload_length = xstrlen( iv_payload ).
    lv_local_size = zcl_sqlite_btree=>local_payload_size(
      iv_payload_size = lv_payload_length
      iv_usable_size  = mv_usable_size ).
    lv_local_length = lv_local_size.

    lv_payload_varint = zcl_sqlite_bytes=>write_varint( lv_payload_length ).
    lv_rowid_varint = zcl_sqlite_bytes=>write_varint( iv_rowid ).

    IF lv_payload_length <= lv_local_size.
      ev_cell = lv_payload_varint && lv_rowid_varint && iv_payload.
      RETURN.
    ENDIF.

* allocate one page per overflow chunk, then link the chunks
    lv_max_chunk = mv_usable_size - 4.
    lv_offset = lv_local_length.
    lv_remaining = lv_payload_length - lv_local_size.
    WHILE lv_remaining > 0.
      IF lv_remaining < lv_max_chunk.
        lv_chunk_size = lv_remaining.
      ELSE.
        lv_chunk_size = lv_max_chunk.
      ENDIF.
      lv_chunk_length = lv_chunk_size.
      ls_overflow-page = mo_pager->allocate_page( ).
      ls_overflow-chunk = iv_payload+lv_offset(lv_chunk_length).
      APPEND ls_overflow TO lt_overflows.
      APPEND ls_overflow-page TO et_pages.
      lv_offset = lv_offset + lv_chunk_length.
      lv_remaining = lv_remaining - lv_chunk_size.
    ENDWHILE.

    LOOP AT lt_overflows INTO ls_overflow.
      lv_index = sy-tabix.
      lv_next_page = 0.
      IF lv_index < lines( lt_overflows ).
        READ TABLE lt_overflows INTO ls_next INDEX lv_index + 1.
        lv_next_page = ls_next-page.
      ENDIF.

      lv_page_data = zero_page( ).
      lv_page_data = set_u32( iv_data   = lv_page_data
                              iv_offset = 0
                              iv_value  = CONV int8( lv_next_page ) ).
      lv_page_data = splice( iv_data   = lv_page_data
                             iv_offset = 4
                             iv_value  = ls_overflow-chunk ).
      mo_pager->put_page( iv_page = ls_overflow-page
                          iv_data = lv_page_data ).
    ENDLOOP.

    READ TABLE lt_overflows INTO ls_overflow INDEX 1.
    lv_first_page = ls_overflow-page.
    lv_pointer_data = '00000000'.
    lv_pointer = set_u32( iv_data   = lv_pointer_data
                          iv_offset = 0
                          iv_value  = CONV int8( lv_first_page ) ).
    ev_cell = lv_payload_varint && lv_rowid_varint
           && iv_payload+0(lv_local_length) && lv_pointer.
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

    lv_data = iv_data.
    lv_cell_length = xstrlen( iv_cell ).
    lv_cell_count = is_target-cell_count.
    lv_content_start = is_target-cell_content_offset.
    IF lv_content_start > xstrlen( lv_data ).
      lv_content_start = mv_usable_size.
    ENDIF.
    lv_fragmented = is_target-fragmented_free_bytes.
    lv_first_free = is_target-first_freeblock.

* find the sorted position first, so duplicate rowids never look like "full"
    lv_insert_index = lv_cell_count + 1.
    LOOP AT is_target-cell_offsets INTO lv_cell_offset.
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

    lv_pointer_end = is_target-cell_pointer_offset + ( lv_cell_count + 1 ) * 2.
    IF lv_pointer_end > lv_content_start.
      fail( iv_code    = zcx_sqlite_error=>sqlite_full
            iv_message = 'b-tree leaf has no room for another cell pointer' ).
    ENDIF.

* prefer a freeblock, then take space from the gap below the cell content
    LOOP AT is_target-freeblocks INTO ls_freeblock.
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
      READ TABLE is_target-cell_offsets INTO lv_cell_offset INDEX lv_index.
      IF sy-subrc <> 0.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'b-tree cell pointer is missing' ).
      ENDIF.
      lv_data = set_u16(
        iv_data   = lv_data
        iv_offset = is_target-cell_pointer_offset + lv_index * 2
        iv_value  = CONV int8( lv_cell_offset ) ).
      lv_index = lv_index - 1.
    ENDWHILE.

    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = is_target-cell_pointer_offset + ( lv_insert_index - 1 ) * 2
      iv_value  = CONV int8( lv_cell_position ) ).

    lv_cell_count = lv_cell_count + 1.
    lv_stored_content = lv_content_start.
    IF lv_stored_content = 65536.
      lv_stored_content = 0.
    ENDIF.

    lv_data = set_u16( iv_data   = lv_data
                       iv_offset = is_target-cell_pointer_offset - 7
                       iv_value  = CONV int8( lv_first_free ) ).
    lv_data = set_u16( iv_data   = lv_data
                       iv_offset = is_target-cell_pointer_offset - 5
                       iv_value  = CONV int8( lv_cell_count ) ).
    lv_data = set_u16( iv_data   = lv_data
                       iv_offset = is_target-cell_pointer_offset - 3
                       iv_value  = lv_stored_content ).
    lv_data = set_u8( iv_data   = lv_data
                      iv_offset = is_target-cell_pointer_offset - 1
                      iv_value  = CONV int8( lv_fragmented ) ).

    rv_data = lv_data.
  ENDMETHOD.

  METHOD read_leaf_cells.
    DATA lv_offset TYPE i.
    DATA lv_payload_length TYPE int8.
    DATA lv_payload_length_size TYPE i.
    DATA lv_rowid_offset TYPE i.
    DATA lv_rowid_size TYPE i.
    DATA lv_local_size TYPE int8.
    DATA lv_cell_length TYPE i.
    DATA lv_rowid TYPE int8.
    DATA ls_cell TYPE ty_leaf_cell.

    LOOP AT is_page-cell_offsets INTO lv_offset.
      TRY.
          lv_payload_length = zcl_sqlite_bytes=>read_varint(
            iv_data   = is_raw-data
            iv_offset = lv_offset ).
          lv_payload_length_size = zcl_sqlite_bytes=>varint_length(
            iv_data   = is_raw-data
            iv_offset = lv_offset ).
          lv_rowid_offset = lv_offset + lv_payload_length_size.
          lv_rowid_size = zcl_sqlite_bytes=>varint_length(
            iv_data   = is_raw-data
            iv_offset = lv_rowid_offset ).
          lv_rowid = zcl_sqlite_bytes=>read_varint(
            iv_data   = is_raw-data
            iv_offset = lv_rowid_offset ).
        CATCH cx_sy_range_out_of_bounds.
          fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
                iv_message = 'table leaf cell header is truncated' ).
      ENDTRY.

      IF lv_payload_length < 0.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'table leaf payload size is negative' ).
      ENDIF.
      lv_local_size = zcl_sqlite_btree=>local_payload_size(
        iv_payload_size = lv_payload_length
        iv_usable_size  = mv_usable_size ).
      lv_cell_length = lv_payload_length_size + lv_rowid_size
                     + CONV i( lv_local_size ).
      IF lv_payload_length > lv_local_size.
        lv_cell_length = lv_cell_length + 4.
      ENDIF.
      IF lv_cell_length < 1
          OR lv_offset + lv_cell_length > xstrlen( is_raw-data ).
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'table leaf cell is truncated' ).
      ENDIF.

      ls_cell-rowid = lv_rowid.
      ls_cell-data = is_raw-data+lv_offset(lv_cell_length).
      APPEND ls_cell TO rt_cells.
    ENDLOOP.
  ENDMETHOD.

  METHOD read_interior_cells.
    DATA lv_offset TYPE i.
    DATA lv_key TYPE int8.
    DATA lv_key_size TYPE i.
    DATA lv_cell_length TYPE i.
    DATA lv_child TYPE int8.
    DATA ls_cell TYPE ty_interior_cell.

    LOOP AT is_page-cell_offsets INTO lv_offset.
      TRY.
          lv_child = zcl_sqlite_bytes=>read_u32(
            iv_data   = is_raw-data
            iv_offset = lv_offset ).
          lv_key = zcl_sqlite_bytes=>read_varint(
            iv_data   = is_raw-data
            iv_offset = lv_offset + 4 ).
          lv_key_size = zcl_sqlite_bytes=>varint_length(
            iv_data   = is_raw-data
            iv_offset = lv_offset + 4 ).
        CATCH cx_sy_range_out_of_bounds.
          fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
                iv_message = 'table interior cell is truncated' ).
      ENDTRY.

      lv_cell_length = 4 + lv_key_size.
      IF lv_child < 1
          OR lv_offset + lv_cell_length > xstrlen( is_raw-data ).
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'table interior cell is invalid' ).
      ENDIF.

      ls_cell-key = lv_key.
      ls_cell-child = CONV i( lv_child ).
      ls_cell-data = is_raw-data+lv_offset(lv_cell_length).
      APPEND ls_cell TO rt_cells.
    ENDLOOP.
  ENDMETHOD.

  METHOD split_leaf_cells.
    DATA lv_total TYPE i.
    DATA lv_left_bytes TYPE i.
    DATA lv_left_required TYPE i.
    DATA lv_right_required TYPE i.
    DATA lv_required TYPE i.
    DATA lv_best_required TYPE i.
    DATA lv_best_index TYPE i.
    DATA lv_index TYPE i.
    DATA lv_count TYPE i.
    DATA ls_cell TYPE ty_leaf_cell.

    lv_count = lines( it_cells ).
    IF lv_count < 2.
      fail( iv_code    = zcx_sqlite_error=>sqlite_full
            iv_message = 'b-tree leaf cell is too large to split' ).
    ENDIF.

    LOOP AT it_cells INTO ls_cell.
      lv_total = lv_total + xstrlen( ls_cell-data ).
    ENDLOOP.

    lv_left_bytes = 0.
    LOOP AT it_cells INTO ls_cell.
      lv_index = sy-tabix.
      lv_left_bytes = lv_left_bytes + xstrlen( ls_cell-data ).
      IF lv_index < lv_count.
        lv_left_required = c_leaf_header_size + lv_index * 2 + lv_left_bytes.
        lv_right_required = c_leaf_header_size + ( lv_count - lv_index ) * 2
                          + lv_total - lv_left_bytes.
        IF lv_left_required <= mv_usable_size
            AND lv_right_required <= mv_usable_size.
          lv_required = lv_left_required.
          IF lv_right_required > lv_required.
            lv_required = lv_right_required.
          ENDIF.
          IF lv_best_index = 0 OR lv_required < lv_best_required.
            lv_best_index = lv_index.
            lv_best_required = lv_required.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF lv_best_index = 0.
      fail( iv_code    = zcx_sqlite_error=>sqlite_full
            iv_message = 'b-tree leaf cells do not fit on two pages' ).
    ENDIF.

    ev_left_count = lv_best_index.
    READ TABLE it_cells INTO ls_cell INDEX lv_best_index.
    ev_promoted_key = ls_cell-rowid.
  ENDMETHOD.

  METHOD split_interior_cells.
    DATA lv_total TYPE i.
    DATA lv_left_bytes TYPE i.
    DATA lv_left_required TYPE i.
    DATA lv_right_required TYPE i.
    DATA lv_required TYPE i.
    DATA lv_best_required TYPE i.
    DATA lv_best_index TYPE i.
    DATA lv_index TYPE i.
    DATA lv_count TYPE i.
    DATA ls_cell TYPE ty_interior_cell.

    lv_count = lines( it_cells ).
    IF lv_count < 3.
      fail( iv_code    = zcx_sqlite_error=>sqlite_full
            iv_message = 'b-tree interior page has too few cells to split' ).
    ENDIF.

    LOOP AT it_cells INTO ls_cell.
      lv_total = lv_total + xstrlen( ls_cell-data ).
    ENDLOOP.

    lv_left_bytes = 0.
    LOOP AT it_cells INTO ls_cell.
      lv_index = sy-tabix.
      IF lv_index >= 2 AND lv_index <= lv_count - 1.
        lv_left_required = c_interior_header_size + ( lv_index - 1 ) * 2
                         + lv_left_bytes.
        lv_right_required = c_interior_header_size + ( lv_count - lv_index ) * 2
                          + lv_total - lv_left_bytes - xstrlen( ls_cell-data ).
        IF lv_left_required <= mv_usable_size
            AND lv_right_required <= mv_usable_size.
          lv_required = lv_left_required.
          IF lv_right_required > lv_required.
            lv_required = lv_right_required.
          ENDIF.
          IF lv_best_index = 0 OR lv_required < lv_best_required.
            lv_best_index = lv_index.
            lv_best_required = lv_required.
          ENDIF.
        ENDIF.
      ENDIF.
      lv_left_bytes = lv_left_bytes + xstrlen( ls_cell-data ).
    ENDLOOP.

    IF lv_best_index = 0.
      fail( iv_code    = zcx_sqlite_error=>sqlite_full
            iv_message = 'b-tree interior cells do not fit on two pages' ).
    ENDIF.

    ev_promote_index = lv_best_index.
    READ TABLE it_cells INTO ls_cell INDEX lv_best_index.
    ev_promoted_key = ls_cell-key.
  ENDMETHOD.

  METHOD build_leaf_page.
    DATA lv_data TYPE xstring.
    DATA lv_cell_offset TYPE i.
    DATA lv_content TYPE i.
    DATA lv_index TYPE i.
    DATA lv_count TYPE i.
    DATA lv_stored_content TYPE int8.
    DATA ls_cell TYPE ty_leaf_cell.

    lv_count = lines( it_cells ).
    lv_data = zero_page( ).
    lv_content = mv_usable_size.
    lv_index = 0.
    LOOP AT it_cells INTO ls_cell.
      lv_cell_offset = lv_content - xstrlen( ls_cell-data ).
      IF lv_cell_offset < iv_offset + c_leaf_header_size + lv_count * 2.
        fail( iv_code    = zcx_sqlite_error=>sqlite_full
              iv_message = 'b-tree leaf split does not fit' ).
      ENDIF.
      lv_data = splice( iv_data   = lv_data
                        iv_offset = lv_cell_offset
                        iv_value  = ls_cell-data ).
      lv_data = set_u16(
        iv_data   = lv_data
        iv_offset = iv_offset + c_leaf_header_size + lv_index * 2
        iv_value  = CONV int8( lv_cell_offset ) ).
      lv_content = lv_cell_offset.
      lv_index = lv_index + 1.
    ENDLOOP.

    lv_stored_content = lv_content.
    IF lv_stored_content = 65536.
      lv_stored_content = 0.
    ENDIF.

    lv_data = set_u8( iv_data   = lv_data
                      iv_offset = iv_offset
                      iv_value  = zcl_sqlite_page=>c_table_leaf ).
    lv_data = set_u16( iv_data   = lv_data
                       iv_offset = iv_offset + 1
                       iv_value  = 0 ).
    lv_data = set_u16( iv_data   = lv_data
                       iv_offset = iv_offset + 3
                       iv_value  = CONV int8( lv_count ) ).
    lv_data = set_u16( iv_data   = lv_data
                       iv_offset = iv_offset + 5
                       iv_value  = lv_stored_content ).
    lv_data = set_u8( iv_data   = lv_data
                      iv_offset = iv_offset + 7
                      iv_value  = 0 ).

    rv_data = lv_data.
  ENDMETHOD.

  METHOD build_interior_page.
    DATA lv_data TYPE xstring.
    DATA lv_cell_offset TYPE i.
    DATA lv_content TYPE i.
    DATA lv_index TYPE i.
    DATA lv_count TYPE i.
    DATA lv_stored_content TYPE int8.
    DATA ls_cell TYPE ty_interior_cell.

    lv_count = lines( it_cells ).
    lv_data = zero_page( ).
    lv_content = mv_usable_size.
    lv_index = 0.
    LOOP AT it_cells INTO ls_cell.
      lv_cell_offset = lv_content - xstrlen( ls_cell-data ).
      IF lv_cell_offset < iv_offset + c_interior_header_size + lv_count * 2.
        fail( iv_code    = zcx_sqlite_error=>sqlite_full
              iv_message = 'b-tree interior split does not fit' ).
      ENDIF.
      lv_data = splice( iv_data   = lv_data
                        iv_offset = lv_cell_offset
                        iv_value  = ls_cell-data ).
      lv_data = set_u16(
        iv_data   = lv_data
        iv_offset = iv_offset + c_interior_header_size + lv_index * 2
        iv_value  = CONV int8( lv_cell_offset ) ).
      lv_content = lv_cell_offset.
      lv_index = lv_index + 1.
    ENDLOOP.

    lv_stored_content = lv_content.
    IF lv_stored_content = 65536.
      lv_stored_content = 0.
    ENDIF.

    lv_data = set_u8( iv_data   = lv_data
                      iv_offset = iv_offset
                      iv_value  = zcl_sqlite_page=>c_table_interior ).
    lv_data = set_u16( iv_data   = lv_data
                       iv_offset = iv_offset + 1
                       iv_value  = 0 ).
    lv_data = set_u16( iv_data   = lv_data
                       iv_offset = iv_offset + 3
                       iv_value  = CONV int8( lv_count ) ).
    lv_data = set_u16( iv_data   = lv_data
                       iv_offset = iv_offset + 5
                       iv_value  = lv_stored_content ).
    lv_data = set_u8( iv_data   = lv_data
                      iv_offset = iv_offset + 7
                      iv_value  = 0 ).
    lv_data = set_u32( iv_data   = lv_data
                       iv_offset = iv_offset + 8
                       iv_value  = CONV int8( iv_rightmost ) ).

    rv_data = lv_data.
  ENDMETHOD.

  METHOD build_interior_cell.
    DATA lv_data TYPE xstring.

    lv_data = '00000000'.
    lv_data = set_u32( iv_data   = lv_data
                       iv_offset = 0
                       iv_value  = CONV int8( iv_child ) ).
    rv_cell = lv_data && zcl_sqlite_bytes=>write_varint( iv_key ).
  ENDMETHOD.

  METHOD build_root_interior.
    DATA lt_cells TYPE ty_interior_cells.
    DATA ls_cell TYPE ty_interior_cell.

    ls_cell-child = iv_left_page.
    ls_cell-key = iv_promoted_key.
    ls_cell-data = build_interior_cell( iv_child = iv_left_page
                                        iv_key   = iv_promoted_key ).
    APPEND ls_cell TO lt_cells.

    rv_data = build_interior_page(
      it_cells     = lt_cells
      iv_rightmost = iv_right_page
      iv_offset    = is_raw-btree_offset ).
    rv_data = preserve_header( iv_data = rv_data
                               is_raw  = is_raw ).
  ENDMETHOD.

  METHOD preserve_header.
    DATA lv_prefix TYPE xstring.

    IF is_raw-btree_offset <= 0.
      rv_data = iv_data.
      RETURN.
    ENDIF.
    IF xstrlen( is_raw-data ) < is_raw-btree_offset.
      fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'b-tree page header is truncated' ).
    ENDIF.
    lv_prefix = is_raw-data+0(is_raw-btree_offset).
    rv_data = splice( iv_data   = iv_data
                      iv_offset = 0
                      iv_value  = lv_prefix ).
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

  METHOD set_u32.
    TRY.
        rv_data = zcl_sqlite_bytes=>write_u32(
          iv_data   = iv_data
          iv_offset = iv_offset
          iv_value  = iv_value ).
      CATCH cx_sy_range_out_of_bounds cx_sy_conversion_overflow.
        fail( iv_code    = zcx_sqlite_error=>sqlite_internal
              iv_message = 'b-tree page number could not be written' ).
    ENDTRY.
  ENDMETHOD.

  METHOD zero_page.
    rv_data = repeat( val = '00'
                      occ = mv_page_size ).
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
