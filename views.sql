-- ============================================================
-- LojaRápida · Views (relatórios recorrentes pedidos pelo PDF)
-- ============================================================
-- 1. pedidos_em_aberto    → time de operações
-- 2. desempenho_catalogo  → time comercial
-- ============================================================

DROP VIEW IF EXISTS pedidos_em_aberto;
DROP VIEW IF EXISTS desempenho_catalogo;


-- ============================================================
-- VIEW 1 · pedidos_em_aberto
-- ------------------------------------------------------------
-- "Em aberto" = pedidos que ainda NÃO foram finalizados.
-- Critério: status NÃO está em (entregue, cancelado, devolvido).
-- Mostra: identificador, nome do cliente, valor total, status atual
-- e há quantas horas o pedido está nesse status (calculado a partir
-- do último alterado_em em historico_status).
-- Ordem: dos mais antigos para os mais recentes.
-- ============================================================
CREATE OR REPLACE VIEW pedidos_em_aberto AS
WITH ultimo_status AS (
    -- Para cada pedido, pega a última transição registrada
    SELECT DISTINCT ON (pedido_id)
        pedido_id,
        alterado_em
    FROM historico_status
    ORDER BY pedido_id, alterado_em DESC
)
SELECT
    pe.id_pedido                                                          AS pedido,
    cl.nome                                                               AS cliente,
    pe.valor_total,
    pe.status,
    ROUND(EXTRACT(EPOCH FROM (NOW() - us.alterado_em)) / 3600.0, 1)       AS horas_no_status
FROM pedidos pe
INNER JOIN cliente cl       ON cl.id_cliente = pe.id_cliente
INNER JOIN ultimo_status us ON us.pedido_id  = pe.id_pedido
WHERE pe.status NOT IN ('entregue', 'cancelado', 'devolvido')
ORDER BY us.alterado_em ASC;  -- dos mais antigos para os mais recentes


-- ============================================================
-- VIEW 2 · desempenho_catalogo
-- ------------------------------------------------------------
-- Performance dos produtos ATIVOS no MÊS CORRENTE.
-- Considera apenas vendas com pagamento aprovado.
-- Classificação:
--   destaque  → top 20% em unidades vendidas (entre os que venderam)
--   regular   → demais que venderam algo
--   parado    → sem nenhuma venda no mês
-- O top 20% é calculado via NTILE(5): quintil 1 = top 20%.
-- ============================================================
CREATE OR REPLACE VIEW desempenho_catalogo AS
WITH vendas_mes AS (
    SELECT
        pr.id_produto,
        pr.nome,
        pr.quantidade_estoque                                AS estoque,
        COALESCE(SUM(ip.quantidade), 0)                      AS unidades_vendidas,
        COALESCE(SUM(ip.quantidade * ip.preco_unitario), 0)  AS receita
    FROM produtos pr
    LEFT JOIN itens_pedido ip ON ip.produto_id = pr.id_produto
    LEFT JOIN pedidos pe
           ON pe.id_pedido = ip.pedido_id
          AND pe.data_criacao >= DATE_TRUNC('month', NOW())
    LEFT JOIN pagamentos pg
           ON pg.pedido_id = pe.id_pedido
          AND pg.status = 'aprovado'
    WHERE pr.status = 'ativo'
    GROUP BY pr.id_produto, pr.nome, pr.quantidade_estoque
),
ranqueado AS (
    -- Divide em 5 grupos iguais por unidades vendidas (apenas quem vendeu).
    -- Quintil 1 = top 20%.
    SELECT
        id_produto,
        NTILE(5) OVER (ORDER BY unidades_vendidas DESC) AS quintil
    FROM vendas_mes
    WHERE unidades_vendidas > 0
)
SELECT
    v.id_produto                          AS codigo,
    v.nome,
    v.estoque,
    v.unidades_vendidas,
    ROUND(v.receita::numeric, 2)          AS receita,
    CASE
        WHEN v.unidades_vendidas = 0 THEN 'parado'
        WHEN r.quintil = 1            THEN 'destaque'
        ELSE                                'regular'
    END                                   AS classificacao
FROM vendas_mes v
LEFT JOIN ranqueado r ON r.id_produto = v.id_produto
ORDER BY v.unidades_vendidas DESC, v.nome;
