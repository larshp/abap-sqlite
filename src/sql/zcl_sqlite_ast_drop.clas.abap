* A DROP TABLE or DROP INDEX statement.
CLASS zcl_sqlite_ast_drop DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_object_type TYPE string
                iv_name        TYPE string
                iv_if_exists   TYPE abap_bool DEFAULT abap_false.

    METHODS get_object_type
      RETURNING VALUE(rv_object_type) TYPE string.

    METHODS get_name
      RETURNING VALUE(rv_name) TYPE string.

    METHODS is_if_exists
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_object_type TYPE string.
    DATA mv_name        TYPE string.
    DATA mv_if_exists   TYPE abap_bool.

ENDCLASS.


CLASS zcl_sqlite_ast_drop IMPLEMENTATION.

  METHOD constructor.
    mv_object_type = iv_object_type.
    mv_name = iv_name.
    mv_if_exists = iv_if_exists.
  ENDMETHOD.

  METHOD get_object_type.
    rv_object_type = mv_object_type.
  ENDMETHOD.

  METHOD get_name.
    rv_name = mv_name.
  ENDMETHOD.

  METHOD is_if_exists.
    rv_result = mv_if_exists.
  ENDMETHOD.

  METHOD dump.
    rv_text = |DROP { mv_object_type } |.
    IF mv_if_exists = abap_true.
      rv_text = rv_text && |IF EXISTS |.
    ENDIF.
    rv_text = rv_text && mv_name.
  ENDMETHOD.

ENDCLASS.
