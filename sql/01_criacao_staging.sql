/*
Projeto: Análise de clientes com SQL — Olist
Etapa 1: criação da camada de dados brutos (staging)

Após executar este arquivo, importe os CSVs pelo pgAdmin conforme o README.
As colunas permanecem como TEXT para preservar os dados originais.
*/

CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE IF NOT EXISTS staging.clientes (
    customer_id TEXT,
    customer_unique_id TEXT,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state TEXT
);

CREATE TABLE IF NOT EXISTS staging.pedidos (
    order_id TEXT,
    customer_id TEXT,
    order_status TEXT,
    order_purchase_timestamp TEXT,
    order_approved_at TEXT,
    order_delivered_carrier_date TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT
);

CREATE TABLE IF NOT EXISTS staging.pagamentos (
    order_id TEXT,
    payment_sequential TEXT,
    payment_type TEXT,
    payment_installments TEXT,
    payment_value TEXT
);

CREATE TABLE IF NOT EXISTS staging.itens_pedido (
    order_id TEXT,
    order_item_id TEXT,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TEXT,
    price TEXT,
    freight_value TEXT
);

CREATE TABLE IF NOT EXISTS staging.produtos (
    product_id TEXT,
    product_category_name TEXT,
    product_name_lenght TEXT,
    product_description_lenght TEXT,
    product_photos_qty TEXT,
    product_weight_g TEXT,
    product_length_cm TEXT,
    product_height_cm TEXT,
    product_width_cm TEXT
);

CREATE TABLE IF NOT EXISTS staging.traducao_categorias (
    product_category_name TEXT,
    product_category_name_english TEXT
);

-- Validação após a importação dos seis CSVs.
SELECT
    (SELECT COUNT(*) FROM staging.clientes) AS clientes,
    (SELECT COUNT(*) FROM staging.pedidos) AS pedidos,
    (SELECT COUNT(*) FROM staging.pagamentos) AS pagamentos,
    (SELECT COUNT(*) FROM staging.itens_pedido) AS itens,
    (SELECT COUNT(*) FROM staging.produtos) AS produtos,
    (SELECT COUNT(*) FROM staging.traducao_categorias) AS traducoes;

-- Verificação das chaves naturais e de possíveis cargas duplicadas.
SELECT
    (SELECT COUNT(*) - COUNT(DISTINCT customer_id) FROM staging.clientes)
        AS clientes_duplicados,
    (SELECT COUNT(*) - COUNT(DISTINCT order_id) FROM staging.pedidos)
        AS pedidos_duplicados,
    (SELECT COUNT(*) - COUNT(DISTINCT product_id) FROM staging.produtos)
        AS produtos_duplicados,
    (SELECT COUNT(*) - COUNT(DISTINCT (order_id, order_item_id))
     FROM staging.itens_pedido) AS itens_duplicados,
    (SELECT COUNT(*) - COUNT(DISTINCT (order_id, payment_sequential))
     FROM staging.pagamentos) AS pagamentos_duplicados;

