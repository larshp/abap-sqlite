CLASS ltcl_page DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS truncated_header FOR TESTING.
ENDCLASS.

CLASS ltcl_page IMPLEMENTATION.

  METHOD truncated_header.
    TRY.
        zcl_sqlite_page=>parse( '00' ).
        cl_abap_unit_assert=>fail( 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_corrupt ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
