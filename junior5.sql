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


);

CREATE TABLE produtos (
    id_produto INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(150) NOT NULL,
    descricao TEXT,
    preco DECIMAL(10,2) NOT NULL,
    quantidade_estoque INT NOT NULL DEFAULT 0,
    status ENUM('ativo', 'inativo', 'sem estoque') NOT NULL DEFAULT 'ativo',
    id_categoria INT,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria)
);
CREATE TABLE cupons (
    id_cupom VARCHAR(50) PRIMARY KEY,
    tipo_desconto ENUM('percentual', 'valor_fixo') NOT NULL,
    valor_desconto DECIMAL(10,2) NOT NULL,
    data_validade DATE NOT NULL,
    uso_maximo INT NOT NULL DEFAULT 1,
    contagem_usos INT NOT NULL DEFAULT 0,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
CREATE TABLE pedidos (
    id_pedido INT PRIMARY KEY AUTO_INCREMENT,
    id_cliente INT,
    id_endereco INT,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    subtotal DECIMAL(10,2) NOT NULL,
    desconto_aplicado DECIMAL(10,2) DEFAULT 0.00,
    valor_total DECIMAL(10,2) NOT NULL,
    status ENUM(
        'aguardando pagamento',
        'pago',
        'em separacao',
        'enviado',
        'entregue',
        'cancelado',
        'devolvido'
    ) NOT NULL DEFAULT 'aguardando pagamento',
    codigo_cupom VARCHAR(50),
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (codigo_cupom) REFERENCES cupons(id_cupom),
    FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente),
    FOREIGN KEY (id_endereco) REFERENCES endereco(id_endereco)
);
CREATE TABLE categorias (
    id_categoria INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    descricao TEXT,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
CREATE TABLE itens_pedido (
    id_item INT PRIMARY KEY AUTO_INCREMENT,
    pedido_id INT NOT NULL,
    produto_id INT NOT NULL,
    quantidade INT NOT NULL,
    preco_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (quantidade * preco_unitario) STORED,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (pedido_id) REFERENCES pedidos(id_pedido),
    FOREIGN KEY (produto_id) REFERENCES produtos(id_produto)
);