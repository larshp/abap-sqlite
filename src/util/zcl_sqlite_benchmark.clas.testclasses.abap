CLASS ltcl_benchmark DEFINITION FINAL FOR TESTING
  DURATION MEDIUM
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS run FOR TESTING.
ENDCLASS.


CLASS ltcl_benchmark IMPLEMENTATION.

  METHOD run.
    DATA ls_result TYPE zcl_sqlite_benchmark=>ty_result.

    ls_result = zcl_sqlite_benchmark=>run( ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-slice_count
      exp = zcl_sqlite_benchmark=>c_slices ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-write_count
      exp = zcl_sqlite_benchmark=>c_rows ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-read_count
      exp = zcl_sqlite_benchmark=>c_rows ).
  ENDMETHOD.

ENDCLASS.
