

-- =============================================
-- Author:		Tolessa Gurmessa
-- Create date: 2/12/2024
-- Description: ORM DoD OUD Patient Report 
-- This is adopted from ORM Patient Report
-- 2024-03-06  TG adding DoD Max encounter date
-- 2024-03-11  TG adding more columns to the datasets, instead of its LSV version
-- 2024-03-13  TG added OUD_DoD flag to create cohorts for the report.
-- 2024-03-14  TG forcing 0 on NULL values for some variables
-- 2024-03-20  TG adding quarters for the report paramenter
-- 2024-04-15  TG removing patients with no PatientICN, the earlier view has inaccurate data
-- 2024-04-16  TG adding F11.9* ICD10 code to OUD diagnosis 
-- 2024-04-17  TG adding Z79.891 column for the report
-- 2024-09-30  LM Adding WITH(NOLOCK)
-- 2024-10-08  LM Optimize for faster run time
-- 2025-01-10  TG Implementing PMOP changes to risk mitigations
-- 2025-02-03  TG Adding MetricInclusion column for downstream use
-- 2025-05-15  TG Fixing a bug that is affecting DoD_OUD only parameter on the report
-- 2025-05-23 RAS Added DISTINCT to #StationAssign as quick fix to improve run time.
-- 2025-05-23  TG Added WITH(NOLOCK) to Present.Diagnosis
-- 2025-05-27  TG Fixing an issue discovered during validation
-- 2025-05-29 RAS Formatting changes just for consistency. Further cleaned up issues causing duplicates and unneccessary rows: 
		-- 1) Added distinct to intitial #cohort table, 2) replaced subquery in #CohortWithRisk that referenced ORM-DoDOUDDiagnosisDate 
		-- because the field needed was already included in the initial #cohort table that join was also using incorrect aliases, 
		-- so it was creating numerous incorrect rows, 3) Limited #inpat to only census patients because that was the only 
		-- information needed in the final table, but multiple records were being included for patients for Census=1 and Census=0 
-- 2025-06-11   TG Adding DoD DIRECT vs Community Care
-- =============================================
CREATE PROCEDURE [Code].[ORM_DoDOUDPatientReport]
	-- Add the parameters for the stored procedure here
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'Code.ORM_DoDOUDPatientReport','Execution of SP Code.ORM_DoDOUDPatientReport'


/*********************************************************************************************
Per Bill Kazanis,

SOURCE	                            Direct or Network Care	     Inpatient or Outpatient
[PDW].[CDWWork_JVPN_CAPER]	        Direct Care	                     Outpatient
[PDW].[CDWWork_JVPN_DirectInpat]	Direct Care	                     Inpatient
[PDW].[CDWWork_JVPN_NetworkInpat]	Network Care	                 Inpatient
[PDW].[CDWWork_JVPN_NetworkOutpat]	Network Care	                  Outpatient

SOURCE	                                       InstanceDateType
[PDW].[CDWWork_JVPN_CAPER]	                      ServiceDate
[PDW].[CDWWork_JVPN_DirectInpat]	              ServiceDate
[PDW].[CDWWork_JVPN_NetworkInpat]	              BeginDateOfCare
[PDW].[CDWWork_JVPN_NetworkOutpat]	              BeginDateOfCare

SOURCE	IDTYPE
[PDW].[CDWWork_JVPN_CAPER]	                    CaperSID
[PDW].[CDWWork_JVPN_DirectInpat]	            DirectInpatSID
[PDW].[CDWWork_JVPN_NetworkInpat]	            NetworkInpatSID
[PDW].[CDWWork_JVPN_NetworkOutpat]	            NetworkOutpatSID

*********************************************************************************************/
----------------------------------------------------------------------------
-- STEP 1:  Pull the DoD OUD Cohort
----------------------------------------------------------------------------
DROP TABLE IF EXISTS #Cohort;
SELECT DISTINCT
	a.MVIPersonSID
    ,a.EDIPI
    ,a.LastName
    ,a.FirstName
    ,a.MiddleName
    ,a.NameSuffix
    ,a.DateofBirth
    ,a.age
    ,a.Gender
	,d.CareType
	,d.LastDoDDiagnosisDate
	,d.LastVADiagnosisDate
	,c.VisitDateTime
	,a.MaxDoDEncounter
	,OUD_DoD = 1
INTO #Cohort 
FROM [ORM].[dod_oud] AS a WITH (NOLOCK)
LEFT JOIN [ORM].[DoDOUDDiagnosisDate] AS d  WITH (NOLOCK)
      ON a.MVIPersonSID = d.MVIPersonSID
LEFT JOIN [ORM].[DoDOUDVAContact] AS c  WITH (NOLOCK)
     ON a.MVIPersonSID = c.MVIPersonSID AND c.MostRecent_ICN = 1
 
----------------------------------------------------------------------------
-- STEP 2:  Assemble the cohort with risk categories
-- The cohort should be the original STORM cohort (active opioid for pain 
-- and/or OUD diagnosis) + the recently discontinued opioid cohort.
----------------------------------------------------------------------------
DROP TABLE IF EXISTS #CohortWithRisk
-- OUD AND OPIOIDFORPAIN_RX 
SELECT  
	c.MVIPersonSID
    ,c.EDIPI
    ,c.LastName
    ,c.FirstName
    ,c.MiddleName
    ,c.NameSuffix
    ,c.DateofBirth
    ,c.age
    ,c.Gender
	,FYQ  = concat('FY',substring(cast(DATEPART(year, c.LastDoDDiagnosisDate) as varchar),3,2),'Q',(DATEPART(quarter, c.LastDoDDiagnosisDate)))
	,c.CareType
	,c.LastDoDDiagnosisDate
	,c.LastVADiagnosisDate
	,c.VisitDateTime
	,c.MaxDoDEncounter
	,r.RiskScore
	,r.RiskScoreAny
	,(r.RiskScore-r.RiskScoreNoSed)/r.RiskScore as RiskScoreOpioidSedImpact
	,(r.RiskScoreAny-r.RiskScoreAnyNoSed)/r.RiskScoreAny as RiskScoreAnyOpioidSedImpact
	,CASE WHEN r.RiskCategory=4 AND p.MVIPersonSID IS NOT NULL THEN 10
		 ELSE r.RiskCategory 
		 END AS RiskCategory
	,r.RiskAnyCategory
	,CASE WHEN r.RiskCategory=4 AND p.MVIPersonSID IS NOT NULL THEN 'Very High - Active Status, No Pills on Hand'
		 ELSE r.RiskCategoryLabel
		 END AS RiskCategoryLabel
	,r.RiskAnyCategoryLabel
	,a.OpioidForPain_Rx
    ,CASE WHEN c.LastVADiagnosisDate IS NOT NULL THEN 1 
	    ELSE a.OUD
		END AS OUD
	,c.OUD_DoD
    ,a.SUDdx_poss 
    ,a.Hospice
    ,a.Anxiolytics_Rx  
	,1 as ORMCohort
	,0 AS ODPastYear
	,NULL AS ODdate
	,0 AS PreparatoryBehavior
INTO #CohortWithRisk
FROM #Cohort AS c
LEFT JOIN (
	SELECT sd.MVIPersonSID 
		,OpioidForPain_Rx
		, CASE WHEN OUD = 1 AND pd.SourceEHR = 'O' THEN 0
		       ELSE sd.OUD END AS OUD
		,SUDdx_poss 
		,Hospice
		,Anxiolytics_Rx
		,ODPastYear
	FROM [SUD].[Cohort] AS sd WITH (NOLOCK)
	LEFT JOIN [Present].[Diagnosis] AS pd WITH (NOLOCK)
	   ON sd.MVIPersonSID = pd.MVIPersonSID AND pd.DxCategory = 'OUD'
	WHERE sd.OUD_DoD = 1 
	) a ON c.MVIPersonSID = a.MVIPersonSID
LEFT JOIN (
	SELECT MVIPersonSID,RiskScore,RiskCategory,RiskAnyCategory,
		   RiskScoreNoSed,RiskScoreAny,RiskScoreAnyNoSed,RiskCategoryLabel,RiskAnyCategoryLabel
	FROM [ORM].[RiskScore]  WITH (NOLOCK)
	WHERE RiskScoreAny>0 
		AND RiskScore>0
	) as r on c.MVIPersonSID = r.MVIPersonSID
LEFT JOIN (
	SELECT MVIPersonSID
	FROM [ORM].[OpioidHistory] WITH (NOLOCK)
	GROUP BY MVIPersonSID
	HAVING MAX(Active) = 1 AND MAX(OpioidOnHand) = 0
	) as p on c.MVIPersonSID = p.MVIPersonSID

----------------------------------------------------------------------------
-- STEP 3:  Join information to the cohort and publish table
----------------------------------------------------------------------------
DROP TABLE IF EXISTS #StationAssign
SELECT
	p.MVIPersonSID, p.ChecklistID, p.STORM
	,b.Sta3n ,b.VISN ,b.Facility
INTO #StationAssign
FROM [Present].[StationAssignments] p WITH(NOLOCK)
INNER JOIN #CohortWithRisk a ON p.MVIPersonSID=a.MVIPersonSID
LEFT JOIN [LookUp].[ChecklistID] AS b WITH(NOLOCK)  ON p.ChecklistID = b.ChecklistID
WHERE p.STORM = 1 

-- Get patients who are currently admitted and the facility where they are inpatient
DROP TABLE IF EXISTS #Inpat
SELECT a.MVIPersonSID,c.Facility,Census
INTO #Inpat
FROM [Inpatient].[BedSection] b WITH(NOLOCK) 
INNER JOIN #CohortWithRisk a ON b.MVIPersonSID=a.MVIPersonSID
INNER JOIN [LookUp].[ChecklistID] c WITH(NOLOCK) ON b.ChecklistID=c.ChecklistID
WHERE b.Census = 1

DROP TABLE IF EXISTS #PatientReportStage;
SELECT 
	c.MVIPersonSID
	,mp.PatientICN
	,c.EDIPI
    ,c.LastName
    ,c.FirstName
    ,c.MiddleName
    ,c.NameSuffix
	,PatientName = RTRIM(CONCAT(c.LastName,', ',c.FirstName,' ',c.MiddleName))
	,mp.PatientSSN
    ,c.DateofBirth
    ,c.age
    ,c.Gender
	,mp.StreetAddress1
	,mp.StreetAddress2
	,mp.City
	,mp.State
	,mp.Zip
	,c.FYQ
	,c.CareType
	,CAST(c.LastDoDDiagnosisDate AS date) LastDoDDiagnosisDate
	,CAST(c.LastVADiagnosisDate AS date) LastVADiagnosisDate
	,CAST(c.VisitDateTime AS date) VisitDateTime
	,c.MaxDoDEncounter
	,s.Sta3n
	,s.ChecklistID
	,s.VISN
	,s.Facility
	,c.OpioidForPain_Rx
	,c.OUD
	,c.OUD_DoD
	,c.SUDdx_poss
	,c.Hospice
	,c.Anxiolytics_Rx
	,c.RiskScore
	,c.RiskScoreAny
	,c.RiskScoreOpioidSedImpact
	,c.RiskScoreAnyOpioidSedImpact
	,CASE WHEN c.ODPastYear = 1 THEN 11
	    ELSE c.RiskCategory
		END AS RiskCategory
    ,CASE WHEN c.ODPastYear = 1 THEN 11
	    ELSE c.RiskAnyCategory
		END AS RiskAnyCategory
	,rio.RIOSORDScore as riosordscore
	,rio.RiskClass as riosordriskclass
	,Case when prf.MVIPersonSID IS NOT NULL then 1 else 0 end as PatientRecordFlag_Suicide
	,CASE WHEN r.Top01Percent = 1 THEN 1 ELSE 0 END AS REACH_01
	,CASE WHEN r.MonthsIdentified24 IS NOT NULL THEN 1 ELSE 0 END AS REACH_Past
	,CASE WHEN c.ODPastYear = 1 AND c.PreparatoryBehavior = 0 THEN 'Overdose In The Past Year (Elevated Risk)'
	      WHEN c.ODPastYear = 1 AND c.PreparatoryBehavior = 1 THEN 'Preparatory Behavior (Elevated Risk)'
	    ELSE c.RiskCategoryLabel
		END AS RiskCategoryLabel
	--,c.RiskCategoryLabel
	,CASE WHEN c.ODPastYear = 1 AND c.PreparatoryBehavior = 0 THEN 'Overdose In The Past Year (Elevated Risk)'
	     WHEN c.ODPastYear = 1 AND c.PreparatoryBehavior = 1 THEN 'Preparatory Behavior (Elevated Risk)'
	    ELSE c.RiskAnyCategoryLabel
		END AS RiskAnyCategoryLabel
	--,c.RiskAnyCategoryLabel
	--,rm.BaselineMitigationsMet
	,s.STORM
	,c.ODPastYear
	,c.ODdate
	,Census=ISNULL(i.Census,0)
	,InpatientFacility=CASE WHEN i.Census=1 THEN i.Facility ELSE NULL END
      ,mp.SourceEHR
INTO #PatientReportStage
FROM #CohortWithRisk AS c
-- Get PatientICN for riosord join
INNER JOIN  [Common].[MasterPatient] AS mp WITH(NOLOCK)  ON c.MVIPersonSID=mp.MVIPersonSID AND mp.PatientICN IS NOT NULL
-- Get facilities where patient will display on reports
LEFT JOIN #StationAssign s ON c.MVIPersonSID=s.MVIPersonSID
LEFT JOIN [PDW].[PBM_AD_DOEx_Staging_RIOSORD] as rio WITH(NOLOCK)  on mp.PatientICN=rio.PatientICN
LEFT JOIN [PRF_HRS].[ActivePRF] as prf WITH(NOLOCK)  on c.MVIPersonSID=prf.MVIPersonSID
LEFT JOIN [REACH].[History] as r WITH(NOLOCK)  on c.MVIPersonSID = r.MVIPersonSID
LEFT JOIN #Inpat i ON c.MVIPersonSID=i.MVIPersonSID

DROP TABLE IF EXISTS #PatientReportStage2;
SELECT DISTINCT
	c.MVIPersonSID
	,c.PatientICN
	,c.EDIPI
    ,c.LastName
    ,c.FirstName
    ,c.MiddleName
    ,c.NameSuffix
	,c.PatientName
	,c.PatientSSN
    ,c.DateofBirth
    ,c.age
    ,c.Gender
	,c.StreetAddress1
	,c.StreetAddress2
	,c.City
	,c.State
	,c.Zip
	,c.FYQ
	,c.CareType
	,c.LastDoDDiagnosisDate
	,c.LastVADiagnosisDate
	,c.VisitDateTime
	,c.MaxDoDEncounter
	,c.Sta3n
	,c.ChecklistID
	,c.VISN
	,c.Facility
	,c.OpioidForPain_Rx
	,c.OUD
	,c.OUD_DoD
	,c.SUDdx_poss
	,c.Hospice
	,c.Anxiolytics_Rx
	,c.RiskScore
	,c.RiskScoreAny
	,c.RiskScoreOpioidSedImpact
	,c.RiskScoreAnyOpioidSedImpact
	,c.RiskCategory
    ,c.RiskAnyCategory
	,rehab.RM_ActiveTherapies_Key
	,rehab.RM_ActiveTherapies_Date
	,rehab.RM_ChiropracticCare_Key
	,rehab.RM_ChiropracticCare_Date
	,rehab.RM_OccupationalTherapy_Key
	,rehab.RM_OccupationalTherapy_Date
	,rehab.RM_OtherTherapy_Key
	,rehab.RM_OtherTherapy_Date
	,rehab.RM_PhysicalTherapy_Key
	,rehab.RM_PhysicalTherapy_Date
	,rehab.RM_SpecialtyTherapy_Key
	,rehab.RM_SpecialtyTherapy_Date
	,rehab.RM_PainClinic_Key
	,rehab.RM_PainClinic_Date
	,rehab.CAM_Key
	,rehab.CAM_Date 
	,c.riosordscore
	,c.riosordriskclass
	,c.PatientRecordFlag_Suicide
	,c.REACH_01
	,c.REACH_Past
	,c.RiskCategoryLabel
	,c.RiskAnyCategoryLabel
	,c.ODPastYear
	,c.ODdate
	,c.STORM
	,c.Census
	,c.InpatientFacility
	,pd.MedLocation
	,pd.MedLocationName
	,pd.MedLocationColor
	,pd.ProviderLocation
	,pd.ProviderLocationName
	,pd.ProviderLocationColor
	,pd.AppointmentLocation
	,pd.AppointmentLocationName
	,pd.AppointmentLocationColor
	,pd.VisitLocation
	,pd.VisitLocationName
	,pd.VisitLocationColor
	,pd.Locations
	,pd.LocationName
	,pd.LocationsColor
	,pd.ActiveMOUD_Patient
	,pd.NonVA_Meds
	,pd.DxId
	,pd.Diagnosis
	,pd.ColumnName
	,pd.Category
	,pd.MedType
	,pd.MedID
	,pd.DrugNameWithoutDose
	,pd.PrescriberName
	,pd.CHOICE
	,rm.MitigationID
	,rm.MitigationIDRx
    ,rm.PrintNameRx
    ,rm.CheckedRx
    ,rm.RedRx
	,rm.MetricInclusion
	,RiskMitigation=CASE WHEN rm.PrintName LIKE 'MEDD%' THEN CONCAT(rm.PrintName,' (30 Day Avg)') ELSE rm.PrintName END
	,rm.DetailsText
	,rm.DetailsDate
	,ISNULL(rm.Checked,0) AS Checked
	,ISNULL(rm.Red,0) AS Red
	,pd.GroupID
	,pd.GroupType
	,pd.ProviderName
	,pd.ProviderSID
	,pd.AppointmentID
	,pd.AppointmentType
	,pd.AppointmentStop
	,pd.AppointmentDatetime
	,pd.VisitStop
	,CASE WHEN MonthsinTreatment < 1 and MonthsinTreatment > 0 THEN '< 1' 
		ELSE CONVERT(VARCHAR,CONVERT(DECIMAL(8,0),MonthsinTreatment)) 
		END MonthsinTreatment
    ,c.SourceEHR
	,ISNULL(lt.Z79891,0) AS Z79891
INTO #PatientReportStage2
FROM #PatientReportStage c
LEFT JOIN [ORM].[Rehab] as rehab WITH(NOLOCK)  on c.MVIPersonSID=rehab.MVIPersonSID
LEFT JOIN [ORM].[RiskMitigation] as rm  WITH(NOLOCK) on c.MVIPersonSID = rm.MVIPersonSID AND rm.MetricInclusion = 1
LEFT JOIN [ORM].[PatientDetails] as pd WITH(NOLOCK) ON c.MVIPersonSID = pd.MVIPersonSID
LEFT JOIN [ORM].[ORM_DoDOUDZ79891]  AS lt  WITH (NOLOCK) ON c.MVIPersonSID = lt.MVIPersonSID


EXEC [Maintenance].[PublishTable] 'ORM.DoDOUDPatientReport', '#PatientReportStage2'

EXEC [Log].[ExecutionEnd] 

END