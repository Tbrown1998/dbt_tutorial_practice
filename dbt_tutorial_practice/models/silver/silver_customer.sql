SELECT
    customer_sk,
    {{ clean_text('customer_code', 'upper') }}                AS customer_code,
    {{ clean_text('first_name') }}                            AS first_name,
    {{ clean_text('last_name') }}                             AS last_name,
    CONCAT_WS(' ', {{ clean_text('first_name') }}, {{ clean_text('last_name') }}) AS full_name,
    {{ clean_text('gender') }}                                AS gender,
    {{ clean_text('email', 'lower') }}                        AS email,
    TRIM(phone)                                               AS phone,
    {{ clean_text('loyalty_tier') }}                          AS loyalty_tier,
    CAST(signup_date AS DATE)                                 AS signup_date
FROM {{ ref('bronze_customer') }}
