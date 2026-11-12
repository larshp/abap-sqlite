* Writer for SQLite index b-trees, see
* https://www.sqlite.org/fileformat.html#b_tree_pages
*
* Index entries are records containing the indexed columns followed by the
* rowid. Interior pages contain real entries as well as child pointers, so an
* entry promoted during a split is removed from the child page. The writer
* keeps the same value ordering as zcl_sqlite_index_cursor: BINARY collation
* with SQLite's NULL, numeric, text, blob rank.
CLASS zcl_sqlite_index_writer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_values TYPE zcl_sqlite_record=>ty_values.
    TYPES ty_keys TYPE STANDARD TABLE OF ty_values WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING io_pager     TYPE REF TO zcl_sqlite_pager
                iv_root_page TYPE i
      RAISING   zcx_sqlite_error.

    METHODS insert_entry
      IMPORTING it_values        TYPE ty_values
                iv_unique        TYPE abap_bool DEFAULT abap_false
                iv_prefix_length TYPE i DEFAULT 0
      RAISING   zcx_sqlite_error.

    METHODS clear_tree
      RAISING zcx_sqlite_error.

* free every page of the index tree, including the root page
    METHODS free_tree
      RAISING zcx_sqlite_error.

    METHODS rebuild
      IMPORTING it_keys          TYPE ty_keys
                iv_unique        TYPE abap_bool DEFAULT abap_false
                iv_prefix_length TYPE i DEFAULT 0
      RAISING   zcx_sqlite_error.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_leaf_header_size     TYPE i VALUE 8.
    CONSTANTS c_interior_header_size TYPE i VALUE 12.

    TYPES ty_pages TYPE STANDARD TABLE OF i WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_overflow,
             page  TYPE i,
             chunk TYPE xstring,
           END OF ty_overflow.
    TYPES ty_overflows TYPE STANDARD TABLE OF ty_overflow WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_cell,
             child  TYPE i,
             values TYPE ty_values,
             data   TYPE xstring,
           END OF ty_cell.
    TYPES ty_cells TYPE STANDARD TABLE OF ty_cell WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_split,
             split           TYPE abap_bool,
             promoted_cell   TYPE xstring,
             promoted_values TYPE ty_values,
             right_page      TYPE i,
           END OF ty_split.

    DATA mo_pager       TYPE REF TO zcl_sqlite_pager.
    DATA mv_root_page   TYPE i.
    DATA mv_page_size   TYPE i.
    DATA mv_usable_size TYPE i.

    METHODS insert_page
      IMPORTING iv_page         TYPE i
                it_values       TYPE ty_values
                iv_cell         TYPE xstring
      RETURNING VALUE(rs_split) TYPE ty_split
      RAISING   zcx_sqlite_error.

    METHODS insert_leaf_page
      IMPORTING iv_page         TYPE i
                is_raw          TYPE zcl_sqlite_pager=>ty_page
                is_page         TYPE zcl_sqlite_page=>ty_page
                it_values       TYPE ty_values
                iv_cell         TYPE xstring
      RETURNING VALUE(rs_split) TYPE ty_split
      RAISING   zcx_sqlite_error.

    METHODS insert_interior_page
      IMPORTING iv_page            TYPE i
                is_raw             TYPE zcl_sqlite_pager=>ty_page
                is_page            TYPE zcl_sqlite_page=>ty_page
                iv_child           TYPE i
                iv_child_index     TYPE i
                it_promoted_values TYPE ty_values
                iv_promoted_cell   TYPE xstring
                iv_right_page      TYPE i
      RETURNING VALUE(rs_split)    TYPE ty_split
      RAISING   zcx_sqlite_error.

    METHODS read_leaf_cells
      IMPORTING is_raw          TYPE zcl_sqlite_pager=>ty_page
                is_page         TYPE zcl_sqlite_page=>ty_page
      RETURNING VALUE(rt_cells) TYPE ty_cells
      RAISING   zcx_sqlite_error.

    METHODS read_interior_cells
      IMPORTING is_raw          TYPE zcl_sqlite_pager=>ty_page
                is_page         TYPE zcl_sqlite_page=>ty_page
      RETURNING VALUE(rt_cells) TYPE ty_cells
      RAISING   zcx_sqlite_error.

    METHODS split_leaf_cells
      IMPORTING it_cells                TYPE ty_cells
      RETURNING VALUE(rv_promote_index) TYPE i
      RAISING   zcx_sqlite_error.

    METHODS split_interior_cells
      IMPORTING it_cells                TYPE ty_cells
      RETURNING VALUE(rv_promote_index) TYPE i
      RAISING   zcx_sqlite_error.

    METHODS contains_prefix
      IMPORTING it_values        TYPE ty_values
                iv_prefix_length TYPE i
      RETURNING VALUE(rv_found)  TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS build_cell
      IMPORTING it_values TYPE ty_values
      EXPORTING ev_cell   TYPE xstring
                et_pages  TYPE ty_pages
      RAISING   zcx_sqlite_error.

    METHODS build_leaf_page
      IMPORTING it_cells       TYPE ty_cells
                iv_offset      TYPE i
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS build_interior_page
      IMPORTING it_cells       TYPE ty_cells
                iv_rightmost   TYPE i
                iv_offset      TYPE i
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS build_root_interior
      IMPORTING is_raw           TYPE zcl_sqlite_pager=>ty_page
                iv_left_page     TYPE i
                iv_promoted_cell TYPE xstring
                iv_right_page    TYPE i
      RETURNING VALUE(rv_data)   TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS clear_page
      IMPORTING iv_page TYPE i
      RAISING   zcx_sqlite_error.

    METHODS free_cell_overflow
      IMPORTING iv_data     TYPE xstring
                iv_offset   TYPE i
                iv_interior TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS free_overflow_chain
      IMPORTING iv_first_page TYPE i
      RAISING   zcx_sqlite_error.

    METHODS compare_records
      IMPORTING it_left           TYPE ty_values
                it_right          TYPE ty_values
      RETURNING VALUE(rv_compare) TYPE i
      RAISING   zcx_sqlite_error.

    METHODS compare_prefix
      IMPORTING it_record         TYPE ty_values
                it_prefix         TYPE ty_values
      RETURNING VALUE(rv_compare) TYPE i
      RAISING   zcx_sqlite_error.

    METHODS compare_value
      IMPORTING io_left           TYPE REF TO zcl_sqlite_value
                io_right          TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(rv_compare) TYPE i
      RAISING   zcx_sqlite_error.

    METHODS value_rank
      IMPORTING io_value       TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(rv_rank) TYPE i
      RAISING   zcx_sqlite_error.

    METHODS compare_bytes
      IMPORTING iv_left           TYPE xstring
                iv_right          TYPE xstring
      RETURNING VALUE(rv_compare) TYPE i
      RAISING   zcx_sqlite_error.

    METHODS preserve_header
      IMPORTING iv_data        TYPE xstring
                is_raw         TYPE zcl_sqlite_pager=>ty_page
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS zero_page
      RETURNING VALUE(rv_data) TYPE xstring.

    METHODS splice
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE xstring
      RETURNING VALUE(rv_data) TYPE xstring.

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

    METHODS read_u32
      IMPORTING iv_data         TYPE xstring
                iv_offset       TYPE i
      RETURNING VALUE(rv_value) TYPE int8
      RAISING   zcx_sqlite_error.

    METHODS interior_cell
      IMPORTING iv_child        TYPE i
                iv_payload_cell TYPE xstring
      RETURNING VALUE(rv_cell)  TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS fail
      IMPORTING iv_code    TYPE i
                iv_message TYPE string
      RAISING   zcx_sqlite_error.

ENDCLASS.


CLASS zcl_sqlite_index_writer IMPLEMENTATION.

  METHOD constructor.
    DATA ls_header TYPE zcl_sqlite_header=>ty_header.

    mo_pager = io_pager.
    mv_root_page = iv_root_page.
    ls_header = io_pager->header( ).
    mv_page_size = CONV i( ls_header-page_size ).
    mv_usable_size = mv_page_size - CONV i( ls_header-reserved_bytes ).
    IF mv_usable_size < zcl_sqlite_btree=>c_min_usable_size.
      fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'index writer usable page size is too small' ).
    ENDIF.
  ENDMETHOD.

  METHOD insert_entry.
    DATA lt_pages TYPE ty_pages.
    DATA lv_cell TYPE xstring.
    DATA lv_page TYPE i.
    DATA lo_error TYPE REF TO zcx_sqlite_error.

    IF iv_unique = abap_true
        AND iv_prefix_length > 0
        AND contains_prefix(
          it_values        = it_values
          iv_prefix_length = iv_prefix_length ) = abap_true.
      fail( iv_code    = zcx_sqlite_error=>sqlite_constraint
            iv_message = 'UNIQUE constraint failed' ).
    ENDIF.

    build_cell(
      EXPORTING
        it_values = it_values
      IMPORTING
        ev_cell   = lv_cell
        et_pages  = lt_pages ).

    TRY.
        insert_page(
          iv_page   = mv_root_page
          it_values = it_values
          iv_cell   = lv_cell ).
      CATCH zcx_sqlite_error INTO lo_error.
        LOOP AT lt_pages INTO lv_page.
          mo_pager->free_page( lv_page ).
        ENDLOOP.
        RAISE EXCEPTION lo_error.
    ENDTRY.
  ENDMETHOD.

  METHOD clear_tree.
    clear_page( mv_root_page ).
    mo_pager->put_page(
      iv_page = mv_root_page
      iv_data = zcl_sqlite_btree=>empty_index_leaf( mv_page_size ) ).
  ENDMETHOD.

  METHOD free_tree.
    clear_page( mv_root_page ).
    mo_pager->free_page( mv_root_page ).
  ENDMETHOD.

  METHOD rebuild.
    DATA lt_values TYPE ty_values.

    clear_tree( ).
    LOOP AT it_keys INTO lt_values.
      insert_entry(
        it_values        = lt_values
        iv_unique        = iv_unique
        iv_prefix_length = iv_prefix_length ).
    ENDLOOP.
  ENDMETHOD.

  METHOD insert_page.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA lt_cells TYPE ty_cells.
    DATA ls_cell TYPE ty_cell.
    DATA lv_child TYPE i.
    DATA lv_child_index TYPE i.
    DATA lv_compare TYPE i.
    DATA ls_split TYPE ty_split.

    ls_raw = mo_pager->get_page( iv_page ).
    ls_page = zcl_sqlite_page=>parse(
      iv_data   = ls_raw-data
      iv_offset = ls_raw-btree_offset ).

    CASE ls_page-page_type.
      WHEN zcl_sqlite_page=>c_index_leaf.
        rs_split = insert_leaf_page(
          iv_page   = iv_page
          is_raw    = ls_raw
          is_page   = ls_page
          it_values = it_values
          iv_cell   = iv_cell ).
      WHEN zcl_sqlite_page=>c_index_interior.
        lt_cells = read_interior_cells(
          is_raw  = ls_raw
          is_page = ls_page ).
        lv_child = ls_page-rightmost_pointer.
        lv_child_index = lines( lt_cells ) + 1.

        LOOP AT lt_cells INTO ls_cell.
          lv_compare = compare_records(
            it_left  = it_values
            it_right = ls_cell-values ).
          IF lv_compare = 0.
            fail( iv_code    = zcx_sqlite_error=>sqlite_constraint
                  iv_message = 'index entry already exists' ).
          ELSEIF lv_compare < 0.
            lv_child = ls_cell-child.
            lv_child_index = sy-tabix.
            EXIT.
          ENDIF.
        ENDLOOP.

        ls_split = insert_page(
          iv_page   = lv_child
          it_values = it_values
          iv_cell   = iv_cell ).
        IF ls_split-split = abap_false.
          RETURN.
        ENDIF.

        rs_split = insert_interior_page(
          iv_page            = iv_page
          is_raw             = ls_raw
          is_page            = ls_page
          iv_child           = lv_child
          iv_child_index     = lv_child_index
          it_promoted_values = ls_split-promoted_values
          iv_promoted_cell   = ls_split-promoted_cell
          iv_right_page      = ls_split-right_page ).
      WHEN OTHERS.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'writer found a non-index b-tree page' ).
    ENDCASE.
  ENDMETHOD.

  METHOD insert_leaf_page.
    DATA lt_cells TYPE ty_cells.
    DATA lt_left TYPE ty_cells.
    DATA lt_right TYPE ty_cells.
    DATA ls_cell TYPE ty_cell.
    DATA ls_new TYPE ty_cell.
    DATA lv_insert_index TYPE i.
    DATA lv_compare TYPE i.
    DATA lv_required TYPE i.
    DATA lv_data TYPE xstring.
    DATA lv_promote_index TYPE i.
    DATA lv_left_data TYPE xstring.
    DATA lv_right_data TYPE xstring.
    DATA lv_left_page TYPE i.
    DATA lv_right_page TYPE i.

    lt_cells = read_leaf_cells(
      is_raw  = is_raw
      is_page = is_page ).

    ls_new-values = it_values.
    ls_new-data = iv_cell.
    lv_insert_index = lines( lt_cells ) + 1.
    LOOP AT lt_cells INTO ls_cell.
      lv_compare = compare_records(
        it_left  = ls_cell-values
        it_right = it_values ).
      IF lv_compare = 0.
        fail( iv_code    = zcx_sqlite_error=>sqlite_constraint
              iv_message = 'index entry already exists' ).
      ELSEIF lv_compare > 0.
        lv_insert_index = sy-tabix.
        EXIT.
      ENDIF.
    ENDLOOP.
    INSERT ls_new INTO lt_cells INDEX lv_insert_index.

    lv_required = c_leaf_header_size + lines( lt_cells ) * 2.
    LOOP AT lt_cells INTO ls_cell.
      lv_required = lv_required + xstrlen( ls_cell-data ).
    ENDLOOP.

    IF lv_required <= mv_usable_size.
      lv_data = build_leaf_page(
        it_cells  = lt_cells
        iv_offset = is_raw-btree_offset ).
      lv_data = preserve_header( iv_data = lv_data
                                 is_raw  = is_raw ).
      mo_pager->put_page( iv_page = iv_page
                          iv_data = lv_data ).
      RETURN.
    ENDIF.

    lv_promote_index = split_leaf_cells( lt_cells ).
    LOOP AT lt_cells INTO ls_cell.
      IF sy-tabix < lv_promote_index.
        APPEND ls_cell TO lt_left.
      ELSEIF sy-tabix = lv_promote_index.
        rs_split-promoted_values = ls_cell-values.
        rs_split-promoted_cell = ls_cell-data.
      ELSE.
        APPEND ls_cell TO lt_right.
      ENDIF.
    ENDLOOP.

    lv_left_data = build_leaf_page(
      it_cells  = lt_left
      iv_offset = 0 ).
    lv_right_data = build_leaf_page(
      it_cells  = lt_right
      iv_offset = 0 ).

    IF iv_page = mv_root_page.
      lv_left_page = mo_pager->allocate_page( ).
      lv_right_page = mo_pager->allocate_page( ).
      mo_pager->put_page( iv_page = lv_left_page
                          iv_data = lv_left_data ).
      mo_pager->put_page( iv_page = lv_right_page
                          iv_data = lv_right_data ).
      lv_data = build_root_interior(
        is_raw           = is_raw
        iv_left_page     = lv_left_page
        iv_promoted_cell = rs_split-promoted_cell
        iv_right_page    = lv_right_page ).
      mo_pager->put_page( iv_page = iv_page
                          iv_data = lv_data ).
      CLEAR rs_split.
      RETURN.
    ENDIF.

    lv_right_page = mo_pager->allocate_page( ).
    mo_pager->put_page( iv_page = iv_page
                        iv_data = lv_left_data ).
    mo_pager->put_page( iv_page = lv_right_page
                        iv_data = lv_right_data ).
    rs_split-split = abap_true.
    rs_split-right_page = lv_right_page.
  ENDMETHOD.

  METHOD insert_interior_page.
    DATA lt_cells TYPE ty_cells.
    DATA lt_left TYPE ty_cells.
    DATA lt_right TYPE ty_cells.
    DATA ls_cell TYPE ty_cell.
    DATA ls_old TYPE ty_cell.
    DATA lv_rightmost TYPE i.
    DATA lv_left_rightmost TYPE i.
    DATA lv_index TYPE i.
    DATA lv_required TYPE i.
    DATA lv_data TYPE xstring.
    DATA lv_promote_index TYPE i.
    DATA lv_left_data TYPE xstring.
    DATA lv_right_data TYPE xstring.
    DATA lv_left_page TYPE i.
    DATA lv_right_page TYPE i.
    DATA lv_old_payload TYPE xstring.

    lt_cells = read_interior_cells(
      is_raw  = is_raw
      is_page = is_page ).
    lv_rightmost = is_page-rightmost_pointer.

    IF iv_child_index <= lines( lt_cells ).
      READ TABLE lt_cells INTO ls_old INDEX iv_child_index.
      IF sy-subrc <> 0 OR ls_old-child <> iv_child.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'index interior child pointer does not match' ).
      ENDIF.
      lv_old_payload = ls_old-data+4.

      ls_cell-values = it_promoted_values.
      ls_cell-child = iv_child.
      ls_cell-data = interior_cell(
        iv_child        = iv_child
        iv_payload_cell = iv_promoted_cell ).
      MODIFY lt_cells FROM ls_cell INDEX iv_child_index.

      ls_cell-values = ls_old-values.
      ls_cell-child = iv_right_page.
      ls_cell-data = interior_cell(
        iv_child        = iv_right_page
        iv_payload_cell = lv_old_payload ).
      lv_index = iv_child_index + 1.
      INSERT ls_cell INTO lt_cells INDEX lv_index.
    ELSE.
      ls_cell-values = it_promoted_values.
      ls_cell-child = iv_child.
      ls_cell-data = interior_cell(
        iv_child        = iv_child
        iv_payload_cell = iv_promoted_cell ).
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

    lv_promote_index = split_interior_cells( lt_cells ).
    LOOP AT lt_cells INTO ls_cell.
      IF sy-tabix < lv_promote_index.
        APPEND ls_cell TO lt_left.
      ELSEIF sy-tabix = lv_promote_index.
        lv_left_rightmost = ls_cell-child.
        rs_split-promoted_values = ls_cell-values.
        rs_split-promoted_cell = ls_cell-data+4.
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
        is_raw           = is_raw
        iv_left_page     = lv_left_page
        iv_promoted_cell = rs_split-promoted_cell
        iv_right_page    = lv_right_page ).
      mo_pager->put_page( iv_page = iv_page
                          iv_data = lv_data ).
      CLEAR rs_split.
      RETURN.
    ENDIF.

    lv_right_page = mo_pager->allocate_page( ).
    mo_pager->put_page( iv_page = iv_page
                        iv_data = lv_left_data ).
    mo_pager->put_page( iv_page = lv_right_page
                        iv_data = lv_right_data ).
    rs_split-split = abap_true.
    rs_split-right_page = lv_right_page.
  ENDMETHOD.

  METHOD read_leaf_cells.
    DATA lv_offset TYPE i.
    DATA lv_payload_length TYPE int8.
    DATA lv_payload_length_size TYPE i.
    DATA lv_local_size TYPE int8.
    DATA lv_cell_length TYPE i.
    DATA lv_payload TYPE xstring.
    DATA ls_cell TYPE ty_cell.

    LOOP AT is_page-cell_offsets INTO lv_offset.
      TRY.
          lv_payload_length = zcl_sqlite_bytes=>read_varint(
            iv_data   = is_raw-data
            iv_offset = lv_offset ).
          lv_payload_length_size = zcl_sqlite_bytes=>varint_length(
            iv_data   = is_raw-data
            iv_offset = lv_offset ).
        CATCH cx_sy_range_out_of_bounds.
          fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
                iv_message = 'index leaf cell header is truncated' ).
      ENDTRY.

      lv_local_size = zcl_sqlite_btree=>local_payload_size(
        iv_payload_size = lv_payload_length
        iv_usable_size  = mv_usable_size
        iv_table_leaf   = abap_false ).
      lv_cell_length = lv_payload_length_size + lv_local_size.
      IF lv_payload_length > lv_local_size.
        lv_cell_length = lv_cell_length + 4.
      ENDIF.
      IF lv_offset + lv_cell_length > xstrlen( is_raw-data ).
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'index leaf cell is truncated' ).
      ENDIF.

      lv_payload = zcl_sqlite_btree=>read_payload(
        io_pager          = mo_pager
        iv_page_data      = is_raw-data
        iv_payload_offset = lv_offset + lv_payload_length_size
        iv_payload_size   = lv_payload_length
        iv_usable_size    = mv_usable_size
        iv_table_leaf     = abap_false ).

      CLEAR ls_cell.
      ls_cell-data = is_raw-data+lv_offset(lv_cell_length).
      ls_cell-values = zcl_sqlite_record=>decode( lv_payload ).
      APPEND ls_cell TO rt_cells.
    ENDLOOP.
  ENDMETHOD.

  METHOD read_interior_cells.
    DATA lv_offset TYPE i.
    DATA lv_child TYPE int8.
    DATA lv_payload_length TYPE int8.
    DATA lv_payload_length_size TYPE i.
    DATA lv_local_size TYPE int8.
    DATA lv_cell_length TYPE i.
    DATA lv_payload TYPE xstring.
    DATA ls_cell TYPE ty_cell.

    LOOP AT is_page-cell_offsets INTO lv_offset.
      TRY.
          lv_child = zcl_sqlite_bytes=>read_u32(
            iv_data   = is_raw-data
            iv_offset = lv_offset ).
          lv_payload_length = zcl_sqlite_bytes=>read_varint(
            iv_data   = is_raw-data
            iv_offset = lv_offset + 4 ).
          lv_payload_length_size = zcl_sqlite_bytes=>varint_length(
            iv_data   = is_raw-data
            iv_offset = lv_offset + 4 ).
        CATCH cx_sy_range_out_of_bounds.
          fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
                iv_message = 'index interior cell header is truncated' ).
      ENDTRY.

      lv_local_size = zcl_sqlite_btree=>local_payload_size(
        iv_payload_size = lv_payload_length
        iv_usable_size  = mv_usable_size
        iv_table_leaf   = abap_false ).
      lv_cell_length = 4 + lv_payload_length_size + lv_local_size.
      IF lv_payload_length > lv_local_size.
        lv_cell_length = lv_cell_length + 4.
      ENDIF.
      IF lv_child < 1
          OR lv_offset + lv_cell_length > xstrlen( is_raw-data ).
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'index interior cell is invalid' ).
      ENDIF.

      lv_payload = zcl_sqlite_btree=>read_payload(
        io_pager          = mo_pager
        iv_page_data      = is_raw-data
        iv_payload_offset = lv_offset + 4 + lv_payload_length_size
        iv_payload_size   = lv_payload_length
        iv_usable_size    = mv_usable_size
        iv_table_leaf     = abap_false ).

      CLEAR ls_cell.
      ls_cell-child = CONV i( lv_child ).
      ls_cell-data = is_raw-data+lv_offset(lv_cell_length).
      ls_cell-values = zcl_sqlite_record=>decode( lv_payload ).
      APPEND ls_cell TO rt_cells.
    ENDLOOP.
  ENDMETHOD.

  METHOD split_leaf_cells.
    DATA lv_count TYPE i.
    DATA lv_total TYPE i.
    DATA lv_left_bytes TYPE i.
    DATA lv_current_bytes TYPE i.
    DATA lv_left_required TYPE i.
    DATA lv_right_required TYPE i.
    DATA lv_required TYPE i.
    DATA lv_best_required TYPE i.
    DATA lv_index TYPE i.
    DATA ls_cell TYPE ty_cell.

    lv_count = lines( it_cells ).
    IF lv_count < 3.
      fail( iv_code    = zcx_sqlite_error=>sqlite_full
            iv_message = 'index leaf page has too few cells to split' ).
    ENDIF.

    LOOP AT it_cells INTO ls_cell.
      lv_total = lv_total + xstrlen( ls_cell-data ).
    ENDLOOP.

    lv_left_bytes = 0.
    LOOP AT it_cells INTO ls_cell.
      lv_index = sy-tabix.
      lv_current_bytes = xstrlen( ls_cell-data ).
      lv_left_bytes = lv_left_bytes + lv_current_bytes.

      IF lv_index >= 2 AND lv_index <= lv_count - 1.
        lv_left_required = c_leaf_header_size + ( lv_index - 1 ) * 2
                         + lv_left_bytes - lv_current_bytes.
        lv_right_required = c_leaf_header_size + ( lv_count - lv_index ) * 2
                          + lv_total - lv_left_bytes.
        IF lv_left_required <= mv_usable_size
            AND lv_right_required <= mv_usable_size.
          lv_required = lv_left_required.
          IF lv_right_required > lv_required.
            lv_required = lv_right_required.
          ENDIF.
          IF rv_promote_index = 0 OR lv_required < lv_best_required.
            rv_promote_index = lv_index.
            lv_best_required = lv_required.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF rv_promote_index = 0.
      fail( iv_code    = zcx_sqlite_error=>sqlite_full
            iv_message = 'index leaf cells do not fit on two pages' ).
    ENDIF.
  ENDMETHOD.

  METHOD split_interior_cells.
    DATA lv_count TYPE i.
    DATA lv_total TYPE i.
    DATA lv_left_bytes TYPE i.
    DATA lv_current_bytes TYPE i.
    DATA lv_left_required TYPE i.
    DATA lv_right_required TYPE i.
    DATA lv_required TYPE i.
    DATA lv_best_required TYPE i.
    DATA lv_index TYPE i.
    DATA ls_cell TYPE ty_cell.

    lv_count = lines( it_cells ).
    IF lv_count < 3.
      fail( iv_code    = zcx_sqlite_error=>sqlite_full
            iv_message = 'index interior page has too few cells to split' ).
    ENDIF.

    LOOP AT it_cells INTO ls_cell.
      lv_total = lv_total + xstrlen( ls_cell-data ).
    ENDLOOP.

    lv_left_bytes = 0.
    LOOP AT it_cells INTO ls_cell.
      lv_index = sy-tabix.
      lv_current_bytes = xstrlen( ls_cell-data ).
      lv_left_bytes = lv_left_bytes + lv_current_bytes.

      IF lv_index >= 2 AND lv_index <= lv_count - 1.
        lv_left_required = c_interior_header_size + ( lv_index - 1 ) * 2
                         + lv_left_bytes - lv_current_bytes.
        lv_right_required = c_interior_header_size + ( lv_count - lv_index ) * 2
                          + lv_total - lv_left_bytes.
        IF lv_left_required <= mv_usable_size
            AND lv_right_required <= mv_usable_size.
          lv_required = lv_left_required.
          IF lv_right_required > lv_required.
            lv_required = lv_right_required.
          ENDIF.
          IF rv_promote_index = 0 OR lv_required < lv_best_required.
            rv_promote_index = lv_index.
            lv_best_required = lv_required.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF rv_promote_index = 0.
      fail( iv_code    = zcx_sqlite_error=>sqlite_full
            iv_message = 'index interior cells do not fit on two pages' ).
    ENDIF.
  ENDMETHOD.

  METHOD contains_prefix.
    DATA lt_prefix TYPE ty_values.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA lo_record TYPE REF TO zcl_sqlite_value.
    DATA lo_prefix TYPE REF TO zcl_sqlite_value.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA lt_cells TYPE ty_cells.
    DATA ls_cell TYPE ty_cell.
    DATA lv_page TYPE i.
    DATA lv_child TYPE i.
    DATA lv_compare TYPE i.
    DATA lv_iterations TYPE i.

    LOOP AT it_values INTO lo_value.
      IF sy-tabix > iv_prefix_length.
        EXIT.
      ENDIF.
      IF lo_value->is_null( ) = abap_true.
        RETURN.
      ENDIF.
      APPEND lo_value TO lt_prefix.
    ENDLOOP.
    IF lines( lt_prefix ) <> iv_prefix_length.
      RETURN.
    ENDIF.

    lv_page = mv_root_page.
    WHILE lv_page > 0.
      lv_iterations = lv_iterations + 1.
      IF lv_iterations > mo_pager->page_count( ).
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'index tree contains a cycle' ).
      ENDIF.

      ls_raw = mo_pager->get_page( lv_page ).
      ls_page = zcl_sqlite_page=>parse(
        iv_data   = ls_raw-data
        iv_offset = ls_raw-btree_offset ).

      CASE ls_page-page_type.
        WHEN zcl_sqlite_page=>c_index_leaf.
          lt_cells = read_leaf_cells(
            is_raw  = ls_raw
            is_page = ls_page ).
          LOOP AT lt_cells INTO ls_cell.
            lv_compare = compare_prefix(
              it_record = ls_cell-values
              it_prefix = lt_prefix ).
            IF lv_compare = 0.
              rv_found = abap_true.
              RETURN.
            ELSEIF lv_compare > 0.
              RETURN.
            ENDIF.
          ENDLOOP.
          RETURN.
        WHEN zcl_sqlite_page=>c_index_interior.
          lt_cells = read_interior_cells(
            is_raw  = ls_raw
            is_page = ls_page ).
          lv_child = ls_page-rightmost_pointer.
          LOOP AT lt_cells INTO ls_cell.
            lv_compare = compare_prefix(
              it_record = ls_cell-values
              it_prefix = lt_prefix ).
            IF lv_compare = 0.
              rv_found = abap_true.
              RETURN.
            ELSEIF lv_compare > 0.
              lv_child = ls_cell-child.
              EXIT.
            ENDIF.
          ENDLOOP.
          lv_page = lv_child.
        WHEN OTHERS.
          fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
                iv_message = 'index tree contains a non-index page' ).
      ENDCASE.
    ENDWHILE.
  ENDMETHOD.

  METHOD build_cell.
    DATA lv_payload TYPE xstring.
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
    DATA lt_overflows TYPE ty_overflows.
    DATA ls_overflow TYPE ty_overflow.
    DATA ls_next TYPE ty_overflow.

    CLEAR et_pages.
    lv_payload = zcl_sqlite_record=>encode( it_values ).
    lv_payload_length = xstrlen( lv_payload ).
    lv_local_size = zcl_sqlite_btree=>local_payload_size(
      iv_payload_size = lv_payload_length
      iv_usable_size  = mv_usable_size
      iv_table_leaf   = abap_false ).
    lv_local_length = lv_local_size.
    lv_payload_varint = zcl_sqlite_bytes=>write_varint( lv_payload_length ).

    IF lv_payload_length <= lv_local_size.
      ev_cell = lv_payload_varint && lv_payload.
      RETURN.
    ENDIF.

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
      ls_overflow-chunk = lv_payload+lv_offset(lv_chunk_length).
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
      lv_page_data = set_u32(
        iv_data   = lv_page_data
        iv_offset = 0
        iv_value  = CONV int8( lv_next_page ) ).
      lv_page_data = splice(
        iv_data   = lv_page_data
        iv_offset = 4
        iv_value  = ls_overflow-chunk ).
      mo_pager->put_page( iv_page = ls_overflow-page
                          iv_data = lv_page_data ).
    ENDLOOP.

    READ TABLE lt_overflows INTO ls_overflow INDEX 1.
    lv_first_page = ls_overflow-page.
    lv_pointer_data = '00000000'.
    lv_pointer = set_u32(
      iv_data   = lv_pointer_data
      iv_offset = 0
      iv_value  = CONV int8( lv_first_page ) ).
    ev_cell = lv_payload_varint
           && lv_payload+0(lv_local_length)
           && lv_pointer.
  ENDMETHOD.

  METHOD build_leaf_page.
    DATA lv_data TYPE xstring.
    DATA lv_cell_offset TYPE i.
    DATA lv_content TYPE i.
    DATA lv_index TYPE i.
    DATA lv_count TYPE i.
    DATA lv_stored_content TYPE int8.
    DATA ls_cell TYPE ty_cell.

    lv_count = lines( it_cells ).
    lv_data = zero_page( ).
    lv_content = mv_usable_size.
    lv_index = 0.
    LOOP AT it_cells INTO ls_cell.
      lv_cell_offset = lv_content - xstrlen( ls_cell-data ).
      IF lv_cell_offset < iv_offset + c_leaf_header_size + lv_count * 2.
        fail( iv_code    = zcx_sqlite_error=>sqlite_full
              iv_message = 'index leaf page does not fit' ).
      ENDIF.
      lv_data = splice(
        iv_data   = lv_data
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

    lv_data = set_u8(
      iv_data   = lv_data
      iv_offset = iv_offset
      iv_value  = zcl_sqlite_page=>c_index_leaf ).
    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = iv_offset + 1
      iv_value  = 0 ).
    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = iv_offset + 3
      iv_value  = CONV int8( lv_count ) ).
    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = iv_offset + 5
      iv_value  = lv_stored_content ).
    lv_data = set_u8(
      iv_data   = lv_data
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
    DATA ls_cell TYPE ty_cell.

    lv_count = lines( it_cells ).
    lv_data = zero_page( ).
    lv_content = mv_usable_size.
    lv_index = 0.
    LOOP AT it_cells INTO ls_cell.
      lv_cell_offset = lv_content - xstrlen( ls_cell-data ).
      IF lv_cell_offset < iv_offset + c_interior_header_size + lv_count * 2.
        fail( iv_code    = zcx_sqlite_error=>sqlite_full
              iv_message = 'index interior page does not fit' ).
      ENDIF.
      lv_data = splice(
        iv_data   = lv_data
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

    lv_data = set_u8(
      iv_data   = lv_data
      iv_offset = iv_offset
      iv_value  = zcl_sqlite_page=>c_index_interior ).
    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = iv_offset + 1
      iv_value  = 0 ).
    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = iv_offset + 3
      iv_value  = CONV int8( lv_count ) ).
    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = iv_offset + 5
      iv_value  = lv_stored_content ).
    lv_data = set_u8(
      iv_data   = lv_data
      iv_offset = iv_offset + 7
      iv_value  = 0 ).
    lv_data = set_u32(
      iv_data   = lv_data
      iv_offset = iv_offset + 8
      iv_value  = CONV int8( iv_rightmost ) ).

    rv_data = lv_data.
  ENDMETHOD.

  METHOD build_root_interior.
    DATA lt_cells TYPE ty_cells.
    DATA ls_cell TYPE ty_cell.

    ls_cell-child = iv_left_page.
    ls_cell-data = interior_cell(
      iv_child        = iv_left_page
      iv_payload_cell = iv_promoted_cell ).
    APPEND ls_cell TO lt_cells.

    rv_data = build_interior_page(
      it_cells     = lt_cells
      iv_rightmost = iv_right_page
      iv_offset    = is_raw-btree_offset ).
    rv_data = preserve_header( iv_data = rv_data
                               is_raw  = is_raw ).
  ENDMETHOD.

  METHOD clear_page.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA lt_cells TYPE ty_cells.
    DATA ls_cell TYPE ty_cell.
    DATA lv_offset TYPE i.
    DATA lv_index TYPE i.

    ls_raw = mo_pager->get_page( iv_page ).
    ls_page = zcl_sqlite_page=>parse(
      iv_data   = ls_raw-data
      iv_offset = ls_raw-btree_offset ).

    CASE ls_page-page_type.
      WHEN zcl_sqlite_page=>c_index_leaf.
        LOOP AT ls_page-cell_offsets INTO lv_offset.
          free_cell_overflow(
            iv_data     = ls_raw-data
            iv_offset   = lv_offset
            iv_interior = abap_false ).
        ENDLOOP.
      WHEN zcl_sqlite_page=>c_index_interior.
        lt_cells = read_interior_cells(
          is_raw  = ls_raw
          is_page = ls_page ).
        LOOP AT lt_cells INTO ls_cell.
          lv_index = sy-tabix.
          READ TABLE ls_page-cell_offsets INTO lv_offset INDEX lv_index.
          clear_page( ls_cell-child ).
          free_cell_overflow(
            iv_data     = ls_raw-data
            iv_offset   = lv_offset
            iv_interior = abap_true ).
        ENDLOOP.
        clear_page( ls_page-rightmost_pointer ).
      WHEN OTHERS.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'index tree contains a non-index page' ).
    ENDCASE.

    IF iv_page <> mv_root_page.
      mo_pager->free_page( iv_page ).
    ENDIF.
  ENDMETHOD.

  METHOD free_cell_overflow.
    DATA lv_varint_offset TYPE i.
    DATA lv_payload_length TYPE int8.
    DATA lv_payload_length_size TYPE i.
    DATA lv_local_size TYPE int8.
    DATA lv_pointer_offset TYPE i.
    DATA lv_first_page TYPE int8.

    IF iv_interior = abap_true.
      lv_varint_offset = iv_offset + 4.
    ELSE.
      lv_varint_offset = iv_offset.
    ENDIF.

    TRY.
        lv_payload_length = zcl_sqlite_bytes=>read_varint(
          iv_data   = iv_data
          iv_offset = lv_varint_offset ).
        lv_payload_length_size = zcl_sqlite_bytes=>varint_length(
          iv_data   = iv_data
          iv_offset = lv_varint_offset ).
      CATCH cx_sy_range_out_of_bounds.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'index cell header is truncated' ).
    ENDTRY.

    lv_local_size = zcl_sqlite_btree=>local_payload_size(
      iv_payload_size = lv_payload_length
      iv_usable_size  = mv_usable_size
      iv_table_leaf   = abap_false ).
    IF lv_payload_length <= lv_local_size.
      RETURN.
    ENDIF.

    lv_pointer_offset = lv_varint_offset + lv_payload_length_size + lv_local_size.
    lv_first_page = read_u32(
      iv_data   = iv_data
      iv_offset = lv_pointer_offset ).
    free_overflow_chain( CONV i( lv_first_page ) ).
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

  METHOD compare_records.
    DATA lv_index TYPE i.
    DATA lo_left TYPE REF TO zcl_sqlite_value.
    DATA lo_right TYPE REF TO zcl_sqlite_value.

    LOOP AT it_left INTO lo_left.
      lv_index = sy-tabix.
      READ TABLE it_right INTO lo_right INDEX lv_index.
      IF sy-subrc <> 0.
        rv_compare = 1.
        RETURN.
      ENDIF.
      rv_compare = compare_value(
        io_left  = lo_left
        io_right = lo_right ).
      IF rv_compare <> 0.
        RETURN.
      ENDIF.
    ENDLOOP.

    IF lines( it_right ) > lines( it_left ).
      rv_compare = -1.
    ELSE.
      rv_compare = 0.
    ENDIF.
  ENDMETHOD.

  METHOD compare_prefix.
    DATA lv_prefix_count TYPE i.
    DATA lv_record_count TYPE i.
    DATA lv_index TYPE i.
    DATA lo_record TYPE REF TO zcl_sqlite_value.
    DATA lo_prefix TYPE REF TO zcl_sqlite_value.

    lv_prefix_count = lines( it_prefix ).
    lv_record_count = lines( it_record ).
    IF lv_prefix_count = 0.
      rv_compare = 0.
      RETURN.
    ENDIF.
    IF lv_record_count < lv_prefix_count.
      rv_compare = -1.
      RETURN.
    ENDIF.

    DO lv_prefix_count TIMES.
      lv_index = sy-index.
      READ TABLE it_record INTO lo_record INDEX lv_index.
      READ TABLE it_prefix INTO lo_prefix INDEX lv_index.
      IF sy-subrc <> 0.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'index comparison value is missing' ).
      ENDIF.
      rv_compare = compare_value(
        io_left  = lo_record
        io_right = lo_prefix ).
      IF rv_compare <> 0.
        RETURN.
      ENDIF.
    ENDDO.

    rv_compare = 0.
  ENDMETHOD.

  METHOD compare_value.
    DATA lv_left_rank TYPE i.
    DATA lv_right_rank TYPE i.
    DATA lv_left_integer TYPE int8.
    DATA lv_right_integer TYPE int8.
    DATA lv_left_real TYPE f.
    DATA lv_right_real TYPE f.
    DATA lv_left_bytes TYPE xstring.
    DATA lv_right_bytes TYPE xstring.

    lv_left_rank = value_rank( io_left ).
    lv_right_rank = value_rank( io_right ).
    IF lv_left_rank < lv_right_rank.
      rv_compare = -1.
      RETURN.
    ELSEIF lv_left_rank > lv_right_rank.
      rv_compare = 1.
      RETURN.
    ENDIF.

    CASE lv_left_rank.
      WHEN 0.
        rv_compare = 0.
      WHEN 1.
        IF io_left->value_type( ) = zcl_sqlite_value=>c_integer
            AND io_right->value_type( ) = zcl_sqlite_value=>c_integer.
          lv_left_integer = io_left->as_integer( ).
          lv_right_integer = io_right->as_integer( ).
          IF lv_left_integer < lv_right_integer.
            rv_compare = -1.
          ELSEIF lv_left_integer > lv_right_integer.
            rv_compare = 1.
          ELSE.
            rv_compare = 0.
          ENDIF.
        ELSE.
          IF io_left->value_type( ) = zcl_sqlite_value=>c_integer.
            lv_left_real = io_left->as_integer( ).
          ELSE.
            lv_left_real = io_left->as_real( ).
          ENDIF.
          IF io_right->value_type( ) = zcl_sqlite_value=>c_integer.
            lv_right_real = io_right->as_integer( ).
          ELSE.
            lv_right_real = io_right->as_real( ).
          ENDIF.
          IF lv_left_real < lv_right_real.
            rv_compare = -1.
          ELSEIF lv_left_real > lv_right_real.
            rv_compare = 1.
          ELSE.
            rv_compare = 0.
          ENDIF.
        ENDIF.
      WHEN 2.
        TRY.
            lv_left_bytes = zcl_sqlite_utf8=>encode( io_left->as_text( ) ).
            lv_right_bytes = zcl_sqlite_utf8=>encode( io_right->as_text( ) ).
          CATCH cx_sy_conversion_codepage.
            fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
                  iv_message = 'index text is not valid UTF-8' ).
        ENDTRY.
        rv_compare = compare_bytes(
          iv_left  = lv_left_bytes
          iv_right = lv_right_bytes ).
      WHEN 3.
        rv_compare = compare_bytes(
          iv_left  = io_left->as_blob( )
          iv_right = io_right->as_blob( ) ).
      WHEN OTHERS.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'index value type is unknown' ).
    ENDCASE.
  ENDMETHOD.

  METHOD value_rank.
    CASE io_value->value_type( ).
      WHEN zcl_sqlite_value=>c_null.
        rv_rank = 0.
      WHEN zcl_sqlite_value=>c_integer OR zcl_sqlite_value=>c_real.
        rv_rank = 1.
      WHEN zcl_sqlite_value=>c_text.
        rv_rank = 2.
      WHEN zcl_sqlite_value=>c_blob.
        rv_rank = 3.
      WHEN OTHERS.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'index value type is unknown' ).
    ENDCASE.
  ENDMETHOD.

  METHOD compare_bytes.
    DATA lv_length TYPE i.
    DATA lv_offset TYPE i.
    DATA lv_left_byte TYPE int8.
    DATA lv_right_byte TYPE int8.

    IF xstrlen( iv_left ) < xstrlen( iv_right ).
      lv_length = xstrlen( iv_left ).
    ELSE.
      lv_length = xstrlen( iv_right ).
    ENDIF.

    DO lv_length TIMES.
      lv_offset = sy-index - 1.
      lv_left_byte = zcl_sqlite_bytes=>read_u8(
        iv_data   = iv_left
        iv_offset = lv_offset ).
      lv_right_byte = zcl_sqlite_bytes=>read_u8(
        iv_data   = iv_right
        iv_offset = lv_offset ).
      IF lv_left_byte < lv_right_byte.
        rv_compare = -1.
        RETURN.
      ELSEIF lv_left_byte > lv_right_byte.
        rv_compare = 1.
        RETURN.
      ENDIF.
    ENDDO.

    IF xstrlen( iv_left ) < xstrlen( iv_right ).
      rv_compare = -1.
    ELSEIF xstrlen( iv_left ) > xstrlen( iv_right ).
      rv_compare = 1.
    ELSE.
      rv_compare = 0.
    ENDIF.
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
    rv_data = splice(
      iv_data   = iv_data
      iv_offset = 0
      iv_value  = lv_prefix ).
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

  METHOD set_u8.
    TRY.
        rv_data = zcl_sqlite_bytes=>write_u8(
          iv_data   = iv_data
          iv_offset = iv_offset
          iv_value  = iv_value ).
      CATCH cx_sy_range_out_of_bounds cx_sy_conversion_overflow.
        fail( iv_code    = zcx_sqlite_error=>sqlite_internal
              iv_message = 'index page byte could not be written' ).
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
              iv_message = 'index page offset could not be written' ).
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
              iv_message = 'index page number could not be written' ).
    ENDTRY.
  ENDMETHOD.

  METHOD read_u32.
    TRY.
        rv_value = zcl_sqlite_bytes=>read_u32(
          iv_data   = iv_data
          iv_offset = iv_offset ).
      CATCH cx_sy_range_out_of_bounds.
        fail( iv_code    = zcx_sqlite_error=>sqlite_corrupt
              iv_message = 'index child pointer is truncated' ).
    ENDTRY.
  ENDMETHOD.

  METHOD interior_cell.
    DATA lv_data TYPE xstring.

    lv_data = '00000000'.
    lv_data = set_u32(
      iv_data   = lv_data
      iv_offset = 0
      iv_value  = CONV int8( iv_child ) ).
    rv_cell = lv_data && iv_payload_cell.
  ENDMETHOD.

  METHOD fail.
    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = iv_code
        iv_message = iv_message.
  ENDMETHOD.

ENDCLASS.
