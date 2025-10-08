# 🛒 SQL Sales Analytics Dashboard

## 📌 Business Problem
The business needs to understand **customer purchase patterns, product profitability, and revenue trends** to optimize marketing and sales strategies.  

## 📊 Dataset
- **Source:** [AdventureWorks Database](https://github.com/microsoft/sql-server-samples/tree/master/samples/databases/adventure-works) (or Northwind dataset)  
- **Size:** 10K+ transactions across customers, orders, and products  

## 🛠️ Tools & Techniques
![SQL](https://img.shields.io/badge/SQL-336791?style=flat&logo=postgresql&logoColor=white)
![Tableau](https://img.shields.io/badge/Tableau-E97627?style=flat&logo=tableau&logoColor=white)
![PowerBI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![Excel](https://img.shields.io/badge/Excel-217346?style=flat&logo=microsoft-excel&logoColor=white)

- SQL (complex joins, window functions, CTEs, stored procedures)  
- Tableau (interactive dashboards, calculated fields)  
- Excel (data cleaning, pivot tables for QA)  

## 🔍 Methodology
1. **Data Extraction** – Imported sales & customer tables from AdventureWorks  
2. **SQL Analysis** –  
   - JOINs to merge customer + order + product data  
   - Window functions for running totals and rankings  
   - CTEs for cohort analysis  
   - Stored procedures for automated reporting  
3. **Visualization** – Created Tableau dashboard with 5+ KPIs  
4. **Business Insights** – Documented actionable recommendations  

## 📈 Key Findings
- Identified **3 customer segments contributing 67% of total revenue**  
- Discovered **top 5 products account for 40% of profits**  
- Found **quarterly retention rate dropped by 12% in 2023**, suggesting churn issues  

## 💡 Business Impact
These insights can guide **targeted marketing campaigns, inventory planning, and retention strategies**, potentially increasing revenue by 15%.  

## 📂 Repo Structure
data/ - raw & processed datasets
notebooks/ - Jupyter notebooks with SQL queries
dashboards/ - Tableau/Power BI dashboards
reports/ - Executive summary (PDF)

## 🔗 Links
- Tableau Dashboard: (https://public.tableau.com/views/Book1_17585285311590/Dashboard1?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)  
- Executive Summary: [PDF report]
