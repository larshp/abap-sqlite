CLASS ltcl_btree DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS table_leaf_formula FOR TESTING RAISING zcx_sqlite_error.
    METHODS index_formula FOR TESTING RAISING zcx_sqlite_error.
    METHODS invalid_usable_size FOR TESTING.
ENDCLASS.


CLASS ltcl_btree IMPLEMENTATION.

  METHOD table_leaf_formula.
* with 4096 byte pages X = 4061 and M = 489
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_btree=>local_payload_size(
        iv_payload_size = 4061 iv_usable_size = 4096 )
      exp = 4061
      msg = 'payload at the table-leaf threshold stays local' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_btree=>local_payload_size(
        iv_payload_size = 4062 iv_usable_size = 4096 )
      exp = 489
      msg = 'payload just over the table-leaf threshold spills' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_btree=>local_payload_size(
        iv_payload_size = 9000 iv_usable_size = 4096 )
      exp = 816
      msg = 'table-leaf payload uses the K formula' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_btree=>local_payload_size(
        iv_payload_size = 12015 iv_usable_size = 4096 )
      exp = 3831
      msg = 'multi-page table-leaf payload uses the K formula' ).
  ENDMETHOD.

  METHOD index_formula.
* with 4096 byte pages X = 1002 and M = 489 for index cells
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_btree=>local_payload_size(
        iv_payload_size = 1002
        iv_usable_size  = 4096
        iv_table_leaf   = abap_false )
      exp = 1002
      msg = 'payload at the index threshold stays local' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_btree=>local_payload_size(
        iv_payload_size = 1003
        iv_usable_size  = 4096
        iv_table_leaf   = abap_false )
      exp = 489
      msg = 'payload just over the index threshold spills' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_btree=>local_payload_size(
        iv_payload_size = 5000
        iv_usable_size  = 4096
        iv_table_leaf   = abap_false )
      exp = 908
      msg = 'index payload uses the K formula' ).
  ENDMETHOD.

  METHOD invalid_usable_size.
    TRY.
        zcl_sqlite_btree=>local_payload_size(
          iv_payload_size = 10 iv_usable_size = 479 ).
        cl_abap_unit_assert=>fail( msg = 'small usable size was accepted' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code exp = zcx_sqlite_error=>sqlite_corrupt ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
