--------סעיף א-------
IF OBJECT_ID('dbo.FindMySum') IS NOT NULL
    DROP FUNCTION dbo.FindMySum;
go
CREATE FUNCTION dbo.FindMySum1(@X INT)
RETURNS TABLE
AS
RETURN
(
  select 
a1.val as num1,
a2.val as num2,
a3.val as num3
from [dbo].[A] a1
join [dbo].[A] a2
on a1.val!=a2.val
join  [dbo].[A] a3
on a1.val!=a3.val and a2.val!=a3.val
where (a1.val+a2.val+a3.val)=@X
);
go

SELECT *
FROM dbo.FindMySum1(32);

-----סעיף ב------
DECLARE @X INT = 32;
IF OBJECT_ID('tempdb..#table_temp') IS NOT NULL
    DROP TABLE #table_temp;

SELECT 
    a1.val as num1,
    a2.val as num2,
    a3.val as num3
INTO #table_temp  
FROM [dbo].[A] a1
JOIN [dbo].[A] a2 ON a1.val < a2.val
JOIN [dbo].[A] a3 ON a2.val < a3.val
WHERE (a1.val + a2.val + a3.val) = @X; 

SELECT * FROM #table_temp;
------סעיף ג---------
SELECT top 1 num1,num2,num3
FROM #table_temp
order by (num1*num2*num3) desc
