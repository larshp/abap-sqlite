CLASS ltcl_page DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_empty TYPE string VALUE 'fixtures/empty.db'.
    CONSTANTS c_small TYPE string VALUE 'fixtures/small.db'.
    CONSTANTS c_three_pages TYPE string VALUE 'fixtures/three_pages.db'.
    CONSTANTS c_indexed TYPE string VALUE 'fixtures/indexed.db'.

* the expectations are the b-tree page headers in the .db fixtures
    TYPES: BEGIN OF ty_page_expect,
             number              TYPE i,
             page_type           TYPE int8,
             cell_count          TYPE i,
             cell_content_offset TYPE i,
             rightmost_pointer   TYPE i,
           END OF ty_page_expect.
    TYPES ty_page_expects TYPE STANDARD TABLE OF ty_page_expect WITH DEFAULT KEY.

    METHODS empty_fixture FOR TESTING.
    METHODS small_fixture FOR TESTING.
    METHODS three_pages_fixture FOR TESTING.
    METHODS indexed_fixture FOR TESTING.
    METHODS cell_pointers FOR TESTING.
    METHODS freeblocks FOR TESTING.
    METHODS bad_page_type FOR TESTING.
    METHODS truncated_header FOR TESTING.

    METHODS assert_fixture
      IMPORTING iv_name  TYPE string
                it_pages TYPE ty_page_expects.
    METHODS open_pager
      IMPORTING iv_name         TYPE string
      RETURNING VALUE(ro_pager) TYPE REF TO zcl_sqlite_pager.
    METHODS raw_page
      IMPORTING iv_name        TYPE string
                iv_page        TYPE i
      RETURNING VALUE(rs_page) TYPE zcl_sqlite_pager=>ty_page.
ENDCLASS.


CLASS ltcl_page IMPLEMENTATION.

  METHOD empty_fixture.
    assert_fixture(
      iv_name = c_empty
      it_pages = VALUE #(
        ( number = 1 page_type = zcl_sqlite_page=>c_table_leaf
          cell_count = 0 cell_content_offset = 4096 rightmost_pointer = 0 ) ) ).
  ENDMETHOD.

  METHOD small_fixture.
    assert_fixture(
      iv_name = c_small
      it_pages = VALUE #(
        ( number = 1 page_type = zcl_sqlite_page=>c_table_leaf
          cell_count = 1 cell_content_offset = 3972 rightmost_pointer = 0 )
        ( number = 2 page_type = zcl_sqlite_page=>c_table_leaf
          cell_count = 3 cell_content_offset = 4048 rightmost_pointer = 0 ) ) ).
  ENDMETHOD.

  METHOD three_pages_fixture.
    assert_fixture(
      iv_name = c_three_pages
      it_pages = VALUE #(
        ( number = 1 page_type = zcl_sqlite_page=>c_table_leaf
          cell_count = 1 cell_content_offset = 4007 rightmost_pointer = 0 )
        ( number = 2 page_type = zcl_sqlite_page=>c_table_interior
          cell_count = 2 cell_content_offset = 4085 rightmost_pointer = 5 )
        ( number = 3 page_type = zcl_sqlite_page=>c_table_leaf
          cell_count = 71 cell_content_offset = 191 rightmost_pointer = 0 )
        ( number = 4 page_type = zcl_sqlite_page=>c_table_leaf
          cell_count = 71 cell_content_offset = 176 rightmost_pointer = 0 )
        ( number = 5 page_type = zcl_sqlite_page=>c_table_leaf
          cell_count = 58 cell_content_offset = 848 rightmost_pointer = 0 ) ) ).
  ENDMETHOD.

  METHOD indexed_fixture.
    assert_fixture(
      iv_name = c_indexed
      it_pages = VALUE #(
        ( number = 1 page_type = zcl_sqlite_page=>c_table_leaf
          cell_count = 2 cell_content_offset = 3937 rightmost_pointer = 0 )
        ( number = 2 page_type = zcl_sqlite_page=>c_table_interior
          cell_count = 1 cell_content_offset = 4091 rightmost_pointer = 7 )
        ( number = 3 page_type = zcl_sqlite_page=>c_index_interior
          cell_count = 1 cell_content_offset = 4037 rightmost_pointer = 5 )
        ( number = 4 page_type = zcl_sqlite_page=>c_index_leaf
          cell_count = 36 cell_content_offset = 2117 rightmost_pointer = 0 )
        ( number = 5 page_type = zcl_sqlite_page=>c_index_leaf
          cell_count = 63 cell_content_offset = 631 rightmost_pointer = 0 )
        ( number = 6 page_type = zcl_sqlite_page=>c_table_leaf
          cell_count = 71 cell_content_offset = 191 rightmost_pointer = 0 )
        ( number = 7 page_type = zcl_sqlite_page=>c_table_leaf
          cell_count = 29 cell_content_offset = 2501 rightmost_pointer = 0 ) ) ).
  ENDMETHOD.

  METHOD cell_pointers.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA lv_offset TYPE i.

    ls_raw = raw_page( iv_name = c_small iv_page = 2 ).
    TRY.
        ls_page = zcl_sqlite_page=>parse(
          iv_data = ls_raw-data iv_offset = ls_raw-btree_offset ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |small page 2 parse failed: { lo_error->message }| ).
    ENDTRY.

    cl_abap_unit_assert=>assert_equals( act = ls_page-cell_count exp = 3 ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_page-cell_content_offset exp = 4048 ).

    READ TABLE ls_page-cell_offsets INTO lv_offset INDEX 1.
    cl_abap_unit_assert=>assert_equals( act = lv_offset exp = 4077 ).
    READ TABLE ls_page-cell_offsets INTO lv_offset INDEX 2.
    cl_abap_unit_assert=>assert_equals( act = lv_offset exp = 4059 ).
    READ TABLE ls_page-cell_offsets INTO lv_offset INDEX 3.
    cl_abap_unit_assert=>assert_equals( act = lv_offset exp = 4048 ).
  ENDMETHOD.

  METHOD freeblocks.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA lv_data TYPE xstring.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA ls_freeblock TYPE zcl_sqlite_page=>ty_freeblock.

    ls_raw = raw_page( iv_name = c_empty iv_page = 1 ).
    lv_data = ls_raw-data.

    TRY.
        lv_data = zcl_sqlite_bytes=>write_u16(
          iv_data = lv_data iv_offset = 101 iv_value = 3900 ).
        lv_data = zcl_sqlite_bytes=>write_u16(
          iv_data = lv_data iv_offset = 105 iv_value = 3900 ).
        lv_data = zcl_sqlite_bytes=>write_u8(
          iv_data = lv_data iv_offset = 107 iv_value = 7 ).
        lv_data = zcl_sqlite_bytes=>write_u16(
          iv_data = lv_data iv_offset = 3900 iv_value = 3920 ).
        lv_data = zcl_sqlite_bytes=>write_u16(
          iv_data = lv_data iv_offset = 3902 iv_value = 20 ).
        lv_data = zcl_sqlite_bytes=>write_u16(
          iv_data = lv_data iv_offset = 3920 iv_value = 0 ).
        lv_data = zcl_sqlite_bytes=>write_u16(
          iv_data = lv_data iv_offset = 3922 iv_value = 30 ).

        ls_page = zcl_sqlite_page=>parse(
          iv_data = lv_data iv_offset = ls_raw-btree_offset ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |freeblock page parse failed: { lo_error->message }| ).
      CATCH cx_sy_conversion_overflow cx_sy_range_out_of_bounds.
        cl_abap_unit_assert=>fail( msg = 'could not build freeblock page' ).
    ENDTRY.

    cl_abap_unit_assert=>assert_equals(
      act = ls_page-first_freeblock exp = 3900 ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_page-fragmented_free_bytes exp = 7 ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_page-freeblocks ) exp = 2 ).

    READ TABLE ls_page-freeblocks INTO ls_freeblock INDEX 1.
    cl_abap_unit_assert=>assert_equals( act = ls_freeblock-offset exp = 3900 ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_freeblock-next_offset exp = 3920 ).
    cl_abap_unit_assert=>assert_equals( act = ls_freeblock-size exp = 20 ).

    READ TABLE ls_page-freeblocks INTO ls_freeblock INDEX 2.
    cl_abap_unit_assert=>assert_equals( act = ls_freeblock-offset exp = 3920 ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_freeblock-next_offset exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = ls_freeblock-size exp = 30 ).
  ENDMETHOD.

  METHOD bad_page_type.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA lv_data TYPE xstring.

    ls_raw = raw_page( iv_name = c_empty iv_page = 1 ).

    TRY.
        lv_data = zcl_sqlite_bytes=>write_u8(
          iv_data = ls_raw-data iv_offset = 100 iv_value = 99 ).
        zcl_sqlite_page=>parse(
          iv_data = lv_data iv_offset = ls_raw-btree_offset ).
        cl_abap_unit_assert=>fail( msg = 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code exp = zcx_sqlite_error=>sqlite_corrupt ).
      CATCH cx_sy_conversion_overflow cx_sy_range_out_of_bounds.
        cl_abap_unit_assert=>fail( msg = 'could not modify fixture page' ).
    ENDTRY.
  ENDMETHOD.

  METHOD truncated_header.
    TRY.
        zcl_sqlite_page=>parse( iv_data = '00' ).
        cl_abap_unit_assert=>fail( msg = 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code exp = zcx_sqlite_error=>sqlite_corrupt ).
    ENDTRY.
  ENDMETHOD.

  METHOD assert_fixture.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA ls_expect TYPE ty_page_expect.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA lv_header_size TYPE i.
    DATA lv_pointer_offset TYPE i.

    lo_pager = open_pager( iv_name ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_pager->page_count( ) exp = lines( it_pages )
      msg = |{ iv_name } page count| ).

    LOOP AT it_pages INTO ls_expect.
      TRY.
          ls_raw = lo_pager->get_page( ls_expect-number ).
          ls_page = zcl_sqlite_page=>parse(
            iv_data = ls_raw-data iv_offset = ls_raw-btree_offset ).
        CATCH zcx_sqlite_error INTO DATA(lo_error).
          cl_abap_unit_assert=>fail(
            msg = |{ iv_name } page { ls_expect-number } parse failed: { lo_error->message }| ).
      ENDTRY.

      cl_abap_unit_assert=>assert_equals(
        act = ls_page-page_type exp = ls_expect-page_type
        msg = |{ iv_name } page { ls_expect-number } type| ).
      cl_abap_unit_assert=>assert_equals(
        act = ls_page-cell_count exp = ls_expect-cell_count
        msg = |{ iv_name } page { ls_expect-number } cell count| ).
      cl_abap_unit_assert=>assert_equals(
        act = lines( ls_page-cell_offsets ) exp = ls_expect-cell_count
        msg = |{ iv_name } page { ls_expect-number } cell pointer count| ).
      cl_abap_unit_assert=>assert_equals(
        act = ls_page-cell_content_offset exp = ls_expect-cell_content_offset
        msg = |{ iv_name } page { ls_expect-number } cell content offset| ).
      cl_abap_unit_assert=>assert_equals(
        act = ls_page-rightmost_pointer exp = ls_expect-rightmost_pointer
        msg = |{ iv_name } page { ls_expect-number } right-most pointer| ).
      cl_abap_unit_assert=>assert_equals(
        act = ls_page-first_freeblock exp = 0
        msg = |{ iv_name } page { ls_expect-number } first freeblock| ).
      cl_abap_unit_assert=>assert_equals(
        act = ls_page-fragmented_free_bytes exp = 0
        msg = |{ iv_name } page { ls_expect-number } fragmented bytes| ).
      cl_abap_unit_assert=>assert_equals(
        act = lines( ls_page-freeblocks ) exp = 0
        msg = |{ iv_name } page { ls_expect-number } freeblocks| ).

      IF ls_expect-page_type = zcl_sqlite_page=>c_index_interior
          OR ls_expect-page_type = zcl_sqlite_page=>c_table_interior.
        lv_header_size = 12.
      ELSE.
        lv_header_size = 8.
      ENDIF.
      cl_abap_unit_assert=>assert_equals(
        act = ls_page-header_size exp = lv_header_size
        msg = |{ iv_name } page { ls_expect-number } header size| ).

      lv_pointer_offset = lv_header_size.
      IF ls_expect-number = 1.
        lv_pointer_offset = zcl_sqlite_header=>c_header_size + lv_header_size.
      ENDIF.
      cl_abap_unit_assert=>assert_equals(
        act = ls_page-cell_pointer_offset exp = lv_pointer_offset
        msg = |{ iv_name } page { ls_expect-number } cell pointer offset| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD open_pager.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_vfs->open( iv_name ).

    TRY.
        ro_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |pager construction failed: { lo_error->message }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD raw_page.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.

    lo_pager = open_pager( iv_name ).

    TRY.
        rs_page = lo_pager->get_page( iv_page ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |page { iv_page } fetch failed: { lo_error->message }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
