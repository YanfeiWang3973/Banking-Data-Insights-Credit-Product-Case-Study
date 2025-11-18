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


-- -------------------------------------------------------------------------------------------------------------------------
-- Business Questions
-- 1, We are planning to launch a new product focused on a specific merchant category (e.g. travel credit
-- card). Which specific merchant category would you like to focus on for this new product?  Please
-- explain your rationale for this category incorporating both the insights derived from the data and
-- other concepts where you see fit.

-- Demension = 'income level'
-- Assumption: higher income people would like to travel more
-- check category tags
select
    distinct(categoryTags)
from transaction;
-- 'Income', 'Bills and Utilities', 'Mortgage abd Rent', 'Taxes' , 'Home'
-- 'Food and Dining', 'Entertainment', 'Shopping', 'Travel'
-- check income levels
select
    MAX(total_Income) as Max_Income ,
    MIN(total_Income ) as Min_Income
from customer ;

with table_1 as (
    select
        trim(transaction.categoryTags) as Category,
        account.balance as Savings,
        customer.total_Income as Income,
        transaction.currencyAmount as Spent
    from transaction
    left join account on account.customer_id = transaction.customerId
    left join customer on account.customer_id = customer.id
    where trim(transaction.categoryTags) in ('Food and Dining', 'Entertainment', 'Shopping', 'Travel')
),
    table_2 as (
        select
            Savings,
            Spent,
            Category,
            case
                WHEN Income IS NULL OR Income = 0 THEN 'Unknown'
                WHEN Income >= 80000 THEN '80k+'
                WHEN Income >= 40000 THEN '40k+'
                ELSE '<40k'
            end as Income_Level
        from table_1
    )
select
    Income_Level,
    Category,
    ROUND(AVG(Spent), 0) AS Average_Spent,
    round( SUM(Spent), 0) as Total_Spent
from table_2
group by Income_level, Category
order by Income_Level desc, Total_Spent DESC;

-- conclusion : interestingly, the middle income class turned to like to travel more instead of the higher / richer class
-- despite we have less higher income customers (assumption) , since the average spending on traveing is still higher income class domainated then the middle income class.
-- a travel reward program bond with flight tickets, shopping , and entertainment for middle income customers.
-- where it will encourage middle income customers to have more reasons to spend more money on targeted purchases.


