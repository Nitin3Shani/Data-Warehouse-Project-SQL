/*
==========================================================================
Quality Check
==========================================================================
Script Purpose : 
            This script performs various quality checks for data consistency, accuracy,
            and standardization across the 'Silver' schema.
            - Null or duplicate primary keys.
            - Unwanted spaces in string fields.
            - Data standardization and consistency.
            - Invalid date ranges and orders.
            - Data consistency between  related fields.

Usage Notes :
          - Run these checks after data loading silver layer.
          - Investigate and resolve any discrepancies found during the checks.
============================================================================
*/


-- check : For Nulls or Duplicates in Primary Key
-- Expectations : No Result
select
cst_id,
count(*)
from silver.crm_cust_info
group by cst_id
having count(*) > 1 or cst_id is null;

-- Check for Unwanted Spaces
-- Expectation : No Result
select
cst_key
from silver.crm_cust_info
where cst_firstname != TRIM(cst_firstname);

-- Data Standardization
select distinct cst_marital_status
from silver.crm_cust_info;

select * from silver.crm_cust_info;

--===========================================================================================

--2nd).silver.crm_prd_info
-- check : For Nulls or Duplicates in Primary Key
-- Expectations : No Result
select
prd_id,
count(*)
from silver.crm_prd_info
group by prd_id
having count(*) > 1 or prd_id is null;


-- Check for Unwanted Spaces
-- Expectation : No Result
select
prd_nm
from silver.crm_prd_info
where prd_nm != TRIM(prd_nm);


-- Check for NULLs or Negative Numbers
-- Expectation : No Result

select
*
from silver.crm_prd_info
where  prd_cost is null or prd_cost < 0;

-- Data Standardization & Consistency
select
distinct prd_line
from silver.crm_prd_info

-- Check for Invalid Date Orders
select
*
from silver.crm_prd_info
where prd_end_date < prd_start_date;


--============================================================================================

--3rd).Bronze.crm_sales_details

--Check for Invalid Dates
select
nullif(sls_order_dt,0) as sls_order_dt
from bronze.crm_sales_details
where sls_order_dt <= 0  
or len(sls_order_dt) != 8
or sls_order_dt > 20500101
or sls_order_dt < 19000101;

--Check for Invalid Dates
select
nullif(sls_ship_dt,0) as sls_ship_dt
from bronze.crm_sales_details
where sls_ship_dt <= 0  
or len(sls_ship_dt) != 8
or sls_ship_dt > 20500101
or sls_ship_dt < 19000101;

--Check for Invalid Dates
select
nullif(sls_due_dt,0) as sls_due_dt
from bronze.crm_sales_details
where sls_due_dt <= 0  
or len(sls_due_dt) != 8
or sls_due_dt > 20500101
or sls_due_dt < 19000101;


-- Check for invalid Date Orders
select
*
from silver.crm_sales_details
where sls_order_dt > sls_ship_dt or sls_order_dt > sls_due_dt;


-- Check Data Consistency : Between Sales, Qunatity, and Price
-- >> Sales = Quantity * Price
-- >> Values must not be NULL,zero, or negative.
select distinct
sls_ord_num,
sls_sales as old_sls_sales,
sls_quantity,
sls_price as old_sls_price,
case when sls_sales is null or sls_sales <= 0 or sls_sales != abs(sls_price) * sls_quantity
     then abs(sls_price) * sls_quantity
     else sls_sales
end as sls_sales,
case when sls_price is null or sls_price <= 0 
     then sls_sales / nullif(sls_quantity,0)
     else sls_price
end as sls_price
from silver.crm_sales_details
where sls_sales !=  sls_quantity * sls_price or sls_sales <= 0  or sls_sales is null
or sls_quantity <= 0  or sls_quantity is null
or sls_price <= 0  or sls_price is null
order by sls_sales, sls_quantity, sls_price;

--============================================================================================
--1). bronze.erp_cust_az12
select
cid,
case when cid like 'NAS%' then SUBSTRING(cid,4,len(cid))
     else cid
end as cid,
bdate,
gen
from bronze.erp_cust_az12;

-- Indentify Out-of-Range Dates
select distinct
bdate
from silver.erp_cust_az12
where bdate < '1924-01-01' or bdate > getdate();

--Data Standardization & Consistency
select distinct
gen
from silver.erp_cust_az12;

--============================================================================================
--2nd). bronze.erp_loc_a101
-- Data Standardization & Consistency
select distinct
cntry
from silver.erp_loc_a101;
