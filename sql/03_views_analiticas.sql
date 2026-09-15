/*
Etapa 3: views analíticas

As agregações por pedido evitam multiplicação de valores ao combinar
pedidos com vários itens e vários registros de pagamento.
*/

CREATE OR REPLACE VIEW analytics.pagamentos_por_pedido AS
SELECT
    order_id,
    COUNT(*) AS quantidade_registros_pagamento,
    COUNT(DISTINCT tipo_pagamento) AS quantidade_formas_pagamento,
    SUM(valor_pagamento)::NUMERIC(14, 2) AS valor_total_pago,
    MAX(quantidade_parcelas) AS maior_quantidade_parcelas
FROM analytics.pagamentos
GROUP BY order_id;

CREATE OR REPLACE VIEW analytics.itens_por_pedido AS
SELECT
    order_id,
    COUNT(*) AS quantidade_itens,
    COUNT(DISTINCT product_id) AS quantidade_produtos_distintos,
    COUNT(DISTINCT seller_id) AS quantidade_vendedores,
    SUM(preco)::NUMERIC(14, 2) AS valor_produtos,
    SUM(frete)::NUMERIC(14, 2) AS valor_frete,
    SUM(preco + frete)::NUMERIC(14, 2) AS valor_total_itens
FROM analytics.itens_pedido
GROUP BY order_id;

CREATE OR REPLACE VIEW analytics.base_pedidos AS
SELECT
    p.order_id,
    p.customer_id,
    c.customer_unique_id,
    c.cidade,
    c.estado,
    p.status_pedido,
    p.data_compra,
    p.data_aprovacao,
    p.data_envio_transportadora,
    p.data_entrega_cliente,
    p.data_estimada_entrega,
    i.quantidade_itens,
    i.quantidade_produtos_distintos,
    i.quantidade_vendedores,
    i.valor_produtos,
    i.valor_frete,
    i.valor_total_itens,
    pg.quantidade_registros_pagamento,
    pg.quantidade_formas_pagamento,
    pg.maior_quantidade_parcelas,
    pg.valor_total_pago
FROM analytics.pedidos AS p
INNER JOIN analytics.clientes AS c ON p.customer_id = c.customer_id
LEFT JOIN analytics.itens_por_pedido AS i ON p.order_id = i.order_id
LEFT JOIN analytics.pagamentos_por_pedido AS pg ON p.order_id = pg.order_id;

CREATE OR REPLACE VIEW analytics.resumo_clientes AS
WITH data_referencia AS (
    SELECT MAX(data_compra)::DATE AS ultima_data_base
    FROM analytics.base_pedidos
    WHERE status_pedido = 'delivered'
      AND valor_total_pago IS NOT NULL
)
SELECT
    b.customer_unique_id,
    MIN(b.data_compra)::DATE AS primeira_compra,
    MAX(b.data_compra)::DATE AS ultima_compra,
    d.ultima_data_base AS data_referencia,
    d.ultima_data_base - MAX(b.data_compra)::DATE AS dias_sem_comprar,
    COUNT(*) AS quantidade_pedidos,
    ROUND(SUM(b.valor_total_pago), 2) AS valor_acumulado,
    ROUND(AVG(b.valor_total_pago), 2) AS ticket_medio_cliente
FROM analytics.base_pedidos AS b
CROSS JOIN data_referencia AS d
WHERE b.status_pedido = 'delivered'
  AND b.valor_total_pago IS NOT NULL
GROUP BY b.customer_unique_id, d.ultima_data_base;

CREATE OR REPLACE VIEW analytics.segmentacao_clientes AS
SELECT
    customer_unique_id,
    primeira_compra,
    ultima_compra,
    data_referencia,
    dias_sem_comprar,
    quantidade_pedidos,
    valor_acumulado,
    ticket_medio_cliente,
    CASE
        WHEN dias_sem_comprar <= 90 THEN 'ativo'
        WHEN dias_sem_comprar <= 180 THEN 'em_risco'
        ELSE 'inativo'
    END AS segmento_retencao
FROM analytics.resumo_clientes;

CREATE OR REPLACE VIEW analytics.rfm_clientes AS
WITH pontuacao_inicial AS (
    SELECT
        r.*,
        CASE
            WHEN dias_sem_comprar <= 30 THEN 5
            WHEN dias_sem_comprar <= 60 THEN 4
            WHEN dias_sem_comprar <= 90 THEN 3
            WHEN dias_sem_comprar <= 180 THEN 2
            ELSE 1
        END AS nota_recencia,
        CASE
            WHEN quantidade_pedidos >= 5 THEN 5
            WHEN quantidade_pedidos = 4 THEN 4
            WHEN quantidade_pedidos = 3 THEN 3
            WHEN quantidade_pedidos = 2 THEN 2
            ELSE 1
        END AS nota_frequencia,
        NTILE(5) OVER (ORDER BY valor_acumulado) AS nota_monetaria
    FROM analytics.resumo_clientes AS r
)
SELECT
    p.*,
    CONCAT(nota_recencia, nota_frequencia, nota_monetaria) AS codigo_rfm,
    CASE
        WHEN nota_recencia >= 4
         AND nota_frequencia >= 4
         AND nota_monetaria >= 4 THEN 'campeoes'
        WHEN nota_recencia >= 3
         AND nota_frequencia >= 3 THEN 'clientes_fieis'
        WHEN nota_recencia <= 2
         AND (nota_frequencia >= 2 OR nota_monetaria >= 4)
            THEN 'em_risco_valiosos'
        WHEN nota_recencia >= 4
         AND nota_frequencia = 1 THEN 'novos_promissores'
        WHEN nota_recencia >= 3
         AND nota_monetaria >= 4 THEN 'alto_valor_recente'
        WHEN nota_recencia <= 2
         AND nota_frequencia = 1 THEN 'hibernando'
        ELSE 'clientes_regulares'
    END AS segmento_rfm
FROM pontuacao_inicial AS p;

-- Todas as comparações devem mostrar uma linha por entidade.
SELECT COUNT(*) AS registros, COUNT(DISTINCT order_id) AS pedidos_distintos
FROM analytics.base_pedidos;

SELECT COUNT(*) AS registros, COUNT(DISTINCT customer_unique_id) AS clientes_distintos
FROM analytics.resumo_clientes;

SELECT COUNT(*) AS registros, COUNT(DISTINCT customer_unique_id) AS clientes_distintos
FROM analytics.rfm_clientes;

