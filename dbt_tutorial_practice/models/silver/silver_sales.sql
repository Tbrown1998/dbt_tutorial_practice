SELECT
    s.sales_id,
    s.date_sk,
    d.date                                                    AS sales_date,
    s.store_sk,
    s.product_sk,
    s.customer_sk,
    s.promotion_sk,
    s.quantity,
    s.unit_price,
    s.gross_amount,
    s.discount_amount,
    s.net_amount,
    {{ safe_divide('s.discount_amount * 100', 's.gross_amount') }} AS discount_pct,
    {{ safe_divide('s.net_amount', 's.quantity') }}           AS net_price_per_unit,
    {{ clean_text('s.payment_method') }}                      AS payment_method
FROM {{ ref('bronze_sales') }} AS s
LEFT JOIN {{ ref('bronze_date') }} AS d
    ON s.date_sk = d.date_sk
