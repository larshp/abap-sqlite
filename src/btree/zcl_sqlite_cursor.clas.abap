* Read-only cursor for a SQLite table b-tree, see
* https://www.sqlite.org/fileformat.html#b_tree_pages
*
* seek( ) positions at the first row whose rowid is greater than or equal to
* iv_rowid. The caller can compare rowid( ) with the requested value to find out
* whether the row exists. Overflow payloads are not supported yet.
CLASS zcl_sqlite_cursor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_pager     TYPE REF TO zcl_sqlite_pager
                iv_root_page TYPE i
      RAISING   zcx_sqlite_error.

    METHODS first
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS next
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS seek
      IMPORTING iv_rowid        TYPE int8
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS rowid
      RETURNING VALUE(rv_rowid) TYPE int8.

    METHODS values
      RETURNING VALUE(rt_values) TYPE zcl_sqlite_record=>ty_values.

    METHODS is_valid
      RETURNING VALUE(rv_valid) TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_frame,
             page_number TYPE i,
             data        TYPE xstring,
             page        TYPE zcl_sqlite_page=>ty_page,
             cell_index  TYPE i,
           END OF ty_frame.
    TYPES ty_frames TYPE STANDARD TABLE OF ty_frame WITH DEFAULT KEY.

    DATA mo_pager TYPE REF TO zcl_sqlite_pager.
    DATA mv_root_page TYPE i.
    DATA mt_frames TYPE ty_frames.
    DATA mv_leaf_number TYPE i.
    DATA ms_leaf_data TYPE xstring.
    DATA ms_leaf_page TYPE zcl_sqlite_page=>ty_page.
    DATA mv_cell_index TYPE i.
    DATA mv_valid TYPE abap_bool.
    DATA mv_rowid TYPE int8.
    DATA mt_values TYPE zcl_sqlite_record=>ty_values.

    METHODS clear_position.
    METHODS descend_left
      IMPORTING iv_page TYPE i
      RAISING   zcx_sqlite_error.
    METHODS find_leaf
      IMPORTING iv_page         TYPE i
                iv_rowid        TYPE int8
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.
    METHODS load_current
      RAISING zcx_sqlite_error.
    METHODS leaf_rowid
      IMPORTING iv_index        TYPE i
      RETURNING VALUE(rv_rowid) TYPE int8
      RAISING   zcx_sqlite_error.
    METHODS child_page
      IMPORTING is_frame       TYPE ty_frame
                iv_index       TYPE i
      RETURNING VALUE(rv_page) TYPE i
      RAISING   zcx_sqlite_error.
    METHODS interior_key
      IMPORTING is_frame        TYPE ty_frame
                iv_index        TYPE i
      RETURNING VALUE(rv_rowid) TYPE int8
      RAISING   zcx_sqlite_error.
    METHODS fail
      IMPORTING iv_message TYPE string
      RAISING   zcx_sqlite_error.
ENDCLASS.


CLASS zcl_sqlite_cursor IMPLEMENTATION.

  METHOD constructor.
    IF io_pager IS NOT BOUND OR iv_root_page < 1.
      fail( 'table cursor needs a pager and a root page' ).
    ENDIF.
    mo_pager = io_pager.
    mv_root_page = iv_root_page.
  ENDMETHOD.

  METHOD first.
    clear_position( ).
    descend_left( mv_root_page ).

    IF mv_valid = abap_false.
      clear_position( ).
      RETURN abap_false.
    ENDIF.

    mv_cell_index = 1.
    load_current( ).
    RETURN abap_true.
  ENDMETHOD.

  METHOD next.
    DATA ls_frame TYPE ty_frame.
    DATA lv_index TYPE i.

    IF mv_valid = abap_false.
      RETURN abap_false.
    ENDIF.

    IF mv_cell_index < ms_leaf_page-cell_count.
      mv_cell_index = mv_cell_index + 1.
      load_current( ).
      RETURN abap_true.
    ENDIF.

    WHILE lines( mt_frames ) > 0.
      lv_index = lines( mt_frames ).
      READ TABLE mt_frames INTO ls_frame INDEX lv_index.
      IF ls_frame-cell_index <= ls_frame-page-cell_count.
        ls_frame-cell_index = ls_frame-cell_index + 1.
        MODIFY mt_frames INDEX lv_index FROM ls_frame.
        mv_valid = abap_false.
        descend_left( child_page(
          is_frame = ls_frame
          iv_index = ls_frame-cell_index ) ).
        mv_cell_index = 1.
        load_current( ).
        RETURN abap_true.
      ELSE.
        DELETE mt_frames INDEX lv_index.
      ENDIF.
    ENDWHILE.

    clear_position( ).
    RETURN abap_false.
  ENDMETHOD.

  METHOD seek.
    clear_position( ).
    rv_found = find_leaf( iv_page = mv_root_page iv_rowid = iv_rowid ).
    IF rv_found = abap_false.
      RETURN.
    ENDIF.
    load_current( ).
  ENDMETHOD.

  METHOD rowid.
    rv_rowid = mv_rowid.
  ENDMETHOD.

  METHOD values.
    rt_values = mt_values.
  ENDMETHOD.

  METHOD is_valid.
    rv_valid = mv_valid.
  ENDMETHOD.

  METHOD clear_position.
    CLEAR mt_frames.
    CLEAR mv_leaf_number.
    CLEAR ms_leaf_data.
    CLEAR ms_leaf_page.
    CLEAR mv_cell_index.
    CLEAR mv_valid.
    CLEAR mv_rowid.
    CLEAR mt_values.
  ENDMETHOD.

  METHOD descend_left.
    DATA lv_page TYPE i.
    DATA lv_iterations TYPE i.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA ls_frame TYPE ty_frame.

    lv_page = iv_page.
    WHILE lv_page > 0.
      lv_iterations = lv_iterations + 1.
      IF lv_iterations > mo_pager->page_count( ).
        fail( 'b-tree is deeper than the file' ).
      ENDIF.

      ls_raw = mo_pager->get_page( lv_page ).
      ls_page = zcl_sqlite_page=>parse(
        iv_data = ls_raw-data iv_offset = ls_raw-btree_offset ).

      CASE ls_page-page_type.
        WHEN zcl_sqlite_page=>c_table_leaf.
          mv_leaf_number = lv_page.
          ms_leaf_data = ls_raw-data.
          ms_leaf_page = ls_page.
          mv_cell_index = 0.
          mv_valid = abap_false.
          IF ls_page-cell_count > 0.
            mv_valid = abap_true.
          ELSEIF lines( mt_frames ) > 0.
            fail( 'non-root table leaf is empty' ).
          ENDIF.
          RETURN.
        WHEN zcl_sqlite_page=>c_table_interior.
          IF ls_page-cell_count = 0.
            fail( 'table interior page has no cells' ).
          ENDIF.
          ls_frame-page_number = lv_page.
          ls_frame-data = ls_raw-data.
          ls_frame-page = ls_page.
          ls_frame-cell_index = 1.
          APPEND ls_frame TO mt_frames.
          lv_page = child_page( is_frame = ls_frame iv_index = 1 ).
        WHEN OTHERS.
          fail( 'cursor found a non-table b-tree page' ).
      ENDCASE.
    ENDWHILE.

    fail( 'b-tree child page number is invalid' ).
  ENDMETHOD.

  METHOD find_leaf.
    DATA lv_page TYPE i.
    DATA lv_iterations TYPE i.
    DATA lv_child TYPE i.
    DATA lv_leaf_index TYPE i.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA ls_frame TYPE ty_frame.
    DATA lv_key TYPE int8.

    lv_page = iv_page.
    WHILE lv_page > 0.
      lv_iterations = lv_iterations + 1.
      IF lv_iterations > mo_pager->page_count( ).
        fail( 'b-tree is deeper than the file' ).
      ENDIF.

      ls_raw = mo_pager->get_page( lv_page ).
      ls_page = zcl_sqlite_page=>parse(
        iv_data = ls_raw-data iv_offset = ls_raw-btree_offset ).

      CASE ls_page-page_type.
        WHEN zcl_sqlite_page=>c_table_leaf.
          IF ls_page-cell_count = 0.
            IF lines( mt_frames ) = 0.
              clear_position( ).
              RETURN abap_false.
            ENDIF.
            fail( 'non-root table leaf is empty' ).
          ENDIF.

          mv_leaf_number = lv_page.
          ms_leaf_data = ls_raw-data.
          ms_leaf_page = ls_page.
          lv_leaf_index = 0.
          DO ls_page-cell_count TIMES.
            lv_key = leaf_rowid( sy-index ).
            IF lv_key >= iv_rowid.
              lv_leaf_index = sy-index.
              EXIT.
            ENDIF.
          ENDDO.

          IF lv_leaf_index > 0.
            mv_cell_index = lv_leaf_index.
            mv_valid = abap_true.
            RETURN abap_true.
          ENDIF.

          mv_cell_index = ls_page-cell_count.
          mv_valid = abap_true.
          rv_found = next( ).
          RETURN.
        WHEN zcl_sqlite_page=>c_table_interior.
          IF ls_page-cell_count = 0.
            fail( 'table interior page has no cells' ).
          ENDIF.

          ls_frame-page_number = lv_page.
          ls_frame-data = ls_raw-data.
          ls_frame-page = ls_page.
          ls_frame-cell_index = 0.
          DO ls_page-cell_count TIMES.
            lv_key = interior_key( is_frame = ls_frame iv_index = sy-index ).
            IF iv_rowid <= lv_key.
              ls_frame-cell_index = sy-index.
              EXIT.
            ENDIF.
          ENDDO.
          IF ls_frame-cell_index = 0.
            ls_frame-cell_index = ls_page-cell_count + 1.
          ENDIF.

          lv_child = child_page(
            is_frame = ls_frame iv_index = ls_frame-cell_index ).
          APPEND ls_frame TO mt_frames.
          lv_page = lv_child.
        WHEN OTHERS.
          fail( 'cursor found a non-table b-tree page' ).
      ENDCASE.
    ENDWHILE.

    fail( 'b-tree child page number is invalid' ).
  ENDMETHOD.

  METHOD load_current.
    DATA lv_cell_offset TYPE i.
    DATA lv_payload_length_i8 TYPE int8.
    DATA lv_payload_length TYPE i.
    DATA lv_rowid_offset TYPE i.
    DATA lv_payload_offset TYPE i.
    DATA lv_payload TYPE xstring.

    READ TABLE ms_leaf_page-cell_offsets INTO lv_cell_offset
      INDEX mv_cell_index.
    IF sy-subrc <> 0.
      fail( 'table cursor cell is outside the page' ).
    ENDIF.

    TRY.
        lv_payload_length_i8 = zcl_sqlite_bytes=>read_varint(
          iv_data = ms_leaf_data iv_offset = lv_cell_offset ).
        lv_rowid_offset = lv_cell_offset + zcl_sqlite_bytes=>varint_length(
          iv_data = ms_leaf_data iv_offset = lv_cell_offset ).
        mv_rowid = zcl_sqlite_bytes=>read_varint(
          iv_data = ms_leaf_data iv_offset = lv_rowid_offset ).
        lv_payload_offset = lv_rowid_offset + zcl_sqlite_bytes=>varint_length(
          iv_data = ms_leaf_data iv_offset = lv_rowid_offset ).
      CATCH cx_sy_range_out_of_bounds.
        fail( 'table cell header is truncated' ).
    ENDTRY.

    IF lv_payload_length_i8 < 0
        OR lv_payload_length_i8 > xstrlen( ms_leaf_data ) - lv_payload_offset.
      fail( 'table cell payload is truncated or uses overflow' ).
    ENDIF.
    lv_payload_length = lv_payload_length_i8.
    lv_payload = ms_leaf_data+lv_payload_offset(lv_payload_length).
    mt_values = zcl_sqlite_record=>decode( lv_payload ).
    mv_valid = abap_true.
  ENDMETHOD.

  METHOD leaf_rowid.
    DATA lv_cell_offset TYPE i.
    DATA lv_rowid_offset TYPE i.

    READ TABLE ms_leaf_page-cell_offsets INTO lv_cell_offset INDEX iv_index.
    IF sy-subrc <> 0.
      fail( 'table leaf cell is outside the page' ).
    ENDIF.

    TRY.
        lv_rowid_offset = lv_cell_offset + zcl_sqlite_bytes=>varint_length(
          iv_data = ms_leaf_data iv_offset = lv_cell_offset ).
        rv_rowid = zcl_sqlite_bytes=>read_varint(
          iv_data = ms_leaf_data iv_offset = lv_rowid_offset ).
      CATCH cx_sy_range_out_of_bounds.
        fail( 'table leaf cell header is truncated' ).
    ENDTRY.
  ENDMETHOD.

  METHOD child_page.
    DATA lv_offset TYPE i.

    IF iv_index < 1.
      fail( 'b-tree child index is invalid' ).
    ENDIF.

    IF iv_index > is_frame-page-cell_count.
      rv_page = is_frame-page-rightmost_pointer.
    ELSE.
      READ TABLE is_frame-page-cell_offsets INTO lv_offset INDEX iv_index.
      IF sy-subrc <> 0.
        fail( 'b-tree child cell is outside the page' ).
      ENDIF.
      TRY.
          rv_page = zcl_sqlite_bytes=>read_u32(
            iv_data = is_frame-data iv_offset = lv_offset ).
        CATCH cx_sy_range_out_of_bounds.
          fail( 'b-tree child pointer is truncated' ).
      ENDTRY.
    ENDIF.

    IF rv_page < 1.
      fail( 'b-tree child page number is invalid' ).
    ENDIF.
  ENDMETHOD.

  METHOD interior_key.
    DATA lv_offset TYPE i.

    READ TABLE is_frame-page-cell_offsets INTO lv_offset INDEX iv_index.
    IF sy-subrc <> 0.
      fail( 'table interior cell is outside the page' ).
    ENDIF.

    TRY.
        rv_rowid = zcl_sqlite_bytes=>read_varint(
          iv_data = is_frame-data iv_offset = lv_offset + 4 ).
      CATCH cx_sy_range_out_of_bounds.
        fail( 'table interior cell key is truncated' ).
    ENDTRY.
  ENDMETHOD.

  METHOD fail.
    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = zcx_sqlite_error=>sqlite_corrupt
        iv_message = iv_message.
  ENDMETHOD.

ENDCLASS.
