* Raw reader and writer for the sqlite_schema table, see
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
    TYPES ty_names TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

    CLASS-METHODS read
      IMPORTING io_pager          TYPE REF TO zcl_sqlite_pager
      RETURNING VALUE(rt_entries) TYPE ty_entries
      RAISING   zcx_sqlite_error.

    CLASS-METHODS append
      IMPORTING io_pager        TYPE REF TO zcl_sqlite_pager
                is_entry        TYPE ty_entry
      RETURNING VALUE(rv_rowid) TYPE int8
      RAISING   zcx_sqlite_error.

* remove the entries with the given names, used by DROP TABLE and DROP INDEX
    CLASS-METHODS remove
      IMPORTING io_pager TYPE REF TO zcl_sqlite_pager
                it_names TYPE ty_names
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
      io_pager     = io_pager
      iv_root_page = 1 ).

    lv_found = lo_cursor->first( ).
    WHILE lv_found = abap_true.
      lt_values = lo_cursor->values( ).
      IF lines( lt_values ) <> 5.
        fail( 'sqlite_schema row does not have five columns' ).
      ENDIF.

      READ TABLE lt_values INTO lo_value INDEX 1.
      ls_entry-type = as_text( io_value  = lo_value
                               iv_column = 'type' ).
      READ TABLE lt_values INTO lo_value INDEX 2.
      ls_entry-name = as_text( io_value  = lo_value
                               iv_column = 'name' ).
      READ TABLE lt_values INTO lo_value INDEX 3.
      ls_entry-tbl_name = as_text(
        io_value  = lo_value
        iv_column = 'tbl_name' ).
      READ TABLE lt_values INTO lo_value INDEX 4.
      ls_entry-rootpage = as_integer(
        io_value  = lo_value
        iv_column = 'rootpage' ).
      READ TABLE lt_values INTO lo_value INDEX 5.
      IF lo_value->is_null( ) = abap_true.
        ls_entry-sql_is_null = abap_true.
        CLEAR ls_entry-sql.
      ELSE.
        ls_entry-sql_is_null = abap_false.
        ls_entry-sql = as_text( io_value  = lo_value
                                iv_column = 'sql' ).
      ENDIF.

      APPEND ls_entry TO rt_entries.
      lv_found = lo_cursor->next( ).
    ENDWHILE.
  ENDMETHOD.

  METHOD append.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lv_found TYPE abap_bool.

    lo_cursor = NEW zcl_sqlite_cursor(
      io_pager     = io_pager
      iv_root_page = 1 ).

    rv_rowid = 1.
    lv_found = lo_cursor->first( ).
    WHILE lv_found = abap_true.
      rv_rowid = lo_cursor->rowid( ) + 1.
      lv_found = lo_cursor->next( ).
    ENDWHILE.

    APPEND zcl_sqlite_value=>text( is_entry-type ) TO lt_values.
    APPEND zcl_sqlite_value=>text( is_entry-name ) TO lt_values.
    APPEND zcl_sqlite_value=>text( is_entry-tbl_name ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( is_entry-rootpage ) TO lt_values.
    IF is_entry-sql_is_null = abap_true.
      APPEND zcl_sqlite_value=>null( ) TO lt_values.
    ELSE.
      APPEND zcl_sqlite_value=>text( is_entry-sql ) TO lt_values.
    ENDIF.

    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = io_pager
      iv_root_page = 1 ).
    lo_writer->insert_row(
      iv_rowid   = rv_rowid
      iv_payload = zcl_sqlite_record=>encode( lt_values ) ).
  ENDMETHOD.

  METHOD remove.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lt_rowids TYPE STANDARD TABLE OF int8 WITH DEFAULT KEY.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA lv_found TYPE abap_bool.
    DATA lv_name TYPE string.
    DATA lv_remove TYPE string.
    DATA lv_rowid TYPE int8.

    lo_cursor = NEW zcl_sqlite_cursor(
      io_pager     = io_pager
      iv_root_page = 1 ).

    lv_found = lo_cursor->first( ).
    WHILE lv_found = abap_true.
      lt_values = lo_cursor->values( ).
      READ TABLE lt_values INTO lo_value INDEX 2.
      lv_name = lo_value->as_text( ).
      LOOP AT it_names INTO lv_remove.
        IF to_upper( lv_remove ) = to_upper( lv_name ).
          lv_rowid = lo_cursor->rowid( ).
          APPEND lv_rowid TO lt_rowids.
          EXIT.
        ENDIF.
      ENDLOOP.
      lv_found = lo_cursor->next( ).
    ENDWHILE.

* deleting from high to low keeps the remaining rowids valid
    SORT lt_rowids DESCENDING.
    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = io_pager
      iv_root_page = 1 ).
    LOOP AT lt_rowids INTO lv_rowid.
      lo_writer->delete_row( lv_rowid ).
    ENDLOOP.
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
