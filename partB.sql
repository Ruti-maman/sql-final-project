 /* ------------------------------------------------------------------------------------------------
   בעיה א' - זיהוי משתמשים תובעניים
   ------------------------------------------------------------------------------------------------
   
   הסבר מילולי לגישת הפתרון (Solution Strategy):
   כדי לזהות משתמשים ששלחו מעל 10 בקשות בחלון זמן של 5 דקות, נקטנו בגישה של "חלון זמן גולש" (Sliding Window):
   
   1. הצלבה עצמית (Self-Join): אנו מבצעים JOIN של טבלת הבקשות לעצמה.
      המטרה: עבור כל "בקשת עוגן" (R1), אנו מחפשים את כל הבקשות השכנות שלה (R2) מאותו משתמש.
      
   2. הגדרת החלון: אנו מסננים את התוצאות כך שנראה רק בקשות (R2) שהתקבלו בטווח של 0 עד 5 דקות
      מהבקשה המקורית (R1).
      
   3. אגרגציה וסינון: אנו סופרים כמה בקשות שכנות נמצאו לכל בקשה מקורית.
      באמצעות HAVING, אנו שומרים רק מקרים בהם הספירה גדולה מ-10.
      
   4. שליפת השיא: לבסוף, אנו שולפים את המשתמש עם מספר החריגות הגבוה ביותר.
*/-----------------------------------------------------------------------------------------------

WITH UsearPeaks AS (
    SELECT 
        R1.UserID,
        COUNT(R2.RequestID) AS RequestCount
    FROM 
        DocumentRequests R1
    JOIN 
        DocumentRequests R2 ON R1.UserID = R2.UserID 
    WHERE 
        R1.RequestID != R2.RequestID 
        AND DATEDIFF(minute, R1.RequestTime, R2.RequestTime) BETWEEN 0 AND 5
    GROUP BY 
        R1.UserID, R1.RequestID
    HAVING 
        COUNT(R2.RequestID) > 10
)
SELECT TOP 1 WITH TIES UserID
FROM UsearPeaks
GROUP BY UserID
ORDER BY MAX(RequestCount) DESC;

GO
/* ------------------------------------------------------------------------------------------------
   בעיה ב' - מקסום טיפול בבקשות דחופות
   ------------------------------------------------------------------------------------------------
   
   הסבר מילולי לגישת הפתרון (Solution Strategy):
   זוהי בעיית אופטימיזציה למציאת מסלול מקסימלי תחת אילוצים. הפתרון מבוצע באמצעות Recursive CTE:
   
   1. הנחות יסוד: הגדרנו זמן טיפול (Duration) לכל בקשה כדי לדעת מתי המערכת מתפנה.
   
   2. עוגן הרקורסיה (Base Case): איתור כל הבקשות שיכולות להיות הראשונות ברצף,
      תוך בדיקה שניתן לסיים אותן לפני פקיעת התוקף (ExpirationTime).
      
   3. צעד רקורסיבי (Recursive Step): המערכת מנסה "לשרשר" את הבקשה הבאה בתור, תחת התנאים:
      - תזמון: הבקשה הבאה מתחילה רק כשהקודמת הסתיימה או כשהחדשה הגיעה (המאוחר מביניהם).
      - מקביליות: הוספנו תמיכה במצב בו שתי בקשות נכנסות באותו זמן בדיוק (באמצעות תנאי OR חכם).
      - תוקף: חובה לסיים את הבקשה החדשה לפני המועד האחרון שלה.
      
   4. בחירת המקסימום: מתוך כל המסלולים החוקיים, נבחר המסלול עם סכום העדיפויות (Priority) הגבוה ביותר.
*/
WITH RequestCalc AS (
    SELECT 
        RequestID,
        Priority,
        RequestTime,
        ExpirationTime,
        10 AS DurationMinutes 
    FROM 
        [dbo].[DocumentRequests]
),
OptimizationPaths AS (
    SELECT 
        RequestID AS LastRequestID,
        CAST(RequestID AS VARCHAR(MAX)) AS RequestPath, 
        Priority AS TotalPriority,      
        RequestTime AS StartTime,
        DATEADD(minute, DurationMinutes, RequestTime) AS FinishTime,
        RequestTime AS OriginalReqTime
    FROM 
        RequestCalc
    WHERE 
        DATEADD(minute, DurationMinutes, RequestTime) <= ExpirationTime

    UNION ALL
    SELECT 
        R.RequestID,
        P.RequestPath + ',' + CAST(R.RequestID AS VARCHAR(MAX)),
        P.TotalPriority + R.Priority,
        CASE 
            WHEN P.FinishTime > R.RequestTime THEN P.FinishTime 
            ELSE R.RequestTime 
        END AS NewStartTime,
        DATEADD(minute, R.DurationMinutes, 
                CASE 
                    WHEN P.FinishTime > R.RequestTime THEN P.FinishTime 
                    ELSE R.RequestTime 
                END) AS NewFinishTime,
        R.RequestTime
    FROM 
        RequestCalc R
    JOIN 
        OptimizationPaths P 
        ON (R.RequestTime > P.OriginalReqTime)
        OR (R.RequestTime = P.OriginalReqTime AND R.RequestID > P.LastRequestID)
    WHERE 
        R.RequestID <> P.LastRequestID
        AND
        DATEADD(minute, R.DurationMinutes, 
                CASE 
                    WHEN P.FinishTime > R.RequestTime THEN P.FinishTime 
                    ELSE R.RequestTime 
                END) <= R.ExpirationTime
)
SELECT TOP 1 
    RequestPath AS OptimalRequestPath,
    TotalPriority AS MaxTotalPriority,
    FinishTime AS EstimatedCompletionTime
FROM 
    OptimizationPaths
ORDER BY 
    TotalPriority DESC 
OPTION (MAXRECURSION 0);

GO

/* ------------------------------------------------------------------------------------------------
   בעיה ג' - זיהוי צווארי בקבוק
   ------------------------------------------------------------------------------------------------
   
   הסבר מילולי לגישת הפתרון (Solution Strategy):
   כדי לזהות עומס חריג, ביצענו קיבוץ לפי שעות (Time Bucketing) וניתוח זמני המתנה:
   
   1. חישוב זמן המתנה (Latency): לכל בקשה שטופלה, חישבנו את ההפרש בדקות בין זמן השליחה
      לזמן התגובה בפועל.
      
   2. חלוקה לשעות: קיבצנו את הבקשות לפי ה"שעה העגולה" בה נשלחו (למשל, כל הבקשות של 10:00-10:59).
      זה מאפשר לזהות מגמות עומס לאורך היום.
      
   3. ממוצע ודירוג: חישבנו את הממוצע לכל שעה, ושלפנו את השעה עם הממוצע הגבוה ביותר (הגרוע ביותר).
*/

SELECT TOP 1 
    CONCAT(DATEPART(HOUR, [RequestTime]), ':00 - ', DATEPART(HOUR, [RequestTime]) + 1, ':00') AS TimeRange,
    AVG(DATEDIFF(minute, [RequestTime], [ResponseTime])) AS AvgWaitTimeMinutes
FROM 
    [dbo].[DocumentRequests]
WHERE 
    [ResponseTime] IS NOT NULL
GROUP BY 
    DATEPART(HOUR, [RequestTime])
ORDER BY 
    AVG(DATEDIFF(minute, [RequestTime], [ResponseTime])) DESC;
