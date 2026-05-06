-- Tabela cliente
CREATE TABLE IF NOT EXISTS cliente (
    id_cliente INT PRIMARY KEY,
    nome VARCHAR(50),
    razao_social VARCHAR(100),
    cpf VARCHAR(11) UNIQUE,
    cnpj VARCHAR(14) UNIQUE,
    email VARCHAR(100) UNIQUE,
    tipo VARCHAR(2) NOT NULL CHECK (tipo IN ('PF', 'PJ'))
);

-- Tabela endereco
CREATE TABLE IF NOT EXISTS endereco (
    id_endereco INT PRIMARY KEY,
    id_cliente INT,
    cep VARCHAR(10),
    logradouro VARCHAR(150),
    numero VARCHAR(10),
    complemento VARCHAR(100),
    bairro VARCHAR(100),
    cidade VARCHAR(100),
    estado VARCHAR(50),
    pais VARCHAR(50),
    tipo_endereco VARCHAR(20) NOT NULL CHECK (tipo_endereco IN ('residencial', 'comercial', 'entrega')),
    principal BOOLEAN DEFAULT FALSE,
    status BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente)
);

-- Tabela categorias
CREATE TABLE IF NOT EXISTS categorias (
    id_categoria INT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    descricao TEXT,
    status VARCHAR(20) CHECK (status IN ('Disponível', 'Sem Estoque'))
);

-- Tabela produtos
CREATE TABLE IF NOT EXISTS produtos (
    id_produto INT PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    descricao TEXT,
    preco DECIMAL(10,2) NOT NULL,
    quantidade_estoque INT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'ativo' CHECK (st|atus IN ('ativo', 'inativo', 'sem estoque')),
    id_categoria INT NOT NULL,
    data_cadastro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria)
);

-- Tabela estoque
CREATE TABLE IF NOT EXISTS estoque (
    id_estoque INT PRIMARY KEY,
    id_produto INT NOT NULL,
    quantidade_disponivel INT NOT NULL,
    quantidade_reservada INT NOT NULL,
    quantidade_minima INT NOT NULL,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_produto) REFERENCES produtos(id_produto)
);

-- Tabela cupons
CREATE TABLE IF NOT EXISTS cupons (
    id_cupom VARCHAR(50) PRIMARY KEY,
    tipo_desconto VARCHAR(20) NOT NULL CHECK (tipo_desconto IN ('percentual', 'valor_fixo')),
    valor_desconto DECIMAL(10,2) NOT NULL,
    data_validade DATE NOT NULL,
    uso_maximo INT NOT NULL DEFAULT 1,
    contagem_usos INT NOT NULL DEFAULT 0,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela pedidos
CREATE TABLE IF NOT EXISTS pedidos (
    id_pedido INT PRIMARY KEY,
    id_cliente INT,
    id_endereco INT,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    subtotal DECIMAL(10,2) NOT NULL,
    desconto_aplicado DECIMAL(10,2) DEFAULT 0.00,
    valor_total DECIMAL(10,2) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'aguardando pagamento'
        CHECK (status IN (
            'aguardando pagamento',
            'pago',
            'em separacao',
            'enviado',
            'entregue',
            'cancelado',
            'devolvido'
        )),
    codigo_cupom VARCHAR(50),
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (codigo_cupom) REFERENCES cupons(id_cupom),
    FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente),
    FOREIGN KEY (id_endereco) REFERENCES endereco(id_endereco)
);

-- Tabela itens_pedido
CREATE TABLE IF NOT EXISTS itens_pedido (
    id_item INT PRIMARY KEY,
    pedido_id INT NOT NULL,
    produto_id INT NOT NULL,
    quantidade INT NOT NULL,
    preco_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (quantidade * preco_unitario) STORED,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pedido_id) REFERENCES pedidos(id_pedido),
    FOREIGN KEY (produto_id) REFERENCES produtos(id_produto)
);

-- Tabela movimento_estoque (sem referência a usuário)
CREATE TABLE IF NOT EXISTS movimento_estoque (
    id_movimento INT PRIMARY KEY,
    id_estoque INT NOT NULL,
    id_item_pedido INT NOT NULL,
    tipo_movimento VARCHAR(10) NOT NULL CHECK (tipo_movimento IN ('entrada', 'saida')),
    quantidade INT NOT NULL,
    data_movimento TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    observacao TEXT,
    origem_movimento VARCHAR(10) NOT NULL CHECK (origem_movimento IN ('compra', 'venda', 'ajuste')),
    FOREIGN KEY (id_estoque) REFERENCES estoque(id_estoque),
    FOREIGN KEY (id_item_pedido) REFERENCES itens_pedido(id_item)
);

-- Tabela entrega_expedicao
CREATE TABLE IF NOT EXISTS entrega_expedicao (
    id_entrega INT PRIMARY KEY,
    id_pedido INT NOT NULL,
    status_entrega VARCHAR(20) NOT NULL
        CHECK (status_entrega IN ('pendente', 'em_transito', 'entregue', 'cancelada')),
    transportadora VARCHAR(255) NOT NULL,
    codigo_rastreamento VARCHAR(255) UNIQUE NOT NULL
);

-- Tabela pagamentos
CREATE TABLE IF NOT EXISTS pagamentos (
    id_pagamento INT PRIMARY KEY,
    pedido_id INT,
    descricao VARCHAR(255),
    metodo VARCHAR(10) CHECK (metodo IN ('cartao', 'pix', 'boleto')),
    valor DECIMAL(10,2),
    data_pagamento TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) CHECK (status IN ('aprovado', 'recusado', 'estornado')),

    FOREIGN KEY (pedido_id) REFERENCES pedidos(id_pedido)
);

-- Tabela status_pedido
CREATE TABLE IF NOT EXISTS status_pedido (
    id_status_pedido INT PRIMARY KEY,
    id_expedicao INT,
    id_pedido INT NOT NULL,
    situacao VARCHAR(50) NOT NULL,
    descricao VARCHAR(255),
    ordem_fluxo INT NOT NULL,
    ativo BOOLEAN DEFAULT TRUE,

    FOREIGN KEY (id_expedicao) REFERENCES entrega_expedicao(id_entrega),
    FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido)
);