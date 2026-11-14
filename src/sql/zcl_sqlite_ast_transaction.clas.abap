* A transaction control statement: BEGIN, COMMIT, END or ROLLBACK.
CLASS zcl_sqlite_ast_transaction DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_action      TYPE string
                iv_mode        TYPE string OPTIONAL
                iv_transaction TYPE abap_bool DEFAULT abap_false
                iv_to          TYPE string OPTIONAL
                iv_savepoint   TYPE abap_bool DEFAULT abap_false.

    METHODS dump REDEFINITION.

    METHODS get_action
      RETURNING VALUE(rv_action) TYPE string.

    METHODS get_mode
      RETURNING VALUE(rv_mode) TYPE string.

    METHODS get_to
      RETURNING VALUE(rv_to) TYPE string.

    METHODS is_savepoint
      RETURNING VALUE(rv_savepoint) TYPE abap_bool.

  PRIVATE SECTION.
    DATA mv_action      TYPE string.
    DATA mv_mode        TYPE string.
    DATA mv_transaction TYPE abap_bool.
    DATA mv_to          TYPE string.
    DATA mv_savepoint   TYPE abap_bool.

ENDCLASS.


CLASS zcl_sqlite_ast_transaction IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_action = iv_action.
    mv_mode = iv_mode.
    mv_transaction = iv_transaction.
    mv_to = iv_to.
    mv_savepoint = iv_savepoint.
  ENDMETHOD.

  METHOD dump.
    rv_text = mv_action.
    IF mv_mode IS NOT INITIAL.
      rv_text = rv_text && | | && mv_mode.
    ENDIF.
    IF mv_transaction = abap_true.
      rv_text = rv_text && | TRANSACTION|.
    ENDIF.
    IF mv_to IS NOT INITIAL.
      rv_text = rv_text && | TO |.
      IF mv_savepoint = abap_true.
        rv_text = rv_text && |SAVEPOINT |.
      ENDIF.
      rv_text = rv_text && mv_to.
    ENDIF.
  ENDMETHOD.

  METHOD get_action.
    rv_action = mv_action.
  ENDMETHOD.

  METHOD get_mode.
    rv_mode = mv_mode.
  ENDMETHOD.

  METHOD get_to.
    rv_to = mv_to.
  ENDMETHOD.

  METHOD is_savepoint.
    rv_savepoint = mv_savepoint.
  ENDMETHOD.

ENDCLASS.
