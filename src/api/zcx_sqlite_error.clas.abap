* SQLite-like result codes, see https://www.sqlite.org/rescode.html
CLASS zcx_sqlite_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS:
      sqlite_ok         TYPE i VALUE 0,
      sqlite_error      TYPE i VALUE 1,
      sqlite_internal   TYPE i VALUE 2,
      sqlite_permission TYPE i VALUE 3,
      sqlite_abort      TYPE i VALUE 4,
      sqlite_busy       TYPE i VALUE 5,
      sqlite_locked     TYPE i VALUE 6,
      sqlite_nomem      TYPE i VALUE 7,
      sqlite_readonly   TYPE i VALUE 8,
      sqlite_interrupt  TYPE i VALUE 9,
      sqlite_ioerr      TYPE i VALUE 10,
      sqlite_corrupt    TYPE i VALUE 11,
      sqlite_notfound   TYPE i VALUE 12,
      sqlite_full       TYPE i VALUE 13,
      sqlite_cantopen   TYPE i VALUE 14,
      sqlite_protocol   TYPE i VALUE 15,
      sqlite_empty      TYPE i VALUE 16,
      sqlite_schema     TYPE i VALUE 17,
      sqlite_toobig     TYPE i VALUE 18,
      sqlite_constraint TYPE i VALUE 19,
      sqlite_mismatch   TYPE i VALUE 20,
      sqlite_misuse     TYPE i VALUE 21,
      sqlite_nolfs      TYPE i VALUE 22,
      sqlite_auth       TYPE i VALUE 23,
      sqlite_format     TYPE i VALUE 24,
      sqlite_range      TYPE i VALUE 25,
      sqlite_notadb     TYPE i VALUE 26,
      sqlite_notice     TYPE i VALUE 27,
      sqlite_warning    TYPE i VALUE 28,
      sqlite_row        TYPE i VALUE 100,
      sqlite_done       TYPE i VALUE 101.

    DATA code TYPE i READ-ONLY.
    DATA message TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING iv_code    TYPE i DEFAULT sqlite_error
                iv_message TYPE string OPTIONAL
                textid     LIKE textid OPTIONAL
                previous   LIKE previous OPTIONAL.
ENDCLASS.


CLASS zcx_sqlite_error IMPLEMENTATION.
  METHOD constructor.
    super->constructor( textid = textid previous = previous ).
    code = iv_code.
    message = iv_message.
  ENDMETHOD.
ENDCLASS.
