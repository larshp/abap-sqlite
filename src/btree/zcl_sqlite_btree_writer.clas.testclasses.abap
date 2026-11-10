CLASS ltcl_btree_writer DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_small_source TYPE string VALUE 'fixtures/small.db'.
    CONSTANTS c_overflow_source TYPE string VALUE 'fixtures/overflow.db'.
    CONSTANTS c_page_512_source TYPE string VALUE 'fixtures/page_512.db'.
    CONSTANTS c_three_pages_source TYPE string VALUE 'fixtures/three_pages.db'.

    TYPES: BEGIN OF ty_database,
             file  TYPE REF TO zif_sqlite_file,
             pager TYPE REF TO zcl_sqlite_pager,
           END OF ty_database.
    TYPES ty_rowids TYPE STANDARD TABLE OF int8 WITH DEFAULT KEY.

    METHODS insert_leaf FOR TESTING RAISING zcx_sqlite_error.
    METHODS duplicate_rowid FOR TESTING RAISING zcx_sqlite_error.
    METHODS overflow_insert FOR TESTING RAISING zcx_sqlite_error.
    METHODS overflow_split FOR TESTING RAISING zcx_sqlite_error.
    METHODS freeblock_insert FOR TESTING RAISING zcx_sqlite_error.
    METHODS interior_insert FOR TESTING RAISING zcx_sqlite_error.
    METHODS root_split FOR TESTING RAISING zcx_sqlite_error.
    METHODS interior_split FOR TESTING RAISING zcx_sqlite_error.

    METHODS copy_and_open
      IMPORTING iv_source          TYPE string
                iv_target          TYPE string
      RETURNING VALUE(rs_database) TYPE ty_database
      RAISING   zcx_sqlite_error.

    METHODS copy_fixture
      IMPORTING iv_source TYPE string
                iv_target TYPE string
      RAISING   zcx_sqlite_error.

    METHODS open_database
      IMPORTING iv_name            TYPE string
      RETURNING VALUE(rs_database) TYPE ty_database
      RAISING   zcx_sqlite_error.

    METHODS close_database
      IMPORTING is_database TYPE ty_database.

    METHODS record
      IMPORTING iv_id             TYPE int8
                iv_name           TYPE string
                iv_price          TYPE f
      RETURNING VALUE(rv_payload) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS record_two_columns
      IMPORTING iv_id             TYPE int8
                iv_name           TYPE string
      RETURNING VALUE(rv_payload) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS assert_row
      IMPORTING io_cursor TYPE REF TO zcl_sqlite_cursor
                iv_id     TYPE int8
                iv_name   TYPE string
                iv_price  TYPE f.

    METHODS make_freeblock
      IMPORTING io_pager         TYPE REF TO zcl_sqlite_pager
                iv_page          TYPE i
                iv_size          TYPE i
      RETURNING VALUE(rv_offset) TYPE i
      RAISING   zcx_sqlite_error.

    METHODS tree_depth
      IMPORTING io_pager        TYPE REF TO zcl_sqlite_pager
                iv_page         TYPE i
                iv_budget       TYPE i
      RETURNING VALUE(rv_depth) TYPE i
      RAISING   zcx_sqlite_error.

    METHODS set_u16
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE int8
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   zcx_sqlite_error.
ENDCLASS.


CLASS ltcl_btree_writer IMPLEMENTATION.

  METHOD insert_leaf.
    DATA ls_database TYPE ty_database.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA lv_found TYPE abap_bool.
    DATA lt_rowids TYPE ty_rowids.
    DATA lt_expected TYPE ty_rowids.
    DATA lv_expected TYPE int8.
    DATA lv_rowid TYPE int8.

    ls_database = copy_and_open(
      iv_source = c_small_source
      iv_target = 'writer/small-insert.db' ).
    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = ls_database-pager
      iv_root_page = 2 ).

    lo_writer->insert_row(
      iv_rowid   = 4
      iv_payload = record( iv_id = 4 iv_name = 'delta' iv_price = '4.5' ) ).
    lo_writer->insert_row(
      iv_rowid   = 10
      iv_payload = record( iv_id = 10 iv_name = 'ten' iv_price = '-1.25' ) ).
    lo_writer->insert_row(
      iv_rowid   = 0
      iv_payload = record( iv_id = 0 iv_name = 'zero' iv_price = '0' ) ).

    ls_database-pager->commit( ).
    close_database( ls_database ).

    ls_database = open_database( 'writer/small-insert.db' ).
    lo_cursor = NEW zcl_sqlite_cursor(
      io_pager     = ls_database-pager
      iv_root_page = 2 ).

    lv_found = lo_cursor->first( ).
    WHILE lv_found = abap_true.
      APPEND lo_cursor->rowid( ) TO lt_rowids.
      lv_found = lo_cursor->next( ).
    ENDWHILE.

    APPEND 0 TO lt_expected.
    APPEND 1 TO lt_expected.
    APPEND 2 TO lt_expected.
    APPEND 3 TO lt_expected.
    APPEND 4 TO lt_expected.
    APPEND 10 TO lt_expected.

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_rowids )
      exp = lines( lt_expected ) ).
    LOOP AT lt_expected INTO lv_expected.
      READ TABLE lt_rowids INTO lv_rowid INDEX sy-tabix.
      cl_abap_unit_assert=>assert_equals(
        act = lv_rowid
        exp = lv_expected ).
    ENDLOOP.

    lv_found = lo_cursor->seek( 4 ).
    cl_abap_unit_assert=>assert_equals( act = lv_found
                                        exp = abap_true ).
    assert_row( io_cursor = lo_cursor
                iv_id     = 4
                iv_name   = 'delta'
                iv_price  = '4.5' ).

    lv_found = lo_cursor->seek( 10 ).
    cl_abap_unit_assert=>assert_equals( act = lv_found
                                        exp = abap_true ).
    assert_row( io_cursor = lo_cursor
                iv_id     = 10
                iv_name   = 'ten'
                iv_price  = '-1.25' ).

    lv_found = lo_cursor->seek( 0 ).
    cl_abap_unit_assert=>assert_equals( act = lv_found
                                        exp = abap_true ).
    assert_row( io_cursor = lo_cursor
                iv_id     = 0
                iv_name   = 'zero'
                iv_price  = '0' ).

    close_database( ls_database ).
  ENDMETHOD.

  METHOD duplicate_rowid.
    DATA ls_database TYPE ty_database.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.

    ls_database = copy_and_open(
      iv_source = c_small_source
      iv_target = 'writer/small-duplicate.db' ).
    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = ls_database-pager
      iv_root_page = 2 ).

    TRY.
        lo_writer->insert_row(
          iv_rowid   = 2
          iv_payload = record( iv_id = 2 iv_name = 'duplicate' iv_price = '9.5' ) ).
        cl_abap_unit_assert=>fail( 'duplicate rowid was accepted' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint ).
    ENDTRY.

    close_database( ls_database ).
  ENDMETHOD.

  METHOD overflow_insert.
    DATA ls_database TYPE ty_database.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA lv_text TYPE string.
    DATA lv_expected TYPE string.
    DATA lv_found TYPE abap_bool.

    ls_database = copy_and_open(
      iv_source = c_overflow_source
      iv_target = 'writer/overflow-insert.db' ).
    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = ls_database-pager
      iv_root_page = 2 ).

    lv_expected = repeat( val = 'Z'
                          occ = 10000 ).
    lo_writer->insert_row(
      iv_rowid   = 100
      iv_payload = record_two_columns( iv_id   = 100
                                       iv_name = lv_expected ) ).
    ls_database-pager->commit( ).
    close_database( ls_database ).

    ls_database = open_database( 'writer/overflow-insert.db' ).
    lo_cursor = NEW zcl_sqlite_cursor(
      io_pager     = ls_database-pager
      iv_root_page = 2 ).
    lv_found = lo_cursor->seek( 100 ).
    cl_abap_unit_assert=>assert_equals( act = lv_found
                                        exp = abap_true ).

    lt_values = lo_cursor->values( ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_values )
      exp = 2 ).
    READ TABLE lt_values INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 100 ).
    READ TABLE lt_values INTO lo_value INDEX 2.
    lv_text = lo_value->as_text( ).
    cl_abap_unit_assert=>assert_equals(
      act = strlen( lv_text )
      exp = 10000 ).
    cl_abap_unit_assert=>assert_equals(
      act = substring( val = lv_text
                       off = 9999
                       len = 1 )
      exp = 'Z' ).

    close_database( ls_database ).
  ENDMETHOD.

  METHOD overflow_split.
    DATA ls_database TYPE ty_database.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA lv_rowid TYPE int8.
    DATA lv_text TYPE string.
    DATA lv_value TYPE string.
    DATA lv_depth TYPE i.
    DATA lv_count TYPE i.
    DATA lv_found TYPE abap_bool.

    ls_database = copy_and_open(
      iv_source = c_small_source
      iv_target = 'writer/small-overflow-split.db' ).
    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = ls_database-pager
      iv_root_page = 2 ).
    lv_text = repeat( val = 'Q'
                      occ = 5000 ).

    DO 20 TIMES.
      lv_rowid = 2000 + sy-index.
      lo_writer->insert_row(
        iv_rowid   = lv_rowid
        iv_payload = record( iv_id    = lv_rowid
                             iv_name  = lv_text
                             iv_price = '1.5' ) ).
    ENDDO.

    ls_database-pager->commit( ).
    close_database( ls_database ).

    ls_database = open_database( 'writer/small-overflow-split.db' ).
    lv_depth = tree_depth(
      io_pager  = ls_database-pager
      iv_page   = 2
      iv_budget = ls_database-pager->page_count( ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_depth
      exp = 2
      msg = 'overflow inserts should split the root leaf' ).

    lo_cursor = NEW zcl_sqlite_cursor(
      io_pager     = ls_database-pager
      iv_root_page = 2 ).
    lv_found = lo_cursor->first( ).
    WHILE lv_found = abap_true.
      lv_count = lv_count + 1.
      lv_found = lo_cursor->next( ).
    ENDWHILE.
    cl_abap_unit_assert=>assert_equals( act = lv_count
                                        exp = 23 ).

    lv_found = lo_cursor->seek( 2020 ).
    cl_abap_unit_assert=>assert_equals( act = lv_found
                                        exp = abap_true ).
    lt_values = lo_cursor->values( ).
    READ TABLE lt_values INTO lo_value INDEX 2.
    lv_value = lo_value->as_text( ).
    cl_abap_unit_assert=>assert_equals( act = strlen( lv_value )
                                        exp = 5000 ).
    cl_abap_unit_assert=>assert_equals(
      act = substring( val = lv_value off = 4999 len = 1 )
      exp = 'Q' ).

    close_database( ls_database ).
  ENDMETHOD.

  METHOD freeblock_insert.
    DATA ls_database TYPE ty_database.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA ls_freeblock TYPE zcl_sqlite_page=>ty_freeblock.
    DATA lv_block TYPE i.
    DATA lv_cell_offset TYPE i.
    DATA lv_found_cell TYPE abap_bool.
    DATA lv_found TYPE abap_bool.
    DATA lv_after_cell TYPE abap_bool.

    ls_database = copy_and_open(
      iv_source = c_small_source
      iv_target = 'writer/small-freeblock.db' ).
    lv_block = make_freeblock(
      io_pager = ls_database-pager
      iv_page  = 2
      iv_size  = 100 ).

    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = ls_database-pager
      iv_root_page = 2 ).
    lo_writer->insert_row(
      iv_rowid   = 4
      iv_payload = record( iv_id = 4 iv_name = 'delta' iv_price = '4.5' ) ).

    ls_raw = ls_database-pager->get_page( 2 ).
    ls_page = zcl_sqlite_page=>parse(
      iv_data   = ls_raw-data
      iv_offset = ls_raw-btree_offset ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_page-cell_count
      exp = 4 ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_page-cell_content_offset
      exp = lv_block ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_page-fragmented_free_bytes
      exp = 0 ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_page-freeblocks )
      exp = 1 ).

    LOOP AT ls_page-cell_offsets INTO lv_cell_offset.
      IF lv_cell_offset = lv_block.
        lv_found_cell = abap_true.
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals(
      act = lv_found_cell
      exp = abap_true
      msg = 'insert takes the beginning of the freeblock' ).

    READ TABLE ls_page-freeblocks INTO ls_freeblock INDEX 1.
    lv_after_cell = boolc( ls_freeblock-offset > lv_block ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_after_cell
      exp = abap_true
      msg = 'freeblock remainder starts after the new cell' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_freeblock-size + ( ls_freeblock-offset - lv_block )
      exp = 100
      msg = 'freeblock remainder keeps the original size' ).

    ls_database-pager->commit( ).
    close_database( ls_database ).

    ls_database = open_database( 'writer/small-freeblock.db' ).
    lo_cursor = NEW zcl_sqlite_cursor(
      io_pager     = ls_database-pager
      iv_root_page = 2 ).
    lv_found = lo_cursor->seek( 4 ).
    cl_abap_unit_assert=>assert_equals( act = lv_found
                                        exp = abap_true ).
    assert_row( io_cursor = lo_cursor
                iv_id     = 4
                iv_name   = 'delta'
                iv_price  = '4.5' ).
    close_database( ls_database ).
  ENDMETHOD.

  METHOD interior_insert.
    DATA ls_database TYPE ty_database.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA lv_found TYPE abap_bool.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    ls_database = copy_and_open(
      iv_source = c_three_pages_source
      iv_target = 'writer/three-pages-insert.db' ).
    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = ls_database-pager
      iv_root_page = 2 ).
    lo_writer->insert_row(
      iv_rowid   = 201
      iv_payload = record_two_columns( iv_id = 201 iv_name = 'value-201' ) ).
    ls_database-pager->commit( ).
    close_database( ls_database ).

    ls_database = open_database( 'writer/three-pages-insert.db' ).
    lo_cursor = NEW zcl_sqlite_cursor(
      io_pager     = ls_database-pager
      iv_root_page = 2 ).
    lv_found = lo_cursor->seek( 201 ).
    cl_abap_unit_assert=>assert_equals( act = lv_found
                                        exp = abap_true ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->rowid( )
      exp = 201 ).

    lt_values = lo_cursor->values( ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_values )
      exp = 2 ).
    READ TABLE lt_values INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 201 ).
    READ TABLE lt_values INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'value-201' ).

    close_database( ls_database ).
  ENDMETHOD.

  METHOD root_split.
    DATA ls_database TYPE ty_database.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA lv_rowid TYPE int8.
    DATA lv_name TYPE string.
    DATA lv_suffix TYPE string.
    DATA lv_count TYPE i.
    DATA lv_depth TYPE i.
    DATA lv_found TYPE abap_bool.

    ls_database = copy_and_open(
      iv_source = c_small_source
      iv_target = 'writer/small-split.db' ).
    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = ls_database-pager
      iv_root_page = 2 ).
    lv_suffix = repeat( val = 'x'
                        occ = 100 ).

    DO 300 TIMES.
      lv_rowid = 1000 + sy-index.
      lv_name = |split-{ lv_rowid }-{ lv_suffix }|.
      lo_writer->insert_row(
        iv_rowid   = lv_rowid
        iv_payload = record( iv_id = lv_rowid iv_name = lv_name iv_price = '1.5' ) ).
    ENDDO.

    ls_database-pager->commit( ).
    close_database( ls_database ).

    ls_database = open_database( 'writer/small-split.db' ).
    ls_raw = ls_database-pager->get_page( 2 ).
    ls_page = zcl_sqlite_page=>parse(
      iv_data   = ls_raw-data
      iv_offset = ls_raw-btree_offset ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_page-page_type
      exp = zcl_sqlite_page=>c_table_interior
      msg = 'root page should become a table interior page' ).

    lv_depth = tree_depth(
      io_pager  = ls_database-pager
      iv_page   = 2
      iv_budget = ls_database-pager->page_count( ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_depth
      exp = 2
      msg = 'root split should produce a two-level tree' ).

    lo_cursor = NEW zcl_sqlite_cursor(
      io_pager     = ls_database-pager
      iv_root_page = 2 ).
    lv_found = lo_cursor->first( ).
    WHILE lv_found = abap_true.
      lv_count = lv_count + 1.
      lv_found = lo_cursor->next( ).
    ENDWHILE.
    cl_abap_unit_assert=>assert_equals(
      act = lv_count
      exp = 303 ).

    lv_found = lo_cursor->seek( 1299 ).
    cl_abap_unit_assert=>assert_equals( act = lv_found
                                        exp = abap_true ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->rowid( )
      exp = 1299 ).
    close_database( ls_database ).
  ENDMETHOD.

  METHOD interior_split.
    DATA ls_database TYPE ty_database.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA lv_rowid TYPE int8.
    DATA lv_name TYPE string.
    DATA lv_suffix TYPE string.
    DATA lv_count TYPE i.
    DATA lv_depth TYPE i.
    DATA lv_found TYPE abap_bool.

    ls_database = copy_and_open(
      iv_source = c_page_512_source
      iv_target = 'writer/page-512-split.db' ).
    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = ls_database-pager
      iv_root_page = 2 ).
    lv_suffix = repeat( val = 'x'
                        occ = 20 ).

    DO 2000 TIMES.
      lv_rowid = 5000 + sy-index.
      lv_name = |row-{ lv_rowid }-{ lv_suffix }|.
      lo_writer->insert_row(
        iv_rowid   = lv_rowid
        iv_payload = record_two_columns( iv_id = lv_rowid iv_name = lv_name ) ).
    ENDDO.

    ls_database-pager->commit( ).
    close_database( ls_database ).

    ls_database = open_database( 'writer/page-512-split.db' ).
    lv_depth = tree_depth(
      io_pager  = ls_database-pager
      iv_page   = 2
      iv_budget = ls_database-pager->page_count( ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_depth
      exp = 3
      msg = 'large insert should produce an interior split' ).

    lo_cursor = NEW zcl_sqlite_cursor(
      io_pager     = ls_database-pager
      iv_root_page = 2 ).
    lv_found = lo_cursor->first( ).
    WHILE lv_found = abap_true.
      lv_count = lv_count + 1.
      lv_found = lo_cursor->next( ).
    ENDWHILE.
    cl_abap_unit_assert=>assert_equals(
      act = lv_count
      exp = 2040 ).

    lv_found = lo_cursor->seek( 6999 ).
    cl_abap_unit_assert=>assert_equals( act = lv_found
                                        exp = abap_true ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->rowid( )
      exp = 6999 ).
    close_database( ls_database ).
  ENDMETHOD.

  METHOD tree_depth.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA lv_offset TYPE i.
    DATA lv_child TYPE int8.
    DATA lv_child_depth TYPE i.
    DATA lv_budget TYPE i.
    DATA lv_max TYPE i.

    IF iv_budget <= 0.
      RETURN.
    ENDIF.

    ls_raw = io_pager->get_page( iv_page ).
    ls_page = zcl_sqlite_page=>parse(
      iv_data   = ls_raw-data
      iv_offset = ls_raw-btree_offset ).

    CASE ls_page-page_type.
      WHEN zcl_sqlite_page=>c_table_leaf.
        rv_depth = 1.
      WHEN zcl_sqlite_page=>c_table_interior.
        lv_budget = iv_budget - 1.
        LOOP AT ls_page-cell_offsets INTO lv_offset.
          TRY.
              lv_child = zcl_sqlite_bytes=>read_u32(
                iv_data   = ls_raw-data
                iv_offset = lv_offset ).
            CATCH cx_sy_range_out_of_bounds.
              RAISE EXCEPTION TYPE zcx_sqlite_error
                EXPORTING
                  iv_code    = zcx_sqlite_error=>sqlite_corrupt
                  iv_message = 'test child pointer is truncated'.
          ENDTRY.
          lv_child_depth = tree_depth(
            io_pager  = io_pager
            iv_page   = CONV i( lv_child )
            iv_budget = lv_budget ).
          IF lv_child_depth > lv_max.
            lv_max = lv_child_depth.
          ENDIF.
        ENDLOOP.

        lv_child_depth = tree_depth(
          io_pager  = io_pager
          iv_page   = ls_page-rightmost_pointer
          iv_budget = lv_budget ).
        IF lv_child_depth > lv_max.
          lv_max = lv_child_depth.
        ENDIF.
        rv_depth = lv_max + 1.
      WHEN OTHERS.
        cl_abap_unit_assert=>fail( 'unexpected b-tree page type' ).
    ENDCASE.
  ENDMETHOD.

  METHOD copy_and_open.
    copy_fixture( iv_source = iv_source
                  iv_target = iv_target ).
    rs_database = open_database( iv_target ).
  ENDMETHOD.

  METHOD copy_fixture.
    DATA lo_vfs TYPE REF TO zcl_sqlite_vfs_table.
    DATA lv_data TYPE xstring.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( iv_target ).
    TRY.
        lv_data = lo_vfs->export( iv_source ).
      CATCH cx_sy_file_access_error.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_notadb
            iv_message = |fixture { iv_source } does not exist|.
    ENDTRY.
    lo_vfs->import( iv_name = iv_target
                    iv_data = lv_data ).
  ENDMETHOD.

  METHOD open_database.
    DATA lo_vfs TYPE REF TO zcl_sqlite_vfs_table.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    rs_database-file = lo_vfs->zif_sqlite_vfs~open( iv_name ).
    rs_database-pager = NEW zcl_sqlite_pager( io_file = rs_database-file ).
  ENDMETHOD.

  METHOD close_database.
    is_database-file->close( ).
  ENDMETHOD.

  METHOD record.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.

    APPEND zcl_sqlite_value=>integer( iv_id ) TO lt_values.
    APPEND zcl_sqlite_value=>text( iv_name ) TO lt_values.
    APPEND zcl_sqlite_value=>real( iv_price ) TO lt_values.
    rv_payload = zcl_sqlite_record=>encode( lt_values ).
  ENDMETHOD.

  METHOD record_two_columns.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.

    APPEND zcl_sqlite_value=>integer( iv_id ) TO lt_values.
    APPEND zcl_sqlite_value=>text( iv_name ) TO lt_values.
    rv_payload = zcl_sqlite_record=>encode( lt_values ).
  ENDMETHOD.

  METHOD assert_row.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    cl_abap_unit_assert=>assert_equals(
      act = io_cursor->rowid( )
      exp = iv_id ).

    lt_values = io_cursor->values( ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_values )
      exp = 3 ).

    READ TABLE lt_values INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = iv_id ).
    READ TABLE lt_values INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = iv_name ).
    READ TABLE lt_values INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( )
      exp = iv_price ).
  ENDMETHOD.

  METHOD make_freeblock.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA lv_data TYPE xstring.

    ls_raw = io_pager->get_page( iv_page ).
    ls_page = zcl_sqlite_page=>parse(
      iv_data   = ls_raw-data
      iv_offset = ls_raw-btree_offset ).
    rv_offset = ls_page-cell_content_offset - iv_size.

    lv_data = ls_raw-data.
    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = ls_page-cell_pointer_offset - 7
      iv_value  = CONV int8( rv_offset ) ).
    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = ls_page-cell_pointer_offset - 3
      iv_value  = CONV int8( rv_offset ) ).
    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = rv_offset
      iv_value  = 0 ).
    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = rv_offset + 2
      iv_value  = CONV int8( iv_size ) ).

    io_pager->put_page( iv_page = iv_page
                        iv_data = lv_data ).
  ENDMETHOD.

  METHOD set_u16.
    TRY.
        rv_data = zcl_sqlite_bytes=>write_u16(
          iv_data   = iv_data
          iv_offset = iv_offset
          iv_value  = iv_value ).
      CATCH cx_sy_range_out_of_bounds cx_sy_conversion_overflow.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_internal
            iv_message = 'test page could not be prepared'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
