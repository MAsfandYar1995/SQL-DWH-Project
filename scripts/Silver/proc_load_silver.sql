CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN

	PRINT('================TRUNCATING TABLE silver.crm_cust_info ==================');

	TRUNCATE TABLE silver.crm_cust_info;

	PRINT('================INSERTING INTO TABLE silver.crm_cust_info ==================');

	INSERT INTO silver.crm_cust_info (
		cst_id,
		cst_key,
		cst_firstname,
		cst_lastname,
		cst_marital_status,
		cst_gndr,
		cst_create_date)
	SELECT
		cst_id,
		cst_key,
		LOWER(TRIM(cst_firstname)) AS cst_firstname, -- data standardization
		LOWER(TRIM(cst_lastname)) AS cst_lastname, -- data standardization
		CASE 
			WHEN UPPER(cst_marital_status) = 'S' THEN 'single'
			WHEN UPPER(cst_marital_status) = 'M' THEN 'married'
			ELSE 'n/a' -- filling nulls
		END AS cst_marital_status,
		CASE 
			WHEN UPPER(cst_gndr) = 'M' THEN 'male'
			WHEN UPPER(cst_gndr) = 'F' THEN 'female'
			ELSE 'n/a' -- filling nulls
		END AS cst_gndr,
		cst_create_date
	FROM (
		SELECT
			*,
			ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS rn
		FROM bronze.crm_cust_info
		WHERE cst_id IS NOT NULL -- remove Nulls from date_rn calculation
	) t
	WHERE rn = 1; -- use only latest-date rows

	PRINT('================TRUNCATING TABLE silver.crm_prd_info ==================');

	TRUNCATE TABLE silver.crm_prd_info;

	PRINT('================INTSERTING INTO silver.crm_prd_info ==================');

	INSERT INTO silver.crm_prd_info(
		prd_id,
		cat_id,
		prd_key,
		prd_nm,
		prd_cost,
		prd_line,
		prd_start_dt,
		prd_end_dt
	)
	SELECT
		prd_id,
		REPLACE(SUBSTRING(TRIM(prd_key),1,5), '-', '_') AS cat_id,
		SUBSTRING(TRIM(prd_key),7,len(TRIM(prd_key))) AS prd_key,
		TRIM(prd_nm) AS prd_nm, -- ideally, check for unwanted space before using TRIM. No unwated spaces in this column
		COALESCE(prd_cost, 0) AS prd_cost,
		CASE UPPER(TRIM(prd_line))
			WHEN 'M' THEN 'mountain'
			WHEN 'R' THEN 'road'
			WHEN 'S' THEN 'other sales'
			WHEN 'T' THEN 'touring'
			ELSE 'n/a'
		END AS prd_line,
		prd_start_dt,
		CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt
	FROM bronze.crm_prd_info;

	PRINT('================TRUNCATING TABLE silver.crm_sales_details ==================');

	TRUNCATE TABLE silver.crm_sales_details;

	PRINT('================TRUNCATING TABLE silver.crm_sales_details ==================');

	INSERT INTO silver.crm_sales_details(
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
	SELECT
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		CASE
			WHEN sls_order_dt <= 0 OR len(sls_order_dt) != 8 THEN NULL
			ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
		END AS sls_order_dt,
		CASE
			WHEN sls_ship_dt <= 0 OR len(sls_ship_dt) != 8 THEN NULL
			ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
		END AS sls_ship_dt,
		CASE
			WHEN sls_due_dt <= 0 OR len(sls_due_dt) != 8 THEN NULL
			ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
		END AS sls_due_dt,
		CASE
			WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) THEN sls_quantity * ABS(sls_price)
			ELSE sls_price
		END AS sls_price,
		sls_quantity,
		CASE
			WHEN sls_price IS NULL OR sls_price <= 0 THEN sls_sales / NULLIF(sls_quantity, 0)
			ELSE sls_price
		END AS sls_price
	FROM bronze.crm_sales_details;

	PRINT('================TRUNCATING TABLE silver.erp_cust_az12 ==================');

	TRUNCATE TABLE silver.erp_cust_az12;

	PRINT('================INSERTING INTO silver.erp_cust_az12 ==================');

	INSERT INTO silver.erp_cust_az12 (
		cid,
		bdate,
		gen
	)
	SELECT
	CASE
		WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, len(cid))
		ELSE cid
	END AS cid,
	CASE 
		WHEN bdate > GETDATE() THEN NULL
		ELSE bdate
	END AS bdate,
	CASE
		WHEN UPPER(gen) IN ('F','FEMALE') THEN 'female'
		WHEN UPPER(gen) IN ('M','MALE') THEN 'male'
		ELSE 'n/a'
	END AS gen
	FROM bronze.erp_cust_az12;

	PRINT('================TRUNCATING TABLE silver.erp_px_cat_g1v2 ==================');

	TRUNCATE TABLE silver.erp_px_cat_g1v2;

	PRINT('================INSERT INTO silver.erp_px_cat_g1v2 ==================');

	INSERT INTO silver.erp_px_cat_g1v2 (
		id,
		cat,
		subcat,
		maintenance
	)
	SELECT
		id,
		cat,
		subcat,
		maintenance
	FROM bronze.erp_px_cat_g1v2;

	PRINT('================TRUNCATING TABLE silver.erp_loc_a101 ==================');

	TRUNCATE TABLE silver.erp_loc_a101;

	PRINT('================INSERTING INTO TABLE silver.erp_loc_a101 ==================');

	INSERT INTO silver.erp_loc_a101 (cid, cntry)
	SELECT
		REPLACE(cid, '-', '') AS cid,
		CASE
			WHEN UPPER(TRIM(cntry)) IN ('USA', 'US') THEN 'united states'
			WHEN UPPER(TRIM(cntry)) IN ('DE') THEN 'german'
			WHEN cntry IS NULL OR cntry = '' THEN 'n/a'
			ELSE lower(cntry)
		END AS cntry
	FROM bronze.erp_loc_a101;
END
