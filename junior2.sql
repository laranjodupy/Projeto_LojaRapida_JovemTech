
*Modelo de tabelas – Sistema de Vendas*

*1. cliente*

* id_cliente *(PK)*
* nome_razao_social
* cpf_cnpj
* email
* telefone
* status
* data_cadastro

*2. endereco*

* id_endereco *(PK)*
* id_cliente *(FK)*
* cep
* logradouro
* numero
* complemento
* bairro
* cidade
* estado
* pais
* tipo_endereco
* principal
* status

*3. categoria_produto*

* id_categoria *(PK)*
* id_categoria_pai *(FK)*
* nome
* descricao
* status

*4. produto*

* id_produto *(PK)*
* id_categoria *(FK)*
* codigo
* sku *(numero do codigo de barras)*
* nome
* descricao
* preco_venda
* status
* data_cadastro

*5. estoque*

* id_estoque *(PK)*
* id_produto *(FK)*
* quantidade_disponivel
* quantidade_reservada
* quantidade_minima
* data_ultima_atualizacao

*6. movimento_estoque*

* id_movimento_estoque *(PK)*
* id_estoque *(FK)*
* id_usuario_responsavel *(FK)*
* id_item_pedido *(FK)*
* tipo_movimento
* quantidade
* data_movimento
* observacao
* origem

*7. pedido*

* id_pedido *(PK)*
* id_cliente *(FK)*
* id_endereco_entrega *(FK)*
* id_endereco_cobranca *(FK)*
* numero_pedido
* data_pedido
* observacao
* frete
* status_atual

*8. item_pedido*

* id_item_pedido *(PK)*
* id_pedido *(FK)*
* id_produto *(FK)*
* quantidade
* preco_unitario
* desconto_item
* observacao_item

*9. pagamento*

* id_pagamento *(PK)*
* id_pedido *(FK)*
* id_forma_pagamento *(FK)*
* valor
* data_pagamento
* status_pagamento
* parcela
* transacao_externa_id

*10. forma_pagamento*

* id_forma_pagamento *(PK)*
* nome
* descricao
* ativo

*11. entrega_expedicao*

* id_entrega *(PK)*
* id_pedido *(FK)*
* status_entrega
* modalidade_envio
* transportadora
* codigo_rastreamento
* data_postagem
* data_prevista_entrega
* data_entrega_real

*12. status_pedido*

* id_status_pedido *(PK)*
* nome
* descricao
* ordem_fluxo
* ativo

*13. historico_status*

* id_historico_status *(PK)*
* id_pedido *(FK)*
* id_status_pedido *(FK)*
* id_usuario_responsavel *(FK)*
* id_status_anterior *(FK)*
* data_alteracao
* observacao

*14. cupom_desconto*

* id_cupom *(PK)*
* codigo
* descricao
* tipo_desconto
* valor_desconto
* percentual_desconto
* data_inicio
* data_fim
* valor_minimo_pedido
* limite_uso_total
* limite_uso_por_cliente
* status

*15. cupom_uso*

* id_cupom_uso *(PK)*
* id_cupom *(FK)*
* id_pedido *(FK)*
* id_cliente *(FK)*
* data_uso
* valor_descontado
* status_uso

*16. usuario_responsavel*

* id_usuario_responsavel *(PK)*
* nome
* email
* perfil
* ativo

*17. log_alteracao*

* id_log_alteracao *(PK)*
* id_usuario_responsavel *(FK)*
* entidade_afetada
* id_registro_afetado
* campo_alterado
* valor_antigo
* valor_novo
* data_alteracao
* acao

Quais produtos estão com estoque abaixo de 10 unidades? Mostre o código, o nome, a
categoria e a quantidade atual. Ordene do produto com menos estoque para o com mais.
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
    SELECT
    DATE(pg.data_pagamento) AS data,
    SUM(pg.valor) AS faturamento_total
FROM pagamento pg
WHERE pg.status_pagamento = 'aprovado' AND pg.data_pagamento >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY data
ORDER BY DATE(pg.data_pagamento) DESC;
---------------------------------------------------------
3. Quais são os 10 produtos mais vendidos em quantidade de unidades no último mês?




3. Quais são os 10 produtos mais vendidos em quantidade de unidades no último mês?
Mostre o nome do produto, a categoria e o total vendido.