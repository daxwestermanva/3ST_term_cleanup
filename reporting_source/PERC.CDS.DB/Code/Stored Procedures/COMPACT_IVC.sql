


-- =============================================
-- Author:			Liam Mina
-- Create date:		2023-08-10
-- Description:		Pulls together IVC (Community Care) data related to COMPACT, including ER notifications, referrals, and paid claims
-- Modifications:
--	2023-10-19	LM	Add notification, referral, and consult IDs from TIUs; merge health factors
--	2024-05-13	LM	Pull health factor/DTA data from new COMPACT.Templates table created in Code.COMPACT
--	2024-12-05	LM	Reclassify Place of Service IDs 31 and 52 as outpatient due to guidance from IVC. Dim table on A06 [CDWWork].[ccrs].[DIM_PLACE_OF_SERVICE]
--	2024-12-31	LM	Remove health factors that match with a claim that is not COMPACT-related
--	2025-01-13	LM	Pull discharge date from associated 1720J records if it's missing from one of the inpatient records
--	2025-05-28	LM	Add claim amount
--	2025-08-07	LM	Fill in discharge date if it doesn't exist in 1720J records but does exist under another payment authority

-- =============================================
CREATE PROCEDURE [Code].[COMPACT_IVC]
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] @Name = 'Code.COMPACT_IVC', @Description = 'Execution of Code.COMPACT_IVC SP'


/****************************************************************************************
Step 1: Get health factor records from Community Care notes documenting COMPACT-related care 
****************************************************************************************/

DROP TABLE IF EXISTS #CommunityHF; 
SELECT 
	MVIPersonSID
	,VisitSID 
	,Sta3n
	,ChecklistID
	,TemplateDateTime 
	,TemplateSelection
	,List
INTO  #CommunityHF
FROM [COMPACT].[Template] h WITH (NOLOCK) 
WHERE List = 'COMPACT_InitialCareCommunity'

DROP TABLE IF EXISTS #CommunityTIU
SELECT p.MVIPersonSID
	,ReferenceDateTime
	,t.VisitSID
INTO #CommunityTIU
FROM [TIU].[TIUDocument] t WITH (NOLOCK)
INNER JOIN #CommunityHF p --limit to COMPACT-related notes
	ON p.VisitSID = t.VisitSID
WHERE t.ReferenceDateTime > '2023-01-17'

DROP TABLE IF EXISTS #AddLocationsVistA_IVC; 
SELECT 
	h.MVIPersonSID
	,ISNULL(dd.StaPa,h.Sta3n) AS StaPa
	,h.VisitSID 
	,h.Sta3n
	,ISNULL(c.ReferenceDateTime, h.TemplateDateTime) AS TemplateDateTime  --for community care notes, use date the note was backdated to to capture start of CC episode
	,v.VisitDateTime
	,h.List
	,h.TemplateSelection
INTO  #AddLocationsVistA_IVC
FROM #CommunityHF h WITH (NOLOCK) 
INNER JOIN [Outpat].[Visit] v WITH (NOLOCK) 
	ON h.VisitSID = v.VisitSID
LEFT JOIN [Lookup].[DivisionFacility] dd WITH (NOLOCK) 
	ON dd.DivisionSID = v.DivisionSID
LEFT JOIN #CommunityTIU c 
	ON h.VisitSID = c.VisitSID


/****************************************************************************************
Step 2: From the text of the Community Care notes, extract any Notification IDs, Referral IDs, or ConsultIDs
Goal is to join the TIU/HF data with the IVC data whenever possible, using these IDs
****************************************************************************************/

--Get IDs from text of TIU document
DROP TABLE IF EXISTS #TIU_HF
SELECT b.MVIPersonSID
	  ,b.PatientICN
	  ,a.Sta3n
	  ,StaPa = ISNULL(s.StaPa,a.Sta3n)
	  ,EntryDateTime = MIN(a.EntryDateTime) OVER (PARTITION BY a.VisitSID)
	  ,ReferenceDateTime = MIN(a.ReferenceDateTime) OVER (PARTITION BY a.VisitSID)
	  ,TIUDocumentDefinition = MAX(a.TIUDocumentDefinition) OVER (PARTITION BY a.VisitSID)
	  ,a.VisitSID
	  --,a.ReportText
	  ,ConsultNumber = MAX(TRIM(CASE WHEN ReportText LIKE '%Consult No%HSRM%'
							THEN SUBSTRING(ReportText, CHARINDEX('Consult No', ReportText) + LEN('Consult No'), 
								CHARINDEX('HSRM', ReportText,CHARINDEX('Consult No',ReportText)+LEN('Consult No')) - CHARINDEX('Consult No', ReportText) - LEN('Consult No'))
							WHEN ReportText LIKE '%Consult No%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Consult No',ReportText)+LEN('Consult No'),LEN(ReportText)-CHARINDEX('Consult No',ReportText) + LEN('Consult No')),12))
							ELSE NULL END)) OVER (PARTITION BY a.VisitSID)
	  ,Notification_ID=MAX(CASE WHEN ReportText LIKE '%Notification ID is%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Notification ID is',ReportText)+LEN('Notification ID is'),LEN(ReportText)-CHARINDEX('Notification ID is',ReportText) + LEN('Notification ID is')),20))
							WHEN ReportText LIKE '%Notification ID of%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Notification ID of',ReportText)+LEN('Notification ID of'),LEN(ReportText)-CHARINDEX('Notification ID of',ReportText) + LEN('Notification ID of')),20))			
							WHEN ReportText LIKE '%Notification ID/Status%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Notification ID/Status:',ReportText)+LEN('Notification ID/Status:'),LEN(ReportText)-CHARINDEX('Notification ID/Status:',ReportText) + LEN('Notification ID/Status:')),20))
							WHEN ReportText LIKE '%Notification ID#%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Notification ID#',ReportText)+LEN('Notification ID#'),LEN(ReportText)-CHARINDEX('Notification ID#',ReportText) + LEN('Notification ID#')),20))
							WHEN ReportText LIKE '%Notification ID #%'
								THEN TRIM(TRIM(TRIM(TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Notification ID #',ReportText)+LEN('Notification ID #'),LEN(ReportText)-CHARINDEX('Notification ID #',ReportText) + LEN('Notification ID #')),20)))))
							WHEN ReportText LIKE '%Notification ID%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Notification ID',ReportText)+LEN('Notification ID'),LEN(ReportText)-CHARINDEX('Notification ID',ReportText) + LEN('Notification ID')),20))
							WHEN ReportText LIKE '%Notification%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Notification',ReportText)+LEN('Notification'),LEN(ReportText)-CHARINDEX('Notification',ReportText) + LEN('Notification')),20))
							WHEN ReportText LIKE '%ECR%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('ECR',ReportText)+LEN('ECR'),LEN(ReportText)-CHARINDEX('ECR',ReportText) + LEN('ECR')),20))
							WHEN ReportText LIKE '%Clinical Review%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Clinical Review',ReportText)+LEN('Clinical Review'),LEN(ReportText)-CHARINDEX('Clinical Review',ReportText) + LEN('Clinical Review')),20))
							WHEN ReportText LIKE '%Coordination Pending%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Coordination Pending',ReportText)+LEN('Coordination Pending'),LEN(ReportText)-CHARINDEX('Coordination Pending',ReportText) + LEN('Coordination Pending')),20))
							WHEN ReportText LIKE '%Records Requested%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Records Requested',ReportText)+LEN('Records Requested'),LEN(ReportText)-CHARINDEX('Records Requested',ReportText) + LEN('Records Requested')),20))
							ELSE NULL END) OVER (PARTITION BY a.VisitSID)
	  ,Referral_ID = MAX(CASE WHEN ReportText LIKE '%Referral #%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Referral #',ReportText)+LEN('Referral #'),LEN(ReportText)-CHARINDEX('Referral #',ReportText) + LEN('Referral #')),13))
							WHEN ReportText LIKE '%Referral ID%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Referral ID',ReportText)+LEN('Referral ID'),LEN(ReportText)-CHARINDEX('Referral ID',ReportText) + LEN('Referral ID')),13))
							WHEN ReportText LIKE '%HSRM ID%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('HSRM ID',ReportText)+LEN('HSRM ID'),LEN(ReportText)-CHARINDEX('HSRM ID',ReportText) + LEN('HSRM ID')),13))
							WHEN ReportText LIKE '%HSRM #%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('HSRM #',ReportText)+LEN('HSRM #'),LEN(ReportText)-CHARINDEX('HSRM #',ReportText) + LEN('HSRM #')),13))
							WHEN ReportText LIKE '%HSRM Ref #%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('HSRM Ref #',ReportText)+LEN('HSRM Ref #'),LEN(ReportText)-CHARINDEX('HSRM Ref #',ReportText) + LEN('HSRM Ref #')),13))
							WHEN ReportText LIKE '%Referral Number%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Referral Number',ReportText)+LEN('Referral Number'),LEN(ReportText)-CHARINDEX('Referral Number',ReportText) + LEN('Referral Number')),13))
							WHEN ReportText LIKE '%Referral%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Referral',ReportText)+LEN('Referral'),LEN(ReportText)-CHARINDEX('Referral',ReportText) + LEN('Referral')),13))
							WHEN ReportText LIKE '%Authorization Number%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Authorization Number',ReportText)+LEN('Authorization Number'),LEN(ReportText)-CHARINDEX('Authorization Number',ReportText) + LEN('Authorization Number')),13))
							WHEN ReportText LIKE '%Auth%'
								THEN TRIM(LEFT(SUBSTRING(ReportText,CHARINDEX('Auth',ReportText)+LEN('Auth'),LEN(ReportText)-CHARINDEX('Auth',ReportText) + LEN('Auth')),13))
							ELSE NULL END) OVER (PARTITION BY a.VisitSID)
	  ,a.HealthFactorType
INTO #TIU_HF
FROM [PDW].[OMHSP_PERC_COMPACT_TIU_IVC] a WITH (NOLOCK) 
INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] b WITH (NOLOCK)
	ON a.PatientSID = b.PatientPersonSID
INNER JOIN [Outpat].[Visit] v WITH (NOLOCK)
	ON a.VisitSID = v.VisitSID
INNER JOIN [Lookup].[DivisionFacility] s WITH (NOLOCK) 
	ON v.DivisionSID = s.DivisionSID
UNION ALL
--Health factors that aren't connected to a CC note 
SELECT h.MVIPersonSID
	  ,i.PatientICN
	  ,h.Sta3n
	  ,h.StaPa --= CASE WHEN s.StaPa IS NULL OR s.StaPa='*' THEN CAST(a.Sta3n AS varchar) ELSE s.StaPa END
	  ,h.TemplateDateTime
	  ,h.VisitDateTime
	  ,TIUDocumentDefinition=NULL
	  ,h.VisitSID
	  ,ConsultNumber=NULL
	  ,Notification_ID=NULL
	  ,Referral_ID=NULL
	  ,h.TemplateSelection
FROM #AddLocationsVistA_IVC h 
INNER JOIN Common.vwMVIPersonSIDPatientICN i WITH (NOLOCK)
	ON h.MVIPersonSID=i.MVIPersonSID
LEFT JOIN [PDW].[OMHSP_PERC_COMPACT_TIU_IVC] t WITH (NOLOCK)
	ON h.VisitSID = t.VisitSID 
	WHERE t.VisitSID IS NULL
;
--Clean up cases where ReferenceDateTime is too early
UPDATE #TIU_HF
SET ReferenceDateTime = EntryDateTime
WHERE ReferenceDateTime < '2023-01-17'


--Clean up extracted IDs
UPDATE #TIU_HF
SET ConsultNumber = REPLACE(ConsultNumber,'_','')

UPDATE #TIU_HF
SET ConsultNumber = REPLACE(ConsultNumber,'#','')

;
UPDATE #TIU_HF
SET ConsultNumber = TRY_CAST(LEFT(SubString(ConsultNumber, PatIndex('%[0-9]%', ConsultNumber), 10), PatIndex('%[^0-9]%', SubString(ConsultNumber, PatIndex('%[0-9]%', ConsultNumber), 10) + 'X')-1)as bigint)
;
ALTER TABLE #TIU_HF
ALTER COLUMN ConsultNumber varchar(20) NULL
;
UPDATE #TIU_HF
SET ConsultNumber = NULL WHERE ConsultNumber='0'

UPDATE #TIU_HF
SET ConsultNumber = CONCAT(Sta3n,'_',RIGHT(ConsultNumber,7)) WHERE LEN(ConsultNumber)>=7

UPDATE #TIU_HF
SET ConsultNumber = NULL WHERE LEN(ConsultNumber)<>11

UPDATE #TIU_HF
SET Notification_ID=NULL WHERE Notification_ID NOT LIKE '%-%'

UPDATE #TIU_HF
SET Referral_ID = REPLACE(Referral_ID,' ','')

UPDATE #TIU_HF
SET Referral_ID = NULL WHERE (Referral_ID NOT LIKE 'VA0%' and Referral_ID NOT LIKE 'VA9%')



/****************************************************************************************
Step 3: Pull together all notifications, referrals, and claims data from IVC related to COMPACT care 
****************************************************************************************/

--Get all Notifications and dx available for 1720J approved notifications
--Notifications don't always result in paid claim, but it is the majority of the first contacts. If it ends up being paid in a claim, use the notification date as the first contact
--notifications are always an initial outpatient setting (ER)
--
DROP TABLE IF EXISTS #Notifications
SELECT
	HSRMReferralID
	,a.NotificationID
	,ConsultID=CAST(NULL as varchar)
	,a.PatientICN
	,VAFacilityID_Sta6a = CASE WHEN a.VAFacilityID LIKE '%(%)%' 
		THEN SUBSTRING(a.VAFacilityId,CHARINDEX('(', a.VAFacilityId) + 1, CHARINDEX(')', a.VAFacilityId) - CHARINDEX('(', a.VAFacilityId) - 1)
		ELSE NULL END
	,AvailabilityFacilityID_Sta6a = CASE WHEN a.AvailabilityFacilityID LIKE '%(%)%' 
		THEN SUBSTRING(a.AvailabilityFacilityID,CHARINDEX('(', a.AvailabilityFacilityID) + 1, CHARINDEX(')', a.AvailabilityFacilityID) - CHARINDEX('(', a.AvailabilityFacilityID) - 1)
		ELSE NULL END
	,CONVERT(DATE, DatePresenting) AS TxDate
	,TRIM(', ,' FROM AdmissionDX + ', ' + DischargeDX + ', ' + Status) AS EncounterCodes
	,Type = 'ER Notification'
	,a.Status
	,CASE WHEN a.Status LIKE '%Approved%1720J%' THEN 0 ELSE 1 END AS Rejected
	,a.Hospital
	,MAX(CASE WHEN a.Status LIKE '%1720J%' THEN 1 ELSE 0 END) OVER (PARTITION BY NotificationID) AS COMPACT
INTO #Notifications 
FROM [PDW].[CBOPC_PA_DOEx_ECREmergencyReferrals] a WITH (NOLOCK)
LEFT JOIN #TIU_HF b ON a.PatientICN=b.PatientICN AND a.HSRMReferralID=b.Referral_ID AND b.Referral_ID IS NOT NULL
WHERE a.DatePresenting >= '2023-01-17' 
	AND (a.Status LIKE '%1720J%' OR b.PatientICN IS NOT NULL)
  
--Get inpatient referrals with no notification with Compact Act Authority and identify as IP or OP
--This is also considered a first contact - this is if they are referred
DROP TABLE IF EXISTS #RefNoNotification
SELECT 
	a.ReferralNumber
	,NotificationID=CAST(NULL as varchar)
	,a.ConsultID
	,a.PatientICN
	,s.StaPa
	,a.ReferralFromDate AS TxDate
	,CASE 
		WHEN (a.SEOC LIKE '%Inpt%' OR a.SEOC LIKE '%Residential%') THEN 'CC Inpatient'
		WHEN (a.SEOC NOT LIKE '%Inpt%' AND a.SEOC NOT LIKE '%Residential%') THEN 'CC Outpatient'
		ELSE 'Missing'
		END AS TxSetting
    ,a.ProgramAuthority AS EncouterCodes
	,a.SEOC
	,a.ReferralStatus
	,Type = 'Referral'
	,CASE WHEN a.ReferralStatus IN ('Cancelled','Rejected') THEN 1 ELSE 0 END AS Rejected
	,a.VendorName
	,MAX(CASE WHEN (a.ProgramAuthority = 'EMERGENT SUICIDE CARE (COMPACT ACT) 1720J' OR a.SEOC LIKE 'COMPACT%') AND a.ReferralStatus NOT IN ('Cancelled','Rejected') THEN 1 ELSE 0 END) OVER (PARTITION BY a.ReferralNumber) AS COMPACT
INTO #RefNoNotification
FROM  [PDW].[VHAHOC_Tier2_DOEx_vwReferralsFactdoex]  AS A WITH (NOLOCK)
LEFT JOIN #TIU_HF b ON a.PatientICN=b.PatientICN AND a.ReferralNumber=b.Referral_ID AND b.Referral_ID IS NOT NULL
LEFT JOIN [Lookup].[Sta6a] s WITH (NOLOCK)
	ON a.StationNumber = s.Sta6a
WHERE 
	ReferralFromDate >= '2023-01-17'
	AND ((ProgramAuthority = 'EMERGENT SUICIDE CARE (COMPACT ACT) 1720J' OR SEOC LIKE 'COMPACT%') OR b.PatientICN IS NOT NULL)
	
	
--Union referrals and notifications
DROP TABLE IF EXISTS #ReferralsNotifications
SELECT DISTINCT PatientICN
	,COALESCE(s.StaPa,s2.StaPa) AS StaPa
	,TxDate
	,TxSetting='CC Emergency'
	,EncounterCodes
	,SEOC=NULL
	,ReferralStatus = Status
	,Rejected
	,Type
	,HSRMReferralID
	,NotificationID
	,ConsultID
	,Hospital
	,COMPACT
INTO #ReferralsNotifications
FROM #Notifications n
LEFT JOIN [Lookup].[Sta6a] s WITH (NOLOCK)
	ON n.VAFacilityID_Sta6a = s.STA6a
LEFT JOIN [Lookup].[Sta6a] s2 WITH (NOLOCK)
	ON n.AvailabilityFacilityID_Sta6a = s2.STA6A
UNION 
SELECT DISTINCT PatientICN
	,StaPa
	,TxDate
	,TxSetting
	,EncouterCodes
	,SEOC
	,ReferralStatus
	,Rejected
	,Type
	,ReferralNumber
	,NotificationID
	,ConsultID
	,VendorName
	,COMPACT
FROM #RefNoNotification


--Get data on 1720J paid claims, designating op and ip
DROP TABLE IF EXISTS #CompactPaid
SELECT DISTINCT
	a.Referral_Number
	,a.Patient_ICN AS PatientICN
	,s.StaPa
	,a.Service_Start_Date AS TxDate
	,CASE 
		WHEN bill_designation = 'OP' THEN 'CC Outpatient'
		WHEN bill_designation = 'IP' THEN 'CC Inpatient'
		WHEN a.Place_of_Service_ID IN ('21', '51') THEN 'CC Inpatient'
		WHEN a.Place_of_Service_ID IN ('41', '42') THEN 'CC Transport'
		ELSE 'CC Outpatient'
		END AS TxSetting
	,ISNULL(MAX(a.Discharge_Date) OVER (PARTITION BY a.Referral_Number),MAX(c.Discharge_Date) OVER (PARTITION BY a.Referral_Number)) AS Discharge_Date
	,a.Payment_Authority
	,Type = 'Paid Claims'
	,MAX(CASE WHEN a.Payment_authority = '1720J' THEN 1 ELSE 0 END) OVER (PARTITION BY a.Referral_Number) AS COMPACT
	,a.Claim_Total_Amount
	,a.ClaimID
	,Transport=0
INTO #CompactPaid
FROM  [PDW].[CDWWork_IVC_CDS_CDS_Claim_Header] AS a WITH (NOLOCK)
LEFT JOIN [PDW].[CDWWork_CCRS_Dim_Bill_Type] AS b WITH (NOLOCK) --Join to get the bill_designation column
	ON a.Bill_Type = b.bill_type_code
LEFT JOIN [Lookup].[Sta6a] s WITH (NOLOCK)
	ON a.Station_Number = s.Sta6a
LEFT JOIN #TIU_HF h ON a.Referral_Number=h.Referral_ID AND h.Referral_ID IS NOT NULL
LEFT JOIN [PDW].[CDWWork_IVC_CDS_CDS_Claim_Header] AS c WITH (NOLOCK)
	ON a.Referral_Number=c.Referral_Number AND a.Admission_Date=c.Admission_Date AND c.IsCurrent='Y' AND c.Claim_Form_Type='I'
WHERE 
       a.Service_Start_Date >='2023-01-17' 
       AND (a.Payment_authority = '1720J' OR h.MVIPersonSID IS NOT NULL)
       AND a.Claim_Status_ID = '71' --paid
       AND a.IsCurrent = 'Y' --Wasn't returned. Removes duplicates
       AND (a.Place_of_Service_ID NOT IN ('81') OR a.Place_of_Service_ID IS NULL) -- (81) lab



UPDATE #CompactPaid
SET Discharge_Date=NULL
WHERE TxSetting IN ('CC Outpatient','CC Transport') AND Discharge_Date IS NOT NULL

UPDATE #CompactPaid
SET Transport=1
WHERE TxSetting='CC Transport'


--Sum Claim amounts and string claim IDs
DROP TABLE IF EXISTS #SumClaims
SELECT Referral_Number
	,PatientICN
	,SUM(Claim_Total_Amount) AS Claim_Total_Amount
	,COUNT(ClaimID) AS ClaimCount
	,MAX(ClaimID) AS ClaimID
	,Transport
INTO #SumClaims
FROM #CompactPaid
WHERE Referral_Number IS NOT NULL
GROUP BY Referral_Number, PatientICN, Transport

----Get discharge dates when the date exists in another line of the data
DROP TABLE IF EXISTS #Add_Discharge
SELECT DISTINCT
	Referral_Number
	,Patient_ICN AS PatientICN
	,a.Service_Start_Date AS TxDate
	,MAX(a.Discharge_Date) OVER (PARTITION BY a.Referral_Number, a.Service_Start_Date) AS Discharge_Date
INTO #Add_Discharge
FROM  [PDW].[CDWWork_IVC_CDS_CDS_Claim_Header] AS a WITH (NOLOCK)
LEFT JOIN [PDW].[CDWWork_CCRS_Dim_Bill_Type] AS b WITH (NOLOCK) --Join to get the bill_designation column
	ON a.Bill_Type = b.bill_type_code
LEFT JOIN [Lookup].[Sta6a] s WITH (NOLOCK)
	ON a.Station_Number = s.Sta6a
LEFT JOIN #TIU_HF h ON a.Patient_ICN=h.PatientICN
WHERE 
	Service_Start_Date >='2023-01-17' 
	AND Claim_Status_ID <> '71' --paid
	AND IsCurrent = 'Y' --Wasn't returned. Removes duplicates
	AND (a.Place_of_Service_ID NOT IN ('41', '42', '81') OR a.Place_of_Service_ID IS NULL) --(41 & 42) ambulance and (81) lab
	AND (a.Payment_authority = '1720J' OR h.PatientICN IS NOT NULL)
	
UPDATE #CompactPaid
SET Discharge_Date = b.Discharge_Date
FROM #CompactPaid a
INNER JOIN #Add_Discharge b 
	ON a.Referral_Number=b.Referral_Number --AND a.TxDate=b.TxDate
WHERE a.Discharge_Date IS NULL AND b.Discharge_Date IS NOT NULL AND a.TxSetting='CC Inpatient'


--Match on Referral/Notification data and paid claim data
--Paid claims
DROP TABLE IF EXISTS #Combine_IVC
SELECT DISTINCT a.Referral_Number
	,c.NotificationID
	,c.ConsultID
	,a.PatientICN
	,a.StaPa
	,ISNULL(c.TxDate,a.TxDate) AS TxDate --use date of referral/notification as start date
	,MAX(a.Discharge_Date) OVER (PARTITION BY a.Referral_Number,s.Transport) AS Discharge_Date
	,MIN(CASE WHEN a.TxSetting = 'CC Inpatient' OR c.TxSetting = 'CC Inpatient' THEN 1
		WHEN a.TxSetting='CC Transport' THEN 2
		ELSE 3 END) OVER (PARTITION BY a.Referral_Number,s.Transport) AS TxSettingNumber
	,TxSetting = CAST(NULL AS varchar)
	,s.Claim_Total_Amount
	,Paid = 1
	,c.ReferralStatus
	,ISNULL(c.Rejected,0) AS Rejected --If paid claim exists with no referral or notification, assume not rejected
	,c.Hospital
	,a.COMPACT AS COMPACT_Claim
	,c.COMPACT AS COMPACT_RefNot
	,s.ClaimID
	,s.ClaimCount
INTO #Combine_IVC
FROM #CompactPaid a
LEFT JOIN #ReferralsNotifications c ON a.PatientICN=c.PatientICN AND a.Referral_Number=c.HSRMReferralID AND a.TxSetting <> 'CC Transport'
LEFT JOIN #SumClaims s ON a.PatientICN=s.PatientICN AND a.Referral_Number=s.Referral_Number 
	AND ((a.TxSetting='CC Transport' AND s.Transport=1) OR (a.TxSetting<> 'CC Transport' AND s.Transport=0))

UNION ALL

--Referrals and notifications without a paid claim
SELECT DISTINCT a.HSRMReferralID
	,a.NotificationID
	,a.ConsultID
	,a.PatientICN
	,a.StaPa
	,a.TxDate
	,Discharge_Date = NULL
	,TxSettingNumber=NULL
	,a.TxSetting
	,Claim_Total_Amount = NULL
	,Paid = 0
	,a.ReferralStatus
	,a.Rejected
	,a.Hospital
	,a.COMPACT AS COMPACT_Claim
	,b.COMPACT AS COMPACT_RefNot
	,b.ClaimID	
	,ClaimCount=NULL
FROM #ReferralsNotifications a
LEFT JOIN #CompactPaid b ON a.PatientICN=b.PatientICN AND a.HSRMReferralID=b.Referral_Number AND b.TxSetting <> 'CC Transport'
WHERE b.PatientICN IS NULL

UPDATE #Combine_IVC
SET TxSetting='CC Inpatient' WHERE TxSettingNumber=1
UPDATE #Combine_IVC
SET TxSetting='CC Transport' WHERE TxSettingNumber=2
UPDATE #Combine_IVC
SET TxSetting='CC Outpatient' WHERE TxSettingNumber=3


DROP TABLE IF EXISTS #StageIVC
SELECT DISTINCT
	c.MVIPersonSID
	,a.Referral_Number
	,a.ConsultID
	,a.NotificationID
	,a.StaPa
	,MIN(a.TxDate) OVER (PARTITION BY a.Referral_Number, TxSetting) AS TxDate
	,MAX(a.Discharge_Date) OVER (PARTITION BY a.Referral_Number, TxSetting) AS DischargeDate
		--ELSE NULL END AS DischargeDate
	,a.TxSetting
	,a.Claim_Total_Amount
	,a.Paid
	,a.ReferralStatus
	,a.Rejected
	,a.Hospital
	,a.COMPACT_Claim
	,a.COMPACT_RefNot
	,a.ClaimID
	,a.ClaimCount
INTO #StageIVC
FROM #Combine_IVC a
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] c WITH (NOLOCK) 
	ON a.PatientICN = c.PatientICN
	
/****************************************************************************************
Step 4: Join IVC and TIU/HF data together
****************************************************************************************/

DROP TABLE IF EXISTS #Together
--Match on Notification ID
SELECT DISTINCT
	a.MVIPersonSID
	,ISNULL(a.Referral_Number,b.Referral_ID) AS ReferralID
	,ISNULL(a.ConsultID,b.ConsultNumber) AS ConsultID
	,ISNULL(a.NotificationID,b.Notification_ID) AS NotificationID
	,b.VisitSID
	,b.StaPa AS HF_StaPa
	,a.StaPa AS Claim_StaPa
	,a.TxDate
	,a.DischargeDate
	,a.TxSetting
	,a.Hospital
	,a.Claim_Total_Amount
	,a.Paid
	,a.ReferralStatus
	,a.Rejected
	,b.HealthFactorType
	,b.EntryDateTime
	,b.ReferenceDateTime
	,a.ClaimID
	,a.ClaimCount
INTO #Together
FROM #StageIVC a
INNER JOIN #TIU_HF b ON a.MVIPersonSID = b.MVIPersonSID AND a.NotificationID=b.Notification_ID
WHERE a.COMPACT_Claim=1 OR a.COMPACT_RefNot=1
UNION 
--Match on Referral ID
SELECT DISTINCT
	a.MVIPersonSID
	,ISNULL(a.Referral_Number,b.Referral_ID) AS ReferralID
	,ISNULL(a.ConsultID,b.ConsultNumber) AS ConsultID
	,ISNULL(a.NotificationID,b.Notification_ID) AS NotificationID
	,b.VisitSID
	,b.StaPa AS HF_StaPa
	,a.StaPa AS Claim_StaPa
	,a.TxDate
	,a.DischargeDate
	,a.TxSetting
	,a.Hospital
	,a.Claim_Total_Amount
	,a.Paid
	,a.ReferralStatus
	,a.Rejected
	,b.HealthFactorType
	,b.EntryDateTime
	,b.ReferenceDateTime
	,a.ClaimID	
	,a.ClaimCount
FROM #StageIVC a
INNER JOIN #TIU_HF b ON a.MVIPersonSID = b.MVIPersonSID AND a.Referral_Number=b.Referral_ID
WHERE a.COMPACT_Claim=1 OR a.COMPACT_RefNot=1
UNION
--Match on Consult ID
SELECT DISTINCT
	a.MVIPersonSID
	,ISNULL(a.Referral_Number,b.Referral_ID) AS ReferralID
	,ISNULL(a.ConsultID,b.ConsultNumber) AS ConsultID
	,ISNULL(a.NotificationID,b.Notification_ID) AS NotificationID
	,b.VisitSID
	,b.StaPa AS HF_StaPa
	,a.StaPa AS Claim_StaPa
	,a.TxDate
	,a.DischargeDate
	,a.TxSetting
	,a.Hospital
	,a.Claim_Total_Amount
	,a.Paid
	,a.ReferralStatus
	,a.Rejected
	,b.HealthFactorType
	,b.EntryDateTime
	,b.ReferenceDateTime
	,a.ClaimID	
	,a.ClaimCount
FROM #StageIVC a
INNER JOIN #TIU_HF b ON a.MVIPersonSID = b.MVIPersonSID AND a.ConsultID=b.ConsultNumber
WHERE a.COMPACT_Claim=1 OR a.COMPACT_RefNot=1
UNION
--Match on date
SELECT DISTINCT
	a.MVIPersonSID
	,ISNULL(a.Referral_Number,b.Referral_ID) AS ReferralID
	,ISNULL(a.ConsultID,b.ConsultNumber) AS ConsultID
	,ISNULL(a.NotificationID,b.Notification_ID) AS NotificationID
	,b.VisitSID
	,b.StaPa AS HF_StaPa
	,a.StaPa AS Claim_StaPa
	,a.TxDate
	,a.DischargeDate
	,a.TxSetting
	,a.Hospital
	,a.Claim_Total_Amount
	,a.Paid
	,a.ReferralStatus
	,a.Rejected
	,b.HealthFactorType
	,b.EntryDateTime
	,b.ReferenceDateTime
	,a.ClaimID	
	,a.ClaimCount
FROM #StageIVC a
INNER JOIN #TIU_HF b ON a.MVIPersonSID = b.MVIPersonSID AND a.TxDate = CAST(b.ReferenceDateTime AS date)
LEFT JOIN #TIU_HF c ON a.MVIPersonSID = c.MVIPersonSID AND a.NotificationID=c.Notification_ID
LEFT JOIN #TIU_HF d ON a.MVIPersonSID = d.MVIPersonSID AND a.Referral_Number=d.Referral_ID
LEFT JOIN #TIU_HF e ON a.MVIPersonSID = e.MVIPersonSID AND a.ConsultID=e.ConsultNumber
WHERE c.MVIPersonSID IS NULL AND d.MVIPersonSID IS NULL AND e.MVIPersonSID IS NULL
AND (a.COMPACT_Claim=1 OR a.COMPACT_RefNot=1)
UNION 
--IVC data with no ID match to HF/TIU data
SELECT DISTINCT
	a.MVIPersonSID
	,ISNULL(a.Referral_Number,b.Referral_ID) AS ReferralID
	,ISNULL(a.ConsultID,b.ConsultNumber) AS ConsultID
	,ISNULL(a.NotificationID,b.Notification_ID) AS NotificationID
	,VisitSID = NULL
	,HF_StaPa = NULL
	,a.StaPa AS Claim_StaPa
	,a.TxDate
	,a.DischargeDate
	,a.TxSetting
	,a.Hospital
	,a.Claim_Total_Amount
	,a.Paid
	,a.ReferralStatus
	,a.Rejected
	,b.HealthFactorType
	,b.EntryDateTime
	,b.ReferenceDateTime
	,a.ClaimID	
	,a.ClaimCount
FROM #StageIVC a
LEFT JOIN #TIU_HF b ON a.MVIPersonSID = b.MVIPersonSID AND a.NotificationID=b.Notification_ID
LEFT JOIN #TIU_HF c ON a.MVIPersonSID = c.MVIPersonSID AND a.Referral_Number=c.Referral_ID
LEFT JOIN #TIU_HF d ON a.MVIPersonSID = d.MVIPersonSID AND a.ConsultID=d.ConsultNumber
LEFT JOIN #TIU_HF e ON a.MVIPersonSID = e.MVIPersonSID AND a.TxDate = CAST(e.ReferenceDateTime AS date)
WHERE b.MVIPersonSID IS NULL AND c.MVIPersonSID IS NULL AND d.MVIPersonSID IS NULL AND e.MVIPersonSID IS NULL
AND (a.COMPACT_Claim=1 OR a.COMPACT_RefNot=1)
UNION 
--TIU/HF data with no ID match on IVC data
SELECT DISTINCT
	a.MVIPersonSID
	,a.Referral_ID AS ReferralID
	,a.ConsultNumber AS ConsultID
	,a.Notification_ID AS NotificationID
	,a.VisitSID
	,a.StaPa AS HF_StaPa
	,Claim_StaPa = NULL
	,TxDate=NULL
	,DischargeDate=NULL
	,TxSetting=CASE WHEN a.HealthFactorType LIKE 'CCET%' THEN 'CC Emergency'
		ELSE 'CC Outpatient' END --no way to know from health factors where the referral is for inpatient or outpatient care, so default to outpatient
	,Hospital = NULL
	,Claim_Total_Amount = NULL
	,Paid=0
	,ReferralStatus=NULL
	,Rejected=0
	,a.HealthFactorType
	,a.EntryDateTime
	,a.ReferenceDateTime
	,ClaimID=NULL
	,ClaimCount=NULL
FROM #TIU_HF a
LEFT JOIN #StageIVC b ON b.NotificationID=a.Notification_ID AND b.MVIPersonSID = a.MVIPersonSID
LEFT JOIN #StageIVC c ON a.Referral_ID=c.Referral_Number AND a.MVIPersonSID = c.MVIPersonSID 
LEFT JOIN #StageIVC d ON a.ConsultNumber=d.ConsultID AND a.MVIPersonSID = d.MVIPersonSID 
LEFT JOIN #StageIVC e ON a.MVIPersonSID = e.MVIPersonSID AND e.TxDate = CAST(a.ReferenceDateTime AS date) 
WHERE b.MVIPersonSID IS NULL AND c.MVIPersonSID IS NULL AND d.MVIPersonSID IS NULL AND e.MVIPersonSID IS NULL   


/****************************************************************************************
Step 5: Stage for final table
****************************************************************************************/

--Drop records where the claim was marked as rejected or the record was not marked as approved for COMPACT according to the IVC data
DROP TABLE IF EXISTS #RemoveRejectedClaims
SELECT
	MVIPersonSID
	,ReferralID
	,ConsultID
	,NotificationID
	,VisitSID
	,ISNULL(a.Claim_StaPa,a.HF_StaPa) AS StaPa
	,CAST(CASE WHEN TxDate IS NULL THEN ReferenceDateTime
		WHEN ReferenceDateTime IS NULL THEN 
			(CASE WHEN DischargeDate < TxDate THEN DischargeDate --weird but sometimes this is true in the data
			 ELSE TxDate END)
		WHEN ReferenceDateTime < TxDate THEN ReferenceDateTime
		ELSE TxDate END as date) AS BeginDate
	,TxDate
	,DischargeDate
	,TxSetting
	,Hospital
	,Claim_Total_Amount
	,Paid
	,ReferralStatus
	,HealthFactorType
	,MIN(ReferenceDateTime) OVER (PARTITION BY VisitSID) AS ReferenceDateTime
	,ClaimID	
	,ClaimCount
INTO #RemoveRejectedClaims
FROM #Together a
WHERE Rejected=0

DROP TABLE IF EXISTS #Final
SELECT DISTINCT
	MVIPersonSID
	,ReferralID
	,MAX(ConsultID) ConsultID
	,MAX(NotificationID) NotificationID
	,MAX(ClaimID) ClaimID
	,MAX(VisitSID) VisitSID
	,StaPa
	,BeginDate
	,TxDate
	,MAX(DischargeDate) DischargeDate
	,TxSetting
	,MAX(Hospital) Hospital
	,MAX(Claim_Total_Amount) Claim_Total_Amount
	,MAX(Paid) Paid
	,MAX(ReferralStatus) ReferralStatus
	,MAX(HealthFactorType) HealthFactorType
	,MAX(ReferenceDateTime) ReferenceDateTime
	,MAX(ClaimCount) ClaimCount
INTO #Final
FROM #RemoveRejectedClaims a
GROUP BY MVIPersonSID, ReferralID, StaPa, BeginDate, TxDate, TxSetting

EXEC [Maintenance].[PublishTable] 'COMPACT.IVC', '#Final' 
	
EXEC [Log].[ExecutionEnd] @Status = 'Completed' ;

END