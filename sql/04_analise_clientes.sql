/*
Etapa 4: respostas às perguntas de negócio

Regra principal: somente pedidos entregues e com pagamento registrado.
Cliente é identificado por customer_unique_id.
*/

-- 1. Quantos clientes fizeram compras?
SELECT COUNT(DISTINCT customer_unique_id) AS clientes_com_compras
FROM analytics.base_pedidos
WHERE status_pedido = 'delivered'
  AND valor_total_pago IS NOT NULL;

-- 2. Qual é o valor total recebido e sua evolução mensal?
SELECT
    ROUND(SUM(valor_total_pago), 2) AS valor_total_recebido
FROM analytics.base_pedidos
WHERE status_pedido = 'delivered'
  AND valor_total_pago IS NOT NULL;

SELECT
    DATE_TRUNC('month', data_compra)::DATE AS mes,
    COUNT(*) AS pedidos_entregues,
    COUNT(DISTINCT customer_unique_id) AS clientes_unicos,
    ROUND(SUM(valor_total_pago), 2) AS valor_mensal_recebido,
    ROUND(AVG(valor_total_pago), 2) AS ticket_medio_mensal
FROM analytics.base_pedidos
WHERE status_pedido = 'delivered'
  AND valor_total_pago IS NOT NULL
GROUP BY DATE_TRUNC('month', data_compra)
ORDER BY mes;

-- 3. Qual é o ticket médio?
SELECT
    ROUND(AVG(valor_total_pago), 2) AS ticket_medio,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY valor_total_pago)::NUMERIC,
        2
    ) AS ticket_mediano
FROM analytics.base_pedidos
WHERE status_pedido = 'delivered'
  AND valor_total_pago IS NOT NULL;

-- 4. Quais clientes possuem maior valor acumulado?
SELECT
    customer_unique_id,
    quantidade_pedidos,
    valor_acumulado,
    ticket_medio_cliente,
    dias_sem_comprar
FROM analytics.resumo_clientes
ORDER BY valor_acumulado DESC, quantidade_pedidos DESC
LIMIT 10;

-- 5. Quais clientes compram com maior frequência?
SELECT
    customer_unique_id,
    quantidade_pedidos,
    valor_acumulado,
    ticket_medio_cliente,
    dias_sem_comprar
FROM analytics.resumo_clientes
ORDER BY quantidade_pedidos DESC, valor_acumulado DESC
LIMIT 10;

-- 6. Há quanto tempo cada cliente não compra?
SELECT
    customer_unique_id,
    ultima_compra,
    data_referencia,
    dias_sem_comprar,
    quantidade_pedidos,
    valor_acumulado
FROM analytics.resumo_clientes
ORDER BY dias_sem_comprar DESC, valor_acumulado DESC;

-- 7. Quantos clientes estão ativos, em risco ou inativos?
SELECT
    segmento_retencao,
    COUNT(*) AS quantidade_clientes,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentual_clientes,
    SUM(quantidade_pedidos) AS quantidade_pedidos,
    ROUND(SUM(valor_acumulado), 2) AS valor_acumulado_segmento
FROM analytics.segmentacao_clientes
GROUP BY segmento_retencao
ORDER BY
    CASE segmento_retencao
        WHEN 'ativo' THEN 1
        WHEN 'em_risco' THEN 2
        WHEN 'inativo' THEN 3
    END;

-- 8. Quais categorias são mais compradas por cada segmento?
WITH categorias_segmento AS (
    SELECT
        s.segmento_retencao,
        COALESCE(pr.categoria_original, 'sem_categoria') AS categoria,
        COUNT(*) AS quantidade_itens,
        COUNT(DISTINCT b.order_id) AS quantidade_pedidos,
        COUNT(DISTINCT b.customer_unique_id) AS quantidade_clientes,
        SUM(i.preco) AS valor_produtos
    FROM analytics.segmentacao_clientes AS s
    INNER JOIN analytics.base_pedidos AS b
        ON s.customer_unique_id = b.customer_unique_id
    INNER JOIN analytics.itens_pedido AS i ON b.order_id = i.order_id
    INNER JOIN analytics.produtos AS pr ON i.product_id = pr.product_id
    WHERE b.status_pedido = 'delivered'
      AND b.valor_total_pago IS NOT NULL
    GROUP BY
        s.segmento_retencao,
        COALESCE(pr.categoria_original, 'sem_categoria')
),
ranking AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY segmento_retencao
            ORDER BY quantidade_itens DESC, categoria
        ) AS posicao
    FROM categorias_segmento
)
SELECT
    segmento_retencao,
    posicao,
    categoria,
    quantidade_itens,
    quantidade_pedidos,
    quantidade_clientes,
    ROUND(valor_produtos, 2) AS valor_produtos
FROM ranking
WHERE posicao <= 5
ORDER BY
    CASE segmento_retencao
        WHEN 'ativo' THEN 1
        WHEN 'em_risco' THEN 2
        WHEN 'inativo' THEN 3
    END,
    posicao;

-- 9. Qual é a taxa de recompra?
SELECT
    COUNT(*) AS total_clientes,
    COUNT(*) FILTER (WHERE quantidade_pedidos = 1) AS clientes_compra_unica,
    COUNT(*) FILTER (WHERE quantidade_pedidos >= 2) AS clientes_recorrentes,
    ROUND(
        COUNT(*) FILTER (WHERE quantidade_pedidos >= 2) * 100.0
        / NULLIF(COUNT(*), 0),
        2
    ) AS taxa_recompra_percentual
FROM analytics.resumo_clientes;

-- 10. Como os clientes se distribuem nos segmentos RFM?
SELECT
    segmento_rfm,
    COUNT(*) AS quantidade_clientes,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentual_clientes,
    SUM(quantidade_pedidos) AS quantidade_pedidos,
    ROUND(SUM(valor_acumulado), 2) AS valor_total,
    ROUND(AVG(valor_acumulado), 2) AS valor_medio_cliente,
    ROUND(AVG(dias_sem_comprar), 2) AS recencia_media
FROM analytics.rfm_clientes
GROUP BY segmento_rfm
ORDER BY valor_total DESC;

