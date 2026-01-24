with GroupMarks as(
select *,
case
    when LAG(TEUR)over (order by cast(SHURA AS INT)) is null then 1
	else 0
end as IsNewGroup
from [dbo].[Finance_Structure]
),
GroupIDs AS (
    SELECT *,
           SUM(IsNewGroup) OVER (ORDER BY CAST(SHURA AS INT)) AS GroupID
    FROM GroupMarks
)
SELECT 
    KOD_ARIHA, KOD_TAVLA_PARAMETRIM, KODSICUM_ELECTRA, SEIF, SHURA, TEUR,
    FIRST_VALUE(TEUR) OVER (PARTITION BY GroupID ORDER BY CAST(SHURA AS INT)) AS KOTERET
FROM GroupIDs
ORDER BY CAST(SHURA AS INT);