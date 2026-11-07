CLASS ltcl_version DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS returns_version FOR TESTING.
ENDCLASS.


CLASS ltcl_version IMPLEMENTATION.
  METHOD returns_version.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_version=>get( )
      exp = '0.1.0' ).
  ENDMETHOD.
ENDCLASS.
