* One row in a VALUES statement.
CLASS zcl_sqlite_ast_values_row DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_list TYPE STANDARD TABLE OF REF TO zcl_sqlite_ast_values_row WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING it_values TYPE zcl_sqlite_ast_node=>ty_nodes.

    METHODS get_values
      RETURNING VALUE(rt_values) TYPE zcl_sqlite_ast_node=>ty_nodes.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mt_values TYPE zcl_sqlite_ast_node=>ty_nodes.

ENDCLASS.


CLASS zcl_sqlite_ast_values_row IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mt_values = it_values.
  ENDMETHOD.

  METHOD dump.
    rv_text = |(| && dump_nodes( mt_values ) && |)|.
  ENDMETHOD.

  METHOD get_values.
    rt_values = mt_values.
  ENDMETHOD.

ENDCLASS.
