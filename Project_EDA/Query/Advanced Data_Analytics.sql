USE DataWarehouseAnalytics
GO

SELECT * FROM [gold.dim_customers]
SELECT * FROM [gold.dim_products]
SELECT * FROM [gold.fact_sales]
GO


----CHANGE OVER TIME
---SALES OVER ORDER DATE
--YEAR
SELECT 
	YEAR(order_date) AS order_year,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS customer_count,
	SUM(quantity) AS total_quantity
FROM [gold.fact_sales]
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date) ASC
GO
--MONTH,YEAR
SELECT 
	DATETRUNC(MONTH,order_date) AS order_year,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS customer_count,
	SUM(quantity) AS total_quantity
FROM [gold.fact_sales]
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH,order_date) 
ORDER BY DATETRUNC(MONTH,order_date)  ASC
GO

--SUBQUERY
SELECT MAX(total_sales) FROM (
	SELECT 
		YEAR(order_date) AS order_year,
		MONTH(order_date) AS order_month,
		SUM(sales_amount) AS total_sales,
		COUNT(DISTINCT customer_key) AS customer_count,
		SUM(quantity) AS total_quantity
	FROM [gold.fact_sales]
	WHERE order_date IS NOT NULL
	GROUP BY YEAR(order_date), MONTH(order_date)
) AS CTE
GO


----CUMULATIVE ANALYSIS
---RUNNING TOTAL SALES(ROLLING TOTAL) TỔNG
SELECT 
	date_time,
	total_sales,
	SUM(total_sales) OVER(ORDER BY date_time) AS Rolling_total
FROM (
	SELECT
		DATETRUNC(MONTH, order_date) AS date_time,
		SUM(sales_amount) AS total_sales
	FROM [gold.fact_sales]
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(MONTH, order_date)
) AS SUB
ORDER BY date_time ASC
GO
---RUNNING TOTAL SALES(ROLLING TOTAL) THEO NĂM
SELECT 
	date_time,
	total_sales,
	SUM(total_sales) OVER(PARTITION BY YEAR(date_time) ORDER BY date_time) AS Rolling_total
FROM (
	SELECT
		DATETRUNC(MONTH, order_date) AS date_time,
		SUM(sales_amount) AS total_sales
	FROM [gold.fact_sales]
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(MONTH, order_date)
) AS SUB
ORDER BY date_time ASC
GO
---MOVING AVERAGE
SELECT 
	date_time,
	total_sales,
	SUM(total_sales) OVER(ORDER BY date_time) AS Rolling_total,
	AVG_Price,
	AVG(AVG_Price) OVER(ORDER BY date_time) AS Moving_average
FROM (
	SELECT
		DATETRUNC(MONTH, order_date) AS date_time,
		SUM(sales_amount) AS total_sales,
		AVG(price) AS AVG_Price
	FROM [gold.fact_sales]
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(MONTH, order_date)
) AS SUB
ORDER BY date_time ASC
GO

----PERFORMANCE ANALYSIS
---(Phân tích so sánh kết quả kinh doanh của năm nay với năm trước, hiện tại với doanh số trung bình của sản phẩm)
--year_to_year
WITH yearly_sales AS(
	SELECT 
		YEAR(sa.order_date) AS order_year,
		pr.product_name,
		SUM(sa.sales_amount) AS current_sales
	FROM [gold.fact_sales] AS sa
	LEFT JOIN [gold.dim_products] AS pr
	ON sa.product_key = pr.product_key
	WHERE sa.order_date IS NOT NULL
	GROUP BY
		YEAR(sa.order_date),
		pr.product_name
)
SELECT
	order_year,
	product_name,
	current_sales,
	AVG(current_sales) OVER(PARTITION BY product_name) AS avg_sales,
	current_sales - AVG(current_sales) OVER(PARTITION BY product_name) AS diff_avg,
	CASE WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) > 0 THEN 'Above Average'
		WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) < 0 THEN 'Below Average'
		ELSE 'Average'
	END AS Category_avg,
	LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS Previous_year_sales,
	current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS year_diff,
	CASE WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
		WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
		ELSE 'No_change'
	END AS Category_year
FROM yearly_sales
ORDER BY product_name, order_year ASC
GO

----PART_TO_WHOLE
---Thể loại sản phẩm nào chiếm nhiều phần trăm nhất trong tổng lượng bán
WITH category_sales AS (
	SELECT
	category,
	SUM(sales_amount) AS total_sales
	FROM [gold.fact_sales]  AS sa
	LEFT JOIN [gold.dim_products] AS pr
	ON sa.product_key = pr.product_key
	GROUP BY category
)
SELECT 
category,
total_sales,
SUM(total_sales) OVER() AS over_sales,
CONCAT(ROUND(((CAST (total_sales AS FLOAT))/SUM(total_sales) OVER())*100,2), '%') AS Percentage_sales
FROM category_sales
ORDER BY total_sales DESC
GO

----Data Segmentation
---Phân loại sản phẩm
WITH products_segmentation AS (
	SELECT
	product_key,
	product_name,
	cost,
	CASE WHEN cost < 100 THEN 'Below 100'
		WHEN cost BETWEEN 100 AND 500 THEN '100-500'
		WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
		ELSE 'Above 1000'
	END AS cost_range
	FROM [gold.dim_products]
)
SELECT 
cost_range,
COUNT(product_key) AS total_products
FROM products_segmentation
GROUP BY cost_range
ORDER BY total_products DESC
GO

---Phân chia tệp khách hàng thành VIP, Regular, New dựa trên thời gian tạo tài khoản và số tiền đã tiêu xài
WITH date_table AS(
	SELECT
	cu.customer_key,
	SUM(sales_amount) AS total_sales,
	MIN(order_date) AS first_date,
	MAX(order_date) AS last_date,
	DATEDIFF(month,MIN(order_date),MAX(order_date)) AS order_time
	FROM [gold.fact_sales] AS sa
	LEFT JOIN  [gold.dim_customers] AS cu
	ON sa.customer_key = cu.customer_key
	GROUP BY cu.customer_key
)
SELECT
segmentation_cus,
COUNT(customer_key) AS total_cus
FROM (
	SELECT
	customer_key,
	CASE WHEN total_sales > 5000 AND order_time >= 12 THEN 'VIP'
		 WHEN total_sales <= 5000 AND order_time >= 12 THEN 'Regular'
		 ELSE 'New'
	END AS segmentation_cus
	FROM date_table
) AS t
GROUP BY segmentation_cus
ORDER BY total_cus DESC
GO

----BÁO CÁO 
/*
============================================================

Mục đích:
- Báo cáo này tổng hợp các chỉ số và hành vi quan trọng của khách hàng.

Các chỉ tiêu:
1. Thu thập các trường dữ liệu thiết yếu như tên, tuổi và chi tiết giao dịch.
2. Phân loại khách hàng thành các nhóm (VIP, Thường xuyên, Mới) và theo nhóm tuổi.
3. Tổng hợp các chỉ số ở cấp độ khách hàng:
   - Tổng số đơn hàng
   - Tổng doanh thu
   - Tổng số lượng đã mua
   - Tổng số sản phẩm
   - Vòng đời khách hàng (tính theo tháng)
4. KPI:
   - Gần đây nhất (số tháng kể từ lần đặt hàng cuối cùng)
   - Giá trị đơn hàng trung bình
   - Chi tiêu trung bình hàng tháng

----------------------------------------------------------

CREATE VIEW gold.report_view AS
WITH basic_query AS
(
	SELECT
		cu.customer_id,
		cu.customer_key,
		cu.customer_number,
		CONCAT(cu.first_Name,' ',cu.last_name) AS fullname,
		DATEDIFF(year, cu.birthdate, GETDATE()) AS age,
		sa.order_number,
		sa.product_key,
		sa.order_date,
		sa.sales_amount,
		sa.quantity
	FROM [gold.fact_sales] AS sa
	LEFT JOIN [gold.dim_customers] AS cu
	ON sa.customer_key = cu.customer_key
	WHERE sa.order_date IS NOT NULL
	),
customer_aggregation AS (
	SELECT 
		customer_key,
		customer_number,
		fullname,
		age,
		COUNT(DISTINCT order_number) AS total_orders,
		SUM(sales_amount) AS total_sales,
		SUM(quantity) AS Total_quantity,
		COUNT(DISTINCT product_key) AS total_products,
		MIN(order_date) AS first_date,
		MAX(order_date) AS last_date,
		DATEDIFF(month,MIN(order_date),MAX(order_date)) AS order_time
	FROM basic_query
	GROUP BY 
		customer_key,
		customer_number,
		fullname,
		age
)
SELECT
	customer_key,
	customer_number,
	fullname,
	age,
	CASE WHEN age < 20 THEN 'Under 20'
		WHEN age BETWEEN 20 AND 29 THEN '20-29'
		WHEN age BETWEEN 30 AND 39 THEN '30-39'
		WHEN age BETWEEN 40 AND 49 THEN '40-49'
		ELSE 'Above 50'
	END AS age_segmentation,
	total_orders,
	total_sales,
	Total_quantity,
	total_products,
	CASE WHEN total_sales > 5000 AND order_time >= 12 THEN 'VIP'
		 WHEN total_sales <= 5000 AND order_time >= 12 THEN 'Regular'
		 ELSE 'New'
	END AS segmentation_cus,
	---Số tháng từ lần cuối đặt sản phẩm
	last_date,
	DATEDIFF(month,last_date,GETDATE()) AS Recency,
	---Số tiền chi trung bình cho 1 đơn hàng
	CASE WHEN total_sales = 0 THEN 0
		ELSE total_sales/total_orders 
	END AS Avg_sales,
	---Số tiền chi trung bình trên tháng từ lúc bắt đầu mua các sản phẩm
	CASE WHEN order_time = 0 THEN total_sales
		ELSE total_sales/order_time 
	END AS Avg_monthly
FROM customer_aggregation
