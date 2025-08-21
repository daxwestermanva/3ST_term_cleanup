
/* =============================================
-- Author:		Tolessa Gurmessa
-- Create date: 2021-11-04
-- Description: Opioid Therapy Risk Report; modification of ORM_PatientQuickView
-- TG --added new variables (MEDD30d and UDS screens) from Academic Detailing; renamed SP to fix typo
-- 2021/11/22 --TG adjusted variables per requirements
-- 2021-12-21 --TG Removing a double join--joined with the same object twice.
-- 2022-02-25  - TG setting null to 0 for some variables to merge the dataset with QuickView
-- 2022-04-22  - TG adding Preparatory behavior to "Suicide or Overdose ..." column
-- 2022-04-22  - TG fixing NULL ODDate columns discovered during validation.
-- 2022-07-08  - JEB Updated Synonym references to point to Synonyms from Core
-- 2023-03-07  - CW Updating data source for UDS credit
-- 2023-04-20  - TG adding new provider type and correcting the existing one
-- 2023-04-21  - TG added logic to populate community care prescribers
-- 2023-08-23  - Updating left join in #cohort temp table as related to Benzodiazepine_Rx and SedatingPainORM_Rx
-- 2024-04-15  - Adding Safety Plan information (completed/declined)
=============================================*/
CREATE PROCEDURE [Code].[ORM_PatientOTRRView]
AS
BEGIN

--EXEC [Log].[ExecutionBegin] @Name = 'Code.ORM_PatientOTRRView', @Description = 'Execution of Code.ORM_PatientOTRRView SP'

DROP TABLE IF EXISTS #cohort;
SELECT DISTINCT	
	   c.MVIPersonSID
	   ,mp.PatientICN
      ,c.ChecklistID
	  ,c.Sta3n
	  ,c.VISN
	  ,c.Facility
      ,mp.[PatientName]
	  ,mp.LastFour
	  ,mp.DateOfBirth
	  ,mp.Age
	  ,mp.Gender
	  ,ad.MEDD30d
      ,c.[OpioidForPain_Rx]
	  ,ISNULL(pm.Benzodiazepine_Rx,0) AS Benzodiazepine_Rx
	  ,ISNULL(pm.SedatingPainORM_Rx,0) AS SedatingPainORM_Rx
	  ,CASE WHEN ag.MOUD IS NOT NULL THEN 1
	        WHEN ag.MOUD IS NULL THEN 0
       END AS MOUD
	  ,r.TramadolOnly
	  ,ad.[riosordscore]
      ,c.[riosordriskclass]
      ,c.[RiskCategory]
	  ,c.[RiskCategorylabel]
      ,c.[RiskScore] 
      ,b.[RiskMitScore]
      ,c.[PatientRecordFlag_Suicide]
	  ,o.DetailsText AS NaloxoneContext
	  ,CAST(o.DetailsDate as date) as NaloxoneDate
	  ,sp.DetailsText SafetyPlanContext
	  ,CAST(sp.DetailsDate as date) as SafetyPlanDate
	  ,uds.LabDate AS UDSDate
	  ,DATEDIFF(DAY, CAST(uds.[LabDate] as datetime),GETDATE()) AS DaysSinceUDS
	  ,con.DetailsDate AS ConsentDate
	  ,DATEDIFF(DAY, CAST(con.[DetailsDate] as datetime),GETDATE()) AS DaysSinceConsent
	  ,pdmp.DetailsDate AS PDMPDate
	  ,DATEDIFF(DAY, CAST(pdmp.[DetailsDate] as datetime),GETDATE()) AS DaysSincePDMP
	  ,ISNULL(ad.ChronicOpioid,0) AS ChronicOpioid
	  ,ISNULL(c.OUD,0) AS OUD
	  ,ISNULL(c.SUDdx_poss,0) AS SUDdx_poss
	  ,ISNULL(c.ODPastYear,0) AS ODPastYear
	  ,ISNULL(c.Hospice,0) AS Hospice
	  --,c.BaselineMitigationsMet
	  ,CAST(id.DetailsDate as date) as ODdate
	  ,id.DetailsText as ODContext
	  ,ISNULL(od.PreparatoryBehavior,0) PreparatoryBehavior
INTO #Cohort
FROM [ORM].[PatientReport] as c WITH(NOLOCK)
INNER JOIN [ORM].[PatientDetails] as b WITH(NOLOCK) on c.MVIPersonSID = b.MVIPersonSID
INNER JOIN [Common].[MasterPatient] as mp WITH(NOLOCK) on c.MVIPersonSID=mp.MVIPersonSID
LEFT JOIN [PDW].[PBM_AD_DOEx_Staging_RIOSORD] as ad WITH(NOLOCK) on mp.PatientICN = ad.PatientICN
LEFT JOIN 
	(SELECT PatientICN, MAX(LabDate) as LabDate FROM Present.UDSLabResults WITH(NOLOCK) GROUP BY PatientICN) as uds 
            on mp.PatientICN = uds.PatientICN
LEFT JOIN 
	(SELECT MVIPersonSID, DetailsDate, DetailsText FROM ORM.RiskMitigation WITH(NOLOCK)
	 WHERE MitigationID = 3) con on c.MVIPersonSID = con.MVIPersonSID
LEFT JOIN 
	(SELECT MVIPersonSID, DetailsDate, DetailsText FROM ORM.RiskMitigation WITH(NOLOCK)
	 WHERE MitigationID = 10) pdmp on c.MVIPersonSID = pdmp.MVIPersonSID
LEFT JOIN [ORM].[RiskScore] r WITH(NOLOCK) on r.MVIPersonSID = c.MVIPersonSID 
LEFT JOIN 
	(SELECT * FROM 
		(SELECT MVIPersonSID, MAX(CAST(Benzodiazepine_Rx as int)) Benzodiazepine_Rx, MAX(CAST(SedatingPainORM_Rx as int)) SedatingPainORM_Rx
		 FROM [Present].[Medications] WITH(NOLOCK)
		 GROUP BY MVIPersonSID) Src
	 WHERE 1 IN ([Benzodiazepine_Rx],[SedatingPainORM_rx])
	) pm
	ON c.MVIPersonSID = pm.MVIPersonSID
LEFT JOIN Present.MOUD ag WITH(NOLOCK) ON c.MVIPersonSID= ag.MVIPersonSID
LEFT JOIN 
	(SELECT MVIPersonSID, DetailsDate, DetailsText FROM ORM.RiskMitigation WITH(NOLOCK)
	 WHERE MitigationID = 2) o on c.MVIPersonSID = o.MVIPersonSID
LEFT JOIN 
	(SELECT MVIPersonSID, DetailsDate, DetailsText FROM ORM.RiskMitigation WITH(NOLOCK)
	 WHERE MitigationID = 13) sp on c.MVIPersonSID = sp.MVIPersonSID
LEFT JOIN 
	(SELECT MVIPersonSID, DetailsDate, DetailsText FROM ORM.RiskMitigation WITH(NOLOCK)
	 WHERE MitigationID = 17) id
	ON id.MVIPersonSID = c.MVIPersonSID
LEFT JOIN 
	(SELECT MVIPersonSID, PreparatoryBehavior,EventDateFormatted, EntryDateTime
     FROM [OMHSP_Standard].[SuicideOverdoseEvent] WITH(NOLOCK)
     WHERE AnyEventOrderDesc = 1) od
	ON c.MVIPersonSID = od.MVIPersonSID 
	AND c.ODdate = ISNULL(od.EventDateFormatted, EntryDateTime);

--PROVIDERS PER LOCATION
DROP TABLE IF EXISTS #uniqueprov;
SELECT * INTO #uniqueprov	
FROM (
	SELECT c.MVIPersonSID
		,c.ChecklistID
		,d.GroupID
		,d.GroupType
		,d.ProviderName
		,d.ProviderSID
		,d.ProviderLocation 
		,RN=row_number() OVER (PARTITION BY c.MVIPersonSID,ChecklistID,GroupID,GroupType ORDER BY ProviderSID)
	FROM #cohort as c
	INNER JOIN [ORM].[PatientDetails] AS d WITH(NOLOCK) ON d.MVIPersonSID=c.MVIPersonSID AND ProviderLocation=ChecklistID
	WHERE ProviderSID>1
) AS a WHERE RN=1;

drop table if exists #pivot;
SELECT MVIPersonSID
	  ,ChecklistID
	  ,max([PACT Team]) AS PACTsid
	  ,max([Primary Care Provider]) AS PCPsid
	  ,max([MH Tx Coordinator]) AS MHTCsid
	  ,max([BHIP TEAM]) AS BHIPsid
	  ,max([VA Opioid Prescriber]) AS VAOPsid
	  ,max([Community Care Prescriber]) AS CCPsid
INTO #pivot
FROM #uniqueprov AS a
	PIVOT (max(ProviderSID) FOR GroupType in (
		[PACT Team],[Primary Care Provider],[VA Opioid Prescriber],[Community Care Prescriber],[MH Tx Coordinator],[BHIP TEAM]) 
  )AS p
 GROUP BY MVIPersonSID,ChecklistID;

DROP TABLE IF EXISTS #providers
SELECT DISTINCT z.*
	  ,u.ProviderName AS PACT 
	  ,v.ProviderName AS PCP 
	  ,w.ProviderName AS MHTC 
	  ,x.ProviderName AS BHIP
	  ,y.ProviderName AS VAOP 
	  ,c.ProviderName AS CCP 
INTO #providers
FROM #pivot AS z
LEFT JOIN (SELECT DISTINCT ProviderSID,ProviderName FROM #uniqueprov) AS u ON u.ProviderSID=PACTsid
LEFT JOIN (SELECT DISTINCT ProviderSID,ProviderName FROM #uniqueprov) AS v ON v.ProviderSID=PCPsid
LEFT JOIN (SELECT DISTINCT ProviderSID,ProviderName FROM #uniqueprov) AS w ON w.ProviderSID=MHTCsid
LEFT JOIN (SELECT DISTINCT ProviderSID,ProviderName FROM #uniqueprov) AS x ON x.ProviderSID=BHIPsid
LEFT JOIN (SELECT DISTINCT ProviderSID,ProviderName FROM #uniqueprov) AS y ON y.ProviderSID=VAOPsid
LEFT JOIN (SELECT DISTINCT ProviderSID,ProviderName FROM #uniqueprov) AS c ON c.ProviderSID=CCPsid;

-------------------
--CREATE TABLE TO CHECK FOR ASSIGNMENTS AT OTHER STATIONS IF PROVIDER IS NULL
DROP TABLE IF EXISTS #AnyProv
SELECT MVIPersonSID
	  ,max([PACT Team]) AS PACT
	  ,max([Primary Care Provider]) AS PCP
	  ,max([MH Tx Coordinator]) AS MHTC
	  ,max([BHIP TEAM]) AS BHIP 
INTO #AnyProv
FROM (
	SELECT MVIPersonSID
		,GroupType
		,ProviderSID
		,ProviderName
	FROM [ORM].[PatientDetails] 
	WHERE ProviderSID>0
  ) AS a
PIVOT (count(ProviderName) 
		FOR GroupType IN ([Primary Care Provider],[PACT Team],[BHIP TEAM],[MH Tx Coordinator])) AS pvt
GROUP BY MVIPersonSID;
------------------

--MOST RECENT PRESCRIBER, OPIOID --REMOVED OTHER RELEVANT MEDS FOR NOW
DROP TABLE IF EXISTS #opipresc
SELECT DISTINCT m.MVIPersonSID
		,m.ChecklistID
		,m.PrescriberName
		,m.PrescriberSID
	    ,RN_loc=ROW_NUMBER() OVER(PARTITION BY m.MVIPersonSID,m.ChecklistID ORDER BY m.IssueDate DESC) 
		,RN=ROW_NUMBER() OVER(PARTITION BY m.MVIPersonSID ORDER BY m.IssueDate DESC) 
INTO #opipresc
FROM (SELECT DISTINCT MVIPersonSID
		,IssueDate
		,StaffName AS PrescriberName
		,ProviderSID AS PrescriberSID
		,ChecklistID
		FROM [ORM].[OpioidHistory] WITH(NOLOCK)
		WHERE Active = 1
  ) AS m; 

DROP TABLE IF EXISTS #meds 
SELECT * 
INTO #meds
FROM #opipresc WHERE RN_Loc=1;

--CHECK FOR ANY RELEVANT PRESCRIBER
DROP TABLE IF EXISTS #rx
SELECT *
INTO #rx
FROM #meds
WHERE RN=1;

--NEXT MENTAL HEALTH AND PRIMARY CARE APPOINTMENTS
DROP TABLE IF EXISTS #appt
SELECT * INTO #appt FROM (
	SELECT MVIPersonSID
		  ,AppointmentDatetime
		  ,AppointmentID
		  ,AppointmentType
		  ,AppointmentLocation
		  ,AppointmentLocationName
		  ,AppointmentStop 
		  ,RN=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID,AppointmentID ORDER BY AppointmentDateTime)
	FROM [ORM].[PatientDetails] WITH(NOLOCK)
	WHERE AppointmentID in (1,3) AND AppointmentDatetime is not null
	) AS a
WHERE RN=1;

--COMBINE ALL
DROP TABLE IF EXISTS #OTRRView;
SELECT c.MVIPersonSID
       ,c.PatientICN
      ,c.ChecklistID
	  ,c.Sta3n
	  ,c.VISN
	  ,c.Facility
      ,c.[PatientName]
	  ,c.LastFour
	  ,c.DateOfBirth
	  ,c.Age
	  ,c.Gender
	  ,c.MEDD30d
      ,c.[OpioidForPain_Rx]
	  ,c.Benzodiazepine_Rx
	  ,c.SedatingPainORM_Rx
	  ,c.MOUD
	  ,ISNULL(c.TramadolOnly, 0) AS TramadolOnly
	  ,c.[riosordscore]
      ,c.[riosordriskclass]
      ,c.[RiskCategory]
	  ,c.[RiskCategorylabel]
      ,c.[RiskScore] 
      ,c.[RiskMitScore]
      ,c.[PatientRecordFlag_Suicide]
      ,c.UDSDate
      ,c.DaysSinceUDS
      ,c.ConsentDate
	  ,c.DaysSinceConsent
	  ,c.PDMPDate
	  ,c.DaysSincePDMP
	  ,c.ChronicOpioid
	  ,c.NaloxoneContext
	  ,c.NaloxoneDate
	  ,c.SafetyPlanContext
	  ,c.SafetyPlanDate
	  ,pc.AppointmentDatetime AS ApptDateTime_PC
	  ,CASE WHEN pc.AppointmentLocation<>c.ChecklistID THEN pc.AppointmentLocationName END AS ApptLocation_PC
	  ,pc.AppointmentStop AS ApptStop_PC
	  ,mh.AppointmentDatetime AS ApptDateTime_MH
	  ,CASE WHEN mh.AppointmentLocation<>c.ChecklistID THEN mh.AppointmentLocationName END AS ApptLocation_MH
	  ,mh.AppointmentStop AS ApptStop_MH
	  ,CASE WHEN p.PCP IS NULL AND a.PCP>0 THEN 'OTHER STATION'
		WHEN p.PCP IS NULL THEN 'UNASSIGNED' 
		ELSE LEFT(p.PCP,CHARINDEX(',',p.PCP + ',')-1)+', '+RIGHT(p.PCP,len(p.PCP)-CHARINDEX(',',p.PCP)) 
		END AS PCP
	  ,CASE WHEN p.PCPsid IS NULL THEN -1 ELSE p.PCPsid END AS PCPsid
	  ,CASE WHEN p.MHTC IS NULL AND a.MHTC>0 THEN 'OTHER STATION'
		WHEN p.MHTC IS NULL THEN 'UNASSIGNED' 
		ELSE LEFT(p.MHTC,CHARINDEX(',',p.MHTC + ',')-1)+', '+RIGHT(p.MHTC,len(p.MHTC)-CHARINDEX(',',p.MHTC)) 
		END AS MHTC
	  ,CASE WHEN p.MHTCsid IS NULL THEN -1 ELSE p.MHTCsid END AS MHTCsid
	  ,CASE WHEN p.BHIP IS NULL AND a.BHIP>0 THEN 'OTHER STATION'
		WHEN p.BHIP IS NULL THEN 'UNASSIGNED'
		ELSE p.BHIP END AS BHIP
	  ,CASE WHEN p.BHIPsid IS NULL THEN -1 ELSE p.BHIPsid END AS BHIPsid
	  ,CASE WHEN p.PACT IS NULL AND a.PACT>0 THEN 'OTHER STATION'
		WHEN p.PACT IS NULL THEN 'UNASSIGNED' 
		ELSE p.PACT END AS PACT
	  ,CASE WHEN p.PACTsid IS NULL THEN -1 ELSE p.PACTsid END AS PACTsid
	  ,CASE WHEN med.PrescriberSID IS NULL THEN -1 ELSE med.PrescriberSID END AS LocalPrescriberSID 
	  ,CASE WHEN med.PrescriberSID IS NULL AND ml.PrescriberSID IS NULL THEN 'NONE' 
		WHEN med.PrescriberSID IS NULL THEN 'OTHER STATION' 
		WHEN med.PrescriberName NOT LIKE '%,%' THEN med.PrescriberName 
		ELSE LEFT(med.PrescriberName,CHARINDEX(',',med.PrescriberName)-1)+', '+RIGHT(med.PrescriberName,len(med.PrescriberName)-CHARINDEX(',',med.PrescriberName)) 
		END as LocalPrescriber 
	  ,ml.PrescriberName AS OtherPrescriber
	  ,CASE WHEN ml.PrescriberSID IS NULL THEN -1 END AS OtherPrescriberSID
	  ,ml.ChecklistID AS OtherPrescriberLocation
	  ,c.OUD
	  ,c.SUDdx_poss
	  ,c.ODPastYear
	  ,c.Hospice
	  --,c.BaselineMitigationsMet
	  ,c.ODdate
	  ,c.ODContext
	  ,c.PreparatoryBehavior
	  ,p.CCP
	  ,p.CCPsid
INTO #OTRRView
FROM #cohort AS c
LEFT JOIN #PROVIDERS AS p ON p.MVIPersonSID=c.MVIPersonSID AND p.ChecklistID=c.ChecklistID
LEFT JOIN #AnyProv AS a ON a.MVIPersonSID=c.MVIPersonSID
LEFT JOIN #appt AS pc ON pc.MVIPersonSID=c.MVIPersonSID AND pc.AppointmentID=3
LEFT JOIN #appt AS mh ON mh.MVIPersonSID=c.MVIPersonSID AND mh.AppointmentID=1
LEFT JOIN #MEDS AS med ON med.MVIPersonSID=c.MVIPersonSID AND med.ChecklistID=c.ChecklistID
LEFT JOIN #rx AS ml ON ml.MVIPersonSID=c.MVIPersonSID

----------------

EXEC [Maintenance].[PublishTable] 'ORM.PatientOTRRView', '#OTRRView'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END