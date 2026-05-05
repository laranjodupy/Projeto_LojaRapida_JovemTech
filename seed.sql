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

-- Tabela forma_pagamento
CREATE TABLE IF NOT EXISTS forma_pagamento (
    id_forma_pagamento INT PRIMARY KEY,
    nome VARCHAR(50) NOT NULL,
    descricao VARCHAR(255),
    ativo BOOLEAN DEFAULT TRUE
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
    status VARCHAR(20) NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo', 'inativo', 'sem estoque')),
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
    metodo VARCHAR(10) CHECK (metodo IN ('cartao', 'pix', 'boleto')),
    valor DECIMAL(10,2),
    data_pagamento TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) CHECK (status IN ('aprovado', 'recusado', 'estornado')),
    FOREIGN KEY (pedido_id) REFERENCES pedidos(id_pedido)
);

-- Tabela status_pedido
CREATE TABLE IF NOT EXISTS status_pedido (
    id_status_pedido INT PRIMARY KEY,
    nome VARCHAR(50) NOT NULL,
    descricao VARCHAR(255),
    ordem_fluxo INT NOT NULL,
    ativo BOOLEAN DEFAULT TRUE
);


-- ============================================================
-- INSERTS PARA O BANCO DE DADOS DA LOJARÁPIDA
-- ============================================================

-- Status do pedido (catálogo)
INSERT INTO status_pedido (id_status_pedido, nome, descricao, ordem_fluxo, ativo) VALUES
(1, 'aguardando pagamento', 'Pedido aguardando confirmação de pagamento', 1, TRUE),
(2, 'pago', 'Pagamento confirmado', 2, TRUE),
(3, 'em separacao', 'Pedido em separação no estoque', 3, TRUE),
(4, 'enviado', 'Pedido enviado ao cliente', 4, TRUE),
(5, 'entregue', 'Pedido entregue ao destinatário', 5, TRUE),
(6, 'cancelado', 'Pedido cancelado', 6, TRUE),
(7, 'devolvido', 'Pedido devolvido pelo cliente', 7, TRUE);

-- Categorias (6)
INSERT INTO categorias (id_categoria, nome, descricao, status) VALUES
(1, 'Escrita', 'Canetas, lápis, marcadores', 'Disponível'),
(2, 'Papelaria', 'Papéis, cadernos, envelopes', 'Disponível'),
(3, 'Organização', 'Pastas, arquivos, organizadores', 'Disponível'),
(4, 'Tecnologia', 'Acessórios de informática, eletrônicos', 'Disponível'),
(5, 'Móveis', 'Cadeiras, mesas, estantes', 'Disponível'),
(6, 'Limpeza', 'Produtos de limpeza para escritório', 'Disponível');

-- Produtos (40, sendo 5 inativos/sem estoque)
INSERT INTO produtos (id_produto, nome, descricao, preco, quantidade_estoque, status, id_categoria, data_cadastro) VALUES
(1, 'Caneta Esferográfica Azul', 'Caneta azul ponta média', 2.50, 10, 'ativo', 1, '2026-03-01 08:00:00'),
(2, 'Caneta Esferográfica Preta', 'Caneta preta ponta fina', 2.50, 10, 'ativo', 1, '2026-03-01 08:00:00'),
(3, 'Lápis HB nº2', 'Lápis preto escolar', 1.80, 10, 'ativo', 1, '2026-03-01 08:00:00'),
(4, 'Marca-texto Amarelo', 'Marca-texto fluorescente', 3.20, 10, 'ativo', 1, '2026-03-01 08:00:00'),
(5, 'Borracha Branca', 'Borracha macia', 1.00, 10, 'ativo', 1, '2026-03-01 08:00:00'),
(6, 'Caneta Hidrográfica 12 cores', 'Estojo com 12 canetas', 12.00, 10, 'ativo', 1, '2026-03-01 08:00:00'),
(7, 'Lapiseira 0.7mm', 'Lapiseira técnica', 8.50, 10, 'ativo', 1, '2026-03-01 08:00:00'),
(8, 'Grafite 0.7mm 12 unidades', 'Refil de grafite', 4.00, 10, 'ativo', 1, '2026-03-01 08:00:00'),
(9, 'Resma Papel A4 500fl', 'Papel sulfite branco', 25.00, 10, 'ativo', 2, '2026-03-01 08:00:00'),
(10, 'Caderno Universitário 200fl', 'Caderno capa dura', 18.00, 10, 'ativo', 2, '2026-03-01 08:00:00'),
(11, 'Bloco de Notas Adesivas 100fl', 'Post-it colorido', 7.50, 10, 'ativo', 2, '2026-03-01 08:00:00'),
(12, 'Envelope Pardo A4 100un', 'Pacote com 100 envelopes', 15.00, 10, 'ativo', 2, '2026-03-01 08:00:00'),
(13, 'Papel Cartão Colorido 20fl', 'Papel cartão A4 sortido', 9.00, 10, 'ativo', 2, '2026-03-01 08:00:00'),
(14, 'Caderno de Desenho A3', 'Caderno para desenho', 22.00, 10, 'ativo', 2, '2026-03-01 08:00:00'),
(15, 'Papel Sulfite A4 100fl colorido', 'Papel colorido pastel', 12.00, 10, 'ativo', 2, '2026-03-01 08:00:00'),
(16, 'Pasta Catálogo 50 plásticos', 'Pasta para documentos', 20.00, 10, 'ativo', 3, '2026-03-01 08:00:00'),
(17, 'Arquivo Morto Papelão 10un', 'Caixas para arquivo', 35.00, 10, 'ativo', 3, '2026-03-01 08:00:00'),
(18, 'Organizador de Mesa 3 andares', 'Organizador de acrílico', 45.00, 10, 'ativo', 3, '2026-03-01 08:00:00'),
(19, 'Caixa Organizadora Plástica 30L', 'Caixa transparente', 30.00, 10, 'ativo', 3, '2026-03-01 08:00:00'),
(20, 'Porta Documentos 12 divisórias', 'Porta documentos expansível', 28.00, 10, 'ativo', 3, '2026-03-01 08:00:00'),
(21, 'Pasta Suspensa 50un', 'Pastas suspensas', 40.00, 10, 'ativo', 3, '2026-03-01 08:00:00'),
(22, 'Grampeador de Mesa', 'Grampeador metálico', 18.00, 10, 'ativo', 3, '2026-03-01 08:00:00'),
(23, 'Mouse Sem Fio', 'Mouse óptico USB', 55.00, 10, 'ativo', 4, '2026-03-01 08:00:00'),
(24, 'Teclado USB Slim', 'Teclado padrão ABNT2', 40.00, 10, 'ativo', 4, '2026-03-01 08:00:00'),
(25, 'Pen Drive 32GB', 'Memória USB 3.0', 35.00, 10, 'ativo', 4, '2026-03-01 08:00:00'),
(26, 'Adaptador USB-C para HDMI', 'Adaptador 4K', 65.00, 10, 'ativo', 4, '2026-03-01 08:00:00'),
(27, 'Fone de Ouvido Headset', 'Headset com microfone', 80.00, 10, 'ativo', 4, '2026-03-01 08:00:00'),
(28, 'Webcam HD 1080p', 'Webcam com autofoco', 120.00, 10, 'ativo', 4, '2026-03-01 08:00:00'),
(29, 'Hub USB 4 portas', 'Hub USB 3.0', 25.00, 10, 'ativo', 4, '2026-03-01 08:00:00'),
(30, 'Cadeira de Escritório Simples', 'Cadeira giratória', 250.00, 10, 'ativo', 5, '2026-03-01 08:00:00'),
(31, 'Mesa de Escritório 120cm', 'Mesa retangular', 180.00, 10, 'ativo', 5, '2026-03-01 08:00:00'),
(32, 'Estante de Aço 5 prateleiras', 'Estante para escritório', 300.00, 10, 'ativo', 5, '2026-03-01 08:00:00'),
(33, 'Suporte para Monitor', 'Suporte articulado', 90.00, 10, 'ativo', 5, '2026-03-01 08:00:00'),
(34, 'Luminária de Mesa LED', 'Luminária com braço flexível', 60.00, 10, 'ativo', 5, '2026-03-01 08:00:00'),
(35, 'Apoio para os Pés Ergonômico', 'Apoio ajustável', 75.00, 10, 'ativo', 5, '2026-03-01 08:00:00'),
(36, 'Desinfetante Multiuso 500ml', 'Limpeza geral', 8.00, 0, 'inativo', 6, '2026-03-01 08:00:00'),
(37, 'Álcool em Gel 200ml', 'Higienização', 5.00, 0, 'inativo', 6, '2026-03-01 08:00:00'),
(38, 'Detergente Líquido 500ml', 'Limpeza de superfícies', 4.00, 0, 'sem estoque', 6, '2026-03-01 08:00:00'),
(39, 'Limpa Vidros Spray', 'Limpa vidros 500ml', 6.50, 0, 'sem estoque', 6, '2026-03-01 08:00:00'),
(40, 'Sabonete Líquido 250ml', 'Sabonete para escritório', 7.00, 0, 'sem estoque', 6, '2026-03-01 08:00:00');

-- Clientes (30, mix PF e PJ)
INSERT INTO cliente (id_cliente, nome, razao_social, cpf, cnpj, email, tipo) VALUES
(1, 'João Silva', NULL, '12345678901', NULL, 'joao@email.com', 'PF'),
(2, 'Maria Souza', NULL, '23456789012', NULL, 'maria@email.com', 'PF'),
(3, 'Carlos Pereira', NULL, '34567890123', NULL, 'carlos@email.com', 'PF'),
(4, 'Ana Oliveira', NULL, '45678901234', NULL, 'ana@email.com', 'PF'),
(5, 'Paulo Santos', NULL, '56789012345', NULL, 'paulo@email.com', 'PF'),
(6, 'Fernanda Costa', NULL, '67890123456', NULL, 'fernanda@email.com', 'PF'),
(7, 'Ricardo Lima', NULL, '78901234567', NULL, 'ricardo@email.com', 'PF'),
(8, 'Juliana Alves', NULL, '89012345678', NULL, 'juliana@email.com', 'PF'),
(9, 'Marcos Rocha', NULL, '90123456789', NULL, 'marcos@email.com', 'PF'),
(10, 'Camila Martins', NULL, '01234567890', NULL, 'camila@email.com', 'PF'),
(11, 'Lucas Ferreira', NULL, '11234567891', NULL, 'lucas@email.com', 'PF'),
(12, 'Amanda Ramos', NULL, '21234567892', NULL, 'amanda@email.com', 'PF'),
(13, 'Bruno Cardoso', NULL, '31234567893', NULL, 'bruno@email.com', 'PF'),
(14, 'Patrícia Nunes', NULL, '41234567894', NULL, 'patricia@email.com', 'PF'),
(15, 'Eduardo Teixeira', NULL, '51234567895', NULL, 'eduardo@email.com', 'PF'),
(16, 'PapelMundo Ltda', 'PapelMundo Comércio de Papelaria Ltda', NULL, '12345678000190', 'contato@papelmundo.com', 'PJ'),
(17, 'OfficeTech SA', 'OfficeTech Soluções de Escritório SA', NULL, '23456789000101', 'vendas@officetech.com', 'PJ'),
(18, 'CleanWork ME', 'CleanWork Materiais de Limpeza ME', NULL, '34567890000112', 'clean@cleanwork.com', 'PJ'),
(19, 'Cia do Caderno', 'Cia do Caderno Livraria e Papelaria Ltda', NULL, '45678901000123', 'sac@ciadocaderno.com', 'PJ'),
(20, 'TechDesk Comércio', 'TechDesk Informática e Móveis Ltda', NULL, '56789012000134', 'comercial@techdesk.com', 'PJ'),
(21, 'Escritório Moderno', 'Escritório Moderno Artigos de Papelaria Ltda', NULL, '67890123000145', 'admin@escritoriomoderno.com', 'PJ'),
(22, 'Distribuidora Rápida', 'Distribuidora Rápida de Papéis Ltda', NULL, '78901234000156', 'distrib@rapida.com', 'PJ'),
(23, 'Casa do Office', 'Casa do Office Comércio de Móveis Ltda', NULL, '89012345000167', 'casa@officemoveis.com', 'PJ'),
(24, 'Premium Paper', 'Premium Paper Importação e Exportação Ltda', NULL, '90123456000178', 'premium@paper.com', 'PJ'),
(25, 'AllPrint Eireli', 'AllPrint Serviços de Impressão Eireli', NULL, '01234567000189', 'allprint@print.com', 'PJ'),
(26, 'MaxWork Comércio', 'MaxWork Materiais de Escritório Ltda', NULL, '11234568000190', 'max@maxwork.com', 'PJ'),
(27, 'Office Prime', 'Office Prime Artigos de Papelaria Ltda', NULL, '21234569000101', 'prime@officeprime.com', 'PJ'),
(28, 'EcoOffice', 'EcoOffice Produtos Ecológicos Ltda', NULL, '31234570000112', 'eco@ecoffice.com', 'PJ'),
(29, 'Universo Escolar', 'Universo Escolar Comércio de Livros e Papéis Ltda', NULL, '41234571000123', 'universo@escolar.com', 'PJ'),
(30, 'Sigma Papéis', 'Sigma Indústria e Comércio de Papéis Ltda', NULL, '51234572000134', 'sigma@sigmapapeis.com', 'PJ');

-- Endereços (um principal por cliente)
INSERT INTO endereco (id_endereco, id_cliente, cep, logradouro, numero, complemento, bairro, cidade, estado, pais, tipo_endereco, principal, status) VALUES
(1, 1, '01001-000', 'Rua Augusta', '100', 'Apto 101', 'Centro', 'São Paulo', 'SP', 'Brasil', 'entrega', TRUE, TRUE),
(2, 2, '02002-000', 'Avenida Paulista', '2000', 'Sala 301', 'Bela Vista', 'São Paulo', 'SP', 'Brasil', 'entrega', TRUE, TRUE),
(3, 3, '03003-000', 'Rua XV de Novembro', '300', 'Conj 15', 'Centro', 'São Paulo', 'SP', 'Brasil', 'entrega', TRUE, TRUE),
(4, 4, '04004-000', 'Alameda Santos', '400', 'Casa', 'Jardins', 'São Paulo', 'SP', 'Brasil', 'entrega', TRUE, TRUE),
(5, 5, '05005-000', 'Rua da Consolação', '500', 'Apto 501', 'Consolação', 'São Paulo', 'SP', 'Brasil', 'entrega', TRUE, TRUE),
(6, 6, '06006-000', 'Avenida Rebouças', '600', 'Andar 10', 'Pinheiros', 'São Paulo', 'SP', 'Brasil', 'entrega', TRUE, TRUE),
(7, 7, '07007-000', 'Rua Vergueiro', '700', 'Bloco B', 'Liberdade', 'São Paulo', 'SP', 'Brasil', 'entrega', TRUE, TRUE),
(8, 8, '08008-000', 'Praça da Sé', '800', 'Sala 801', 'Sé', 'São Paulo', 'SP', 'Brasil', 'entrega', TRUE, TRUE),
(9, 9, '09009-000', 'Rua Bela Cintra', '900', 'Cobertura', 'Consolação', 'São Paulo', 'SP', 'Brasil', 'entrega', TRUE, TRUE),
(10, 10, '10010-000', 'Avenida Ipiranga', '1000', 'Conjunto 10', 'Centro', 'São Paulo', 'SP', 'Brasil', 'entrega', TRUE, TRUE),
(11, 11, '11011-000', 'Rua Cardoso de Almeida', '110', 'Casa 2', 'Perdizes', 'São Paulo', 'SP', 'Brasil', 'entrega', TRUE, TRUE),
(12, 12, '12012-000', 'Rua Oscar Freire', '1200', 'Loja B', 'Jardim Paulista', 'São Paulo', 'SP', 'Brasil', 'entrega', TRUE, TRUE),
(13, 13, '13013-000', 'Avenida Faria Lima', '1300', '12º andar', 'Itaim Bibi', 'São Paulo', 'SP', 'Brasil', 'entrega', TRUE, TRUE),
(14, 14, '14014-000', 'Rua Tabapuã', '140', 'Casa', 'Itaim Bibi', 'São Paulo', 'SP', 'Brasil', 'entrega', TRUE, TRUE),
(15, 15, '15015-000', 'Rua Joaquim Floriano', '1500', 'Conj 1515', 'Itaim Bibi', 'São Paulo', 'SP', 'Brasil', 'entrega', TRUE, TRUE),
(16, 16, '16016-000', 'Avenida Engenheiro Luiz Carlos Berrini', '1600', 'Torre Norte', 'Brooklin', 'São Paulo', 'SP', 'Brasil', 'comercial', TRUE, TRUE),
(17, 17, '17017-000', 'Rua Gomes de Carvalho', '1700', 'Sala 170', 'Vila Olímpia', 'São Paulo', 'SP', 'Brasil', 'comercial', TRUE, TRUE),
(18, 18, '18018-000', 'Avenida das Nações Unidas', '1800', 'Galpão 3', 'Santo Amaro', 'São Paulo', 'SP', 'Brasil', 'comercial', TRUE, TRUE),
(19, 19, '19019-000', 'Rua Augusta', '1900', 'Loja 19', 'Cerqueira César', 'São Paulo', 'SP', 'Brasil', 'comercial', TRUE, TRUE),
(20, 20, '20020-000', 'Avenida Paulista', '2001', 'Conj 2001', 'Bela Vista', 'São Paulo', 'SP', 'Brasil', 'comercial', TRUE, TRUE),
(21, 21, '21021-000', 'Rua Bandeira Paulista', '210', 'Sala 21', 'Itaim Bibi', 'São Paulo', 'SP', 'Brasil', 'comercial', TRUE, TRUE),
(22, 22, '22022-000', 'Avenida do Estado', '2200', 'Barracão 2', 'Cambuci', 'São Paulo', 'SP', 'Brasil', 'comercial', TRUE, TRUE),
(23, 23, '23023-000', 'Rua da Mooca', '230', 'Galpão', 'Mooca', 'São Paulo', 'SP', 'Brasil', 'comercial', TRUE, TRUE),
(24, 24, '24024-000', 'Avenida Interlagos', '2400', 'Sala 240', 'Interlagos', 'São Paulo', 'SP', 'Brasil', 'comercial', TRUE, TRUE),
(25, 25, '25025-000', 'Rua Santa Ifigênia', '250', 'Loja 25', 'Santa Ifigênia', 'São Paulo', 'SP', 'Brasil', 'comercial', TRUE, TRUE),
(26, 26, '26026-000', 'Rua 25 de Março', '260', 'Box 26', 'Centro', 'São Paulo', 'SP', 'Brasil', 'comercial', TRUE, TRUE),
(27, 27, '27027-000', 'Avenida Dr. Arnaldo', '270', 'Sala 27', 'Sumaré', 'São Paulo', 'SP', 'Brasil', 'comercial', TRUE, TRUE),
(28, 28, '28028-000', 'Rua Clodomiro Amazonas', '280', 'Conj 28', 'Vila Nova Conceição', 'São Paulo', 'SP', 'Brasil', 'comercial', TRUE, TRUE),
(29, 29, '29029-000', 'Avenida São João', '2900', '15º andar', 'Centro', 'São Paulo', 'SP', 'Brasil', 'comercial', TRUE, TRUE),
(30, 30, '30030-000', 'Rua da Consolação', '3000', 'Galeria', 'Consolação', 'São Paulo', 'SP', 'Brasil', 'comercial', TRUE, TRUE);

-- Cupons de desconto (8, variados)
INSERT INTO cupons (id_cupom, tipo_desconto, valor_desconto, data_validade, uso_maximo, contagem_usos, ativo, criado_em) VALUES
('CUP1', 'percentual', 10.00, '2026-06-01', 10, 3, TRUE, '2026-03-01 08:00:00'),
('CUP2', 'valor_fixo', 15.00, '2026-05-10', 5, 5, TRUE, '2026-03-05 10:00:00'),
('CUP3', 'percentual', 20.00, '2026-04-15', 20, 8, FALSE, '2026-03-10 12:00:00'),
('CUP4', 'valor_fixo', 5.00, '2026-07-01', 50, 0, TRUE, '2026-04-01 14:00:00'),
('CUP5', 'percentual', 15.00, '2026-05-20', 5, 5, FALSE, '2026-04-05 09:00:00'),
('CUP6', 'valor_fixo', 25.00, '2026-04-20', 10, 2, FALSE, '2026-04-08 11:30:00'),
('CUP7', 'percentual', 5.00, '2026-12-31', 100, 10, TRUE, '2026-04-10 16:00:00'),
('CUP8', 'valor_fixo', 30.00, '2026-06-15', 3, 3, TRUE, '2026-04-15 08:00:00');

-- Forma de pagamento (apoio)
INSERT INTO forma_pagamento (id_forma_pagamento, nome, descricao, ativo) VALUES
(1, 'Cartão de Crédito', 'Pagamento com cartão de crédito', TRUE),
(2, 'PIX', 'Transferência instantânea', TRUE),
(3, 'Boleto Bancário', 'Boleto com vencimento', TRUE);

-- Pedidos (80) com status variados, datas no último mês
INSERT INTO pedidos (id_pedido, id_cliente, id_endereco, data_criacao, subtotal, desconto_aplicado, valor_total, status, codigo_cupom) VALUES
(1, 1, 1, '2026-04-01 10:15:00', 2.50, 0.00, 2.50, 'entregue', NULL),
(2, 2, 2, '2026-04-01 14:30:00', 2.50, 0.00, 2.50, 'entregue', NULL),
(3, 3, 3, '2026-04-02 09:20:00', 1.80, 0.09, 1.71, 'entregue', 'CUP7'),
(4, 4, 4, '2026-04-02 16:45:00', 3.20, 0.00, 3.20, 'entregue', NULL),
(5, 5, 5, '2026-04-03 11:00:00', 13.00, 0.00, 13.00, 'entregue', NULL),
(6, 6, 6, '2026-04-03 15:30:00', 12.00, 0.00, 12.00, 'entregue', NULL),
(7, 7, 7, '2026-04-04 08:50:00', 8.50, 0.00, 8.50, 'entregue', NULL),
(8, 8, 8, '2026-04-04 13:15:00', 4.00, 0.40, 3.60, 'entregue', 'CUP1'),
(9, 9, 9, '2026-04-05 10:00:00', 25.00, 0.00, 25.00, 'entregue', NULL),
(10, 10, 10, '2026-04-05 16:20:00', 46.00, 0.00, 46.00, 'entregue', NULL),
(11, 11, 11, '2026-04-06 09:10:00', 7.50, 0.00, 7.50, 'enviado', NULL),
(12, 12, 12, '2026-04-07 11:25:00', 15.00, 0.00, 15.00, 'enviado', NULL),
(13, 13, 13, '2026-04-08 14:40:00', 9.00, 5.00, 4.00, 'enviado', 'CUP4'),
(14, 14, 14, '2026-04-09 10:05:00', 22.00, 0.00, 22.00, 'enviado', NULL),
(15, 15, 15, '2026-04-09 15:50:00', 47.00, 0.00, 47.00, 'enviado', NULL),
(16, 16, 16, '2026-04-10 12:30:00', 20.00, 0.00, 20.00, 'enviado', NULL),
(17, 17, 17, '2026-04-10 17:00:00', 35.00, 0.00, 35.00, 'enviado', NULL),
(18, 18, 18, '2026-04-11 09:45:00', 45.00, 25.00, 20.00, 'enviado', 'CUP6'),
(19, 19, 19, '2026-04-12 11:15:00', 30.00, 0.00, 30.00, 'enviado', NULL),
(20, 20, 20, '2026-04-12 14:50:00', 278.00, 0.00, 278.00, 'enviado', NULL),
(21, 21, 21, '2026-04-13 10:20:00', 40.00, 0.00, 40.00, 'em separacao', NULL),
(22, 22, 22, '2026-04-14 13:35:00', 18.00, 0.00, 18.00, 'em separacao', NULL),
(23, 23, 23, '2026-04-15 09:55:00', 55.00, 5.50, 49.50, 'em separacao', 'CUP1'),
(24, 24, 24, '2026-04-15 16:10:00', 40.00, 0.00, 40.00, 'em separacao', NULL),
(25, 25, 25, '2026-04-16 10:40:00', 110.00, 0.00, 110.00, 'em separacao', NULL),
(26, 26, 26, '2026-04-16 15:00:00', 65.00, 0.00, 65.00, 'pago', NULL),
(27, 27, 27, '2026-04-17 11:20:00', 80.00, 0.00, 80.00, 'pago', NULL),
(28, 28, 28, '2026-04-17 14:55:00', 120.00, 6.00, 114.00, 'pago', 'CUP7'),
(29, 29, 29, '2026-04-18 09:30:00', 25.00, 0.00, 25.00, 'pago', NULL),
(30, 30, 30, '2026-04-18 13:40:00', 253.20, 0.00, 253.20, 'pago', NULL),
(31, 1, 1, '2026-04-19 10:10:00', 180.00, 0.00, 180.00, 'aguardando pagamento', NULL),
(32, 2, 2, '2026-04-20 12:25:00', 300.00, 0.00, 300.00, 'aguardando pagamento', NULL),
(33, 3, 3, '2026-04-20 15:45:00', 90.00, 5.00, 85.00, 'aguardando pagamento', 'CUP4'),
(34, 4, 4, '2026-04-21 09:15:00', 60.00, 0.00, 60.00, 'aguardando pagamento', NULL),
(35, 5, 5, '2026-04-21 16:30:00', 100.00, 0.00, 100.00, 'aguardando pagamento', NULL),
(36, 6, 6, '2026-04-22 10:50:00', 12.00, 0.00, 12.00, 'cancelado', NULL),
(37, 7, 7, '2026-04-22 14:05:00', 8.50, 0.00, 8.50, 'cancelado', NULL),
(38, 8, 8, '2026-04-23 09:00:00', 1.80, 0.09, 1.71, 'cancelado', 'CUP7'),
(39, 9, 9, '2026-04-23 11:30:00', 25.00, 0.00, 25.00, 'cancelado', NULL),
(40, 10, 10, '2026-04-24 15:20:00', 25.20, 0.00, 25.20, 'cancelado', NULL),
(41, 11, 11, '2026-04-06 08:00:00', 7.50, 0.00, 7.50, 'devolvido', NULL),
(42, 12, 12, '2026-04-07 09:30:00', 15.00, 0.00, 15.00, 'devolvido', NULL),
(43, 13, 13, '2026-04-08 14:00:00', 25.00, 5.00, 20.00, 'devolvido', 'CUP3'),
(44, 14, 14, '2026-04-09 10:40:00', 22.00, 0.00, 22.00, 'devolvido', NULL),
(45, 15, 15, '2026-04-10 11:50:00', 55.00, 0.00, 55.00, 'devolvido', NULL),
(46, 16, 16, '2026-04-11 13:15:00', 20.00, 0.00, 20.00, 'entregue', NULL),
(47, 17, 17, '2026-04-12 08:25:00', 35.00, 0.00, 35.00, 'entregue', NULL),
(48, 18, 18, '2026-04-13 10:00:00', 9.00, 0.90, 8.10, 'entregue', 'CUP1'),
(49, 19, 19, '2026-04-14 14:40:00', 30.00, 0.00, 30.00, 'entregue', NULL),
(50, 20, 20, '2026-04-15 09:50:00', 62.00, 0.00, 62.00, 'entregue', NULL),
(51, 21, 21, '2026-04-16 11:15:00', 40.00, 0.00, 40.00, 'enviado', NULL),
(52, 22, 22, '2026-04-17 13:30:00', 18.00, 0.00, 18.00, 'enviado', NULL),
(53, 23, 23, '2026-04-18 10:05:00', 45.00, 25.00, 20.00, 'enviado', 'CUP6'),
(54, 24, 24, '2026-04-19 12:45:00', 40.00, 0.00, 40.00, 'enviado', NULL),
(55, 25, 25, '2026-04-20 14:00:00', 55.00, 0.00, 55.00, 'enviado', NULL),
(56, 26, 26, '2026-04-21 09:20:00', 65.00, 0.00, 65.00, 'em separacao', NULL),
(57, 27, 27, '2026-04-22 11:35:00', 80.00, 0.00, 80.00, 'em separacao', NULL),
(58, 28, 28, '2026-04-23 13:50:00', 55.00, 5.50, 49.50, 'em separacao', 'CUP1'),
(59, 29, 29, '2026-04-24 15:05:00', 25.00, 0.00, 25.00, 'em separacao', NULL),
(60, 30, 30, '2026-04-25 10:15:00', 100.00, 0.00, 100.00, 'em separacao', NULL),
(61, 1, 1, '2026-04-26 09:30:00', 2.50, 0.00, 2.50, 'pago', NULL),
(62, 2, 2, '2026-04-27 11:45:00', 2.50, 0.00, 2.50, 'pago', NULL),
(63, 3, 3, '2026-04-28 13:00:00', 120.00, 5.00, 115.00, 'pago', 'CUP4'),
(64, 4, 4, '2026-04-29 14:20:00', 3.20, 0.00, 3.20, 'pago', NULL),
(65, 5, 5, '2026-04-30 10:10:00', 28.20, 0.00, 28.20, 'pago', NULL),
(66, 6, 6, '2026-05-01 09:00:00', 12.00, 0.00, 12.00, 'aguardando pagamento', NULL),
(67, 7, 7, '2026-05-01 11:20:00', 8.50, 0.00, 8.50, 'aguardando pagamento', NULL),
(68, 8, 8, '2026-05-02 13:30:00', 90.00, 4.50, 85.50, 'aguardando pagamento', 'CUP7'),
(69, 9, 9, '2026-05-02 15:40:00', 25.00, 0.00, 25.00, 'aguardando pagamento', NULL),
(70, 10, 10, '2026-05-03 10:00:00', 85.00, 0.00, 85.00, 'aguardando pagamento', NULL),
(71, 11, 11, '2026-05-03 12:10:00', 7.50, 0.00, 7.50, 'aguardando pagamento', NULL),
(72, 12, 12, '2026-05-04 09:30:00', 15.00, 0.00, 15.00, 'aguardando pagamento', NULL),
(73, 13, 13, '2026-05-04 11:45:00', 1.80, 0.18, 1.62, 'aguardando pagamento', 'CUP1'),
(74, 14, 14, '2026-05-04 14:00:00', 22.00, 0.00, 22.00, 'aguardando pagamento', NULL),
(75, 15, 15, '2026-05-05 08:30:00', 25.20, 0.00, 25.20, 'aguardando pagamento', NULL),
(76, 16, 16, '2026-04-20 15:00:00', 20.00, 0.00, 20.00, 'cancelado', NULL),
(77, 17, 17, '2026-04-25 10:30:00', 35.00, 0.00, 35.00, 'cancelado', NULL),
(78, 18, 18, '2026-04-28 12:00:00', 9.00, 0.00, 9.00, 'cancelado', NULL),
(79, 19, 19, '2026-05-01 09:45:00', 30.00, 0.00, 30.00, 'cancelado', NULL),
(80, 20, 20, '2026-05-03 11:50:00', 278.00, 0.00, 278.00, 'cancelado', NULL);

-- Itens de pedido corrigidos (todos os 95 itens)
INSERT INTO itens_pedido (id_item, pedido_id, produto_id, quantidade, preco_unitario) VALUES
(1, 1, 1, 1, 2.50),
(2, 2, 2, 1, 2.50),
(3, 3, 3, 1, 1.80),
(4, 4, 4, 1, 3.20),
(5, 5, 5, 1, 1.00),
(6, 5, 15, 1, 12.00),
(7, 6, 6, 1, 12.00),
(8, 7, 7, 1, 8.50),
(9, 8, 8, 1, 4.00),
(10, 9, 9, 1, 25.00),
(11, 10, 10, 1, 18.00),
(12, 10, 20, 1, 28.00),
(13, 11, 11, 1, 7.50),
(14, 12, 12, 1, 15.00),
(15, 13, 13, 1, 9.00),
(16, 14, 14, 1, 22.00),
(17, 15, 15, 1, 12.00),
(18, 15, 25, 1, 35.00),
(19, 16, 16, 1, 20.00),
(20, 17, 17, 1, 35.00),
(21, 18, 18, 1, 45.00),
(22, 19, 19, 1, 30.00),
(23, 20, 20, 1, 28.00),
(24, 20, 30, 1, 250.00),
(25, 21, 21, 1, 40.00),
(26, 22, 22, 1, 18.00),
(27, 23, 23, 1, 55.00),
(28, 24, 24, 1, 40.00),
(29, 25, 25, 1, 35.00),
(30, 25, 35, 1, 75.00),
(31, 26, 26, 1, 65.00),
(32, 27, 27, 1, 80.00),
(33, 28, 28, 1, 120.00),
(34, 29, 29, 1, 25.00),
(35, 30, 30, 1, 250.00),
(36, 30, 4, 1, 3.20),
(37, 31, 31, 1, 180.00),
(38, 32, 32, 1, 300.00),
(39, 33, 33, 1, 90.00),
(40, 34, 34, 1, 60.00),
(41, 35, 35, 1, 75.00),
(42, 35, 9, 1, 25.00),
(43, 36, 6, 1, 12.00),
(44, 37, 7, 1, 8.50),
(45, 38, 3, 1, 1.80),
(46, 39, 9, 1, 25.00),
(47, 40, 4, 1, 3.20),
(48, 40, 14, 1, 22.00),
(49, 41, 11, 1, 7.50),
(50, 42, 12, 1, 15.00),
(51, 43, 9, 1, 25.00),
(52, 44, 14, 1, 22.00),
(53, 45, 9, 1, 25.00),
(54, 45, 19, 1, 30.00),
(55, 46, 16, 1, 20.00),
(56, 47, 17, 1, 35.00),
(57, 48, 13, 1, 9.00),
(58, 49, 19, 1, 30.00),
(59, 50, 14, 1, 22.00),
(60, 50, 24, 1, 40.00),
(61, 51, 21, 1, 40.00),
(62, 52, 22, 1, 18.00),
(63, 53, 18, 1, 45.00),
(64, 54, 24, 1, 40.00),
(65, 55, 19, 1, 30.00),
(66, 55, 29, 1, 25.00),
(67, 56, 26, 1, 65.00),
(68, 57, 27, 1, 80.00),
(69, 58, 23, 1, 55.00),
(70, 59, 29, 1, 25.00),
(71, 60, 24, 1, 40.00),
(72, 60, 34, 1, 60.00),
(73, 61, 1, 1, 2.50),
(74, 62, 2, 1, 2.50),
(75, 63, 28, 1, 120.00),
(76, 64, 4, 1, 3.20),
(77, 65, 29, 1, 25.00),
(78, 65, 4, 1, 3.20),
(79, 66, 6, 1, 12.00),
(80, 67, 7, 1, 8.50),
(81, 68, 33, 1, 90.00),
(82, 69, 9, 1, 25.00),
(83, 70, 34, 1, 60.00),
(84, 70, 9, 1, 25.00),
(85, 71, 11, 1, 7.50),
(86, 72, 12, 1, 15.00),
(87, 73, 3, 1, 1.80),
(88, 74, 14, 1, 22.00),
(89, 75, 4, 1, 3.20),
(90, 75, 14, 1, 22.00),
(91, 76, 16, 1, 20.00),
(92, 77, 17, 1, 35.00),
(93, 78, 13, 1, 9.00),
(94, 79, 19, 1, 30.00),
(95, 80, 10, 1, 18.00);

-- Correções de subtotal/valor_total em pedidos que divergem
UPDATE pedidos SET subtotal = 28.20, valor_total = 28.20 WHERE id_pedido = 65;
UPDATE pedidos SET subtotal = 85.00, valor_total = 85.00 WHERE id_pedido = 70;
UPDATE pedidos SET subtotal = 25.20, valor_total = 25.20 WHERE id_pedido = 75;
-- pedido 80 já foi atualizado para 18.00

 -- Pedidos com status 'enviado', 'entregue' ou 'devolvido' recebem uma entrada na tabela de entrega_expedicao
INSERT INTO entrega_expedicao (id_entrega, id_pedido, status_entrega, transportadora, codigo_rastreamento)
SELECT
    ROW_NUMBER() OVER (ORDER BY id_pedido),
    id_pedido,
    CASE
        WHEN status = 'entregue' THEN 'entregue'
        WHEN status = 'enviado' THEN 'em_transito'
        WHEN status = 'devolvido' THEN 'entregue'  -- a entrega foi feita antes da devolução
    END,
    CASE (id_pedido % 3)
        WHEN 0 THEN 'Transportadora Rápida'
        WHEN 1 THEN 'Logística Expressa'
        ELSE 'Correios'
    END,
    'BR' || LPAD(id_pedido::TEXT, 8, '0') || 'BR'
FROM pedidos
WHERE status IN ('enviado', 'entregue', 'devolvido');

-- Contagens de uso de cupons
UPDATE cupons SET contagem_usos = 7 WHERE id_cupom = 'CUP1';
UPDATE cupons SET contagem_usos = 3 WHERE id_cupom = 'CUP4';
UPDATE cupons SET contagem_usos = 13 WHERE id_cupom = 'CUP7';
UPDATE cupons SET contagem_usos = 9