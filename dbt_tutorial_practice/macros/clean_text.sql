{#
    Trims whitespace and standardises the casing of a text column.
    case_type: 'upper' | 'lower' | 'initcap' (default)
#}
{% macro clean_text(column_name, case_type='initcap') -%}
    {%- if case_type == 'upper' -%}
        UPPER(TRIM({{ column_name }}))
    {%- elif case_type == 'lower' -%}
        LOWER(TRIM({{ column_name }}))
    {%- else -%}
        INITCAP(TRIM({{ column_name }}))
    {%- endif -%}
{%- endmacro %}
