{#
    Divides two expressions, returning NULL instead of erroring when the
    denominator is 0, and rounds the result.
#}
{% macro safe_divide(numerator, denominator, decimals=2) -%}
    ROUND({{ numerator }} / NULLIF({{ denominator }}, 0), {{ decimals }})
{%- endmacro %}
