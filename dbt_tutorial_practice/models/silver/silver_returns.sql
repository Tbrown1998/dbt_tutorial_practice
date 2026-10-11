SELECT
    r.sales_id,
    r.date_sk,
    r.store_sk,
    r.product_sk,
    r.returned_qty,
    {{ clean_text('r.return_reason') }}                       AS return_reason,
    r.refund_amount,
    {{ safe_divide('r.refund_amount', 'r.returned_qty') }}    AS refund_per_unit,
    s.quantity                                                AS sold_qty,
    {{ safe_divide('r.returned_qty * 100', 's.quantity') }}   AS returned_qty_pct,
    {{ safe_divide('r.refund_amount * 100', 's.net_amount') }} AS refund_pct_of_sale
FROM {{ ref('bronze_returns') }} AS r
LEFT JOIN {{ ref('bronze_sales') }} AS s
    ON r.sales_id = s.sales_id
