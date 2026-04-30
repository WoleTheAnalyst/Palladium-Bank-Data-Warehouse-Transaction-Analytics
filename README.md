# 🏦 Palladium Bank — Data Warehouse & Transaction Analytics

**Tool Used:** MySQL  
**Focus:** Data Warehouse Design · ETL Pipeline · Aggregation Layer  

---

## 📌 Project Overview

This project designs and implements a full data warehouse for Palladium Bank, a fictional retail bank. Using a star schema architecture, raw transaction data is modelled into a clean, query-optimised structure that supports branch performance analysis, customer behaviour tracking, product usage insights, and channel distribution reporting.

---

## 🗂️ Schema Design — Star Schema

The warehouse follows a classic **star schema** with one central fact table surrounded by five dimension tables.

### Fact Table

| Table | Description |
|---|---|
| `fact_transactions` | Core transaction records — amount, balance, type, and all foreign keys |

### Dimension Tables

| Table | Description |
|---|---|
| `dim_date` | Full date breakdown — day, month, quarter, year |
| `dim_customer` | Customer details and tier classification |
| `dim_branch` | Branch name and state location |
| `dim_product` | Product name and product type |
| `dim_channel` | Transaction channel (e.g. Mobile, ATM, Branch) |

---

## ⚙️ ETL Pipeline

The pipeline loads data from a raw staging table (`transaction_data - Sheet1`) into the warehouse in the following order:

1. **Rename and clean columns** — fix encoding issues in amount and balance fields
2. **Load dimension tables** — customers, branches, products, channels using `DISTINCT` selects
3. **Load `dim_date`** — generate date keys from `txn_date` using `DATE_FORMAT`
4. **Load `fact_transactions`** — join all dimension tables to resolve surrogate keys, then insert
5. **Deduplication guard** — second fact insert uses `WHERE txn_id NOT IN (...)` to prevent duplicates

### Data Quality Checks Included

```sql
-- Check for nulls
SELECT * FROM `transaction_data - Sheet1` WHERE amount IS NULL;

-- Check for duplicate transactions
SELECT txn_id, COUNT(*) FROM `transaction_data - Sheet1`
GROUP BY txn_id HAVING COUNT(*) > 1;

-- Check for negative amounts
SELECT * FROM `transaction_data - Sheet1` WHERE amount < 0;

-- Check for unmatched customers
SELECT s.txn_id FROM `transaction_data - Sheet1` s
LEFT JOIN dim_customer c ON s.customer_id = c.customer_id
WHERE c.customer_key IS NULL;
```

---

## 📊 Aggregation Layer

A pre-aggregated summary table `agg_monthly_branch_revenue` is built to support fast dashboard queries without hitting the full fact table each time.

| Column | Description |
|---|---|
| `total_txn_count` | Total number of transactions |
| `total_txn_volume` | Sum of all transaction amounts |
| `total_deposits` | Sum of deposit transactions only |
| `total_withdrawals` | Sum of withdrawal and ATM withdrawal transactions |
| `unique_customers` | Count of distinct customers per branch per month |

---

## 🚀 Performance Optimisation

Three indexes are applied to the fact table to speed up joins and filters:

```sql
CREATE INDEX idx_fact_date     ON fact_transactions(date_key);
CREATE INDEX idx_fact_customer ON fact_transactions(customer_key);
CREATE INDEX idx_fact_branch   ON fact_transactions(branch_key);
```

---

## 🛠️ Tools Used

- **MySQL** — schema design, ETL, aggregation, indexing
- **dbdiagram.io** — schema visualisation
- **Excel / CSV** — raw data staging

---

## 📂 Files in this Repository

| File | Description |
|---|---|
| `palladium_bank_schema.sql` | Full schema — table creation, ETL pipeline, data quality checks, aggregation |
| `schema_diagram.png` | Star schema ERD from dbdiagram.io |

---

## 👤 Author

**Kolawole Odewusi**  
Data Analyst | Excel · Python · Power BI · SQL  
[LinkedIn](https://www.linkedin.com/in/kolawole-odewusi-940438231/) · [GitHub](https://github.com/WoleTheAnalyst)
