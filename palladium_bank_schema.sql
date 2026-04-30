create database bankdata;
use bankdata;

CREATE TABLE dim_branch (
    branch_key      SERIAL          PRIMARY KEY,
    branch_id       VARCHAR(10)     NOT NULL,
    branch_name     VARCHAR(100)    NOT NULL,
    state           VARCHAR(50)     NOT NULL
);


CREATE TABLE dim_product (
    product_key     SERIAL          PRIMARY KEY,
    product_id      VARCHAR(10)     NOT NULL,
    product_name    VARCHAR(100)    NOT NULL,
    product_type    VARCHAR(50)     NOT NULL
);


CREATE TABLE dim_channel (
    channel_key     SERIAL          PRIMARY KEY,
    channel_name    VARCHAR(50)     NOT NULL
);


CREATE TABLE dim_date (
    date_key        INT             PRIMARY KEY,  
    full_date       DATE            NOT NULL,
    day_number      INT             NOT NULL,
    month_number    INT             NOT NULL,
    month_name      VARCHAR(10)     NOT NULL,
    quarter_number  INT             NOT NULL,
    year_number     INT             NOT NULL
);

CREATE TABLE dim_customer (
    customer_key    SERIAL          PRIMARY KEY,  
    customer_id     VARCHAR(10)     NOT NULL,     
    customer_name   VARCHAR(100)    NOT NULL,     
    tier            VARCHAR(20)     NOT NULL      
);



CREATE TABLE fact_transactions (
    transaction_key   SERIAL          PRIMARY KEY,  
    
    date_key          INT             NOT NULL REFERENCES dim_date(date_key),
    customer_key      INT             NOT NULL REFERENCES dim_customer(customer_key),
    branch_key        INT             NOT NULL REFERENCES dim_branch(branch_key),
    product_key       INT             NOT NULL REFERENCES dim_product(product_key),
    channel_key       INT             NOT NULL REFERENCES dim_channel(channel_key),
    
   
    txn_id            VARCHAR(20)     NOT NULL UNIQUE,  
    txn_type          VARCHAR(50)     NOT NULL,        
    
  
    amount            NUMERIC(18,2)   NOT NULL,
    balance_after     NUMERIC(18,2)   NULL
);

ALTER TABLE `transaction_data - Sheet1`
CHANGE `Amount (â‚¦)` `amount` NUMERIC(18,2),
CHANGE `Balance_After (â‚¦)` `balance_after` NUMERIC(18,2);


INSERT INTO dim_customer (customer_id, customer_name, tier)
SELECT DISTINCT customer_id, customer_name, tier
FROM `transaction_data - sheet1`;

INSERT INTO dim_branch (branch_id, branch_name, state)
SELECT DISTINCT branch_id, branch_name, state
FROM `transaction_data - Sheet1`;

INSERT INTO dim_product (product_id, product_name, product_type)
SELECT DISTINCT product_id, product_name, product_type
FROM `transaction_data - Sheet1`;

INSERT INTO dim_channel (channel_name)
SELECT DISTINCT channel
FROM `transaction_data - Sheet1`;


INSERT INTO fact_transactions 
(date_key, customer_key, branch_key, product_key, channel_key, txn_id, txn_type, amount, balance_after)
SELECT 
    CAST(DATE_FORMAT(s.txn_date, '%Y%m%d') AS UNSIGNED),
    c.customer_key,
    b.branch_key,
    p.product_key,
    ch.channel_key,
    s.txn_id,
    s.txn_type,
    s.amount,
    s.balance_after
FROM `transaction_data - Sheet1` s
JOIN dim_customer c  ON s.customer_id = c.customer_id
JOIN dim_branch b    ON s.branch_id   = b.branch_id
JOIN dim_product p   ON s.product_id  = p.product_id
JOIN dim_channel ch  ON s.channel     = ch.channel_name;





INSERT INTO dim_date (date_key, full_date, day_number, month_number, month_name, quarter_number, year_number)
SELECT DISTINCT
    CAST(DATE_FORMAT(txn_date, '%Y%m%d') AS UNSIGNED),
    DATE(txn_date),
    DAY(txn_date),
    MONTH(txn_date),
    MONTHNAME(txn_date),
    QUARTER(txn_date),
    YEAR(txn_date)
FROM `transaction_data - Sheet1`;



INSERT INTO fact_transactions 
(date_key, customer_key, branch_key, product_key, channel_key, txn_id, txn_type, amount, balance_after)
SELECT 
    CAST(DATE_FORMAT(s.txn_date, '%Y%m%d') AS UNSIGNED),
    c.customer_key,
    b.branch_key,
    p.product_key,
    ch.channel_key,
    s.txn_id,
    s.txn_type,
    s.amount,
    s.balance_after
FROM `transaction_data - Sheet1` s
JOIN dim_customer c  ON s.customer_id = c.customer_id
JOIN dim_branch b    ON s.branch_id   = b.branch_id
JOIN dim_product p   ON s.product_id  = p.product_id
JOIN dim_channel ch  ON s.channel     = ch.channel_name
WHERE s.txn_id NOT IN (SELECT txn_id FROM fact_transactions);

INSERT INTO dim_customer (customer_id, customer_name, tier)
SELECT DISTINCT s.customer_id, s.customer_name, s.tier
FROM `transaction_data - Sheet1` s
WHERE s.customer_id NOT IN (SELECT customer_id FROM dim_customer);

SELECT * FROM `transaction_data - Sheet1`
WHERE amount IS NULL;

SELECT txn_id, COUNT(*) 
FROM `transaction_data - Sheet1`
GROUP BY txn_id
HAVING COUNT(*) > 1;

SELECT * FROM `transaction_data - Sheet1`
WHERE amount < 0;

SELECT s.txn_id 
FROM `transaction_data - Sheet1` s
LEFT JOIN dim_customer c ON s.customer_id = c.customer_id
WHERE c.customer_key IS NULL;




CREATE INDEX idx_fact_date 
ON fact_transactions(date_key);

CREATE INDEX idx_fact_customer 
ON fact_transactions(customer_key);


CREATE INDEX idx_fact_branch 
ON fact_transactions(branch_key);


CREATE TABLE agg_monthly_branch_revenue (
    year_number         INT             NOT NULL,
    month_number        INT             NOT NULL,
    month_name          VARCHAR(10)     NOT NULL,
    branch_key          INT             NOT NULL,
    branch_name         VARCHAR(100)    NOT NULL,
    state               VARCHAR(50)     NOT NULL,
    total_txn_count     INT             NOT NULL DEFAULT 0,
    total_txn_volume    NUMERIC(20,2)   NOT NULL DEFAULT 0.00,
    total_deposits      NUMERIC(20,2)   NOT NULL DEFAULT 0.00,
    total_withdrawals   NUMERIC(20,2)   NOT NULL DEFAULT 0.00,
    unique_customers    INT             NOT NULL DEFAULT 0,
    PRIMARY KEY (year_number, month_number, branch_key)
);



INSERT INTO agg_monthly_branch_revenue
(year_number, month_number, month_name, branch_key, branch_name, state,
total_txn_count, total_txn_volume, total_deposits, total_withdrawals, unique_customers)

SELECT
    d.year_number,
    d.month_number,
    d.month_name,
    b.branch_key,
    b.branch_name,
    b.state,
    COUNT(f.transaction_key)                                        AS total_txn_count,
    SUM(f.amount)                                               AS total_txn_volume,
    SUM(CASE WHEN f.txn_type = 'Deposit' THEN f.amount ELSE 0 END) AS total_deposits,
    SUM(CASE WHEN f.txn_type IN ('Withdrawal', 'ATM Withdrawal') THEN f.amount ELSE 0 END) AS total_withdrawals,
    COUNT(DISTINCT f.customer_key)                                  AS unique_customers
FROM fact_transactions f
JOIN dim_date d   ON f.date_key   = d.date_key
JOIN dim_branch b ON f.branch_key = b.branch_key
GROUP BY d.year_number, d.month_number, d.month_name, b.branch_key, b.branch_name, b.state;


