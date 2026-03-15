# 🏢 Data Warehouse Project — SQL (Medallion Architecture)

![SQL Server](https://img.shields.io/badge/SQL%20Server-T--SQL-blue?logo=microsoftsqlserver)
![Architecture](https://img.shields.io/badge/Architecture-Medallion%20(Bronze%20→%20Silver%20→%20Gold)-gold)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

A fully structured data warehouse built with **Microsoft SQL Server** using the **Medallion Architecture** (Bronze → Silver → Gold). The project ingests raw data from two source systems (CRM and ERP), applies robust data cleansing and transformation, and surfaces analytics-ready views for reporting and business intelligence.

---

## 📑 Table of Contents

- [Project Overview](#-project-overview)
- [Architecture](#-architecture)
- [Repository Structure](#-repository-structure)
- [Data Sources](#-data-sources)
- [Layer Breakdown](#-layer-breakdown)
  - [Bronze Layer](#-bronze-layer--raw-ingestion)
  - [Silver Layer](#-silver-layer--cleansed--transformed)
  - [Gold Layer](#-gold-layer--business-ready-star-schema)
- [Data Quality Checks](#-data-quality-checks)
- [Getting Started](#-getting-started)
- [Documentation](#-documentation)
- [About Me](#-about-me)

---

## 📌 Project Overview

This project demonstrates the end-to-end design and implementation of a modern data warehouse. Key objectives include:

- Consolidating data from **CRM** and **ERP** source systems into a unified warehouse
- Applying the **ETL pattern** (Extract → Transform → Load) across three schema layers
- Delivering a clean **Star Schema** in the Gold layer for analytical querying
- Ensuring data integrity through automated **quality checks**

---

## 🏛️ Architecture

The warehouse follows the **Medallion Architecture** pattern, progressively refining data across three layers:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   SOURCE    │────▶│   BRONZE    │────▶│   SILVER    │────▶│    GOLD    │
│  CRM + ERP  │     │  Raw Copy   │     │  Cleansed   │     │  Star      │
│  CSV Files  │     │  (Staging)  │     │  Enriched   │     │  Schema    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

| Layer  | Schema   | Purpose                                          |
|--------|----------|--------------------------------------------------|
| Bronze | `bronze` | Raw data ingested from CSV files — no transformation |
| Silver | `silver` | Cleansed, standardized, and deduplicated data    |
| Gold   | `gold`   | Business-ready dimension & fact views (Star Schema) |

---

## 📁 Repository Structure

```
Data-Warehouse-Project-SQL/
│
├── datasets/
│   ├── source_crm/
│   │   ├── cust_info.csv          # Customer master data
│   │   ├── prd_info.csv           # Product master data
│   │   └── sales_details.csv      # Sales transactions
│   └── source_erp/
│       ├── CUST_AZ12.csv          # Customer demographics (ERP)
│       ├── LOC_A101.csv           # Customer location data
│       └── PX_CAT_G1V2.csv        # Product category data
│
├── docs/
│   ├── 1).Data_Warehouse_Architecture.png
│   ├── 2).Data_Flow_Diagram.png
│   ├── 3).Data_Integration.png
│   ├── 4).Sales_Data_Mart.png
│   └── data_catalog.md            # Gold layer data dictionary
│
├── scripts/
│   ├── init_database.sql          # Database & schema creation
│   ├── bronze/
│   │   ├── ddl_bronze.sql         # Bronze table definitions
│   │   └── proc_load_bronze.sql   # Bulk load stored procedure
│   ├── silver/
│   │   ├── ddl_silver.sql         # Silver table definitions
│   │   └── proc_load_silver.sql   # ETL transformation stored procedure
│   └── gold/
│       └── ddl.gold.sql           # Gold layer view definitions
│
├── tests/
│   └── quality_checks_silver.sql  # Data quality validation scripts
│
├── LICENSE
└── README.md
```

---

## 🗄️ Data Sources

| Source | Tables / Files | Description |
|--------|---------------|-------------|
| **CRM** | `cust_info.csv` | Customer identifiers, names, gender, marital status |
| **CRM** | `prd_info.csv` | Product codes, costs, product lines, lifecycle dates |
| **CRM** | `sales_details.csv` | Order numbers, quantities, prices, and dates |
| **ERP** | `CUST_AZ12.csv` | Customer birthdates and gender (supplementary) |
| **ERP** | `LOC_A101.csv` | Customer country / location data |
| **ERP** | `PX_CAT_G1V2.csv` | Product categories, subcategories, and maintenance flags |

---

## 🔩 Layer Breakdown

### 🥉 Bronze Layer — Raw Ingestion

The Bronze layer is a **faithful copy** of the source CSV data, loaded without any transformation. It acts as the staging area and historical record of all source data.

**Tables:**

| Table | Source |
|-------|--------|
| `bronze.crm_cust_info` | CRM customer info |
| `bronze.crm_prd_info` | CRM product info |
| `bronze.crm_sales_details` | CRM sales transactions |
| `bronze.erp_cust_az12` | ERP customer demographics |
| `bronze.erp_loc_a101` | ERP customer locations |
| `bronze.erp_px_cat_g1v2` | ERP product categories |

Data is loaded via the stored procedure: `bronze.load_bronze` using `BULK INSERT` from the CSV files.

---

### 🥈 Silver Layer — Cleansed & Transformed

The Silver layer applies business rules and transformations to produce clean, consistent, and deduplicated data. Key transformations include:

- **Deduplication** — Retains only the latest customer record per `cst_id` using `ROW_NUMBER()`
- **Whitespace trimming** — All string fields cleaned with `TRIM()`
- **Code standardization** — Gender (`M/F → Male/Female`), marital status (`M/S → Married/Single`), product line codes (`M/R/S/T → Mountain/Road/Other Sales/Touring`) all mapped to human-readable labels
- **Date validation** — Integer-encoded dates (e.g. `20210115`) validated and cast to `DATE`; invalid/future dates set to `NULL`
- **Derived fields** — `cat_id` extracted from composite `prd_key`; product `prd_end_date` calculated as one day before the next product version's start date
- **Sales recalculation** — `sls_sales` recomputed as `|price| × quantity` when original value is missing, zero, or inconsistent
- **ERP key normalization** — `NAS` prefix stripped from ERP customer IDs; country code abbreviations expanded (e.g. `US/USA → United States`, `DE → Germany`)

Loaded via: `EXEC silver.load_silver`

---

### 🥇 Gold Layer — Business-Ready Star Schema

The Gold layer exposes three SQL **Views** forming a clean Star Schema for analytics and reporting. No data is physically stored — the views join and enrich Silver data on the fly.

#### `gold.dim_customers`
Customer dimension enriched by joining CRM and ERP data. CRM is treated as the master system for gender, with ERP used as fallback.

| Column | Type | Description |
|--------|------|-------------|
| `customer_key` | INT | Surrogate key (generated via `ROW_NUMBER()`) |
| `customer_id` | INT | Source customer ID |
| `customer_number` | NVARCHAR(50) | Alphanumeric tracking identifier |
| `first_name` | NVARCHAR(50) | First name |
| `last_name` | NVARCHAR(50) | Last name |
| `country` | NVARCHAR(50) | Country of residence |
| `marital_status` | NVARCHAR(50) | Married / Single |
| `gender` | NVARCHAR(50) | Male / Female / n/a |
| `birthdate` | DATE | Date of birth |
| `create_date` | DATE | Record creation date |

#### `gold.dim_products`
Product dimension joined with ERP category data. Historical product records (where `prd_end_date IS NOT NULL`) are excluded.

| Column | Type | Description |
|--------|------|-------------|
| `product_key` | INT | Surrogate key |
| `product_id` | INT | Source product ID |
| `product_number` | NVARCHAR(50) | Product code |
| `product_name` | NVARCHAR(50) | Descriptive product name |
| `category_id` | NVARCHAR(50) | Category identifier |
| `category` | NVARCHAR(50) | Product category (e.g. Bikes) |
| `subcategory` | NVARCHAR(50) | Product subcategory |
| `maintenance_required` | NVARCHAR(50) | Yes / No |
| `cost` | INT | Unit cost |
| `product_line` | NVARCHAR(50) | Road / Mountain / Touring / Other |
| `start_date` | DATE | Product availability start date |

#### `gold.fact_sales`
Central fact table joining sales transactions with product and customer dimension surrogate keys.

| Column | Type | Description |
|--------|------|-------------|
| `order_number` | NVARCHAR(50) | Unique order identifier |
| `product_key` | INT | FK → `dim_products` |
| `customer_key` | INT | FK → `dim_customers` |
| `order_date` | DATE | Date order was placed |
| `shipping_date` | DATE | Date order was shipped |
| `due_date` | DATE | Payment due date |
| `sales_amount` | INT | Total sale value |
| `quantity` | INT | Units ordered |
| `price` | INT | Unit price |

---

## ✅ Data Quality Checks

After loading the Silver layer, run `tests/quality_checks_silver.sql` to validate:

| Check | Target | Expectation |
|-------|--------|-------------|
| Null or duplicate PKs | `crm_cust_info`, `crm_prd_info` | No results |
| Unwanted whitespace | String columns | No results |
| Negative / null costs | `prd_cost` | No results |
| Invalid date ranges | Birthdates, order dates | No results |
| Date order violations | `order_dt > ship_dt` | No results |
| Sales consistency | `sales ≠ qty × price` | No results |
| Data standardization | Gender, marital status, country | Distinct clean values |

---

## 🚀 Getting Started

### Prerequisites

- Microsoft SQL Server (2019 or later recommended)
- SQL Server Management Studio (SSMS) or Azure Data Studio
- Source CSV files placed in the `datasets/` directory

### Execution Order

Run the scripts in the following sequence:

```sql
-- Step 1: Initialize the database and schemas
-- ⚠️ WARNING: Drops and recreates the DataWarehouse database
scripts/init_database.sql

-- Step 2: Create Bronze tables
scripts/bronze/ddl_bronze.sql

-- Step 3: Load raw data into Bronze
scripts/bronze/proc_load_bronze.sql
EXEC bronze.load_bronze;

-- Step 4: Create Silver tables
scripts/silver/ddl_silver.sql

-- Step 5: Transform and load Silver
scripts/silver/proc_load_silver.sql
EXEC silver.load_silver;

-- Step 6: Create Gold views
scripts/gold/ddl.gold.sql

-- Step 7: Run quality checks
tests/quality_checks_silver.sql
```

> ⚠️ **Important:** `init_database.sql` will **drop and recreate** the `DataWarehouse` database. Ensure you have backups before running in any environment with existing data.

---

## 📖 Documentation

Detailed diagrams are available in the `docs/` folder:

| Document | Description |
|----------|-------------|
| `1).Data_Warehouse_Architecture.png` | Overall warehouse architecture |
| `2).Data_Flow_Diagram.png` | Data flow across all layers |
| `3).Data_Integration.png` | Source-to-target integration mapping |
| `4).Sales_Data_Mart.png` | Star schema / sales data mart design |
| `data_catalog.md` | Full Gold layer data dictionary |

---

## 👤 About Me

Hi! I'm **Nitin Shani** — a data professional passionate about building scalable data infrastructure and turning raw data into actionable insights.

**🔧 Skills & Tech Stack:**
- **Databases:** SQL Server, T-SQL, PostgreSQL
- **Data Engineering:** ETL pipelines, Data Warehousing, Medallion Architecture
- **Tools:** SSMS, Power BI, draw.io
- **Concepts:** Star Schema, Data Modeling, Data Quality, Stored Procedures

**🌐 Connect with me:**
- 🐙 [GitHub](https://github.com/your-username)
- 📧 nitinshani91@gmail.com

---

> *Feel free to fork this project, raise issues, or reach out if you'd like to collaborate!*
