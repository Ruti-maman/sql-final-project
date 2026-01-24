--1
SELECT 
    L.ItemCode,
    SUM(L.Qty) AS TotalQuantity,
    SUM(L.LineSum * (1 - (COALESCE(H.DiscPrcnt, 0) / 100.0))) AS TotalSalesAmount,
    COUNT(DISTINCT L.DocNum) AS InvoiceCount
FROM 
    SalesLine AS L
    JOIN SalesHeader AS H ON L.DocNum = H.DocNum
GROUP BY 
    L.ItemCode
ORDER BY 
    L.ItemCode;
--2
select distinct s.DocNum
from [dbo].[SalesLine] s
join [dbo].[SalesLine] sl
on s.DocNum=sl.DocNum
where s.ItemCode=3611010and sl.ItemCode=3611600

--3
select SalesPersonName
from [dbo].[SalesPerson] sp 
join [dbo].[SalesHeader]sh
on sp.SalesPersonCode=sh.SalesPersonCode
join [dbo].[SalesLine] sl
on sh.DocNum=sl.DocNum
join [dbo].[Items] i
on i.ItemCode=sl.ItemCode
group by SalesPersonName 
having count(distinct sl.ItemCode)=(select  COUNT( distinct ItemCode)
from [dbo].[Items]
)

--4
with AgentStats as
(
select [SalesPersonCode],count(distinct i.ItemCode) as countItem,sum(Qty) as sumItem
from [dbo].[SalesHeader] sh
join [dbo].[SalesLine] sl
on sh.DocNum=sl.DocNum
join [dbo].[Items] i
on i.ItemCode=sl.ItemCode
group by [SalesPersonCode]
),
ListItem as
(
select ItemCode ,SalesPersonCode
from [dbo].[SalesHeader] sh
join [dbo].[SalesLine] sl 
on sh.DocNum=sl.DocNum
),
BestVariety as
(
select ItemCode
from ListItem
where [SalesPersonCode]in(
select top 1 with ties [SalesPersonCode]
from AgentStats
order by countItem desc
)),
BestQty as
(
select ItemCode
from ListItem
where [SalesPersonCode]in(
select top 1 with ties [SalesPersonCode]
from AgentStats
order by sumItem desc
)),
WorstVariety as
(
select ItemCode
from ListItem
where [SalesPersonCode]in(
select top 1 with ties [SalesPersonCode]
from AgentStats
order by countItem 
))

select ItemCode
from BestVariety
intersect
select ItemCode
from BestQty
except
select ItemCode
from WorstVariety
order by ItemCode


--5
WITH RawData AS (
    SELECT
        SP.SalesPersonName,
        SP.SalesPersonCode,
        L.ItemCode,
        L.LineSum,
        H.DocDiscount,
        SUM(L.LineSum) OVER (PARTITION BY H.DocNum) as DocTotalGross
    FROM SalesHeader H
    JOIN SalesLine L ON H.DocNum = L.DocNum
    JOIN SalesPerson SP ON H.SalesPersonCode = SP.SalesPersonCode
),
ItemNetSales AS (
    SELECT
        SalesPersonName,
        SalesPersonCode,
        ItemCode,
        SUM(
            CASE 
                WHEN DocTotalGross = 0 THEN 0 
                ELSE LineSum * ( (DocTotalGross - DocDiscount) / DocTotalGross )
            END
        ) AS TotalRealSales 
    FROM
        RawData
    GROUP BY
        SalesPersonName, SalesPersonCode, ItemCode
),
FinalStats AS (
    SELECT
        SalesPersonName,
        ItemCode,
        TotalRealSales,
        AVG(TotalRealSales) OVER (PARTITION BY SalesPersonCode) AS AvgNetSalesPerPerson
    FROM
        ItemNetSales
)
SELECT
    SalesPersonName,
    ItemCode,
    AvgNetSalesPerPerson,
    TotalRealSales
FROM
    FinalStats
WHERE
    TotalRealSales < AvgNetSalesPerPerson
ORDER BY
    SalesPersonName, TotalRealSales;

-----6
WITH SalesPersonTotals AS (
    SELECT
        H.SalesPersonCode,
        SP.SalesPersonName,
        SUM(L.Qty) AS TotalQtyPerPerson
    FROM SalesHeader H
    JOIN SalesLine L ON H.DocNum = L.DocNum
    JOIN SalesPerson SP ON H.SalesPersonCode = SP.SalesPersonCode
    GROUP BY
        H.SalesPersonCode, SP.SalesPersonName
),
ParetoAnalysis AS (
    SELECT
        SalesPersonCode,
        SalesPersonName,
        TotalQtyPerPerson,
        SUM(TotalQtyPerPerson) OVER (ORDER BY TotalQtyPerPerson DESC) AS RunningTotalQty,
        SUM(TotalQtyPerPerson) OVER () AS GrandTotalQty
    FROM
        SalesPersonTotals
),
TopPerformers AS (
    SELECT
        SalesPersonCode,
        SalesPersonName,
        TotalQtyPerPerson
    FROM
        ParetoAnalysis
    WHERE
        (RunningTotalQty - TotalQtyPerPerson) / GrandTotalQty < 0.88
)
SELECT
    TP.SalesPersonName,
    TP.TotalQtyPerPerson,   
    H.DocNum,               
    H.DocDate,              
    SUM(L.Qty) AS InvoiceQty 
FROM
    TopPerformers TP
JOIN
    SalesHeader H ON TP.SalesPersonCode = H.SalesPersonCode
JOIN
    SalesLine L ON H.DocNum = L.DocNum
GROUP BY
    TP.SalesPersonName, TP.TotalQtyPerPerson, H.DocNum, H.DocDate
ORDER BY
    TP.TotalQtyPerPerson DESC,
    H.DocDate ASC;             

-----7
SELECT
    SP.SalesPersonCode,
    SP.SalesPersonName,
    (
        SELECT SUM(L.LineSum) - SUM(DISTINCT H.DocDiscount)
        FROM SalesHeader H
        JOIN SalesLine L ON H.DocNum = L.DocNum
        WHERE H.SalesPersonCode = SP.SalesPersonCode
    ) AS TotalNetSales,
    (
        SELECT 
            (SUM(L.LineSum) - SUM(DISTINCT H.DocDiscount)) 
            / 
            COUNT(DISTINCT H.DocNum)
        FROM 
            SalesHeader H
        JOIN 
            SalesLine L ON H.DocNum = L.DocNum
        WHERE 
            H.SalesPersonCode = SP.SalesPersonCode
    ) AS AvgNetSalesPerInvoice

FROM
    SalesPerson SP
ORDER BY
    SP.SalesPersonCode;