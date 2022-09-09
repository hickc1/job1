
/***************************************************************************************************
Create Date:        2022-Sep
Author:             Chris Hicks
Description:        This is a bunch of scripts to show a code demo

*/

--Create Loading Table
CREATE TABLE [dbo].[stg_Pedestrian_Counts](
	[ID] [bigint] NOT NULL,
	[Date_Time] [datetime2](7) NOT NULL, --This could be a varchar if the data has potential date issues.
	[Year] [smallint] NOT NULL,
	[Month] [nvarchar](50) NOT NULL,
	[Mdate] [tinyint] NOT NULL,
	[Day] [nvarchar](50) NOT NULL,
	[Time] [tinyint] NOT NULL,
	[Sensor_ID] [bigint] NOT NULL,
	[Sensor_Name] [nvarchar](255) NOT NULL,
	[Hourly_Counts] [nvarchar](50) NOT NULL --varchar as the number had a comma in the field 
) ON [PRIMARY]
GO

--Loaded the csv file using sql csv load

--Check no records loaded
select count(*) from [dbo].[stg_Pedestrian_Counts]
4,415,574


--setup fact table to store the Pedestrian_Counts
drop table [dbo].[fact_Pedestrian_Counts]

CREATE TABLE [dbo].[fact_Pedestrian_Counts](
	[ID] [bigint] NOT NULL,
	[Date_Time] [datetime2](7) NOT NULL,
	[Sensor_ID] [bigint] NOT NULL,
	[Hourly_Counts] int NOT NULL
) ON [PRIMARY]
GO



--truncate table [dbo].[fact_Pedestrian_Counts]

insert into [dbo].[fact_Pedestrian_Counts]
SELECT [ID]
      ,[Date_Time]
      ,[Sensor_ID]
      , CAST(replace(Hourly_Counts,',','') AS INT) Hourly_Counts
  FROM [dbo].[stg_Pedestrian_Counts]

  select top 100 * from [dbo].[fact_Pedestrian_Counts]

-----------------------------------------------------------------------------------------------------------
---Load Sensor Dim table, first load into staging table, check Data Quality issues and make final dim table
-----------------------------------------------------------------------------------------------------------
drop table [dbo].[dim_Sensor];
drop table [dbo].[stg_Sensor];

CREATE TABLE [dbo].[stg_Sensor](
	[Sensor_ID] [bigint] NOT NULL,
    [Sensor_Name] [nvarchar](255) NOT NULL,
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[dim_Sensor](
	[Sensor_ID] [bigint] NOT NULL,
    [Sensor_Name] [nvarchar](255) NOT NULL,
) ON [PRIMARY]
GO

--Load the sensor staging table
insert into [dbo].[stg_Sensor]
SELECT distinct 
       p.[Sensor_ID]
      ,p.[Sensor_Name]
  FROM [dbo].[stg_Pedestrian_Counts] p 


--Check Data Quality issues in the Sensor data
select Sensor_id from [dbo].[stg_Sensor]
group by Sensor_id having count(*) > 1


--Data issues in the following id's would get them fixed if possible, if no control then put in a lookup known issues table and have a data 
-- sme to make the call on the correct name, I am just doing a max name for this example

select Sensor_id, min(Sensor_name), max(Sensor_name) from [dbo].[dim_Sensor]
where Sensor_id in 
    (select Sensor_id from [dbo].[dim_Sensor]
    group by Sensor_id having count(*) > 1)
    --(46, 54, 64, 66, 67,68,69,72, 75, 76, 77)
group by Sensor_id
order by Sensor_id 

--Table to store know issues and data fix
CREATE TABLE [dbo].[dq_Sensor_issues](
	[Sensor_ID] [bigint] NOT NULL,
    [Sensor_Name_original] [nvarchar](255) NOT NULL,
    [Sensor_Name_fix] [nvarchar](255) NOT NULL,
) ON [PRIMARY]
GO

--insert known sensor name issues with original name and fixed name.
insert into [dbo].[dq_Sensor_issues] values (46,	'Pelham St (S)','Pelham St (South)');
insert into [dbo].[dq_Sensor_issues] values (54,	'Lincoln-Swanston (West)','Lincoln-Swanston(West)');
insert into [dbo].[dq_Sensor_issues] values (64,	'Royal Pde - Grattan St','Royal Pde-Grattan St');
insert into [dbo].[dq_Sensor_issues] values (66,	'State Library - New','State Library-New');
insert into [dbo].[dq_Sensor_issues] values (67,	'Flinders Ln - Degraves St (South)','Flinders Ln -Degraves St (South)');
insert into [dbo].[dq_Sensor_issues] values (68,	'Flinders Ln - Degraves St (North)','Flinders Ln -Degraves St (North)');
insert into [dbo].[dq_Sensor_issues] values (69,	'Flinders Ln - Degraves St (Crossing)','Flinders Ln -Degraves St (Crossing)');
insert into [dbo].[dq_Sensor_issues] values (72,	'Flinders St - ACMI','Flinders St-ACMI');
insert into [dbo].[dq_Sensor_issues] values (75,	'Spring St - Flinders St (West)','Spring St- Flinders St (West)');
insert into [dbo].[dq_Sensor_issues] values (76,	'Macaulay Rd - Bellair St','Macaulay Rd-Bellair St');
insert into [dbo].[dq_Sensor_issues] values (77,	'Harbour Esplanade (West) - Ped Path','Harbour Esplanade (West) - Pedestrian Pa');


--Load the sensor dim table where id is not already in table
insert into [dbo].[dim_Sensor]
SELECT distinct 
       p.[Sensor_ID]
      , COALESCE(dq.[Sensor_Name_fix], p.[Sensor_Name]) --use corrected name if one exists
  FROM [dbo].[stg_Pedestrian_Counts] p left join [dbo].[dq_Sensor_issues] dq on  p.Sensor_ID = dq.Sensor_ID
  left join [dbo].[dim_Sensor] s on p.Sensor_ID = s.Sensor_ID --only insert rows if not alread in dim table
  where s.Sensor_ID is null

--Check Data Quality issues in dim_sensor table
select Sensor_id from  [dbo].[dim_Sensor]
group by Sensor_id having count(*) > 1
--looks ok only distict sensor records

--check the fix is working ok
select * from [dbo].[dim_Sensor] where Sensor_id in (46, 54, 64, 66, 67,68,69,72, 75, 76, 77)

--can check reload works can delete these 3 records and run the re-load script above and should only reload only deleted records
delete from [dbo].[dim_Sensor] where Sensor_ID in (17,7, 76)  

-----------------------------------------------------------------------------------------------------------
--Make dim_date table
-----------------------------------------------------------------------------------------------------------

drop table  [dbo].[dim_Date]

CREATE TABLE [dbo].[dim_Date](
    [Date] [date] NOT NULL,
	[Date_Time] [datetime2](7) NOT NULL, 
	[Year] [smallint] NOT NULL,
	[Month] [varchar](30) NOT NULL,
	[Mdate] [tinyint] NOT NULL,
	[Day] [varchar](10) NOT NULL,
	[Time] [tinyint] NOT NULL,
) ON [PRIMARY]
GO

--populate dim_date (quick and dirty assume all dates exist)
insert into [dbo].[dim_Date]
SELECT distinct 
    [Date_Time],
    [Date_Time],
	[Year],
	[Month],
	[Mdate] ,
	[Day] ,
	[Time] 
  FROM [dbo].[stg_Pedestrian_Counts] p 

--Looking at data and dates used
select min(date_time)
, max(date_time) 
, count(*) no_records
, DATEDIFF(day, min(date_time), max(date_time) ) no_days
, DATEDIFF(day, min(date_time), max(date_time) )  * 24 no_records
from [dbo].[dim_Date]


--check we have all dim records created
select min(date_time)
, max(date_time) 
, count(*) no_records
, DATEDIFF(day, min(date_time), max(date_time) ) + 1 no_days
, (DATEDIFF(day, min(date_time), max(date_time) ) + 1)  * 24 expected_no_records
from [dbo].[dim_Date]

--Missing times
select 
convert(date,date_Time), count(*)
from [dbo].[dim_Date] 
group by convert(date,date_Time)
having count(*) <> 24

--Rebuild the dim date the correct way to include all date and hours
truncate table [dbo].[dim_Date]

--Make a Dim date for every hour for date range 2009-05-01 to 2022-07-31 
with
tally as
(select top 1000 n = row_number() over(order by (select null)) - 1 from sys.messages), calendar as
(select [Date] = cast(dateadd(d, n, '2009-05-01') as date) from tally where n < datediff(d, '2009-05-01', '2022-08-01') ), [hours] as
(select top 24 n from tally)

insert into [dbo].[dim_Date]
select 
[Date] = format(c.[Date],'M/d/yyyy')
--[Date] = DATEADD(HOUR,h.n, format(c.[Date],'M/d/yyyy'))
, DATEADD(HOUR,h.n, format(c.[Date],'M/d/yyyy'))
, Year(c.[Date]) as [Year]
, DATENAME(month,c.[Date]) [Month]
, month(c.[Date]) as [Mdate]
, FORMAT(c.[Date],'dddd') as [Day]
, h.n as [Time]
from [hours] h
cross join calendar c
order by DATEADD(HOUR,h.n, format(c.[Date],'M/d/yyyy')), h.n

--check we now have all dim records created
select min(date_time)
, max(date_time) 
, count(*) no_records
, DATEDIFF(day, min(date_time), max(date_time) ) + 1 no_days
, (DATEDIFF(day, min(date_time), max(date_time) ) + 1)  * 24 expected_no_records
from [dbo].[dim_Date]

--Date Dim now has all records

---------------------------------------
--Perform query's
---------------------------------------

--create view to make reporting table
create view [dbo].vw_Pedestrian_Counts as
select 
    fp.[ID] 
	,fp.[Date_Time] 
	,dd.[Year] 
	,dd.[Month] 
	,dd.[Mdate] 
	,dd.[Day] 
	,dd.[Time] 
	,fp.[Sensor_ID] 
	,ds.[Sensor_Name] 
	,fp.[Hourly_Counts] 
FROM [dbo].[fact_Pedestrian_Counts] fp join [dbo].[dim_Date] dd on fp.[Date_Time] = dd.[Date_Time]
join [dbo].[dim_Sensor] ds on fp.[Sensor_ID] = ds.[Sensor_ID]


select top 10 * from [dbo].vw_Pedestrian_Counts

-----------------------------------------------------------------------------------------------------------
-- Requirement 1: Top 10 (most pedestrians) locations by day
-----------------------------------------------------------------------------------------------------------
select top 10 
DateDay
, DaySummary.Sensor_ID
, ds.[Sensor_Name]
, no_pedestrians
from 
    (select format(fp.[Date_Time],'M/d/yyyy') DateDay
    , fp.[Sensor_ID]
    , sum(fp.[Hourly_Counts]) no_pedestrians
    from [dbo].[fact_Pedestrian_Counts] fp
    group by format(fp.[Date_Time],'M/d/yyyy')
    , fp.[Sensor_ID]
    ) DaySummary 
    join [dbo].[dim_Sensor] ds on DaySummary.[Sensor_ID] = ds.[Sensor_ID]
Order by no_pedestrians desc

12/8/2016	35	Southbank	95832
3/8/2015	7	Birrarung Marr	88086
3/13/2022	29	St Kilda Rd-Alexandra Gardens	87407
3/8/2015	38	Flinders St-Swanston St (West)	85375
2/17/2018	35	Southbank	82158
3/13/2016	7	Birrarung Marr	81848
3/11/2012	7	Birrarung Marr	79902
4/25/2015	38	Flinders St-Swanston St (West)	79278
2/22/2015	38	Flinders St-Swanston St (West)	79089
4/10/2015	38	Flinders St-Swanston St (West)	78378


-----------------------------------------------------------------------------------------------------------
--Requirement 2: Top 10 (most pedestrians) locations by month
-----------------------------------------------------------------------------------------------------------     
select top 10 
Date_Month
, [Year]
, MonthSummary.Sensor_ID
, ds.[Sensor_Name]
, no_pedestrians
from 
    (select DATENAME(month,fp.[Date_Time]) Date_Month
    , Year(fp.[Date_Time]) as [Year]
    , fp.[Sensor_ID]
    , sum(fp.[Hourly_Counts]) no_pedestrians
    from [dbo].[fact_Pedestrian_Counts] fp
    group by 
     DATENAME(month,fp.[Date_Time]) 
    , Year(fp.[Date_Time])
    , fp.[Sensor_ID]
    ) MonthSummary 
    join [dbo].[dim_Sensor] ds on MonthSummary.[Sensor_ID] = ds.[Sensor_ID]
Order by no_pedestrians desc


March	2015	38	Flinders St-Swanston St (West)	1966429
March	2016	38	Flinders St-Swanston St (West)	1951326
December	2015	38	Flinders St-Swanston St (West)	1931228
April	2016	38	Flinders St-Swanston St (West)	1900791
December	2016	38	Flinders St-Swanston St (West)	1857062
January	2016	38	Flinders St-Swanston St (West)	1844471
October	2015	38	Flinders St-Swanston St (West)	1820460
November	2015	38	Flinders St-Swanston St (West)	1818857
July	2016	38	Flinders St-Swanston St (West)	1811931
August	2016	38	Flinders St-Swanston St (West)	1805067

-----------------------------------------------------------------------------------------------------------
--Requirement 3: Which location has shown most decline due to lockdowns in last 2 years
-----------------------------------------------------------------------------------------------------------

/*
Melbourne Lockdown dates:
Tuesday 31st March 2020 to Tuesday 12th May 2020
Thursday 9th July 2020 to Tuesday 27th October 2020.
Saturday 13th February 2021 to Wednesday 17th February 2021
Friday 28th May 2021 to Thursday 10th June 2021
Friday 16th July 2021 to Tuesday 27th July 2021
Thursday 5th August 2021 to Thursday 21st October 2021

Going to use range 31st March 2020 to 21st October 2021 as the lockdown period, could make a table and add in all the date ranges but this is a few hour exercise

select top 100 max(Date_time), min(date_time) from [dbo].[fact_Pedestrian_Counts] fp
2022-07-31 23:00:00.0000000
2009-05-01 00:00:00.0000000

*/

drop view vw_sensor_avg_per_day

create view vw_sensor_avg_per_day as 
--This view will give a day ave for lockdown and non lockdown by sensor   
select Sensor_id
 , sum(CASE
    WHEN Lockdown = 1
    THEN avg_per_day
    ELSE 0
    END) as avg_per_day_Lockdown
 , sum(CASE
    WHEN Lockdown = 0
    THEN avg_per_day
    ELSE 0
    END) as avg_per_day_non_Lockdown
FROM
    (select [Sensor_ID]
    , Lockdown
    , avg(no_pedestrians) avg_per_day
    from (
        select format(fp.[Date_Time],'M/d/yyyy') DateDay
        , CASE
                WHEN fp.[Date_Time] BETWEEN '03/31/2020' AND '10/21/2021'
                THEN 1
                ELSE 0
        END as Lockdown
        , fp.[Sensor_ID]
        , sum(fp.[Hourly_Counts]) no_pedestrians
        from [dbo].[fact_Pedestrian_Counts] fp
        group by format(fp.[Date_Time],'M/d/yyyy')
        , fp.[Sensor_ID]
        , CASE
                WHEN fp.[Date_Time] BETWEEN '03/31/2020' AND '10/21/2021'
                THEN 1
                ELSE 0
        END 
        ) DaySummary 
    Group by [Sensor_ID], Lockdown) x
  group by Sensor_id  


--Now lets see what had the biggest impact, I am going to ignore 0 records as may impact the results
--Going to make the impact the biggest fall in numbers could also do % drop

select top 10 
av.Sensor_id 
, ds.[Sensor_Name]
, avg_per_day_non_Lockdown
, avg_per_day_Lockdown
, avg_per_day_non_Lockdown - avg_per_day_Lockdown as Diff
from vw_sensor_avg_per_day av join [dbo].[dim_Sensor] ds on av.[Sensor_ID] = ds.[Sensor_ID]
where avg_per_day_Lockdown > 0
Order by avg_per_day_non_Lockdown - avg_per_day_Lockdown desc

Sensor_id	Sensor_Name	avg_per_day_non_Lockdown	avg_per_day_Lockdown	Diff
35	Southbank	36100	11245	24855
41	Flinders La-Swanston St (West)	40990	16656	24334
4	Town Hall (West)	35241	12504	22737
3	Melbourne Central	28625	7373	21252
22	Flinders St-Elizabeth St (East)	36785	15831	20954
24	Spencer St-Collins St (North)	27413	7213	20200
6	Flinders Street Station Underpass	28052	9449	18603
2	Bourke Street Mall (South)	25046	6529	18517
1	Bourke Street Mall (North)	27260	10885	16375
28	The Arts Centre	22878	7559	15319


-----------------------------------------------------------------------------------------------------------      
--Requirement 4: Which location has most growth in last year
-----------------------------------------------------------------------------------------------------------
--as the record sets latest date is 2022-07-31 "in the last year" will be taken as 2021-07-31 to 2022-07-31

--going to sum up the previous year totals and compare with the last year totals then get the %growth

drop view vw_current_vs_last_year_no_pedestrians

--setup base view
create view vw_current_vs_last_year_no_pedestrians as
select [Sensor_ID]
, sum (Hourly_Counts) no_pedestrians_a_year
, sum( CASE
    WHEN fp.[Date_Time] BETWEEN '2021-07-31' AND '2022-07-31'
        THEN Hourly_Counts
        ELSE 0
        END) as no_pedestrians_CurrentYear
, sum( CASE
    WHEN fp.[Date_Time] BETWEEN '2020-07-31' AND '2021-07-31'
        THEN Hourly_Counts
        ELSE 0
        END) as no_pedestrians_PreviousYear        
from [dbo].[fact_Pedestrian_Counts] fp
where fp.[Date_Time] BETWEEN '2020-07-31' AND '2022-07-31'
group by [Sensor_ID]


--Select the biggest % increase over the last year
select top 10  
v.[Sensor_ID]
, ds.[Sensor_Name]
, no_pedestrians_CurrentYear
, no_pedestrians_PreviousYear   
, (no_pedestrians_CurrentYear - no_pedestrians_PreviousYear) / CONVERT(decimal(10,2),no_pedestrians_PreviousYear) * 100  as Percentage_Increase
from  vw_current_vs_last_year_no_pedestrians v join [dbo].[dim_Sensor] ds on v.[Sensor_ID] = ds.[Sensor_ID]
where no_pedestrians_PreviousYear <> 0 
order by (no_pedestrians_CurrentYear - no_pedestrians_PreviousYear) / CONVERT(decimal(10,2),no_pedestrians_PreviousYear) * 100  desc

Sensor_ID	Sensor_Name	no_pedestrians_CurrentYear	no_pedestrians_PreviousYear	Percentage_Increase
78	Harbour Esplanade (West) - Bike Path	423379	63132	570.62503959900
77	Harbour Esplanade (West) - Pedestrian Pa	1349065	298216	352.37847734500
54	Lincoln-Swanston(West)	829220	298217	178.05926556800
29	St Kilda Rd-Alexandra Gardens	1937751	810690	139.02490471000
76	Macaulay Rd-Bellair St	497435	211234	135.49002528000
3	Melbourne Central	6337464	2816221	125.03432791600
75	Spring St- Flinders St (West)	358234	161573	121.71649966200
35	Southbank	8616313	3964220	117.35203898800
11	Waterfront City	824781	380766	116.61098942600
72	Flinders St-ACMI	2046475	1025564	99.54629842700


-----------------------------------------------------------------------------------------------------------      
--Requirement 5: Other potential analysis
-----------------------------------------------------------------------------------------------------------

--could look at most unused sensor
--could link the data set with other data such as road work improvements/ initiatives, have they increased the pedestrian use
--could add in weather information to see if weather contitions change behaviour
--check for missing sensor data and try to understand why there are data gaps 

--------------------------------------------------------------------------------------------------------------
--Thanks I enjoyed the challenge, please provide feedback to christianhicks@hotmail.com

--The END
--------------------------------------------------------------------------------------------------------------