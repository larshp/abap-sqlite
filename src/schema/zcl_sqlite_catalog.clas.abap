* Raw reader for the sqlite_schema table, see
* https://www.sqlite.org/schematab.html
*
* The entries are returned in rowid order, which is the order SELECT * FROM
* sqlite_schema uses. SQL text can be NULL for internal index entries, so the
* catalog keeps an explicit sql_is_null flag instead of mapping NULL to ''.
CLASS zcl_sqlite_catalog DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_entry,
             type        TYPE string,
             name        TYPE string,
             tbl_name    TYPE string,
             rootpage    TYPE int8,
             sql         TYPE string,
             sql_is_null TYPE abap_bool,
           END OF ty_entry.
    TYPES ty_entries TYPE STANDARD TABLE OF ty_entry WITH DEFAULT KEY.

    CLASS-METHODS read
      IMPORTING io_pager          TYPE REF TO zcl_sqlite_pager
      RETURNING VALUE(rt_entries) TYPE ty_entries
      RAISING   zcx_sqlite_error.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS as_text
      IMPORTING io_value       TYPE REF TO zcl_sqlite_value
                iv_column      TYPE string
      RETURNING VALUE(rv_text) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS as_integer
      IMPORTING io_value        TYPE REF TO zcl_sqlite_value
                iv_column       TYPE string
      RETURNING VALUE(rv_value) TYPE int8
      RAISING   zcx_sqlite_error.

    CLASS-METHODS fail
      IMPORTING iv_message TYPE string
      RAISING   zcx_sqlite_error.
ENDCLASS.


CLASS zcl_sqlite_catalog IMPLEMENTATION.

  METHOD read.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA lv_found TYPE abap_bool.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA ls_entry TYPE ty_entry.

    lo_cursor = NEW zcl_sqlite_cursor(
      io_pager = io_pager
      iv_root_page = 1 ).

    lv_found = lo_cursor->first( ).
    WHILE lv_found = abap_true.
      lt_values = lo_cursor->values( ).
      IF lines( lt_values ) <> 5.
        fail( 'sqlite_schema row does not have five columns' ).
      ENDIF.

      READ TABLE lt_values INTO lo_value INDEX 1.
      ls_entry-type = as_text( io_value = lo_value iv_column = 'type' ).
      READ TABLE lt_values INTO lo_value INDEX 2.
      ls_entry-name = as_text( io_value = lo_value iv_column = 'name' ).
      READ TABLE lt_values INTO lo_value INDEX 3.
      ls_entry-tbl_name = as_text(
        io_value = lo_value iv_column = 'tbl_name' ).
      READ TABLE lt_values INTO lo_value INDEX 4.
      ls_entry-rootpage = as_integer(
        io_value = lo_value iv_column = 'rootpage' ).
      READ TABLE lt_values INTO lo_value INDEX 5.
      IF lo_value->is_null( ) = abap_true.
        ls_entry-sql_is_null = abap_true.
        CLEAR ls_entry-sql.
      ELSE.
        ls_entry-sql_is_null = abap_false.
        ls_entry-sql = as_text( io_value = lo_value iv_column = 'sql' ).
      ENDIF.

      APPEND ls_entry TO rt_entries.
      lv_found = lo_cursor->next( ).
    ENDWHILE.
  ENDMETHOD.

  METHOD as_text.
    IF io_value->value_type( ) <> zcl_sqlite_value=>c_text.
      fail( |sqlite_schema column { iv_column } is not text| ).
    ENDIF.
    rv_text = io_value->as_text( ).
  ENDMETHOD.

  METHOD as_integer.
    IF io_value->value_type( ) <> zcl_sqlite_value=>c_integer.
      fail( |sqlite_schema column { iv_column } is not an integer| ).
    ENDIF.
    rv_value = io_value->as_integer( ).
  ENDMETHOD.

  METHOD fail.
    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = zcx_sqlite_error=>sqlite_corrupt
        iv_message = iv_message.
  ENDMETHOD.

ENDCLASS.
