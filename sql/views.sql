-- =============================================================
-- Northwind SQL Analytics — Views Analíticas
-- Autor: Samuel
-- Banco: PostgreSQL 15+ (Northwind)
-- Descrição: 7 views de Business Intelligence prontas para
--            dashboards e análise de dados comerciais.
-- =============================================================
-- Execução: psql -h localhost -U postgres -d northwind -f views.sql
-- Ou: colar no PgAdmin e executar tudo de uma vez.
-- =============================================================


-- =============================================================
-- VIEW 1: vw_receita_ytd
-- Pergunta: Qual a receita mês a mês e o acumulado do ano?
-- Conceitos: CTE, SUM() OVER (PARTITION BY), Window Function
-- =============================================================

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


-- =============================================================
-- VIEW 2: vw_crescimento_mensal
-- Pergunta: A receita está crescendo ou caindo mês a mês?
-- Conceitos: CTE encadeada, LAG(), CASE WHEN, ::NUMERIC
-- =============================================================

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


-- =============================================================
-- VIEW 3: vw_top_10_produtos
-- Pergunta: Quais são os 10 produtos que mais faturam?
-- Conceitos: GROUP BY, SUM, ORDER BY DESC, LIMIT
-- =============================================================

CREATE OR REPLACE VIEW vw_top_10_produtos AS
SELECT 
    p.product_name,
    SUM(od.unit_price * od.quantity) AS vendas
FROM order_details od
JOIN products p ON p.product_id = od.product_id
GROUP BY p.product_id, od.product_id, p.product_name
ORDER BY SUM(od.unit_price * od.quantity) DESC
LIMIT 10;


-- =============================================================
-- VIEW 4: vw_top_funcionarios_1997
-- Pergunta: Quais funcionários geraram mais receita em 1997?
-- Conceitos: JOIN 3 tabelas, WHERE EXTRACT, GROUP BY, LIMIT
-- =============================================================

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


-- =============================================================
-- VIEW 5: vw_segmentacao_clientes
-- Pergunta: Como segmentar a base por comportamento de compra?
-- Conceitos: CTE, NTILE(5), CASE WHEN, desconto aplicado
-- =============================================================

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


-- =============================================================
-- VIEW 6: vw_clientes_uk_premium
-- Pergunta: Quais clientes UK têm mais de $1.000 em compras?
-- Conceitos: WHERE + HAVING (filtro em duas camadas), JOIN
-- =============================================================

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


-- =============================================================
-- VIEW 7: vw_clientes_vip
-- Pergunta: Quem são os clientes VIP (Top 40%)?
-- Conceitos: CTE encadeada, NTILE(5), WHERE tier <= 2
-- =============================================================

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


-- =============================================================
-- FIM — 7 views criadas com sucesso.
-- Verificar: SELECT table_name FROM information_schema.views 
--            WHERE table_schema = 'public' AND table_name LIKE 'vw_%';
-- =============================================================
