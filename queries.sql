select
    p.codigo AS codigo_produto,
    p.nome AS produto,
    c.categoria AS categoria_produto,
    e.quantidade_disponivel AS quantidade_atual
FROM produto p
INNER JOIN categoria_produto c
    ON c.id_categoria = p.id_categoria
INNER JOIN estoque e
    ON e.id_produto = p.id_produto
WHERE e.quantidade_disponivel < 10
ORDER BY e.quantidade_disponivel ASC, p.nome ASC;

Qual o faturamento total por dia nos últimos 30 dias? Considere apenas pedidos com
pagamento aprovado. Ordene da data mais recente para a mais antiga.
select
    DATE(pg.data_pagamento) AS data,
    SUM(pg.valor) AS faturamento_total
FROM pagamento pg
WHERE pg.status_pagamento = 'aprovado' AND pg.data_pagamento >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY data
ORDER BY DATE(pg.data_pagamento) DESC;