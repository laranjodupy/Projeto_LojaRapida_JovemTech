# LojaRápida — Apostila de Estudo

CajuHub Formação Dev Junior · Banco de Dados PostgreSQL · Projeto Final

> **Como usar esta apostila:**
> Cada junior tem uma seção dedicada com **o que fez, o que vai defender, perguntas que vão cair e as respostas prontas**. Leia primeiro a sua parte. Treine as respostas em voz alta. Depois leia as outras seções — o instrutor pode perguntar qualquer coisa pra qualquer um.

---

## 1. Contexto do projeto (todos precisam saber)

A **LojaRápida** é um e-commerce de papelaria/escritório que vende para PF e PJ. Saiu de um ERP genérico para construir plataforma própria. Nosso papel: **construir o banco de dados em PostgreSQL**.

**Exigência principal do CTO:** rastreabilidade total do pedido — da criação até a entrega ou devolução.

**O que entregamos no total:**
- Schema com 8 entidades obrigatórias (cliente, categorias, produtos, cupons, pedidos, itens_pedido, pagamentos, histórico_status) + tabelas de apoio
- Seed com 1 mês de operação simulada (80 pedidos, 30 clientes, 40 produtos, 8 cupons)
- 12 queries respondendo perguntas do time comercial e operações
- 2 views encapsulando relatórios recorrentes
- Transaction obrigatória com cenário de SUCESSO e ROLLBACK forçado

**Arquivos no repositório:**
- `schema.sql` — definição das tabelas
- `seed.sql` — dados de teste
- `queries.sql` — as 12 perguntas de negócio
- `views.sql` — relatórios encapsulados
- `transaction.sql` — cenário ACID

---

## 2. Junior 1 — Schema + Categorias e Produtos do seed

### 🎯 O que você fez

Você modelou o **banco** em si: criou todas as tabelas, definiu chaves primárias, estrangeiras, CHECK constraints e índices. Depois populou as **categorias** (6) e os **produtos** (40) no seed.

### 📁 Arquivos pelos quais você responde
- `schema.sql` (todo)
- `seed.sql` — bloco de `INSERT INTO categorias` e `INSERT INTO produtos`

### 🧠 O que você defende (decisões críticas)

**1. Por que `itens_pedido.preco_unitario` é independente do `produtos.preco`?**
Porque o preço do produto muda com o tempo. Se a Caneta hoje custa R$ 2,50 e amanhã virar R$ 3,00, o pedido de ontem **ainda mostra R$ 2,50**. Senão estaríamos reescrevendo história — quebraria auditoria, nota fiscal e conferência com extrato bancário. É o padrão **price snapshot**.

**2. Por que `pedidos.codigo_cupom` (referência) e `pedidos.desconto_aplicado` (valor) ao mesmo tempo?**
Dupla referência intencional. `codigo_cupom` rastreia **qual** cupom foi usado. `desconto_aplicado` guarda o **valor real** descontado em reais, calculado uma vez no momento da compra. Cupom pode ser deletado ou ter percentual alterado depois — pedido tem que preservar o que foi cobrado.

**3. Por que CHECK `quantidade_estoque >= 0` no banco?**
Defesa em camadas. A aplicação valida antes pra dar UX boa. O banco impede mesmo se a aplicação falhar. Se duas compras simultâneas tentam decrementar o mesmo produto, o banco bloqueia a segunda. **É a base que faz o ROLLBACK automático funcionar na transaction obrigatória.**

**4. Por que CHECK `contagem_usos <= uso_maximo` em cupons?**
Garante que ninguém usa o cupom além do limite. Se a aplicação falhar e tentar `UPDATE cupons SET contagem_usos = 100` num cupom com `uso_maximo = 10`, o banco rejeita.

**5. Por que `historico_status` separado do `pedidos.status`?**
`pedidos.status` é leitura rápida ("qual o status agora?"). `historico_status` é trilha de auditoria ("quando foi pago?", "quanto tempo levou pra enviar?"). Sem o histórico, a Q10 (tempo médio entre pago e enviado) é **impossível**.

### ❓ Perguntas que vão cair pra você

**Q: Por que o preço do item é salvo separadamente e não buscado do produto?**
> R: Porque o preço do produto pode mudar. O pedido de ontem não pode mostrar o preço de hoje — viraria reescrever história fiscal. Implicação direta na auditoria e conferência com extrato bancário.

**Q: O que acontece se o estoque de um produto chegar a zero? Isso é controlado pelo banco ou pela aplicação?**
> R: Os dois. A aplicação valida antes pra dar mensagem amigável. O banco tem CHECK (quantidade_estoque >= 0) como última linha de defesa. Em race condition, o banco bloqueia.

**Q: Como você garantiu que o código de cupom é único e não pode ser reutilizado além do limite?**
> R: Unicidade pela PRIMARY KEY no `id_cupom`. Limite de uso pela constraint `chk_usos_dentro_limite CHECK (contagem_usos <= uso_maximo)` — se alguém tentar UPDATE pra incrementar além do máximo, o banco rejeita.

**Q: Como você modelou a aplicação de cupom no pedido? Onde fica o desconto?**
> R: Dupla referência. `pedidos.codigo_cupom` aponta pra `cupons.id_cupom` (rastreabilidade — qual cupom foi usado). `pedidos.desconto_aplicado` guarda o valor real descontado em reais. O valor é materializado porque o cupom pode mudar ou ser deletado depois — o pedido tem que preservar o que foi cobrado.

**Q: Por que vocês escolheram `historico_status` separado em vez de só usar `pedidos.atualizado_em`?**
> R: `atualizado_em` só guarda a última vez que o pedido mudou. Perde todas as transições intermediárias. Pra responder "quando foi pago?" e "quanto tempo demorou pra enviar?" precisamos da trilha completa. `historico_status` é append-only, fonte da verdade.

---

## 3. Junior 2 — Clientes/Cupons do seed + Queries Q1, Q2, Q3, Q5

### 🎯 O que você fez

Populou os **clientes** (30 — 15 PF + 15 PJ) e os **cupons** (8 — válidos, expirados, esgotados) no seed. Escreveu as 4 queries mais diretas do projeto.

### 📁 Arquivos pelos quais você responde
- `seed.sql` — blocos de `INSERT INTO cliente` e `INSERT INTO cupons`
- `queries.sql` — Q1, Q2, Q3, Q5

### 🧠 O que você defende

**Q1 — Estoque < 10:** filtro simples + JOIN com categorias + ORDER BY estoque ASC. Filtra `status = 'ativo'` porque não faz sentido reportar reposição de produto inativo.

**Q2 — Faturamento por dia (30 dias):** GROUP BY DATE + filtro **`pg.status = 'aprovado'`**. Sem esse filtro, o faturamento vem inflado com pedidos que não geraram receita.

**Q3 — Top 10 produtos vendidos:** JOIN triplo (itens_pedido + produtos + categorias) + GROUP BY + ORDER BY DESC + LIMIT 10. Filtra pagamento aprovado e pedidos do último mês.

**Q5 — Cupons mais usados:** simples ORDER BY contagem_usos DESC. Filtra `contagem_usos > 0` (cupons nunca usados não interessam).

### ❓ Perguntas que vão cair

**Q: Por que sua Q2 filtra apenas pagamento aprovado? O que muda se incluir os recusados?**
> R: Faturamento ficaria inflado com vendas que não entraram no caixa. Pagamento recusado = cliente tentou e falhou. Não houve receita. Incluir recusados criaria divergência com extrato bancário.

**Q: Sua Q1 ordena de qual jeito? Por quê?**
> R: ORDER BY quantidade_estoque ASC primeiro, depois por nome. O time de operações precisa ver primeiro os produtos com MENOS estoque pra repor antes que zerem.

**Q: Como você garantiu na Q3 que está pegando o último mês?**
> R: WHERE pe.data_criacao >= NOW() - INTERVAL '30 days'. Pega pedidos criados nos últimos 30 dias.

**Q: Por que sua Q5 filtra `contagem_usos > 0`?**
> R: Cupons que nunca foram usados não são relevantes pro relatório de "mais utilizados". Reduzem a lista pra quem realmente teve uso.

**Q: Como você populou clientes PF e PJ? Por que tem CPF e CNPJ em colunas separadas?**
> R: 15 PF (com CPF preenchido, CNPJ NULL) e 15 PJ (CNPJ preenchido, CPF NULL). Tem coluna `tipo` pra distinguir. CHECK garante que tipo IN ('PF', 'PJ').

---

## 4. Junior 3 — Queries Q4, Q6, Q8, Q11

### 🎯 O que você fez

Escreveu 4 queries de complexidade intermediária — agregações com filtros condicionais, anti-join e GROUP BY com HAVING.

### 📁 Arquivos pelos quais você responde
- `queries.sql` — Q4, Q6, Q8, Q11

### 🧠 O que você defende

**Q4 — Ticket médio PF vs PJ:** AVG(valor_total) com GROUP BY tipo de cliente. Filtra pagamento aprovado pra não inflar com vendas não confirmadas.

**Q6 — Clientes com >3 pedidos no mês:** GROUP BY cliente + **HAVING COUNT(*) > 3**. Atenção: mais de 3 = `> 3`, NÃO `>= 3`. E `HAVING`, não `WHERE` — porque é filtro depois da agregação.

**Q8 — Produtos nunca comprados:** **LEFT JOIN itens_pedido + WHERE IS NULL**. É o padrão **anti-join**. Não usei `NOT IN` porque tem o gotcha: se algum `produto_id` em `itens_pedido` fosse NULL (não é o caso, mas como hábito), `NOT IN` retornaria zero linhas silenciosamente.

**Q11 — Aguardando pagamento >2 dias:** filtro `status = 'aguardando pagamento' AND data_criacao < NOW() - INTERVAL '2 days'`. Mostra dias aguardando pra time de operações cobrar o cliente.

### ❓ Perguntas que vão cair

**Q: Na Q6, por que você usou HAVING em vez de WHERE?**
> R: WHERE filtra ANTES da agregação (linha por linha). HAVING filtra DEPOIS da agregação (grupo por grupo). Como queremos clientes com COUNT > 3, o filtro tem que rodar depois do GROUP BY — então HAVING.

**Q: Na Q8, por que LEFT JOIN + IS NULL e não NOT IN ou NOT EXISTS?**
> R: LEFT JOIN com IS NULL é mais legível pro caso "anti-join" e seguro contra NULL na subquery. NOT IN tem um gotcha clássico: se a subquery tiver qualquer NULL, retorna zero linhas silenciosamente.

**Q: Na Q4, qual a diferença prática entre PF e PJ?**
> R: No nosso seed, PJ tem ticket médio próximo ao de PF mas em volume menor de pedidos. PF gera mais faturamento total porque tem mais pedidos. Insight: PF é a maioria do faturamento mesmo com ticket parecido.

**Q: Na Q11, por que filtrar exatamente 2 dias e não 1?**
> R: É a regra de negócio do PDF. Operações considera 2 dias como o limite normal. Após esse prazo, o pedido entra em "atenção" pra possível cancelamento ou contato com cliente.

**Q: Q8 considera produtos inativos?**
> R: Sim. A query filtra apenas por "nunca apareceu em itens_pedido", independente do status. Faz sentido — produto inativo nunca foi vendido também é informação relevante pro time comercial decidir descontinuar de vez.

---

## 5. Junior 4 — Queries Q7, Q9, Q10, Q12

### 🎯 O que você fez

Escreveu as 4 queries mais avançadas. Aqui mora o uso de **CTE, DATE_TRUNC, self-join** e cálculo de delta temporal entre status. Estas queries são as que mais provavelmente vão ser cobradas na defesa.

### 📁 Arquivos pelos quais você responde
- `queries.sql` — Q7, Q9, Q10, Q12

### 🧠 O que você defende

**Q7 — Cancelados por mês (3 meses):** `DATE_TRUNC('month', data_criacao)` agrupa todos os timestamps no primeiro dia do mês. SUM(valor_total) mostra o impacto financeiro do cancelamento.

**Q9 — Clientes acima da média:** **CTE com 2 estágios**. Primeiro: `gastos_clientes` agrega total gasto por cliente. Segundo: `media_geral` calcula a média. SELECT final filtra quem está acima. Filtra pagamento aprovado.

**Q10 — Tempo médio entre pago e enviado:** **self-join** em `historico_status`. Uma cópia filtra `status_novo = 'pago'`, outra cópia filtra `status_novo = 'enviado'`, ligadas pelo mesmo `pedido_id`. Diferença em horas via `EXTRACT(EPOCH FROM ...) / 3600`.

**Q12 — Categoria com maior receita no mês:** JOIN itens_pedido + produtos + categorias + pedidos + pagamentos. SUM(quantidade * preco_unitario) por categoria. ORDER BY receita DESC.

### ❓ Perguntas que vão cair

**Q: Sua Q9 usa CTE ou subquery? Como você estruturou?**
> R: CTE com 2 estágios. Primeiro CTE `gastos_clientes` agrega o total gasto por cliente. Segundo CTE `media_geral` calcula a média desses totais. SELECT final filtra quem gastou acima. Estruturei com CTE pra deixar a média explícita como conceito — fica mais legível que aninhar AVG dentro do WHERE.

**Q: Como você calculou o tempo entre dois status do mesmo pedido (Q10)? Quais tabelas e colunas você usou?**
> R: Self-join na tabela `historico_status`. Uma cópia da tabela filtrada por `status_novo = 'pago'`, outra cópia filtrada por `status_novo = 'enviado'`, ligadas pelo mesmo `pedido_id`. A diferença em horas vem de `EXTRACT(EPOCH FROM (data_enviado - data_pago)) / 3600`. DATE_TRUNC('month') agrupa por mês.

**Q: Por que self-join e não window function (LAG)?**
> R: Self-join é mais explícito sobre **quais transições** queremos casar. LAG funcionaria mas seria frágil se aparecessem mais transições intermediárias. Self-join filtra exatamente o que interessa.

**Q: Na Q7, por que DATE_TRUNC e não TO_CHAR?**
> R: DATE_TRUNC retorna um timestamp (mantém o tipo). TO_CHAR retorna string. Pra GROUP BY, DATE_TRUNC é mais limpo — agrupa todos os timestamps do mesmo mês no primeiro dia. Uso TO_CHAR só no SELECT pra exibir formatado.

**Q: Sua Q12 ordena por unidades vendidas ou por receita? Por quê?**
> R: Por receita (SUM(quantidade * preco_unitario)). A pergunta é "categoria com maior receita". Unidades vendidas é métrica diferente — produto barato pode ter muitas unidades sem gerar receita alta.

**Q: Como você garante que Q9 só pega o último mês?**
> R: WHERE pe.data_criacao >= NOW() - INTERVAL '30 days' dentro do CTE `gastos_clientes`. A média é calculada apenas sobre clientes que compraram nesse período.

---

## 6. Junior 5 — Views + Transaction

### 🎯 O que você fez

A entrega mais densa em conceitos: 2 views encapsulando relatórios com window function (NTILE) + a transaction obrigatória do PDF com cenário de sucesso e ROLLBACK forçado.

### 📁 Arquivos pelos quais você responde
- `views.sql` — `pedidos_em_aberto` e `desempenho_catalogo`
- `transaction.sql` — sucesso, falha e função

### 🧠 O que você defende

**View `pedidos_em_aberto`:**
- Filtra `status NOT IN ('entregue', 'cancelado', 'devolvido')` — pedido enviado ainda está em aberto.
- JOIN com cliente pra mostrar o nome.
- Calcula `horas_no_status` a partir do último `alterado_em` em `historico_status` (não da data de criação do pedido).
- Ordena dos mais antigos pros mais recentes.

**View `desempenho_catalogo`:**
- Apenas produtos `ativos`, mês corrente, pagamento aprovado.
- LEFT JOIN com itens_pedido garante que produtos sem venda apareçam.
- Classificação por **NTILE(5) OVER (ORDER BY unidades_vendidas DESC)** — quintil 1 = top 20% = `destaque`. Resto que vendeu = `regular`. Sem venda = `parado`.

**Transaction sucesso (BEGIN/COMMIT):**
4 operações atômicas:
1. UPDATE pedidos SET status = 'pago'
2. INSERT pagamentos (status aprovado)
3. UPDATE produtos (decrementa estoque)
4. INSERT historico_status (registra transição)

**Transaction falha (ROLLBACK forçado):**
Tira 99999 do estoque de um produto → viola CHECK (quantidade_estoque >= 0) → Postgres aborta a transação inteira. Snapshot ANTES e DEPOIS provam que **nada** persistiu — nem o status, nem o pagamento que individualmente teriam passado.

**Função `processar_pagamento_pedido` (bonus):**
Encapsula o fluxo numa stored procedure com `SELECT ... FOR UPDATE` (lock pessimista) — evita dupla execução concorrente.

### ❓ Perguntas que vão cair

**Q: Se um pedido for enviado agora, a view `pedidos_em_aberto` para de mostrá-lo automaticamente?**
> R: Não. Enviado continua em aberto — operações precisa monitorar até a entrega. A view só exclui entregue, cancelado e devolvido. Como view é virtual, qualquer mudança no `pedidos.status` reflete instantaneamente — não tem nada pra "atualizar" na view.

**Q: A view `desempenho_catalogo` mostra produtos sem nenhuma venda no mês?**
> R: Sim, com a classificação `parado`. LEFT JOIN com itens_pedido garante que produtos sem itens correspondentes apareçam com unidades_vendidas = 0. Esconder os parados esconderia o problema do time comercial.

**Q: Como você classificou destaque/regular/parado?**
> R: NTILE(5) OVER (ORDER BY unidades_vendidas DESC) divide os produtos vendidos em 5 grupos iguais por volume. Quintil 1 é o top 20% — esses são `destaque`. Resto que vendeu fica `regular`. Quem não vendeu fica `parado` (CASE separado pra unidades = 0).

**Q: O que aconteceria se o estoque do segundo produto fosse insuficiente após o primeiro já ter sido decrementado?**
> R: O CHECK constraint `(quantidade_estoque >= 0)` violaria. O Postgres aborta a transação INTEIRA — incluindo o decremento do primeiro produto que já tinha passado. Tudo ou nada. ACID na prática: integridade do banco preservada mesmo em falha parcial.

**Q: Como você garantiu que o pagamento e o decremento de estoque aconteceram de forma atômica?**
> R: BEGIN/COMMIT do Postgres. Tudo dentro do bloco é uma unidade indivisível. Se qualquer comando falha, o COMMIT vira ROLLBACK automático e nenhum efeito persiste. Adicionalmente criamos a função `processar_pagamento_pedido` com `SELECT ... FOR UPDATE` pra lock pessimista — evita dois processos pagarem o mesmo pedido simultaneamente.

**Q: Por que a view `pedidos_em_aberto` calcula horas a partir de `historico_status.alterado_em` em vez de `pedidos.atualizado_em`?**
> R: `pedidos.atualizado_em` reflete a última alteração de qualquer campo do pedido (incluindo correções administrativas). `historico_status.alterado_em` reflete especificamente quando o status mudou pela última vez. Pra "horas no status atual", a fonte da verdade é o histórico.

---

## 7. Tech Lead (João Lopes) — coordenação

Eu (João Lopes) sou o tech lead. Coordenei a integração das partes, fiz o seed dos pedidos, itens, pagamentos e histórico de status (a parte que amarra tudo), e revisei/corrigi cada entrega.

Se o instrutor perguntar algo que ninguém soube responder, eu cubro.

---

## 8. Aviso final — para todos os juniores

> ## ⚠️ ESTUDEM O TRABALHO DE TODOS, NÃO SÓ A SUA PARTE.
>
> O instrutor pode perguntar **qualquer coisa para qualquer um**.
>
> Não importa que cada um seja "responsável" por uma seção — durante a defesa, ele vai testar se o time entendeu o projeto **como um todo**, não se cada um decorou a sua parte.
>
> **Ritmo de estudo recomendado:**
>
> 1. Hoje: leia sua seção em profundidade. Treine as respostas em voz alta.
> 2. Quinta: leia as outras 4 seções. Foque nas perguntas previstas.
> 3. Sexta de manhã: ensaio com o tech lead — ele pergunta qualquer coisa, todos têm que saber responder.
> 4. Antes da apresentação: releia esta apostila inteira mais uma vez.
>
> **A defesa é coletiva — se um cair, todos caem.** Portanto: estudem o trabalho de todos.

---

## 9. Checklist da equipe antes da apresentação

- [ ] Banco populado no Supabase rodando schema → seed → views (na ordem)
- [ ] Cada um abriu sua parte do código e RODOU pelo menos uma vez
- [ ] Cada um leu as outras 4 seções desta apostila
- [ ] Treinaram as perguntas previstas em voz alta
- [ ] Fizeram pelo menos um ensaio coletivo
- [ ] Levaram laptop com Supabase aberto pra demo ao vivo
- [ ] Slides abertos na tela
- [ ] PDF do projeto à mão pra consultar enunciado se preciso

---

**Boa apresentação. 🎯**
