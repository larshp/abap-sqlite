* Base class for SQL expression AST nodes.
CLASS zcl_sqlite_ast_node DEFINITION
  PUBLIC
  CREATE PROTECTED.

  PUBLIC SECTION.
    TYPES ty_node TYPE REF TO zcl_sqlite_ast_node.
    TYPES ty_nodes TYPE STANDARD TABLE OF ty_node WITH DEFAULT KEY.

    METHODS dump
      RETURNING VALUE(rv_text) TYPE string.

  PROTECTED SECTION.
    CLASS-METHODS dump_nodes
      IMPORTING it_nodes       TYPE ty_nodes
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS quote_string
      IMPORTING iv_value       TYPE string
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_node IMPLEMENTATION.

  METHOD dump.
    rv_text = 'NODE'.
  ENDMETHOD.

  METHOD dump_nodes.
    DATA lo_node TYPE ty_node.

    LOOP AT it_nodes INTO lo_node.
      IF rv_text IS NOT INITIAL.
        " ANORMALY: character literals lose trailing blanks when concatenated
        rv_text = rv_text && |, |.
      ENDIF.
      rv_text = rv_text && lo_node->dump( ).
    ENDLOOP.
  ENDMETHOD.

  METHOD quote_string.
    rv_text = iv_value.
    REPLACE ALL OCCURRENCES OF '''' IN rv_text WITH ''''''.
    rv_text = |'{ rv_text }'|.
  ENDMETHOD.

ENDCLASS.
