* Deterministic pseudo random numbers for the compatibility scenarios. The
* Park-Miller generator is repeated in the verifier so ABAP and sql.js run the
* same workload.
CLASS zcl_sqlite_random DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_seed TYPE int8 DEFAULT 12345.

    METHODS next
      IMPORTING iv_limit        TYPE i
      RETURNING VALUE(rv_value) TYPE i.

  PRIVATE SECTION.
    DATA mv_seed TYPE int8.
ENDCLASS.


CLASS zcl_sqlite_random IMPLEMENTATION.

  METHOD constructor.
    mv_seed = iv_seed.
  ENDMETHOD.

  METHOD next.
    mv_seed = ( mv_seed * 48271 ) MOD 2147483647.
    rv_value = CONV i( mv_seed MOD iv_limit ).
  ENDMETHOD.

ENDCLASS.
