/*
Etapa 5: consultas compactas para o resumo executivo e dashboard.
*/

-- Indicadores gerais.
WITH pedidos_validos AS (
    SELECT *
    FROM analytics.base_pedidos
    WHERE status_pedido = 'delivered'
      AND valor_total_pago IS NOT NULL
),
indicadores_pedidos AS (
    SELECT
        MIN(data_compra)::DATE AS inicio_periodo,
        MAX(data_compra)::DATE AS fim_periodo,
        COUNT(*) AS pedidos_entregues,
        COUNT(DISTINCT customer_unique_id) AS clientes_unicos,
        SUM(valor_total_pago) AS valor_total_recebido,
        AVG(valor_total_pago) AS ticket_medio,
        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY valor_total_pago) AS ticket_mediano
    FROM pedidos_validos
),
indicadores_clientes AS (
    SELECT
        COUNT(*) FILTER (WHERE quantidade_pedidos = 1) AS clientes_compra_unica,
        COUNT(*) FILTER (WHERE quantidade_pedidos >= 2) AS clientes_recorrentes,
        COUNT(*) AS total_clientes
    FROM analytics.resumo_clientes
)
SELECT
    p.inicio_periodo,
    p.fim_periodo,
    p.pedidos_entregues,
    p.clientes_unicos,
    ROUND(p.valor_total_recebido, 2) AS valor_total_recebido,
    ROUND(p.ticket_medio, 2) AS ticket_medio,
    ROUND(p.ticket_mediano::NUMERIC, 2) AS ticket_mediano,
    c.clientes_compra_unica,
    c.clientes_recorrentes,
    ROUND(
        c.clientes_recorrentes * 100.0 / NULLIF(c.total_clientes, 0),
        2
    ) AS taxa_recompra_percentual
FROM indicadores_pedidos AS p
CROSS JOIN indicadores_clientes AS c;

-- Evolução mensal.
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

-- Segmentos RFM.
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

