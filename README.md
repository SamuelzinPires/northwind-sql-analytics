# 📊 Northwind SQL Analytics — Business Intelligence Views

> Análise de dados comerciais do banco Northwind usando PostgreSQL, com foco em métricas de negócio reais: receita, crescimento, segmentação de clientes e ranking de produtos.

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Advanced-orange?style=for-the-badge)

---

## 🎯 Sobre o Projeto

Este projeto transforma o clássico banco de dados **Northwind** — uma base de dados de e-commerce B2B com pedidos, produtos, clientes e fornecedores — em um conjunto de **7 views analíticas reutilizáveis** que respondem a perguntas reais de negócio.

**O objetivo não é só escrever SQL.** É demonstrar a capacidade de:
- Traduzir problemas de negócio em queries estruturadas
- Criar views documentadas e reutilizáveis (prontas para dashboards)
- Usar técnicas avançadas: CTEs encadeadas, Window Functions, LAG, NTILE, HAVING
- Pensar como analista de dados, não apenas como desenvolvedor

---

## 🏗️ Arquitetura

```
┌──────────────────────────────────────────────────┐
│                    Docker                         │
│                                                   │
│  ┌─────────────┐       ┌──────────────────────┐  │
│  │ PostgreSQL   │◄─────│  northwind.sql        │  │
│  │ Port: 5432   │       │  (dados populados)    │  │
│  └──────┬──────┘       └──────────────────────┘  │
│         │                                         │
│  ┌──────▼──────┐                                  │
│  │   PgAdmin    │  ← Interface visual             │
│  │ Port: 8080   │                                  │
│  └─────────────┘                                  │
│         │                                         │
│  ┌──────▼──────────────────────────────────────┐  │
│  │           7 Analytical Views                 │  │
│  │  vw_receita_ytd                              │  │
│  │  vw_crescimento_mensal                       │  │
│  │  vw_top_10_produtos                          │  │
│  │  vw_top_funcionarios_1997                    │  │
│  │  vw_segmentacao_clientes                     │  │
│  │  vw_clientes_uk_premium                      │  │
│  │  vw_clientes_vip                             │  │
│  └──────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

---

## 🛠️ Stack

| Tecnologia | Versão | Uso |
|---|---|---|
| PostgreSQL | 15+ | Banco de dados relacional |
| Docker / Docker Compose | latest | Containerização do ambiente |
| PgAdmin 4 | latest | Interface visual para queries |
| SQL | — | CTEs, Window Functions, JOINs, HAVING, VIEWs |

---

## 🚀 Como Rodar

### Pré-requisitos
- [Docker](https://www.docker.com/) instalado
- [Docker Compose](https://docs.docker.com/compose/) instalado

### Setup

```bash
# 1. Clone o repositório
git clone https://github.com/SEU_USUARIO/northwind-sql-analytics.git
cd northwind-sql-analytics

# 2. Suba o ambiente
docker-compose up -d

# 3. Acesse o PgAdmin
# URL: http://localhost:8080

# 4. Conecte ao banco Northwind
# Host: postgres | Port: 5432 | Database: northwind

# 5. Execute as views
# Rode o arquivo sql/views.sql no PgAdmin ou via psql
```

### Verificar que tudo funciona

```sql
-- Lista todas as views criadas
SELECT table_name FROM information_schema.views 
WHERE table_schema = 'public' AND table_name LIKE 'vw_%';

-- Testar uma view
SELECT * FROM vw_top_10_produtos;
```

---

## 📈 As 7 Views Analíticas

Cada view responde a uma **pergunta de negócio** específica. A ordem segue uma narrativa: começamos pela receita geral, identificamos tendências, descobrimos o que vende mais, quem vende mais, segmentamos a base, focamos em um mercado específico e finalmente encontramos os VIPs.

---

### 1. `vw_receita_ytd` — Receita Mensal + Acumulado Year-To-Date

> **Pergunta de negócio:** *"Qual a receita mês a mês e como ela acumula ao longo do ano?"*

**Conceitos SQL:** `CTE` · `SUM() OVER (PARTITION BY ano ORDER BY mes)` · Window Function acumulativa · `ROUND` + `::NUMERIC`

```sql
CREATE OR REPLACE VIEW vw_receita_ytd AS
WITH faturamento_mensal AS (
    SELECT 
        EXTRACT(YEAR FROM o.order_date) AS ano,
        EXTRACT(MONTH FROM o.order_date) AS mes,
        SUM(od.unit_price * od.quantity) AS receita_do_mes
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    GROUP BY EXTRACT(YEAR FROM o.order_date), EXTRACT(MONTH FROM o.order_date)
)
SELECT 
    ano,
    mes,
    ROUND(receita_do_mes::NUMERIC, 2) AS receita_do_mes,
    ROUND(SUM(receita_do_mes) OVER (PARTITION BY ano ORDER BY mes)::NUMERIC, 2) AS receita_ytd
FROM faturamento_mensal
ORDER BY ano, mes;
```

**O que essa view entrega:**
- Receita isolada de cada mês
- Receita acumulada (YTD) progressiva — essencial para saber se o ano está no caminho certo
- `PARTITION BY ano` garante que o acumulado reinicia a cada ano

---

### 2. `vw_crescimento_mensal` — Crescimento Month-over-Month com LAG

> **Pergunta de negócio:** *"A receita está crescendo ou caindo mês a mês? Qual o percentual de variação?"*

**Conceitos SQL:** `CTE encadeada` (vírgula mágica) · `LAG()` · `CASE WHEN` (defesa contra divisão por zero) · `::NUMERIC` (Type Casting)

```sql
CREATE OR REPLACE VIEW vw_crescimento_mensal AS
WITH vendas_mensais AS (
    SELECT 
        EXTRACT(YEAR FROM o.order_date) AS ano,
        EXTRACT(MONTH FROM o.order_date) AS mes,
        SUM(od.unit_price * od.quantity) AS faturamento_atual
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    GROUP BY EXTRACT(YEAR FROM o.order_date), EXTRACT(MONTH FROM o.order_date)
),
faturamento_com_lag AS (
    SELECT 
        ano, mes, faturamento_atual,
        LAG(faturamento_atual) OVER (ORDER BY ano, mes) AS faturamento_anterior
    FROM vendas_mensais
)
SELECT 
    ano, mes, faturamento_atual, faturamento_anterior,
    CASE
        WHEN faturamento_anterior IS NULL OR faturamento_anterior = 0 THEN 0
        ELSE ROUND(((faturamento_atual - faturamento_anterior) / faturamento_anterior * 100)::NUMERIC, 2)
    END AS percentual_growth
FROM faturamento_com_lag;
```

**O que essa view entrega:**
- Receita atual vs receita do mês anterior lado a lado
- Percentual de crescimento/queda (MoM%)
- `CASE WHEN` protege contra `DivisionByZero` — se o mês anterior for NULL ou zero, retorna 0 em vez de crashar

**Decisão técnica:** CTEs encadeadas com vírgula (`WITH vendas_mensais AS (...), faturamento_com_lag AS (...)`) criam uma "linha de montagem" — cada etapa lê a anterior, mantendo o código legível.

---

### 3. `vw_top_10_produtos` — Ranking dos 10 Produtos que Mais Faturam

> **Pergunta de negócio:** *"Quais são os 10 produtos que mais geram receita?"*

**Conceitos SQL:** `JOIN` · `GROUP BY` · `SUM` · `ORDER BY DESC` · `LIMIT`

```sql
CREATE OR REPLACE VIEW vw_top_10_produtos AS
SELECT 
    p.product_name,
    SUM(od.unit_price * od.quantity) AS vendas
FROM order_details od
JOIN products p ON p.product_id = od.product_id
GROUP BY p.product_id, od.product_id, p.product_name
ORDER BY SUM(od.unit_price * od.quantity) DESC
LIMIT 10;
```

**O que essa view entrega:**
- Top 10 produtos ordenados por receita total
- Base para análise de portfólio de produtos (Pareto 80/20)
- Identifica quais produtos concentram o faturamento

---

### 4. `vw_top_funcionarios_1997` — Top 5 Vendedores do Ano de 1997

> **Pergunta de negócio:** *"Quais funcionários geraram mais receita em 1997?"*

**Conceitos SQL:** `JOIN` (3 tabelas) · `WHERE` com `EXTRACT` · `GROUP BY` · `SUM` · `LIMIT`

```sql
CREATE OR REPLACE VIEW vw_top_funcionarios_1997 AS
SELECT 
    e.first_name,
    e.last_name,
    SUM(od.unit_price * od.quantity) AS faturamento_total
FROM employees e
JOIN orders o ON e.employee_id = o.employee_id
JOIN order_details od ON o.order_id = od.order_id
WHERE EXTRACT(YEAR FROM o.order_date) = 1997
GROUP BY e.first_name, e.last_name
ORDER BY SUM(od.unit_price * od.quantity) DESC
LIMIT 5;
```

**O que essa view entrega:**
- Os 5 funcionários com maior volume de vendas em 1997
- JOIN com 3 tabelas: `employees` → `orders` → `order_details`
- Filtro temporal com `EXTRACT(YEAR FROM ...)` para isolar o ano

---

### 5. `vw_segmentacao_clientes` — Segmentação por Volume de Compras (NTILE)

> **Pergunta de negócio:** *"Como segmentar a base de clientes por comportamento de compra? Quem são os premium, regulares e low-value?"*

**Conceitos SQL:** `CTE` · `NTILE(5)` · Window Function de ranking · `CASE WHEN` · Desconto aplicado · `::NUMERIC`

```sql
CREATE OR REPLACE VIEW vw_segmentacao_clientes AS
WITH receita_por_cliente AS (
    SELECT 
        c.customer_id,
        c.company_name,
        c.country,
        SUM(od.unit_price * od.quantity * (1 - od.discount)) AS total_gasto
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_details od ON o.order_id = od.order_id
    GROUP BY c.customer_id, c.company_name, c.country
)
SELECT 
    customer_id,
    company_name,
    country,
    ROUND(total_gasto::NUMERIC, 2) AS total_gasto,
    NTILE(5) OVER (ORDER BY total_gasto DESC) AS quintil,
    CASE
        WHEN NTILE(5) OVER (ORDER BY total_gasto DESC) <= 2 THEN 'Premium (Top 40%)'
        WHEN NTILE(5) OVER (ORDER BY total_gasto DESC) <= 4 THEN 'Regular'
        ELSE 'Low Value'
    END AS segmento
FROM receita_por_cliente
ORDER BY total_gasto DESC;
```

**O que essa view entrega:**
- Cada cliente classificado em 5 quintis por volume de compras
- Labels automáticos: Premium (Top 40%), Regular, Low Value
- Considera desconto no cálculo (`1 - od.discount`)
- Base pronta para campanhas de marketing segmentadas

---

### 6. `vw_clientes_uk_premium` — Clientes UK High-Value (> $1.000)

> **Pergunta de negócio:** *"Quais clientes do Reino Unido são high-value, com mais de $1.000 em compras?"*

**Conceitos SQL:** `WHERE` + `HAVING` (filtro em duas camadas) · `JOIN` · `GROUP BY` · `SUM`

```sql
CREATE OR REPLACE VIEW vw_clientes_uk_premium AS
SELECT 
    c.country,
    c.customer_id,
    SUM(od.unit_price * od.quantity) AS faturamento_total
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_details od ON o.order_id = od.order_id
WHERE c.country = 'UK'
GROUP BY c.customer_id, c.company_name, c.country
HAVING SUM(od.unit_price * od.quantity) > 1000
ORDER BY SUM(od.unit_price * od.quantity) DESC;
```

**O que essa view entrega:**
- Lista de clientes UK com total acima de $1.000
- Demonstra a diferença crucial entre `WHERE` (filtra linhas antes do agrupamento) e `HAVING` (filtra grupos depois da agregação)
- `WHERE` seleciona o país → `GROUP BY` agrupa → `HAVING` filtra pelo total

---

### 7. `vw_clientes_vip` — Classificação VIP (Top 40% por Faturamento)

> **Pergunta de negócio:** *"Quem são os nossos clientes VIP — os que realmente sustentam o negócio?"*

**Conceitos SQL:** `CTE encadeada` · `NTILE(5)` · `WHERE tier <= 2` · `JOIN` (3 tabelas)

```sql
CREATE OR REPLACE VIEW vw_clientes_vip AS
WITH faturamento_por_cliente AS (
    SELECT 
        c.company_name,
        SUM(od.unit_price * od.quantity) AS faturamento_total
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_details od ON o.order_id = od.order_id
    GROUP BY c.company_name
),
segmentacao AS (
    SELECT 
        faturamento_total,
        company_name,
        NTILE(5) OVER (ORDER BY faturamento_total DESC) AS tier_clientes
    FROM faturamento_por_cliente
)
SELECT 
    company_name,
    faturamento_total,
    tier_clientes
FROM segmentacao
WHERE tier_clientes <= 2;
```

**O que essa view entrega:**
- Apenas os clientes dos tiers 1 e 2 (Top 40%)
- Filtra automaticamente quem é VIP com base no volume de compras
- Combina CTE encadeada com NTILE para segmentar e depois filtrar

---

## 🗺️ Diagrama ER — Tabelas Utilizadas

```
┌──────────────┐     ┌─────────────────┐     ┌──────────────┐
│  customers   │     │     orders      │     │ order_details │
│──────────────│     │─────────────────│     │──────────────│
│ customer_id  │◄────│ customer_id     │     │ order_id     │
│ company_name │     │ order_id        │────►│ product_id   │
│ country      │     │ order_date      │     │ unit_price   │
│ contact_name │     │ employee_id     │     │ quantity     │
└──────────────┘     └────────┬────────┘     │ discount     │
                              │              └──────┬───────┘
                     ┌────────▼────────┐            │
                     │   employees     │    ┌───────▼──────┐
                     │─────────────────│    │   products   │
                     │ employee_id     │    │──────────────│
                     │ first_name      │    │ product_id   │
                     │ last_name       │    │ product_name │
                     └─────────────────┘    └──────────────┘
```

---

## 📚 Conceitos SQL Demonstrados

| Conceito | Onde aparece | Nível |
|---|---|---|
| `INNER JOIN` (2–3 tabelas) | Todas as views | Intermediário |
| `CTE` (`WITH ... AS`) | R1, R2, R5, R7 | Intermediário |
| `CTE encadeada` (vírgula) | R2, R7 | Avançado |
| `SUM() OVER (PARTITION BY)` | R1 (YTD acumulado) | Avançado |
| `LAG()` | R2 (crescimento MoM) | Avançado |
| `NTILE()` | R5, R7 (segmentação) | Avançado |
| `GROUP BY` + `ORDER BY` + `LIMIT` | R3, R4 | Intermediário |
| `WHERE` + `HAVING` | R6 (filtro duplo) | Intermediário |
| `CASE WHEN` (defesa pipeline) | R2, R5 | Avançado |
| `EXTRACT(YEAR/MONTH)` | R1, R2, R4 | Intermediário |
| Type Casting (`::NUMERIC`) | R1, R2, R5 | Avançado |
| `CREATE OR REPLACE VIEW` | Todas | Intermediário |

---

## 🧠 O Que Aprendi

1. **GROUP BY esmaga linhas, Window Functions preservam.** Quando preciso calcular uma métrica por grupo MAS manter os dados individuais na tela, uso `OVER (PARTITION BY ...)` em vez de `GROUP BY`.

2. **CTEs encadeadas são a "linha de montagem" do SQL.** Em vez de uma subquery aninhada ilegível, encadeio CTEs com vírgula: cada etapa lê a anterior. Usado em `vw_crescimento_mensal` e `vw_clientes_vip`.

3. **Sempre proteger contra divisão por zero.** Em produção, `CASE WHEN valor = 0 THEN 0 ELSE calculo END` é obrigatório. Um `DivisionByZero` derruba o pipeline inteiro.

4. **`WHERE` filtra antes do `GROUP BY`, `HAVING` filtra depois.** `vw_clientes_uk_premium` demonstra isso: `WHERE country = 'UK'` seleciona as linhas → `GROUP BY` agrupa → `HAVING SUM(...) > 1000` filtra os grupos.

5. **Type Casting é real.** PostgreSQL não aceita `ROUND()` com `FLOAT`. Precisa de `::NUMERIC` antes de arredondar.

6. **`NTILE(5)` transforma dados em segmentos de negócio.** Em vez de definir manualmente os cortes, o banco divide automaticamente em quintis. Tiers 1–2 = Premium, 3–4 = Regular, 5 = Low Value.

---

## 📂 Estrutura do Repositório

```
projeto_northwind/
├── docker-compose.yml          # PostgreSQL + PgAdmin
├── sql/
│   ├── northwind.sql           # Script de criação do banco
│   └── views.sql               # As 7 views analíticas
├── screenshots/                # Prints dos resultados (opcional)
└── README.md                   # Este arquivo
```

---

## 👤 Autor

**Samuel** 

---

*Projeto desenvolvido como parte do [Data Engineering Roadmap](https://github.com/lvgalvao/data-engineering-roadmap) — Projeto 05: SQL Advanced Analytics.*
