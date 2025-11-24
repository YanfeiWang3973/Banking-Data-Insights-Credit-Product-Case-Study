create database TD_interview ;
use TD_interview;

drop table if exists account;

create table account(
    index_col int ,
    branchNumber int ,
    type varchar(15),
    openDate date,
    id varchar(60),
    iban varchar(60),
    balance int,
    currency varchar(10),
    customer_id varchar (60)
);

set global local_infile =1;

show variables like "local_infile";


load data local infile "C:/weCloudData2024/marketing_analytics_2023 (1)/Interviews/TD_analyticsmanager/TD_analyticsmanager/BusinessCase_Data/BusinessCase_Accts.csv"
into table account
fields terminated by ","
lines terminated by "\n"
ignore 1 rows ;

select * from account limit 10;

-- create the second table and import the data
drop table if exists customer;

create table customer (
    index_id int,
    id varchar(60),
    type varchar(30),
    gender varchar(20),
    birthDate date,
    workActivity varchar(25),
    occupationIndustry varchar(35),
    total_Income float,
    relationship_statues varchar(20),
    habitation_Status varchar(20),
    address_principal varchar(10),
    school_attendance varchar(25),
    schools int
);

LOAD DATA LOCAL INFILE 'C:/weCloudData2024/marketing_analytics_2023 (1)/Interviews/TD_analyticsmanager/TD_analyticsmanager/BusinessCase_Data/BusinessCase_Custs.csv'
INTO TABLE customer
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  index_id,
  id,
  type,
  gender,
  @birthDate,  -- only this column as a variable
  workActivity,
  occupationIndustry,
  total_Income,
  relationship_statues,
  habitation_Status,
  address_principal,
  school_attendance,
  schools
)
SET
  birthDate = STR_TO_DATE(@birthDate, '%m/%d/%Y');


select * from customer;

-- create the third table
drop table if exists tx;

drop table if exists transaction;

create table transaction (
    index_row int,
    description varchar(30),
    currencyAmount float,
    locationRegion varchar(10),
    locationCity varchar(10),
    originationDateTime datetime,
    customerId varchar(60),
    merchantId varchar(60),
    accountId varchar(60),
    categoryTags varchar(30)
);

set global local_infile = 1 ;

load data local infile "C:/weCloudData2024/marketing_analytics_2023 (1)/Interviews/TD_analyticsmanager/TD_analyticsmanager/BusinessCase_Data/BusinessCase_Tx.csv"
into table transaction
fields terminated by ","
lines terminated by "\r\n"
ignore 1 rows ;

alter table transaction
drop column  locationRegion,
drop column  locationCity ;

select * from transaction limit 10;
select * from customer limit 10;
select * from account limit 10;

-- what branch has the most number of customers?

select count(distinct(id)) as number_of_customer ,
       branchNumber
from account
group by branchNumber
order by number_of_customer desc
limit 1;

-- How old is the oldest customer as of 2019-07-01
select
    id,
    timestampdiff(year, birthDate, '2019-07-01') as Age
from customer
group by id
-- having  Age <= 100
order by Age desc
limit 1;

-- How many accounts does the oldest customer have?
select
    customer.id,
    timestampdiff(year, customer.birthDate, '2019-07-01') as Age,
    count(account.id) as number_of_accounts
from customer
left join account on customer.id = account.customer_id
group by id, Age
order by Age desc
limit 1;


-- How many transactions went to Starbucks in April?
select * from transaction;

select
    extract( month from originationDateTime) as Required_month,
    count(*) as number_of_transactions
from transaction
where description like '%STARBUCKS%'
    AND Month(originationDateTime)= 4
group by Required_month
;

-- How much was spent on Starbucks in April?​

select
    description,
    extract(month from originationDateTime) as month_required,
    round(sum(currencyAmount), 2)  as total_spent
from transaction
    where MONTH(originationDateTime)=4
    and description like '%STARBUCKS%'
group by month_required;

-- Hypothesis Testing: Is the average spend at Starbucks (statistically) significantly different in April
-- compared to June?

SELECT
    description,
    EXTRACT(MONTH FROM originationDateTime) as required_month ,
    round(avg(currencyAmount),2)  as average_spending
from transaction
where month(originationDateTime) in (4, 6)
and description like '%STARBUCKS%'
GROUP BY required_month;


-- Which date exhibited the highest average spend above trend at Starbucks (based on a 10-period
-- moving average, ignoring missing dates)?
WITH starbucks_tx AS (
  SELECT
    originationDateTime,
    currencyAmount,
    ROW_NUMBER() OVER (ORDER BY originationDateTime) AS rn
  FROM td_interview.transaction
  WHERE description LIKE '%STARBUCKS%'
),

moving_avg_calc AS (
  SELECT
    tx1.originationDateTime,
    tx1.currencyAmount,
    ROUND(AVG(tx2.currencyAmount), 2) AS moving_avg,
    ROUND(tx1.currencyAmount - AVG(tx2.currencyAmount), 2) AS above_trend
  FROM starbucks_tx tx1
  JOIN starbucks_tx tx2
    ON tx2.rn BETWEEN tx1.rn - 10 AND tx1.rn - 1
  WHERE tx1.rn > 10  -- 👈 Filter out rows that can't have 10 previous values
  GROUP BY tx1.originationDateTime, tx1.currencyAmount, tx1.rn
)

SELECT *
FROM moving_avg_calc
ORDER BY above_trend DESC
LIMIT 1;



-- -------------------------------------------------------------------------------------------------------------------------
-- Business Questions
-- 1, We are planning to launch a new product focused on a specific merchant category (e.g. travel credit
-- card). Which specific merchant category would you like to focus on for this new product?  Please
-- explain your rationale for this category incorporating both the insights derived from the data and
-- other concepts where you see fit.

 -- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 -- Method 1 : Pareto Analysis (80/20)
-- Goal: by checking on cumulative total spending for each "category", see the most spent "category", and use them as the mian target of the next product's rewards

select
    categoryTags,
    total_spend,
    ROUND(sum(total_spend) OVER (ORDER BY total_spend DESC) / SUM(total_spend) OVER() * 100, 2)  as cumulative_percentage
FROM (
select
    ROUND(sum(currencyAmount), 2) as total_spend ,
    categoryTags
from transaction
WHERE categoryTags NOT IN ( 'Income', 'Transfer', 'Taxes', 'Mortgage and Rent', 'Bills and Utilities', 'Home', '')
and categoryTags is not null
group by categoryTags ) AS temp_1
order by total_spend DESC ;

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- by using user segmentation method I am dividing users with 1, income + savings , and 2, age, 3, gender

-- conclusion : interestingly, the middle income class turned to like to travel more instead of the higher / richer class
-- despite we have less higher income customers (assumption) , since the average spending on traveing is still higher income class domainated then the middle income class.
-- a travel reward program bond with flight tickets, shopping , and entertainment for middle income customers.
-- where it will encourage middle income customers to have more reasons to spend more money on targeted purchases.

-- Step 1: Raw transaction + customer info
WITH table_1 AS (
    SELECT
        TRIM(t.categoryTags) AS category,
        a.balance AS savings,
        c.total_Income AS income,
        t.currencyAmount AS spent
    FROM transaction t
    LEFT JOIN account a ON a.customer_id = t.customerId
    LEFT JOIN customer c ON a.customer_id = c.id
    WHERE TRIM(t.categoryTags) IN ('Food and Dining', 'Entertainment', 'Shopping', 'Travel')
),

-- Step 2: Segment users and aggregate spend
table_2 AS (
    SELECT
        category,
        CASE
            WHEN income IS NULL OR income = 0 THEN 'Unknown'
            WHEN income >= 80000 THEN '80k+'
            WHEN income >= 40000 THEN '40k+'
            ELSE '<40k'
        END AS income_level,
        CASE
            WHEN savings IS NULL THEN 'Unknown'
            WHEN savings >= 25000 THEN '25k+'
            WHEN savings >= 5000 THEN '5k+'
            ELSE '<5k'
        END AS saving_level,
        SUM(spent) AS total_spent,
        AVG(spent) AS avg_spent
    FROM table_1
    GROUP BY category, income_level, saving_level
),

-- Step 3: Total spending per category (for proper cumulative %)
category_totals AS (
    SELECT
        category,
        SUM(total_spent) AS category_total
    FROM table_2
    GROUP BY category
),

category_cumulative AS (
    SELECT
        category,
        category_total,
        ROUND(
            SUM(category_total) OVER (ORDER BY category_total DESC)
            / SUM(category_total) OVER () * 100, 2
        ) AS cumulative_percentage
    FROM category_totals
)

-- Final output
SELECT
    t2.income_level,
    t2.saving_level,
    t2.category,
    ROUND(t2.avg_spent, 0) AS average_spent,
    ROUND(t2.total_spent, 0) AS total_spent,
    cc.cumulative_percentage
FROM table_2 t2
JOIN category_cumulative cc ON cc.category = t2.category
WHERE t2.income_level != 'Unknown'
  AND t2.saving_level != 'Unknown'
ORDER BY income_level DESC, total_spent DESC;


