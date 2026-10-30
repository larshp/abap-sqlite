CLASS ltcl_record DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_serial_types TYPE string VALUE 'fixtures/serial_types.db'.

    TYPES ty_records TYPE STANDARD TABLE OF xstring WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_expected,
             kind       TYPE i,
             int_value  TYPE int8,
             real_value TYPE f,
             text_value TYPE string,
             blob_value TYPE xstring,
           END OF ty_expected.
    TYPES ty_expected_values TYPE STANDARD TABLE OF ty_expected WITH DEFAULT KEY.

    METHODS serial_types_fixture FOR TESTING.
    METHODS reserved_serial_type FOR TESTING.
    METHODS truncated_record FOR TESTING.
    METHODS bad_header FOR TESTING.

    METHODS read_records
      RETURNING VALUE(rt_records) TYPE ty_records.
    METHODS assert_values
      IMPORTING it_values   TYPE zcl_sqlite_record=>ty_values
                it_expected TYPE ty_expected_values.
    METHODS open_pager
      RETURNING VALUE(ro_pager) TYPE REF TO zcl_sqlite_pager.
ENDCLASS.


CLASS ltcl_record IMPLEMENTATION.

  METHOD serial_types_fixture.
    DATA lt_records TYPE ty_records.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lt_expected TYPE ty_expected_values.
    DATA lv_record TYPE xstring.

    lt_records = read_records( ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_records ) exp = 2 ).

    READ TABLE lt_records INTO lv_record INDEX 1.
    TRY.
        lt_values = zcl_sqlite_record=>decode( lv_record ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |first record decode failed: { lo_error->message }| ).
    ENDTRY.

    lt_expected = VALUE #(
      ( kind = zcl_sqlite_value=>c_null )
      ( kind = zcl_sqlite_value=>c_integer int_value = -1 )
      ( kind = zcl_sqlite_value=>c_integer int_value = -129 )
      ( kind = zcl_sqlite_value=>c_integer int_value = -32769 )
      ( kind = zcl_sqlite_value=>c_integer int_value = -8388609 )
      ( kind = zcl_sqlite_value=>c_integer int_value = -2147483649 )
      ( kind = zcl_sqlite_value=>c_integer int_value = -140737488355329 )
      ( kind = zcl_sqlite_value=>c_real real_value = '1.5' )
      ( kind = zcl_sqlite_value=>c_integer int_value = 0 )
      ( kind = zcl_sqlite_value=>c_integer int_value = 1 )
      ( kind = zcl_sqlite_value=>c_blob blob_value = '' )
      ( kind = zcl_sqlite_value=>c_text text_value = '' )
      ( kind = zcl_sqlite_value=>c_blob blob_value = '010203' )
      ( kind = zcl_sqlite_value=>c_text text_value = 'abc' )
      ( kind = zcl_sqlite_value=>c_text text_value = 'hello' ) ).
    assert_values( it_values = lt_values it_expected = lt_expected ).

    READ TABLE lt_records INTO lv_record INDEX 2.
    TRY.
        lt_values = zcl_sqlite_record=>decode( lv_record ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>fail( msg = |second record decode failed: { lo_error->message }| ).
    ENDTRY.

    lt_expected = VALUE #(
      ( kind = zcl_sqlite_value=>c_null )
      ( kind = zcl_sqlite_value=>c_integer int_value = 127 )
      ( kind = zcl_sqlite_value=>c_integer int_value = 32767 )
      ( kind = zcl_sqlite_value=>c_integer int_value = 8388607 )
      ( kind = zcl_sqlite_value=>c_integer int_value = 2147483647 )
      ( kind = zcl_sqlite_value=>c_integer int_value = 140737488355327 )
      ( kind = zcl_sqlite_value=>c_integer int_value = 140737488355328 )
      ( kind = zcl_sqlite_value=>c_real real_value = '-1.5' )
      ( kind = zcl_sqlite_value=>c_integer int_value = 0 )
      ( kind = zcl_sqlite_value=>c_integer int_value = 1 )
      ( kind = zcl_sqlite_value=>c_blob blob_value = '' )
      ( kind = zcl_sqlite_value=>c_text text_value = '' )
      ( kind = zcl_sqlite_value=>c_blob blob_value = '040506' )
      ( kind = zcl_sqlite_value=>c_text text_value = 'xyz' )
      ( kind = zcl_sqlite_value=>c_text text_value = 'world' ) ).
    assert_values( it_values = lt_values it_expected = lt_expected ).
  ENDMETHOD.

  METHOD reserved_serial_type.
    TRY.
        zcl_sqlite_record=>decode( '020A' ).
        cl_abap_unit_assert=>fail( msg = 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code exp = zcx_sqlite_error=>sqlite_corrupt ).
    ENDTRY.
  ENDMETHOD.

  METHOD truncated_record.
    TRY.
        zcl_sqlite_record=>decode( '0201' ).
        cl_abap_unit_assert=>fail( msg = 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code exp = zcx_sqlite_error=>sqlite_corrupt ).
    ENDTRY.
  ENDMETHOD.

  METHOD bad_header.
    TRY.
        zcl_sqlite_record=>decode( '05' ).
        cl_abap_unit_assert=>fail( msg = 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code exp = zcx_sqlite_error=>sqlite_corrupt ).
    ENDTRY.
  ENDMETHOD.

  METHOD read_records.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA lv_cell_offset TYPE i.
    DATA lv_payload_length_i8 TYPE int8.
    DATA lv_payload_length TYPE i.
    DATA lv_rowid_offset TYPE i.
    DATA lv_rowid_length TYPE i.
    DATA lv_payload_offset TYPE i.
    DATA lv_record TYPE xstring.

    lo_pager = open_pager( ).
    TRY.
        ls_raw = lo_pager->get_page( 2 ).
        ls_page = zcl_sqlite_page=>parse(
          iv_data = ls_raw-data iv_offset = ls_raw-btree_offset ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |record page parse failed: { lo_error->message }| ).
    ENDTRY.

    LOOP AT ls_page-cell_offsets INTO lv_cell_offset.
      TRY.
          lv_payload_length_i8 = zcl_sqlite_bytes=>read_varint(
            iv_data = ls_raw-data iv_offset = lv_cell_offset ).
          lv_rowid_offset = lv_cell_offset + zcl_sqlite_bytes=>varint_length(
            iv_data = ls_raw-data iv_offset = lv_cell_offset ).
          lv_rowid_length = zcl_sqlite_bytes=>varint_length(
            iv_data = ls_raw-data iv_offset = lv_rowid_offset ).
          lv_payload_offset = lv_rowid_offset + lv_rowid_length.

          IF lv_payload_length_i8 > xstrlen( ls_raw-data ) - lv_payload_offset.
            cl_abap_unit_assert=>fail( msg = 'fixture record is truncated' ).
          ENDIF.
          lv_payload_length = lv_payload_length_i8.
          lv_record = ls_raw-data+lv_payload_offset(lv_payload_length).
        CATCH cx_sy_range_out_of_bounds.
          cl_abap_unit_assert=>fail( msg = 'fixture cell is truncated' ).
      ENDTRY.
      APPEND lv_record TO rt_records.
    ENDLOOP.
  ENDMETHOD.

  METHOD assert_values.
    DATA ls_expected TYPE ty_expected.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA lv_index TYPE i.

    cl_abap_unit_assert=>assert_equals(
      act = lines( it_values ) exp = lines( it_expected ) ).

    LOOP AT it_expected INTO ls_expected.
      lv_index = lv_index + 1.
      READ TABLE it_values INTO lo_value INDEX lv_index.
      cl_abap_unit_assert=>assert_equals(
        act = sy-subrc exp = 0
        msg = |value { lv_index } is missing| ).
      cl_abap_unit_assert=>assert_equals(
        act = lo_value->value_type( ) exp = ls_expected-kind
        msg = |value { lv_index } type| ).

      CASE ls_expected-kind.
        WHEN zcl_sqlite_value=>c_null.
          cl_abap_unit_assert=>assert_equals(
            act = lo_value->is_null( ) exp = abap_true
            msg = |value { lv_index } null| ).
        WHEN zcl_sqlite_value=>c_integer.
          cl_abap_unit_assert=>assert_equals(
            act = lo_value->as_integer( ) exp = ls_expected-int_value
            msg = |value { lv_index } integer| ).
        WHEN zcl_sqlite_value=>c_real.
          cl_abap_unit_assert=>assert_equals(
            act = lo_value->as_real( ) exp = ls_expected-real_value
            msg = |value { lv_index } real| ).
        WHEN zcl_sqlite_value=>c_text.
          cl_abap_unit_assert=>assert_equals(
            act = lo_value->as_text( ) exp = ls_expected-text_value
            msg = |value { lv_index } text| ).
        WHEN zcl_sqlite_value=>c_blob.
          cl_abap_unit_assert=>assert_equals(
            act = lo_value->as_blob( ) exp = ls_expected-blob_value
            msg = |value { lv_index } blob| ).
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD open_pager.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_vfs->open( c_serial_types ).

    TRY.
        ro_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |pager construction failed: { lo_error->message }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
