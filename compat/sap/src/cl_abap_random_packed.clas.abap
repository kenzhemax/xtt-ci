CLASS cl_abap_random_packed DEFINITION PUBLIC FINAL CREATE PRIVATE.
  " xtt-ci compat: open-abap-core has cl_abap_random_int but not this one.
  " Same approach as core's cl_abap_random_int: the seed is accepted and not
  " used, values are whole numbers in [min, max] within the integer range.
  PUBLIC SECTION.
    TYPES p31_0 TYPE p LENGTH 16 DECIMALS 0.

    CLASS-METHODS create
      IMPORTING
        seed        TYPE i OPTIONAL
        min         TYPE p31_0 DEFAULT -2147483648
        max         TYPE p31_0 DEFAULT 2147483647
      RETURNING
        VALUE(prng) TYPE REF TO cl_abap_random_packed.

    METHODS get_next
      RETURNING
        VALUE(value) TYPE p31_0.

  PRIVATE SECTION.
    DATA mv_min TYPE i.
    DATA mv_max TYPE i.
ENDCLASS.

CLASS cl_abap_random_packed IMPLEMENTATION.
  METHOD create.
    CREATE OBJECT prng.
    prng->mv_min = min.
    prng->mv_max = max.
  ENDMETHOD.

  METHOD get_next.
    value = cl_abap_random=>create( )->intinrange(
      low  = mv_min
      high = mv_max ).
  ENDMETHOD.
ENDCLASS.
