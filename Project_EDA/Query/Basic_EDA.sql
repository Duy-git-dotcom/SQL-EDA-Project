USE DataWarehouseAnalytics
GO

SELECT * FROM [gold.dim_customers]
SELECT * FROM [gold.dim_products]
SELECT * FROM [gold.fact_sales]
GO

----KIỂM TRA DATABASE
--ĐỐI TƯỢNG TRONG DATABASE
SELECT * FROM INFORMATION_SCHEMA.TABLES
GO

--CỘT TRONG DATABASE
SELECT * FROM INFORMATION_SCHEMA.COLUMNS
GO

----KIỂM TRA CHIỀU DỮ LIỆU KHÔNG LIÊN TỤC(DIMENSION EXPLORATION)
--XUẤT THÂN KHÁCH HÀNG
SELECT DISTINCT country FROM [gold.dim_customers]
SELECT country, COUNT(*) FROM [gold.dim_customers]
GROUP BY country
GO

--CÁC LOẠI HÌNH SẢN PHẨM CỦA DOANH NGHIỆP
SELECT DISTINCT category, subcategory, product_name FROM [gold.dim_products]
ORDER BY 1,2,3
GO

----KIỂM TRA DỮ LIỆU ĐO LƯỜNG (MEASURE EXPLORATION)
-- TÌM TỔNG DOANH SỐ
SELECT SUM(sales_amount) AS Total_Sales FROM dbo.[gold.fact_sales]
-- TÌM SỐ LƯỢNG SẢN PHẨM ĐÃ BÁN
SELECT SUM(quantity) AS Total_Quantity FROM dbo.[gold.fact_sales]
-- TÌM GIÁ BÁN TRUNG BÌNH
SELECT AVG(price) AS AVG_Price FROM dbo.[gold.fact_sales]
-- TÌM TỔNG SỐ ĐƠN HÀNG
SELECT COUNT(DISTINCT order_number) AS Total_Order FROM dbo.[gold.fact_sales]
-- TÌM TỔNG SỐ SẢN PHẨM
SELECT COUNT(DISTINCT product_key) AS Total_Products FROM dbo.[gold.fact_sales]
-- TÌM TỔNG SỐ KHÁCH HÀNG
SELECT COUNT(customer_key) AS Total_Customers FROM dbo.[gold.dim_customers]
-- TÌM TỔNG SỐ KHÁCH HÀNG ĐÃ TỪNG ĐẶT HÀNG
SELECT COUNT(DISTINCT customer_key) AS Ordered_Customers FROM dbo.[gold.fact_sales]
GO

----KHÁM PHÁ DỮ LIỆU THỜI GIAN 
--SỐ THỜI GIAN KỂ TỪ LẦN BÁN SẢN PHẨM ĐẦU TIÊN TỚI LẦN CUỐI
SELECT 
MIN(order_date) AS min_orderdate,
MAX(order_date) AS max_orderdate,
DATEDIFF(month,MIN(order_date),MAX(order_date)) AS datediff_order
FROM dbo.[gold.fact_sales]
GO

--ĐỘ TUỔI CỦA KHÁCH HÀNG
SELECT 
MIN(birthdate) AS Oldest,
DATEDIFF(year,MIN(birthdate),GETDATE()) AS Oldest_Age,
MAX(birthdate) AS Youngest,
DATEDIFF(year,MAX(birthdate),GETDATE()) AS Youngest_Age
FROM dbo.[gold.dim_customers]
GO

--TRUY VẤN BÁO CÁO TẤT CẢ NHỮNG THÔNG SỐ CẦN THIẾT
SELECT 'Total Sales' AS Measure_name, SUM(sales_amount) AS Measure_value FROM dbo.[gold.fact_sales]
UNION ALL
SELECT 'Total Quantity' , SUM(quantity) FROM dbo.[gold.fact_sales]
UNION ALL
SELECT 'Average Price', AVG(price) FROM dbo.[gold.fact_sales]
UNION ALL
SELECT 'Total Nr. Orders', COUNT(DISTINCT order_number) FROM dbo.[gold.fact_sales]
UNION ALL
SELECT 'Total Nr. Products', COUNT(product_name) FROM dbo.[gold.dim_products]
UNION ALL
SELECT 'Total Nr. Customers', COUNT(customer_key) FROM dbo.[gold.dim_customers]
GO


----SO SÁNH CÁC BIẾN MEASURES THEO BIẾN DIMENSION
-- TÌM TỔNG SỐ KHÁCH HÀNG THEO QUỐC GIA 
SELECT 
country,
COUNT(customer_key) AS Total_Customers
FROM dbo.[gold.dim_customers]
GROUP BY country
ORDER BY Total_Customers DESC
GO

-- TÌM TỔNG SỐ KHÁCH HÀNG THEO GIỚI TÍNH
SELECT 
gender,
COUNT(customer_key) AS Total_Customers
FROM dbo.[gold.dim_customers]
GROUP BY gender
ORDER BY Total_Customers DESC
GO

-- TÌM TỔNG SỐ SẢN PHẨM THEO LOẠI MỤC 
SELECT 
category,
COUNT(product_key) AS Total_Products
FROM dbo.[gold.dim_products]
GROUP BY category
ORDER BY Total_Products DESC
GO
-- CHI PHÍ TRUNG BÌNH CHO TỪNG LOẠI SẢN PHẨM LÀ BAO NHIÊU? 
SELECT 
category,
AVG(cost) AS AVG_cost
FROM dbo.[gold.dim_products]
GROUP BY category
ORDER BY AVG_cost DESC
GO

-- TỔNG DOANH THU CHO TỪNG LOẠI SẢN PHẨM LÀ BAO NHIÊU? 
SELECT 
pr.category,
SUM(sa.price-pr.cost) AS Total_Revenue
FROM dbo.[gold.dim_products] AS pr
RIGHT JOIN dbo.[gold.fact_sales] AS sa
ON pr.product_key = sa.product_key
GROUP BY pr.category
ORDER BY Total_Revenue DESC
GO

-- TÌM TỔNG DOANH THU ĐẠT ĐƯỢC BỞI TỪNG KHÁCH HÀNG
SELECT 
cu.customer_key,
cu.first_name,
cu.last_name,
SUM(sa.sales_amount) AS Total_Revenue
FROM dbo.[gold.dim_customers] AS cu
RIGHT JOIN dbo.[gold.fact_sales] AS sa
ON cu.customer_key = sa.customer_key
GROUP BY 
cu.customer_key,
cu.first_name,
cu.last_name
ORDER BY Total_Revenue DESC
GO

-- PHÂN PHỐI CỦA CÁC MẶT HÀNG ĐÃ BÁN CHO CÁC QUỐC GIA LÀ GÌ?
SELECT 
cu.country,
SUM(sa.quantity) AS Total_Sold_Items
FROM dbo.[gold.dim_customers] AS cu
RIGHT JOIN dbo.[gold.fact_sales] AS sa
ON cu.customer_key = sa.customer_key
GROUP BY cu.country
ORDER BY Total_Sold_Items DESC
GO

----PHÂN TÍCH PHÂN HẠNG
--5 SẢN PHẨM CÓ DOANH THU CAO NHẤT
SELECT 
TOP 5 pr.product_name,
SUM(sa.sales_amount) AS Total_Revenue,
ROW_NUMBER() OVER(ORDER BY SUM(sa.sales_amount) ASC) AS Rankings
FROM dbo.[gold.dim_products] AS pr
RIGHT JOIN dbo.[gold.fact_sales] AS sa
ON pr.product_key = sa.product_key
GROUP BY pr.product_name
GO 

--5 SẢN PHẨM CÓ DOANH THU THẤP NHẤT
SELECT 
TOP 5 pr.product_name,
SUM(sa.sales_amount) AS Total_Revenue
FROM dbo.[gold.dim_products] AS pr
RIGHT JOIN dbo.[gold.fact_sales] AS sa
ON pr.product_key = sa.product_key
GROUP BY pr.product_name
ORDER BY Total_Revenue ASC
GO 

--TOP 3 NGƯỜI CÓ ÍT ĐƠN ĐẶT HÀNG NHẤT 
SELECT TOP 3
cu.customer_key,
cu.first_name,
cu.last_name,
COUNT(DISTINCT order_number) AS total_orders
FROM dbo.[gold.dim_customers] AS cu
RIGHT JOIN dbo.[gold.fact_sales] AS sa
ON cu.customer_key = sa.customer_key
GROUP BY 
cu.customer_key,
cu.first_name,
cu.last_name
ORDER BY total_orders 
GO
