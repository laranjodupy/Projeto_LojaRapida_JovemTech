CREATE OR REPLACE VIEW pedidos_em_aberto as SELECT p.id_pedido, c.nome, p.valor_total
FROM pedidos p   
INNER JOIN pagamentos pg ON p.id_pedido = pg.pedido_id
INNER JOIN status
WHERE pg.status_pagamento = 'aprovado' AND p.status IN ('aguardando pagamento', 'processando', 'enviado');