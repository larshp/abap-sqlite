REPORT zsqlite_demo.

CLASS lcl_demo DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS run
      RAISING zcx_sqlite_error.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_item,
             id    TYPE i,
             name  TYPE string,
             qty   TYPE i,
             price TYPE p LENGTH 8 DECIMALS 2,
           END OF ty_item.
    TYPES ty_items TYPE STANDARD TABLE OF ty_item WITH DEFAULT KEY.

    CLASS-METHODS fill_items
      RETURNING VALUE(rt_items) TYPE ty_items.

    CLASS-METHODS write_items
      IMPORTING it_items TYPE ty_items.
ENDCLASS.


CLASS lcl_demo IMPLEMENTATION.

  METHOD run.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_statement TYPE REF TO zif_sqlite_statement.
    DATA lt_items    TYPE ty_items.
    DATA lt_report   TYPE ty_items.
    DATA ls_result   TYPE zcl_sqlite_database=>ty_result.
    DATA lv_file     TYPE string.

    lv_file = 'demo.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_file ).

    lo_database = zcl_sqlite_database=>open( lv_file ).
    lo_database->exec(
      'CREATE TABLE items (' &&
      ' id INTEGER PRIMARY KEY,' &&
      ' name TEXT NOT NULL,' &&
      ' qty INTEGER NOT NULL DEFAULT 0,' &&
      ' price REAL);' &&
      'CREATE INDEX items_name ON items(name)' ).

    lt_items = fill_items( ).
    lo_database->insert_table(
      iv_table_name = 'items'
      it_data       = lt_items ).

    lo_statement = lo_database->prepare( 'UPDATE items SET qty = qty + ? WHERE name = ?' ).
    lo_statement->bind(
      iv_index = 1
      io_value = zcl_sqlite_value=>integer( 2 ) ).
    lo_statement->bind(
      iv_index = 2
      io_value = zcl_sqlite_value=>text( 'apple' ) ).
    lo_statement->step( ).

    lo_database->select_into(
      EXPORTING
        iv_sql   = 'SELECT id, name, qty, price FROM items ORDER BY id'
      CHANGING
        ct_table = lt_report ).
    WRITE / 'Items after the prepared update'.
    write_items( lt_report ).

    lo_database->begin( ).
    lo_database->execute( 'DELETE FROM items' ).
    lo_database->rollback( ).
    ls_result = lo_database->query( 'SELECT id FROM items' ).
    WRITE / |Rows after rollback: { lines( ls_result-rows ) }|.

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_file ).
  ENDMETHOD.

  METHOD fill_items.
    DATA ls_item TYPE ty_item.

    ls_item-id = 1.
    ls_item-name = 'apple'.
    ls_item-qty = 3.
    ls_item-price = '0.50'.
    APPEND ls_item TO rt_items.

    ls_item-id = 2.
    ls_item-name = 'banana'.
    ls_item-qty = 4.
    ls_item-price = '0.25'.
    APPEND ls_item TO rt_items.

    ls_item-id = 3.
    ls_item-name = 'cherry'.
    ls_item-qty = 1.
    ls_item-price = '2.00'.
    APPEND ls_item TO rt_items.
  ENDMETHOD.

  METHOD write_items.
    DATA ls_item  TYPE ty_item.
    DATA lv_total TYPE p LENGTH 10 DECIMALS 2.

    LOOP AT it_items INTO ls_item.
      WRITE / |{ ls_item-id } { ls_item-name } { ls_item-qty } { ls_item-price }|.
      lv_total = lv_total + ls_item-qty * ls_item-price.
    ENDLOOP.
    WRITE / |Total value: { lv_total }|.
  ENDMETHOD.

ENDCLASS.


DATA lo_error TYPE REF TO zcx_sqlite_error.

START-OF-SELECTION.
  TRY.
      lcl_demo=>run( ).
    CATCH zcx_sqlite_error INTO lo_error.
      WRITE / |SQLite error { lo_error->code }: { lo_error->message }|.
  ENDTRY.
