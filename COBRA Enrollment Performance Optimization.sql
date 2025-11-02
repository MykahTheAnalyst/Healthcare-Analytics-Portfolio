/* ============================================================
   Project 2: COBRA Enrollment Performance Optimization
   ============================================================ */

-- 1️⃣ Drop existing summary table if it exists
DROP TABLE IF EXISTS dbo.COBRA_Performance_Summary;

-- 2️⃣ Create a unified performance summary table
SELECT
    E.Employer_ID,
    
    -- 🔹 Member Demographics & Key Dates
    COUNT(DISTINCT E.Member_ID) AS Total_Eligible,
    COUNT(DISTINCT EL.Member_ID) AS Total_Elected,
    ROUND(100.0 * COUNT(DISTINCT EL.Member_ID) / NULLIF(COUNT(DISTINCT E.Member_ID), 0), 2) AS Election_Rate_Percent,

    -- 🔹 Mailing Timeliness (Physical or Digital)
    SUM(CASE 
            WHEN DATEDIFF(DAY, E.Eligibility_Date, C.Packet_Generated_Date) <= 14 THEN 1 
            ELSE 0 
        END) AS OnTime_Mailings,
    SUM(CASE 
            WHEN DATEDIFF(DAY, E.Eligibility_Date, C.Packet_Generated_Date) > 14 THEN 1 
            ELSE 0 
        END) AS Late_Mailings,
    ROUND(100.0 * SUM(CASE 
            WHEN DATEDIFF(DAY, E.Eligibility_Date, C.Packet_Generated_Date) <= 14 THEN 1 
            ELSE 0 END) / NULLIF(COUNT(DISTINCT E.Member_ID), 0), 2) AS OnTime_Mailing_Rate_Percent,

    -- 🔹 Election Timeliness (Compliance Tracking)
    ROUND(AVG(DATEDIFF(DAY, C.Initiation_Date, EL.Election_Date)), 2) AS Avg_Days_To_Elect,
    SUM(CASE 
            WHEN DATEDIFF(DAY, C.Initiation_Date, EL.Election_Date) > 44 THEN 1 
            ELSE 0 
        END) AS Non_Compliant_Cases,
    ROUND(100.0 * SUM(CASE 
            WHEN DATEDIFF(DAY, C.Initiation_Date, EL.Election_Date) <= 44 THEN 1 
            ELSE 0 END) / NULLIF(COUNT(DISTINCT EL.Member_ID), 0), 2) AS Compliance_Rate_Percent,

    -- 🔹 Portal Adoption Metrics
    COUNT(DISTINCT P.Member_ID) AS Portal_Registrations,
    COUNT(DISTINCT CASE WHEN EL.Source = 'Portal' THEN EL.Member_ID END) AS Digital_Elections,
    ROUND(100.0 * COUNT(DISTINCT P.Member_ID) / NULLIF(COUNT(DISTINCT E.Member_ID), 0), 2) AS Portal_Adoption_Rate_Percent,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN EL.Source = 'Portal' THEN EL.Member_ID END) / NULLIF(COUNT(DISTINCT EL.Member_ID), 0), 2) AS Digital_Election_Rate_Percent,

    -- 🔹 Call Center Impact Metrics
    COUNT(DISTINCT CC.Call_ID) AS Total_Calls,
    ROUND(1.0 * COUNT(DISTINCT CC.Call_ID) / NULLIF(COUNT(DISTINCT E.Member_ID), 0), 2) AS Calls_Per_Member,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN EL.Source = 'Portal' THEN E.Member_ID END) / NULLIF(COUNT(DISTINCT CC.Member_ID), 0), 2) AS Digital_vs_Call_Ratio_Percent,

    -- 🔹 Operational Averages for Dashboard KPIs
    ROUND(AVG(DATEDIFF(DAY, E.Eligibility_Date, C.Packet_Generated_Date)), 2) AS Avg_Days_To_Mail,
    ROUND(AVG(DATEDIFF(DAY, E.Eligibility_Date, C.Initiation_Date)), 2) AS Avg_Days_To_Initiate

INTO dbo.COBRA_Performance_Summary
FROM dbo.COBRA_Eligibility E
LEFT JOIN dbo.COBRA_Packet_Log C 
    ON E.Member_ID = C.Member_ID
LEFT JOIN dbo.COBRA_Election EL 
    ON E.Member_ID = EL.Member_ID
LEFT JOIN dbo.Portal_User_Logins P 
    ON E.Member_ID = P.Member_ID
LEFT JOIN dbo.Call_Center_Contacts CC 
    ON E.Member_ID = CC.Member_ID
GROUP BY 
    E.Employer_ID
ORDER BY 
    E.Employer_ID;

-- 3️⃣ Preview the unified summary output
SELECT 
    Employer_ID,
    Total_Eligible,
    Total_Elected,
    Election_Rate_Percent,
    OnTime_Mailings,
    Late_Mailings,
    OnTime_Mailing_Rate_Percent,
    Avg_Days_To_Elect,
    Non_Compliant_Cases,
    Compliance_Rate_Percent,
    Portal_Registrations,
    Digital_Elections,
    Portal_Adoption_Rate_Percent,
    Digital_Election_Rate_Percent,
    Total_Calls,
    Calls_Per_Member,
    Digital_vs_Call_Ratio_Percent,
    Avg_Days_To_Mail,
    Avg_Days_To_Initiate
FROM dbo.COBRA_Performance_Summary
ORDER BY Employer_ID;
