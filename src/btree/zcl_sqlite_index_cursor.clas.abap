* Read-only cursor for a SQLite index b-tree, see
* https://www.sqlite.org/fileformat.html#b_tree_pages
*
* Index entries are records containing the indexed columns followed by the
* rowid. Interior pages contain real entries too, not just separators, so a
* cursor has to emit them between the child subtrees. seek( ) positions at the
* first entry whose key prefix is greater than or equal to it_prefix. Text
* comparison uses the BINARY collation.
CLASS zcl_sqlite_index_cursor DEFINITION
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
      IMPORTING it_prefix       TYPE zcl_sqlite_record=>ty_values
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

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
             child_index TYPE i,
             key_emitted TYPE abap_bool,
           END OF ty_frame.
    TYPES ty_frames TYPE STANDARD TABLE OF ty_frame WITH DEFAULT KEY.

    DATA mo_pager TYPE REF TO zcl_sqlite_pager.
    DATA mv_root_page TYPE i.
    DATA mv_usable_size TYPE i.
    DATA mt_frames TYPE ty_frames.
    DATA mv_page_number TYPE i.
    DATA mv_page_data TYPE xstring.
    DATA mv_page TYPE zcl_sqlite_page=>ty_page.
    DATA mv_cell_index TYPE i.
    DATA mv_valid TYPE abap_bool.
    DATA mv_values TYPE zcl_sqlite_record=>ty_values.

    METHODS clear_position.
    METHODS descend_left
      IMPORTING iv_page TYPE i
      RAISING   zcx_sqlite_error.
    METHODS set_leaf
      IMPORTING iv_page_number TYPE i
                iv_page_data   TYPE xstring
                iv_page        TYPE zcl_sqlite_page=>ty_page
      RAISING   zcx_sqlite_error.
    METHODS load_current
      RAISING zcx_sqlite_error.
    METHODS cell_values
      IMPORTING is_page          TYPE zcl_sqlite_page=>ty_page
                iv_page_data     TYPE xstring
                iv_index         TYPE i
                iv_interior      TYPE abap_bool
      RETURNING VALUE(rt_values) TYPE zcl_sqlite_record=>ty_values
      RAISING   zcx_sqlite_error.
    METHODS child_page
      IMPORTING is_frame       TYPE ty_frame
                iv_index       TYPE i
      RETURNING VALUE(rv_page) TYPE i
      RAISING   zcx_sqlite_error.
    METHODS advance_from_leaf
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.
    METHODS advance_after_interior
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.
    METHODS compare_prefix
      IMPORTING it_record         TYPE zcl_sqlite_record=>ty_values
                it_prefix         TYPE zcl_sqlite_record=>ty_values
      RETURNING VALUE(rv_compare) TYPE i
      RAISING   zcx_sqlite_error.
    METHODS compare_value
      IMPORTING io_left           TYPE REF TO zcl_sqlite_value
                io_right          TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(rv_compare) TYPE i
      RAISING   zcx_sqlite_error.
    METHODS compare_bytes
      IMPORTING iv_left           TYPE xstring
                iv_right          TYPE xstring
      RETURNING VALUE(rv_compare) TYPE i.
    METHODS value_rank
      IMPORTING io_value       TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(rv_rank) TYPE i
      RAISING   zcx_sqlite_error.
    METHODS fail
      IMPORTING iv_message TYPE string
      RAISING   zcx_sqlite_error.
ENDCLASS.


CLASS zcl_sqlite_index_cursor IMPLEMENTATION.

  METHOD constructor.
    DATA ls_header TYPE zcl_sqlite_header=>ty_header.

    IF io_pager IS NOT BOUND OR iv_root_page < 1.
      fail( 'index cursor needs a pager and a root page' ).
    ENDIF.
    mo_pager = io_pager.
    mv_root_page = iv_root_page.

    ls_header = io_pager->header( ).
    mv_usable_size = ls_header-page_size - ls_header-reserved_bytes.
    IF mv_usable_size < zcl_sqlite_btree=>c_min_usable_size.
      fail( 'index cursor usable page size is too small' ).
    ENDIF.
  ENDMETHOD.

  METHOD first.
    clear_position( ).
    descend_left( mv_root_page ).
    IF mv_valid = abap_false.
      clear_position( ).
      RETURN abap_false.
    ENDIF.
    load_current( ).
    RETURN abap_true.
  ENDMETHOD.

  METHOD next.
    DATA lv_found TYPE abap_bool.

    IF mv_valid = abap_false.
      RETURN abap_false.
    ENDIF.

    CASE mv_page-page_type.
      WHEN zcl_sqlite_page=>c_index_leaf.
        IF mv_cell_index < mv_page-cell_count.
          mv_cell_index = mv_cell_index + 1.
          load_current( ).
          RETURN abap_true.
        ENDIF.
        lv_found = advance_from_leaf( ).
      WHEN zcl_sqlite_page=>c_index_interior.
        lv_found = advance_after_interior( ).
      WHEN OTHERS.
        fail( 'index cursor is not on an index page' ).
    ENDCASE.

    IF lv_found = abap_false.
      clear_position( ).
    ENDIF.
    RETURN lv_found.
  ENDMETHOD.

  METHOD seek.
    DATA lv_page TYPE i.
    DATA lv_iterations TYPE i.
    DATA lv_child TYPE i.
    DATA lv_compare TYPE i.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA ls_frame TYPE ty_frame.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.

    IF lines( it_prefix ) = 0.
      RETURN first( ).
    ENDIF.

    clear_position( ).
    lv_page = mv_root_page.

    WHILE lv_page > 0.
      lv_iterations = lv_iterations + 1.
      IF lv_iterations > mo_pager->page_count( ).
        fail( 'index b-tree is deeper than the file' ).
      ENDIF.

      ls_raw = mo_pager->get_page( lv_page ).
      ls_page = zcl_sqlite_page=>parse(
        iv_data = ls_raw-data iv_offset = ls_raw-btree_offset ).

      CASE ls_page-page_type.
        WHEN zcl_sqlite_page=>c_index_leaf.
          set_leaf(
            iv_page_number = lv_page
            iv_page_data   = ls_raw-data
            iv_page        = ls_page ).
          IF mv_valid = abap_false.
            RETURN abap_false.
          ENDIF.

          DO ls_page-cell_count TIMES.
            lt_values = cell_values(
              is_page      = ls_page
              iv_page_data = ls_raw-data
              iv_index     = sy-index
              iv_interior  = abap_false ).
            lv_compare = compare_prefix(
              it_record = lt_values
              it_prefix = it_prefix ).
            IF lv_compare >= 0.
              mv_cell_index = sy-index.
              load_current( ).
              RETURN abap_true.
            ENDIF.
          ENDDO.

          mv_cell_index = ls_page-cell_count.
          RETURN next( ).
        WHEN zcl_sqlite_page=>c_index_interior.
          IF ls_page-cell_count = 0.
            fail( 'index interior page has no cells' ).
          ENDIF.

          lv_child = 0.
          DO ls_page-cell_count TIMES.
            lt_values = cell_values(
              is_page      = ls_page
              iv_page_data = ls_raw-data
              iv_index     = sy-index
              iv_interior  = abap_true ).
            lv_compare = compare_prefix(
              it_record = lt_values
              it_prefix = it_prefix ).
            IF lv_compare >= 0.
              lv_child = sy-index.
              EXIT.
            ENDIF.
          ENDDO.
          IF lv_child = 0.
            lv_child = ls_page-cell_count + 1.
          ENDIF.

          ls_frame-page_number = lv_page.
          ls_frame-data = ls_raw-data.
          ls_frame-page = ls_page.
          ls_frame-child_index = lv_child.
          ls_frame-key_emitted = abap_false.
          APPEND ls_frame TO mt_frames.
          lv_page = child_page(
            is_frame = ls_frame
            iv_index = lv_child ).
        WHEN OTHERS.
          fail( 'index cursor found a non-index b-tree page' ).
      ENDCASE.
    ENDWHILE.

    fail( 'index b-tree child page number is invalid' ).
  ENDMETHOD.

  METHOD values.
    rt_values = mv_values.
  ENDMETHOD.

  METHOD is_valid.
    rv_valid = mv_valid.
  ENDMETHOD.

  METHOD clear_position.
    CLEAR mt_frames.
    CLEAR mv_page_number.
    CLEAR mv_page_data.
    CLEAR mv_page.
    CLEAR mv_cell_index.
    CLEAR mv_valid.
    CLEAR mv_values.
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
        fail( 'index b-tree is deeper than the file' ).
      ENDIF.

      ls_raw = mo_pager->get_page( lv_page ).
      ls_page = zcl_sqlite_page=>parse(
        iv_data = ls_raw-data iv_offset = ls_raw-btree_offset ).

      CASE ls_page-page_type.
        WHEN zcl_sqlite_page=>c_index_leaf.
          set_leaf(
            iv_page_number = lv_page
            iv_page_data   = ls_raw-data
            iv_page        = ls_page ).
          RETURN.
        WHEN zcl_sqlite_page=>c_index_interior.
          IF ls_page-cell_count = 0.
            fail( 'index interior page has no cells' ).
          ENDIF.
          ls_frame-page_number = lv_page.
          ls_frame-data = ls_raw-data.
          ls_frame-page = ls_page.
          ls_frame-child_index = 1.
          ls_frame-key_emitted = abap_false.
          APPEND ls_frame TO mt_frames.
          lv_page = child_page(
            is_frame = ls_frame
            iv_index = 1 ).
        WHEN OTHERS.
          fail( 'index cursor found a non-index b-tree page' ).
      ENDCASE.
    ENDWHILE.

    fail( 'index b-tree child page number is invalid' ).
  ENDMETHOD.

  METHOD set_leaf.
    mv_page_number = iv_page_number.
    mv_page_data = iv_page_data.
    mv_page = iv_page.
    mv_cell_index = 0.
    mv_valid = abap_false.
    CLEAR mv_values.

    IF iv_page-cell_count > 0.
      mv_cell_index = 1.
      mv_valid = abap_true.
    ELSEIF lines( mt_frames ) > 0.
      fail( 'non-root index leaf is empty' ).
    ENDIF.
  ENDMETHOD.

  METHOD load_current.
    IF mv_cell_index < 1 OR mv_cell_index > mv_page-cell_count.
      fail( 'index cursor cell is outside the page' ).
    ENDIF.

    CASE mv_page-page_type.
      WHEN zcl_sqlite_page=>c_index_interior.
        mv_values = cell_values(
          is_page      = mv_page
          iv_page_data = mv_page_data
          iv_index     = mv_cell_index
          iv_interior  = abap_true ).
      WHEN zcl_sqlite_page=>c_index_leaf.
        mv_values = cell_values(
          is_page      = mv_page
          iv_page_data = mv_page_data
          iv_index     = mv_cell_index
          iv_interior  = abap_false ).
      WHEN OTHERS.
        fail( 'index cursor is not on an index page' ).
    ENDCASE.
    mv_valid = abap_true.
  ENDMETHOD.

  METHOD cell_values.
    DATA lv_cell_offset TYPE i.
    DATA lv_varint_offset TYPE i.
    DATA lv_payload_length TYPE int8.
    DATA lv_payload_offset TYPE i.

    READ TABLE is_page-cell_offsets INTO lv_cell_offset INDEX iv_index.
    IF sy-subrc <> 0.
      fail( 'index cell is outside the page' ).
    ENDIF.

    IF iv_interior = abap_true.
      IF lv_cell_offset + 4 > xstrlen( iv_page_data ).
        fail( 'index interior cell is truncated' ).
      ENDIF.
      lv_varint_offset = lv_cell_offset + 4.
    ELSE.
      lv_varint_offset = lv_cell_offset.
    ENDIF.

    TRY.
        lv_payload_length = zcl_sqlite_bytes=>read_varint(
          iv_data = iv_page_data iv_offset = lv_varint_offset ).
        lv_payload_offset = lv_varint_offset
          + zcl_sqlite_bytes=>varint_length(
            iv_data = iv_page_data iv_offset = lv_varint_offset ).
      CATCH cx_sy_range_out_of_bounds.
        fail( 'index cell header is truncated' ).
    ENDTRY.
    IF lv_payload_length < 0.
      fail( 'index cell payload size is negative' ).
    ENDIF.

    rt_values = zcl_sqlite_record=>decode(
      zcl_sqlite_btree=>read_payload(
        io_pager          = mo_pager
        iv_page_data      = iv_page_data
        iv_payload_offset = lv_payload_offset
        iv_payload_size   = lv_payload_length
        iv_usable_size    = mv_usable_size
        iv_table_leaf     = abap_false ) ).
  ENDMETHOD.

  METHOD child_page.
    DATA lv_offset TYPE i.

    IF iv_index < 1.
      fail( 'index b-tree child index is invalid' ).
    ENDIF.

    IF iv_index > is_frame-page-cell_count.
      rv_page = is_frame-page-rightmost_pointer.
    ELSE.
      READ TABLE is_frame-page-cell_offsets INTO lv_offset INDEX iv_index.
      IF sy-subrc <> 0.
        fail( 'index b-tree child cell is outside the page' ).
      ENDIF.
      TRY.
          rv_page = zcl_sqlite_bytes=>read_u32(
            iv_data = is_frame-data iv_offset = lv_offset ).
        CATCH cx_sy_range_out_of_bounds.
          fail( 'index b-tree child pointer is truncated' ).
      ENDTRY.
    ENDIF.

    IF rv_page < 1.
      fail( 'index b-tree child page number is invalid' ).
    ENDIF.
  ENDMETHOD.

  METHOD advance_from_leaf.
    DATA ls_frame TYPE ty_frame.
    DATA lv_frame_index TYPE i.
    DATA lv_child TYPE i.

    WHILE lines( mt_frames ) > 0.
      lv_frame_index = lines( mt_frames ).
      READ TABLE mt_frames INTO ls_frame INDEX lv_frame_index.
      IF sy-subrc <> 0.
        fail( 'index b-tree frame is missing' ).
      ENDIF.

      IF ls_frame-key_emitted = abap_false
          AND ls_frame-child_index <= ls_frame-page-cell_count.
        ls_frame-key_emitted = abap_true.
        MODIFY mt_frames INDEX lv_frame_index FROM ls_frame.

        mv_page_number = ls_frame-page_number.
        mv_page_data = ls_frame-data.
        mv_page = ls_frame-page.
        mv_cell_index = ls_frame-child_index.
        mv_valid = abap_true.
        load_current( ).
        RETURN abap_true.
      ENDIF.

      lv_child = ls_frame-child_index + 1.
      IF lv_child <= ls_frame-page-cell_count + 1.
        ls_frame-child_index = lv_child.
        ls_frame-key_emitted = abap_false.
        MODIFY mt_frames INDEX lv_frame_index FROM ls_frame.
        descend_left( child_page(
          is_frame = ls_frame
          iv_index = lv_child ) ).
        IF mv_valid = abap_false.
          RETURN abap_false.
        ENDIF.
        load_current( ).
        RETURN abap_true.
      ENDIF.

      DELETE mt_frames INDEX lv_frame_index.
    ENDWHILE.

    RETURN abap_false.
  ENDMETHOD.

  METHOD advance_after_interior.
    DATA ls_frame TYPE ty_frame.
    DATA lv_frame_index TYPE i.
    DATA lv_child TYPE i.

    IF lines( mt_frames ) = 0.
      fail( 'index interior cursor has no frame' ).
    ENDIF.
    lv_frame_index = lines( mt_frames ).
    READ TABLE mt_frames INTO ls_frame INDEX lv_frame_index.
    IF sy-subrc <> 0.
      fail( 'index b-tree frame is missing' ).
    ENDIF.
    IF ls_frame-page_number <> mv_page_number.
      fail( 'index interior cursor is on the wrong page' ).
    ENDIF.

    lv_child = ls_frame-child_index + 1.
    IF lv_child <= ls_frame-page-cell_count + 1.
      ls_frame-child_index = lv_child.
      ls_frame-key_emitted = abap_false.
      MODIFY mt_frames INDEX lv_frame_index FROM ls_frame.
      descend_left( child_page(
        is_frame = ls_frame
        iv_index = lv_child ) ).
      IF mv_valid = abap_false.
        RETURN abap_false.
      ENDIF.
      load_current( ).
      RETURN abap_true.
    ENDIF.

    DELETE mt_frames INDEX lv_frame_index.
    RETURN advance_from_leaf( ).
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
        fail( 'index comparison value is missing' ).
      ENDIF.
      rv_compare = compare_value(
        io_left = lo_record
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
            fail( 'index text is not valid UTF-8' ).
        ENDTRY.
        rv_compare = compare_bytes(
          iv_left = lv_left_bytes
          iv_right = lv_right_bytes ).
      WHEN 3.
        rv_compare = compare_bytes(
          iv_left = io_left->as_blob( )
          iv_right = io_right->as_blob( ) ).
      WHEN OTHERS.
        fail( 'index value type is unknown' ).
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
        iv_data = iv_left iv_offset = lv_offset ).
      lv_right_byte = zcl_sqlite_bytes=>read_u8(
        iv_data = iv_right iv_offset = lv_offset ).
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
        fail( 'index value type is unknown' ).
    ENDCASE.
  ENDMETHOD.

  METHOD fail.
    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = zcx_sqlite_error=>sqlite_corrupt
        iv_message = iv_message.
  ENDMETHOD.

ENDCLASS.
