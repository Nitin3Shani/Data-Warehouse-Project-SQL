/*
=========================================================================================
Stored Procedure : Load silver Layer (Bronze -> Silver)
=========================================================================================
Script Purpose:
              This stored procedure performes the ETL (Extract, Transform, Load) process to
              populate the 'silver' schema tables from the 'bronze' schema.
  Actions Performed :
        - Truncates silver tables.
        - Inserts transformed and cleansed data from Bronze into Silver tables.

parameters:
        None.
        This stored procedure does not accept any parameters or return any values.

Usage Example: 
          Exec Silver.load_silver;
=========================================================================================
*/

create or alter procedure silver.load_silver as 
begin
    begin try
        declare @start_time datetime, @end_time datetime,@batch_start_time datetime, @batch_end_time datetime;

         set @batch_start_time = getdate();
		    print'====================================================================================';
		    print'Loading Silver Layer';
		    print'====================================================================================';

		    print'------------------------------------------------------------------------------------';
		    print'Loading CRM Tables';
		    print'------------------------------------------------------------------------------------';

        set @start_time = getdate();
        print'>> Truncating Table : silver.crm_cust_info';
        truncate table silver.crm_cust_info;
        --1).silver.crm_cust_info
        insert into silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )

        select
        cst_id,
        cst_key,
        trim(cst_firstname) as cst_firstname,
        trim(cst_lastname) as cst_lastname,
        case when upper(trim(cst_marital_status)) = 'M' then 'Married'
	         when UPPER(trim(cst_marital_status)) = 'S' then 'Single'
	         else 'n/a'
        end	 cst_material_status,
        case when upper(trim(cst_gndr)) = 'M' then 'Male'
	         when upper(trim(cst_gndr)) = 'F' then 'Female'
	         else 'n/a'
        end  cst_gndr,
        cst_create_date
        from
        (
        select 
        *,
        ROW_NUMBER() over(partition by cst_id order by cst_create_date desc) as flag_last
        from bronze.crm_cust_info
        where cst_id is not null)t
        where flag_last = 1  ;

   	    set @end_time = getdate();
	    print'>> Load Duration : ' + cast(datediff(second,@start_time,@end_time) as nvarchar) + ' Seconds';
	    print'-------------------------------------------------------------------------------------------------------------------';


        set @start_time = getdate();
        print'>> Truncating Table : silver.crm_prd_info';
        truncate table silver.crm_prd_info;
        --2).silver.crm_prd_info
        insert into silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_date,
            prd_end_date
        )
        select
        prd_id,
        replace(SUBSTRING(prd_key,1,5),'-','_') as cat_id,--Extract category id
        SUBSTRING(prd_key,7,len(prd_key)) as prd_key, --Extract product key
        prd_nm,
        coalesce(prd_cost,0) as prd_cost,
        case when upper(trim(prd_line)) = 'M' then 'Mountain'
	         when upper(trim(prd_line)) = 'R' then 'Road'
	         when upper(trim(prd_line)) = 'S' then 'other Sales'
	         when upper(trim(prd_line)) = 'T' then 'Touring'
             else 'n/a'
        end as prd_line,-- Map product line codes to descriptive values
        prd_start_date,
        CAST(
            cast((lead(prd_start_date) over(partition by prd_key order by prd_start_date)) as datetime) - 1
        AS date) AS prd_end_date -- Calculate end date as one day before the next start date
        from bronze.crm_prd_info;
        set @end_time = getdate();
	    print'>> Load Duration : ' + cast(datediff(second,@start_time,@end_time) as nvarchar) + ' Seconds';
	    print'-------------------------------------------------------------------------------------------------------------------';


        set @start_time = getdate();
        print'>> Truncating Table : silver.crm_sales_details';
        truncate table silver.crm_sales_details;
        --3).silver.crm_sales_details
        insert into silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        select 
        sls_ord_num,
        sls_prd_key,	
        sls_cust_id,
        case when sls_order_dt = 0 or len(sls_order_dt) != 8 then null
                  else cast(cast(sls_order_dt as varchar) as date) 
        end as sls_order_dt,
        case when sls_ship_dt = 0 or len(sls_ship_dt) != 8 then null
                  else cast(cast(sls_ship_dt as varchar) as date) 
        end as sls_ship_dt,
        case when sls_due_dt = 0 or len(sls_due_dt) != 8 then null
                  else cast(cast(sls_due_dt as varchar) as date) 
        end as sls_due_dt,
        case when sls_sales is null or sls_sales <= 0 or sls_sales != abs(sls_price) * sls_quantity
             then abs(sls_price) * sls_quantity
             else sls_sales
        end as sls_sales,-- Recalculate sales if original value is missing or incorrect
        sls_quantity,
        case when sls_price is null or sls_price <= 0 
             then sls_sales / nullif(sls_quantity,0)
             else sls_price
        end as sls_price -- Derive price if original value is invalid
        from bronze.crm_sales_details;

	    set @end_time = getdate();
	    print'>> Load Duration : ' + cast(datediff(second,@start_time,@end_time) as nvarchar) + ' Seconds';
	    print'-------------------------------------------------------------------------------------------------------------------';

	    print'------------------------------------------------------------------------------------';
	    print'Loading ERP Tables';
	    print'------------------------------------------------------------------------------------';

        set @start_time = getdate();
        print'>> Truncating Table : silver.erp_cust_az12';
        truncate table silver.erp_cust_az12;
        --1).silver.erp_cust_az12
        insert into silver.erp_cust_az12 (
            cid,
            bdate,
            gen
        )
        select
        case when cid like 'NAS%' then SUBSTRING(cid,4,len(cid))-- Remove 'NAS' prefix if present
             else cid
        end as cid,
        case when bdate > getdate() then null
             else bdate
        end as bdate,-- Set future birthdates to null
        case when upper(trim(gen)) in ('F','Female') then 'Female'
             when upper(trim(gen)) in ('M','Male') then 'Male'
             else 'n/a'
        end as gen-- Normalize gender values and handle unknown cases
        from bronze.erp_cust_az12;

   	    set @end_time = getdate();
	    print'>> Load Duration : ' + cast(datediff(second,@start_time,@end_time) as nvarchar) + ' Seconds';
	    print'-------------------------------------------------------------------------------------------------------------------';


        set @start_time = getdate();
        print'>> Truncating Table : silver.erp_loc_a101';
        truncate table silver.erp_loc_a101;
        --2).silver.erp_loc_a101
        insert into silver.erp_loc_a101 (
            cid,
            cntry
        )
        select
        replace(cid,'-','') as cid,
        case when trim(cntry) in ('US','USA') then 'United States'
             when trim(cntry) = ('DE')  then 'Germany'
             when trim(cntry) is null or trim(cntry) = '' then 'n/a'
             else trim(cntry)
        end as cntry--Normalize and Hnadle missing or blank country codes
        from bronze.erp_loc_a101;

        set @end_time = getdate();
	    print'>> Load Duration : ' + cast(datediff(second,@start_time,@end_time) as nvarchar) + ' Seconds';
	    print'-------------------------------------------------------------------------------------------------------------------';


        set @start_time = getdate();
        print'>> Truncating Table : silver.erp_px_cat_g1v2';
        truncate table silver.erp_px_cat_g1v2;
        --3).silver.erp_px_cat_g1v2
        insert into silver.erp_px_cat_g1v2 (
            id,
            cat,
            subcat,
            maintenance
        )
        select
        id,
        cat,
        subcat,
        maintenance
        from bronze.erp_px_cat_g1v2;

   	    set @end_time = getdate();
        print'>> Load Duration : ' + cast(datediff(second,@start_time,@end_time) as nvarchar) + ' Seconds';
	    print'-------------------------------------------------------------------------------------------------------------------';

        set @batch_end_time = getdate();
        print'==========================================================================';
	    print'Loading Silver Layer is Completed'
	    print'>> Total Load Duration : ' + cast(datediff(second,@batch_start_time,@batch_end_time) as nvarchar) + ' Seconds';
	    print'==========================================================================';

    end try

    begin catch
        print 'Error occurred during loading silver layer: ' ;
        print'Error Message : ' + error_message();
	    print'Error Number : ' + cast(error_number() as nvarchar);
	    print'Error Line : ' + cast(error_line() as nvarchar);
	    print'Error Procedure : ' + error_procedure();
    end catch

end;
