   -- Project: COBRA Initiation-to-Election + Call Center Tracking

-- 1️⃣ Drop existing temp tables
DROP TABLE IF EXISTS #COBRA_Summary;
DROP TABLE IF EXISTS #COBRA_CallSummary;

-- 2️⃣ Create unified summary from COBRA process data
SELECT
    c.EmployerGroup,
    c.MemberID,
    c.MemberName,
    c.QualifyingEventDate,
    c.InitiationDate,
    c.PacketSentDate,
    c.ElectionReceivedDate,
    c.PortalEnrollmentDate,
    c.CommunicationChannel,  

    -- Timelines
    DATEDIFF(DAY, c.QualifyingEventDate, c.InitiationDate) AS Days_To_Initiate,
    DATEDIFF(DAY, c.InitiationDate, c.PacketSentDate) AS Days_To_Send_Packet,
    DATEDIFF(DAY, c.PacketSentDate, c.ElectionReceivedDate) AS Days_To_Elect,

    -- Compliance
    CASE 
        WHEN DATEDIFF(DAY, c.QualifyingEventDate, c.PacketSentDate) > 44 THEN 'Late'
        ELSE 'On Time'
    END AS Notification_Status,

    -- Adoption Flags
    CASE WHEN c.CommunicationChannel = 'Portal' THEN 1 ELSE 0 END AS Portal_Used_Flag,
    CASE WHEN c.CommunicationChannel = 'Mail' THEN 1 ELSE 0 END AS Mail_Used_Flag,

    -- Adoption Timelines
    CASE 
        WHEN c.PortalEnrollmentDate IS NOT NULL THEN 
             DATEDIFF(DAY, c.InitiationDate, c.PortalEnrollmentDate)
        ELSE NULL
    END AS Days_To_Adopt_Portal,

    -- Risk Indicators
    CASE WHEN DATEDIFF(DAY, c.InitiationDate, c.PacketSentDate) > 7 THEN 1 ELSE 0 END AS Late_Mailing_Flag,
    CASE WHEN c.ElectionReceivedDate IS NULL THEN 1 ELSE 0 END AS Missing_Election_Flag

INTO #COBRA_Summary
FROM dbo.COBRA_Initiations AS c;



-- 3️⃣ Summarize Call Center Data (Inbound Calls Related to COBRA)

SELECT
    MemberID,
    COUNT(*) AS Total_Calls,
    SUM(CASE WHEN CallReason LIKE '%packet%' THEN 1 ELSE 0 END) AS Packet_Status_Inquiries,
    SUM(CASE WHEN CallReason LIKE '%enrollment%' THEN 1 ELSE 0 END) AS Enrollment_Status_Inquiries,
    SUM(CASE WHEN CallReason LIKE '%deadline%' THEN 1 ELSE 0 END) AS Deadline_Inquiries,
    SUM(CASE WHEN CallReason LIKE '%portal%' THEN 1 ELSE 0 END) AS Portal_Support_Calls,
    ROUND(AVG(CallDuration_Min), 2) AS Avg_Call_Duration_Min,
    SUM(CASE WHEN ResolutionStatus = 'Escalated' THEN 1 ELSE 0 END) AS Escalated_Calls
INTO #COBRA_CallSummary
FROM dbo.CallCenter_Logs
WHERE CallCategory = 'COBRA'
GROUP BY MemberID;



-- 4️⃣ Merge COBRA Workflow + Call Center Summary
SELECT
    c.EmployerGroup,
    COUNT(DISTINCT c.MemberID) AS Total_Eligible_Members,

    -- Portal Adoption
    SUM(c.Portal_Used_Flag) AS Total_Portal_Enrollments,
    ROUND(100.0 * SUM(c.Portal_Used_Flag) / NULLIF(COUNT(*),0), 2) AS Portal_Adoption_Rate_Percent,

    -- Timeliness Metrics
    ROUND(AVG(c.Days_To_Initiate), 2) AS Avg_Days_To_Initiate,
    ROUND(AVG(c.Days_To_Send_Packet), 2) AS Avg_Days_To_Send_Packet,
    ROUND(AVG(c.Days_To_Elect), 2) AS Avg_Days_To_Elect,
    SUM(CASE WHEN c.Notification_Status = 'Late' THEN 1 ELSE 0 END) AS Total_Late_Notifications,

    -- Risk Indicators
    SUM(c.Late_Mailing_Flag) AS Total_Late_Mailings,
    SUM(c.Missing_Election_Flag) AS Missing_Election_Count,

    -- Call Center KPIs
    COUNT(DISTINCT cs.MemberID) AS Members_Who_Called,
    COALESCE(SUM(cs.Total_Calls), 0) AS Total_Calls_Received,
    COALESCE(ROUND(AVG(cs.Total_Calls), 2), 0) AS Avg_Calls_Per_Member,
    COALESCE(SUM(cs.Packet_Status_Inquiries), 0) AS Packet_Status_Calls,
    COALESCE(SUM(cs.Enrollment_Status_Inquiries), 0) AS Enrollment_Status_Calls,
    COALESCE(SUM(cs.Deadline_Inquiries), 0) AS Deadline_Calls,
    COALESCE(SUM(cs.Portal_Support_Calls), 0) AS Portal_Help_Calls,
    COALESCE(SUM(cs.Escalated_Calls), 0) AS Escalated_Calls,
    COALESCE(ROUND(AVG(cs.Avg_Call_Duration_Min), 2), 0) AS Avg_Call_Duration_Min,

    -- Derived Efficiency Metrics
    ROUND(100.0 * SUM(CASE WHEN c.Notification_Status = 'On Time' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Compliance_Rate_Percent,
    ROUND(100.0 * COUNT(DISTINCT cs.MemberID) / COUNT(*), 2) AS Member_Call_Rate_Percent

FROM #COBRA_Summary c
LEFT JOIN #COBRA_CallSummary cs ON c.MemberID = cs.MemberID
GROUP BY c.EmployerGroup
ORDER BY c.EmployerGroup;


