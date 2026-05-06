-- ============================================================
-- LojaRápida · Queries de negócio (12 perguntas do PDF)
-- ============================================================
-- Cada query está identificada por comentário com o número da pergunta.
-- Para rodar uma de cada vez: selecione o bloco entre comentários.
-- ============================================================


-- ============================================================
-- Q1 — Quais produtos estão com estoque abaixo de 10 unidades?
-- Mostre o código, o nome, a categoria e a quantidade atual.
-- Ordene do produto com menos estoque para o com mais.
-- ============================================================
SELECT
    p.id_produto       AS codigo,
    p.nome             AS produto,
    c.nome             AS categoria,
    p.quantidade_estoque AS estoque_atual
FROM produtos p
INNER JOIN categorias c ON c.id_categoria = p.id_categoria
WHERE p.quantidade_estoque < 10
  AND p.status = 'ativo'   -- não faz sentido reportar reposição de produto inativo
ORDER BY p.quantidade_estoque ASC, p.nome ASC;


-- ============================================================
-- Q2 — Faturamento total por dia nos últimos 30 dias.
-- Considere apenas pedidos com pagamento aprovado.
-- Ordene da data mais recente para a mais antiga.
-- ============================================================
SELECT
    DATE(pg.data_pagamento)             AS dia,
    COUNT(DISTINCT pe.id_pedido)        AS qtd_pedidos,
    SUM(pe.valor_total)                 AS faturamento_total
FROM pedidos pe
INNER JOIN pagamentos pg
        ON pg.pedido_id = pe.id_pedido
       AND pg.status = 'aprovado'
WHERE pg.data_pagamento >= NOW() - INTERVAL '30 days'
GROUP BY DATE(pg.data_pagamento)
ORDER BY dia DESC;


-- ============================================================
-- Q3 — Top 10 produtos mais vendidos em quantidade no último mês.
-- Mostre o nome do produto, a categoria e o total vendido.
-- ============================================================
SELECT
    pr.nome                AS produto,
    c.nome                 AS categoria,
    SUM(ip.quantidade)     AS unidades_vendidas
FROM itens_pedido ip
INNER JOIN produtos pr   ON pr.id_produto = ip.produto_id
INNER JOIN categorias c  ON c.id_categoria = pr.id_categoria
INNER JOIN pedidos pe    ON pe.id_pedido = ip.pedido_id
INNER JOIN pagamentos pg ON pg.pedido_id = pe.id_pedido AND pg.status = 'aprovado'
WHERE pe.data_criacao >= NOW() - INTERVAL '30 days'
GROUP BY pr.id_produto, pr.nome, c.nome
ORDER BY unidades_vendidas DESC
LIMIT 10;


-- ============================================================
-- Q4 — Ticket médio por tipo de cliente (PF vs PJ).
-- Considere apenas pedidos com pagamento aprovado.
-- ============================================================
SELECT
    cl.tipo,
    COUNT(DISTINCT pe.id_pedido)              AS qtd_pedidos,
    ROUND(AVG(pe.valor_total)::numeric, 2)    AS ticket_medio,
    ROUND(SUM(pe.valor_total)::numeric, 2)    AS faturamento_total
FROM pedidos pe
INNER JOIN cliente cl     ON cl.id_cliente = pe.id_cliente
INNER JOIN pagamentos pg  ON pg.pedido_id = pe.id_pedido AND pg.status = 'aprovado'
GROUP BY cl.tipo
ORDER BY ticket_medio DESC;


-- ============================================================
-- Q5 — Cupons de desconto mais utilizados.
-- Mostre código, tipo, valor e contagem de usos.
-- Ordene do mais usado para o menos.
-- ============================================================
SELECT
    id_cupom         AS codigo,
    tipo_desconto,
    valor_desconto,
    contagem_usos
FROM cupons
WHERE contagem_usos > 0
ORDER BY contagem_usos DESC, id_cupom ASC;


-- ============================================================
-- Q6 — Clientes que fizeram MAIS de 3 pedidos no último mês.
-- Mostre o nome, o tipo e a contagem de pedidos.
-- ============================================================
SELECT
    cl.nome           AS cliente,
    cl.tipo,
    COUNT(pe.id_pedido) AS qtd_pedidos
FROM cliente cl
INNER JOIN pedidos pe ON pe.id_cliente = cl.id_cliente
WHERE pe.data_criacao >= NOW() - INTERVAL '30 days'
GROUP BY cl.id_cliente, cl.nome, cl.tipo
HAVING COUNT(pe.id_pedido) > 3
ORDER BY qtd_pedidos DESC, cl.nome;


-- ============================================================
-- Q7 — Valor total de pedidos cancelados por mês nos últimos 3 meses.
-- ============================================================
SELECT
    TO_CHAR(DATE_TRUNC('month', data_criacao), 'YYYY-MM') AS mes,
    COUNT(*)         AS qtd_cancelados,
    SUM(valor_total) AS valor_total_cancelado
FROM pedidos
WHERE status = 'cancelado'
  AND data_criacao >= DATE_TRUNC('month', NOW()) - INTERVAL '2 months'
GROUP BY DATE_TRUNC('month', data_criacao)
ORDER BY mes DESC;


-- ============================================================
-- Q8 — Produtos NUNCA comprados (não aparecem em nenhum item de pedido).
-- Mostre nome, categoria e data de cadastro.
-- ============================================================
SELECT
    pr.nome              AS produto,
    c.nome               AS categoria,
    pr.data_cadastro::date AS data_cadastro
FROM produtos pr
INNER JOIN categorias c ON c.id_categoria = pr.id_categoria
LEFT JOIN itens_pedido ip ON ip.produto_id = pr.id_produto
WHERE ip.id_item IS NULL
ORDER BY c.nome, pr.nome;


-- ============================================================
-- Q9 — Clientes que gastaram ACIMA da média no último mês.
-- Mostre nome, tipo e valor total. Ordem decrescente.
-- (Estruturado com CTE pra deixar a média explícita.)
-- ============================================================
WITH gastos_clientes AS (
    SELECT
        cl.id_cliente,
        cl.nome,
        cl.tipo,
        SUM(pe.valor_total) AS total_gasto
    FROM cliente cl
    INNER JOIN pedidos pe    ON pe.id_cliente = cl.id_cliente
    INNER JOIN pagamentos pg ON pg.pedido_id = pe.id_pedido AND pg.status = 'aprovado'
    WHERE pe.data_criacao >= NOW() - INTERVAL '30 days'
    GROUP BY cl.id_cliente, cl.nome, cl.tipo
),
media_geral AS (
    SELECT AVG(total_gasto) AS media FROM gastos_clientes
)
SELECT
    g.nome            AS cliente,
    g.tipo,
    ROUND(g.total_gasto::numeric, 2) AS total_gasto,
    ROUND((SELECT media FROM media_geral)::numeric, 2) AS media_geral
FROM gastos_clientes g
WHERE g.total_gasto > (SELECT media FROM media_geral)
ORDER BY g.total_gasto DESC;


-- ============================================================
-- Q10 — Tempo médio entre status "pago" e "enviado" por mês.
-- Self-join na tabela historico_status pra cruzar as duas transições.
-- ============================================================
WITH transicoes AS (
    SELECT
        h_pago.pedido_id,
        h_pago.alterado_em                          AS data_pago,
        h_enviado.alterado_em                       AS data_enviado,
        DATE_TRUNC('month', h_enviado.alterado_em)  AS mes
    FROM historico_status h_pago
    INNER JOIN historico_status h_enviado
            ON h_enviado.pedido_id = h_pago.pedido_id
           AND h_enviado.status_novo = 'enviado'
    WHERE h_pago.status_novo = 'pago'
)
SELECT
    TO_CHAR(mes, 'YYYY-MM')  AS mes,
    COUNT(*)                 AS qtd_pedidos,
    ROUND(AVG(EXTRACT(EPOCH FROM (data_enviado - data_pago)) / 3600.0)::numeric, 2) AS horas_medias,
    ROUND(AVG(EXTRACT(EPOCH FROM (data_enviado - data_pago)) / 86400.0)::numeric, 2) AS dias_medios
FROM transicoes
GROUP BY mes
ORDER BY mes DESC;


-- ============================================================
-- Q11 — Pedidos aguardando pagamento há MAIS de 2 dias.
-- Mostre identificador, nome do cliente, valor e data de criação.
-- ============================================================
SELECT
    pe.id_pedido       AS pedido,
    cl.nome            AS cliente,
    pe.valor_total,
    pe.data_criacao,
    ROUND(EXTRACT(EPOCH FROM (NOW() - pe.data_criacao)) / 86400.0, 1) AS dias_aguardando
FROM pedidos pe
INNER JOIN cliente cl ON cl.id_cliente = pe.id_cliente
WHERE pe.status = 'aguardando pagamento'
  AND pe.data_criacao < NOW() - INTERVAL '2 days'
ORDER BY pe.data_criacao ASC;


-- ============================================================
-- Q12 — Categoria de produto com MAIOR receita total no último mês.
-- (Mostra todas ranqueadas — fica fácil ver a top.)
-- ============================================================
SELECT
    c.nome AS categoria,
    SUM(ip.quantidade)                              AS unidades_vendidas,
    ROUND(SUM(ip.quantidade * ip.preco_unitario)::numeric, 2) AS receita
FROM itens_pedido ip
INNER JOIN produtos pr   ON pr.id_produto = ip.produto_id
INNER JOIN categorias c  ON c.id_categoria = pr.id_categoria
INNER JOIN pedidos pe    ON pe.id_pedido = ip.pedido_id
INNER JOIN pagamentos pg ON pg.pedido_id = pe.id_pedido AND pg.status = 'aprovado'
WHERE pe.data_criacao >= NOW() - INTERVAL '30 days'
GROUP BY c.id_categoria, c.nome
ORDER BY receita DESC;
