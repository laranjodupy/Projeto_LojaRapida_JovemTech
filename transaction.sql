-- ============================================================
-- LojaRápida · Transaction obrigatória (PDF — Cenário de transaction)
-- ============================================================
-- O PDF exige que ao confirmar pagamento de um pedido, TRÊS operações
-- aconteçam de forma atômica:
--   1) status do pedido vira 'pago'
--   2) registro de pagamento aprovado é inserido
--   3) estoque dos produtos do pedido é decrementado
-- + (extra do nosso modelo) registra a transição em historico_status.
--
-- Se QUALQUER UMA dessas operações falhar (ex.: estoque insuficiente),
-- nenhuma pode persistir. Isso é garantido pelo BEGIN/COMMIT do Postgres
-- combinado com o CHECK (quantidade_estoque >= 0) na tabela produtos.
-- ============================================================


-- ============================================================
-- PARTE 1 · Descobrir um pedido elegível pra teste
-- ------------------------------------------------------------
-- Roda esse SELECT antes pra escolher um pedido que:
--   - está com status 'aguardando pagamento'
--   - tem 2 ou mais itens (exigência do PDF)
-- ============================================================
SELECT
    pe.id_pedido,
    cl.nome             AS cliente,
    pe.valor_total,
    COUNT(ip.id_item)   AS qtd_itens
FROM pedidos pe
INNER JOIN cliente cl       ON cl.id_cliente = pe.id_cliente
INNER JOIN itens_pedido ip  ON ip.pedido_id  = pe.id_pedido
WHERE pe.status = 'aguardando pagamento'
GROUP BY pe.id_pedido, cl.nome, pe.valor_total
HAVING COUNT(ip.id_item) >= 2
ORDER BY pe.id_pedido
LIMIT 5;


-- ============================================================
-- PARTE 2 · Caso de SUCESSO (BEGIN/COMMIT)
-- ------------------------------------------------------------
-- Pedido escolhido: id 75 (Eduardo Teixeira, R$ 25.20, 2 itens — produtos 4 e 14).
-- Substitua os IDs se necessário (rode a PARTE 1 antes pra confirmar).
-- ============================================================

-- Snapshot ANTES (rodar separadamente pra ver o estado original)
SELECT
    'antes' AS momento,
    (SELECT status                FROM pedidos      WHERE id_pedido  = 75) AS status_pedido,
    (SELECT COUNT(*)              FROM pagamentos   WHERE pedido_id  = 75) AS qtd_pagamentos,
    (SELECT COUNT(*)              FROM historico_status WHERE pedido_id = 75) AS qtd_historico,
    (SELECT quantidade_estoque    FROM produtos     WHERE id_produto = 4)  AS estoque_p4,
    (SELECT quantidade_estoque    FROM produtos     WHERE id_produto = 14) AS estoque_p14;

-- Transaction
BEGIN;

-- 1) Status do pedido vira 'pago'
UPDATE pedidos
SET status = 'pago',
    atualizado_em = NOW()
WHERE id_pedido = 75
  AND status = 'aguardando pagamento';   -- defesa contra dupla execução

-- 2) Registra pagamento aprovado
INSERT INTO pagamentos (id_pagamento, pedido_id, descricao, metodo, valor, data_pagamento, status)
SELECT
    (SELECT COALESCE(MAX(id_pagamento), 0) + 1 FROM pagamentos),
    id_pedido,
    'Pagamento aprovado do pedido #' || id_pedido,
    'pix',
    valor_total,
    NOW(),
    'aprovado'
FROM pedidos WHERE id_pedido = 75;

-- 3) Decrementa estoque de cada produto do pedido
-- Se algum estoque for insuficiente, o CHECK (quantidade_estoque >= 0)
-- aborta automaticamente e o COMMIT vira ROLLBACK.
UPDATE produtos pr
SET quantidade_estoque = pr.quantidade_estoque - ip.quantidade
FROM itens_pedido ip
WHERE ip.produto_id = pr.id_produto
  AND ip.pedido_id = 75;

-- 4) Registra a transição no histórico
INSERT INTO historico_status (pedido_id, status_anterior, status_novo, alterado_em, usuario_responsavel)
VALUES (75, 'aguardando pagamento', 'pago', NOW(), 'sistema');

COMMIT;

-- Snapshot DEPOIS — deve mostrar status 'pago', +1 pagamento, +1 histórico, estoques diminuídos
SELECT
    'depois' AS momento,
    (SELECT status                FROM pedidos      WHERE id_pedido  = 75) AS status_pedido,
    (SELECT COUNT(*)              FROM pagamentos   WHERE pedido_id  = 75) AS qtd_pagamentos,
    (SELECT COUNT(*)              FROM historico_status WHERE pedido_id = 75) AS qtd_historico,
    (SELECT quantidade_estoque    FROM produtos     WHERE id_produto = 4)  AS estoque_p4,
    (SELECT quantidade_estoque    FROM produtos     WHERE id_produto = 14) AS estoque_p14;


-- ============================================================
-- PARTE 3 · Caso de FALHA com ROLLBACK forçado
-- ------------------------------------------------------------
-- Demonstra atomicidade: se UMA operação falhar, TODAS são desfeitas,
-- mesmo as que individualmente teriam funcionado.
--
-- Estratégia: forçar quantidade_estoque negativo no UPDATE final.
-- O CHECK constraint do banco aborta a transação inteira.
-- ============================================================

-- Pedido escolhido: id 74 (Patrícia Nunes, aguardando pagamento, 1+ itens)
-- Snapshot ANTES
SELECT
    'antes_falha' AS momento,
    (SELECT status                FROM pedidos      WHERE id_pedido  = 74) AS status_pedido,
    (SELECT COUNT(*)              FROM pagamentos   WHERE pedido_id  = 74) AS qtd_pagamentos,
    (SELECT quantidade_estoque    FROM produtos     WHERE id_produto = 14) AS estoque_p14;

-- Transaction que VAI FALHAR de propósito
BEGIN;

-- 1) Status (vai dar certo)
UPDATE pedidos
SET status = 'pago'
WHERE id_pedido = 74 AND status = 'aguardando pagamento';

-- 2) Pagamento (vai dar certo)
INSERT INTO pagamentos (id_pagamento, pedido_id, descricao, metodo, valor, data_pagamento, status)
SELECT
    (SELECT COALESCE(MAX(id_pagamento), 0) + 1 FROM pagamentos),
    id_pedido,
    'Pagamento (vai falhar) do pedido #' || id_pedido,
    'pix',
    valor_total,
    NOW(),
    'aprovado'
FROM pedidos WHERE id_pedido = 74;

-- 3) DECREMENTO PROPOSITALMENTE INVÁLIDO
-- Tira 99999 do estoque do produto 14 → quantidade_estoque viraria negativo.
-- O CHECK (quantidade_estoque >= 0) aborta a transação aqui.
UPDATE produtos
SET quantidade_estoque = quantidade_estoque - 99999
WHERE id_produto = 14;
-- Postgres aborta com:
--   ERROR: new row for relation "produtos" violates check constraint "produtos_quantidade_estoque_check"

-- O COMMIT abaixo nunca executa — a transação já está em estado de erro.
ROLLBACK;

-- Snapshot DEPOIS — deve estar IDÊNTICO ao 'antes_falha':
-- status continua 'aguardando pagamento', sem novo pagamento, estoque intacto.
SELECT
    'depois_falha' AS momento,
    (SELECT status                FROM pedidos      WHERE id_pedido  = 74) AS status_pedido,
    (SELECT COUNT(*)              FROM pagamentos   WHERE pedido_id  = 74) AS qtd_pagamentos,
    (SELECT quantidade_estoque    FROM produtos     WHERE id_produto = 14) AS estoque_p14;


-- ============================================================
-- PARTE 4 · Versão production-ready como FUNCTION (bonus)
-- ------------------------------------------------------------
-- Em produção, esse fluxo viraria uma stored procedure encapsulando
-- a transação. Demonstra maturidade do modelo na defesa.
--
-- Uso: SELECT * FROM processar_pagamento_pedido(<id>, 'pix');
-- ============================================================
CREATE OR REPLACE FUNCTION processar_pagamento_pedido(
    p_pedido_id INT,
    p_metodo    VARCHAR
) RETURNS TABLE (
    pedido_id      INT,
    status_novo    VARCHAR,
    valor_pago     DECIMAL,
    itens_baixados INT
) AS $$
DECLARE
    v_status_atual VARCHAR;
    v_valor_total  DECIMAL(10,2);
    v_qtd_itens    INT;
BEGIN
    -- Lock pessimista no pedido (evita dupla execução concorrente)
    SELECT status, valor_total
    INTO v_status_atual, v_valor_total
    FROM pedidos
    WHERE id_pedido = p_pedido_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido % não encontrado', p_pedido_id;
    END IF;

    IF v_status_atual <> 'aguardando pagamento' THEN
        RAISE EXCEPTION 'Pedido % não está aguardando pagamento (status: %)', p_pedido_id, v_status_atual;
    END IF;

    -- 1) status -> pago
    UPDATE pedidos SET status = 'pago', atualizado_em = NOW() WHERE id_pedido = p_pedido_id;

    -- 2) pagamento aprovado
    INSERT INTO pagamentos (id_pagamento, pedido_id, descricao, metodo, valor, data_pagamento, status)
    VALUES (
        (SELECT COALESCE(MAX(id_pagamento), 0) + 1 FROM pagamentos),
        p_pedido_id,
        'Pagamento aprovado do pedido #' || p_pedido_id,
        p_metodo,
        v_valor_total,
        NOW(),
        'aprovado'
    );

    -- 3) baixa de estoque (CHECK aborta automaticamente se ficar negativo)
    UPDATE produtos pr
    SET quantidade_estoque = pr.quantidade_estoque - ip.quantidade
    FROM itens_pedido ip
    WHERE ip.produto_id = pr.id_produto
      AND ip.pedido_id = p_pedido_id;

    GET DIAGNOSTICS v_qtd_itens = ROW_COUNT;

    -- 4) histórico
    INSERT INTO historico_status (pedido_id, status_anterior, status_novo, alterado_em, usuario_responsavel)
    VALUES (p_pedido_id, 'aguardando pagamento', 'pago', NOW(), 'sistema');

    RETURN QUERY SELECT p_pedido_id, 'pago'::VARCHAR, v_valor_total, v_qtd_itens;
END;
$$ LANGUAGE plpgsql;

-- Como usar a função:
--   SELECT * FROM processar_pagamento_pedido(75, 'cartao');
--
-- Como testar a falha pela função:
--   1. UPDATE produtos SET quantidade_estoque = 0 WHERE id_produto = X;  -- onde X é um produto do pedido
--   2. SELECT * FROM processar_pagamento_pedido(Y, 'pix');               -- Y é pedido aguardando
--   → ERROR + ROLLBACK automático. Status do pedido permanece intacto.
