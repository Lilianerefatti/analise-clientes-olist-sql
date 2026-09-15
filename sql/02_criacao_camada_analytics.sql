/*
Etapa 2: criação da camada tratada (analytics)

Execute após criar e carregar todas as tabelas de staging.
*/

CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.clientes (
    customer_id TEXT PRIMARY KEY,
    customer_unique_id TEXT NOT NULL,
    cep_prefixo TEXT,
    cidade TEXT,
    estado CHAR(2)
);

INSERT INTO analytics.clientes (
    customer_id, customer_unique_id, cep_prefixo, cidade, estado
)
SELECT
    TRIM(customer_id),
    TRIM(customer_unique_id),
    NULLIF(TRIM(customer_zip_code_prefix), ''),
    NULLIF(TRIM(customer_city), ''),
    UPPER(NULLIF(TRIM(customer_state), ''))
FROM staging.clientes
ON CONFLICT (customer_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS analytics.pedidos (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    status_pedido TEXT NOT NULL,
    data_compra TIMESTAMP NOT NULL,
    data_aprovacao TIMESTAMP,
    data_envio_transportadora TIMESTAMP,
    data_entrega_cliente TIMESTAMP,
    data_estimada_entrega TIMESTAMP,
    CONSTRAINT fk_pedidos_clientes
        FOREIGN KEY (customer_id)
        REFERENCES analytics.clientes(customer_id)
);

INSERT INTO analytics.pedidos (
    order_id,
    customer_id,
    status_pedido,
    data_compra,
    data_aprovacao,
    data_envio_transportadora,
    data_entrega_cliente,
    data_estimada_entrega
)
SELECT
    TRIM(order_id),
    TRIM(customer_id),
    LOWER(TRIM(order_status)),
    NULLIF(TRIM(order_purchase_timestamp), '')::TIMESTAMP,
    NULLIF(TRIM(order_approved_at), '')::TIMESTAMP,
    NULLIF(TRIM(order_delivered_carrier_date), '')::TIMESTAMP,
    NULLIF(TRIM(order_delivered_customer_date), '')::TIMESTAMP,
    NULLIF(TRIM(order_estimated_delivery_date), '')::TIMESTAMP
FROM staging.pedidos
ON CONFLICT (order_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS analytics.produtos (
    product_id TEXT PRIMARY KEY,
    categoria_original TEXT,
    categoria_ingles TEXT,
    tamanho_nome INTEGER,
    tamanho_descricao INTEGER,
    quantidade_fotos INTEGER,
    peso_g NUMERIC(10, 2),
    comprimento_cm NUMERIC(10, 2),
    altura_cm NUMERIC(10, 2),
    largura_cm NUMERIC(10, 2)
);

INSERT INTO analytics.produtos (
    product_id,
    categoria_original,
    categoria_ingles,
    tamanho_nome,
    tamanho_descricao,
    quantidade_fotos,
    peso_g,
    comprimento_cm,
    altura_cm,
    largura_cm
)
SELECT
    TRIM(p.product_id),
    NULLIF(TRIM(p.product_category_name), ''),
    NULLIF(TRIM(t.product_category_name_english), ''),
    NULLIF(TRIM(p.product_name_lenght), '')::INTEGER,
    NULLIF(TRIM(p.product_description_lenght), '')::INTEGER,
    NULLIF(TRIM(p.product_photos_qty), '')::INTEGER,
    NULLIF(TRIM(p.product_weight_g), '')::NUMERIC(10, 2),
    NULLIF(TRIM(p.product_length_cm), '')::NUMERIC(10, 2),
    NULLIF(TRIM(p.product_height_cm), '')::NUMERIC(10, 2),
    NULLIF(TRIM(p.product_width_cm), '')::NUMERIC(10, 2)
FROM staging.produtos AS p
LEFT JOIN staging.traducao_categorias AS t
    ON p.product_category_name = t.product_category_name
ON CONFLICT (product_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS analytics.itens_pedido (
    order_id TEXT NOT NULL,
    order_item_id INTEGER NOT NULL,
    product_id TEXT NOT NULL,
    seller_id TEXT NOT NULL,
    data_limite_envio TIMESTAMP,
    preco NUMERIC(12, 2) NOT NULL,
    frete NUMERIC(12, 2) NOT NULL,
    CONSTRAINT pk_itens_pedido PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT fk_itens_pedido_pedidos
        FOREIGN KEY (order_id) REFERENCES analytics.pedidos(order_id),
    CONSTRAINT fk_itens_pedido_produtos
        FOREIGN KEY (product_id) REFERENCES analytics.produtos(product_id)
);

INSERT INTO analytics.itens_pedido (
    order_id, order_item_id, product_id, seller_id,
    data_limite_envio, preco, frete
)
SELECT
    TRIM(order_id),
    NULLIF(TRIM(order_item_id), '')::INTEGER,
    TRIM(product_id),
    TRIM(seller_id),
    NULLIF(TRIM(shipping_limit_date), '')::TIMESTAMP,
    NULLIF(TRIM(price), '')::NUMERIC(12, 2),
    NULLIF(TRIM(freight_value), '')::NUMERIC(12, 2)
FROM staging.itens_pedido
ON CONFLICT (order_id, order_item_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS analytics.pagamentos (
    order_id TEXT NOT NULL,
    sequencia_pagamento INTEGER NOT NULL,
    tipo_pagamento TEXT NOT NULL,
    quantidade_parcelas INTEGER NOT NULL,
    valor_pagamento NUMERIC(12, 2) NOT NULL,
    CONSTRAINT pk_pagamentos PRIMARY KEY (order_id, sequencia_pagamento),
    CONSTRAINT fk_pagamentos_pedidos
        FOREIGN KEY (order_id) REFERENCES analytics.pedidos(order_id)
);

INSERT INTO analytics.pagamentos (
    order_id,
    sequencia_pagamento,
    tipo_pagamento,
    quantidade_parcelas,
    valor_pagamento
)
SELECT
    TRIM(order_id),
    NULLIF(TRIM(payment_sequential), '')::INTEGER,
    LOWER(TRIM(payment_type)),
    NULLIF(TRIM(payment_installments), '')::INTEGER,
    NULLIF(TRIM(payment_value), '')::NUMERIC(12, 2)
FROM staging.pagamentos
ON CONFLICT (order_id, sequencia_pagamento) DO NOTHING;

-- Contagens esperadas: 99.441; 99.441; 32.951; 112.650; 103.886.
SELECT
    (SELECT COUNT(*) FROM analytics.clientes) AS clientes,
    (SELECT COUNT(*) FROM analytics.pedidos) AS pedidos,
    (SELECT COUNT(*) FROM analytics.produtos) AS produtos,
    (SELECT COUNT(*) FROM analytics.itens_pedido) AS itens,
    (SELECT COUNT(*) FROM analytics.pagamentos) AS pagamentos;

-- As três verificações devem retornar zero.
SELECT
    COUNT(*) FILTER (WHERE p.order_id IS NULL) AS itens_sem_pedido,
    COUNT(*) FILTER (WHERE pr.product_id IS NULL) AS itens_sem_produto
FROM analytics.itens_pedido AS i
LEFT JOIN analytics.pedidos AS p ON i.order_id = p.order_id
LEFT JOIN analytics.produtos AS pr ON i.product_id = pr.product_id;

SELECT
    COUNT(*) FILTER (WHERE p.order_id IS NULL) AS pagamentos_sem_pedido
FROM analytics.pagamentos AS pg
LEFT JOIN analytics.pedidos AS p ON pg.order_id = p.order_id;

