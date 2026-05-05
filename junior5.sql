CREATE TABLE IF NOT EXISTS estoque (
    id_estoque INT PRIMARY KEY AUTO_INCREMENT,
    id_produto INT NOT NULL,
    quantidade_disponivel INT NOT NULL,
    quantidade_reservada INT NOT NULL,
    quantidade_minima INT NOT NULL,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (id_produto) REFERENCES produto(id_produto) 
);
-- tabela de estoque criada acima


CREATE TABLE IF NOT EXISTS movimento_estoque (
    id_movimento INT PRIMARY KEY AUTO_INCREMENT,
    id_estoque INT NOT NULL,
    id_item_pedido INT NOT NULL,
    tipo_movimento ENUM('entrada', 'saida') NOT NULL,
    quantidade INT NOT NULL, 
    data_movimento TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    observacao TEXT,
    origem_movimento ENUM('compra', 'venda', 'ajuste') NOT NULL,

    FOREIGN KEY (id_estoque) REFERENCES estoque(id_estoque),
    FOREIGN KEY (id_usuario_responsavel) REFERENCES usuario(id_usuario),
    FOREIGN KEY (id_item_pedido) REFERENCES item_pedido(id_item_pedido)
);

-- tabela de movimento de estoque criada acima

CREATE TABLE IF NOT EXISTS entrega_expedicao (
    id_entrega INT PRIMARY KEY AUTO_INCREMENT,
    id_pedido INT NOT NULL,
    status_entrega ENUM('pendente', 'em_transito', 'entregue', 'cancelada') NOT NULL,
    transportadora VARCHAR(255) NOT NULL,
    codigo_rastreamento VARCHAR(255) UNIQUE NOT NULL,


)