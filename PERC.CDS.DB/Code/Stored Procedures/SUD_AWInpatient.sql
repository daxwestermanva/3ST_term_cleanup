
/*=============================================
-- Author:		Elena Cherkasova
-- Create date: 2024-09-09
-- Description:	Quarterly (rolling 4-quarter) summary data for inpatient discharges with an Alcohol Withdrawal (AW) diagnosis

-- UPDATES: 
--
  =============================================*/
CREATE PROCEDURE [Code].[SUD_AWInpatient]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.SUD_AWInpatient', @Description = 'Execution of Code.SUD_AWInpatient SP'

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

/*CODE TABLE OF CONTENTS

 Step 0 - Identify the last rolling quarter
 Step 1 - All inpatient discharges within the timeframe and bedsections of interest
 Step 2 - identify discharges with AW diagnosis (#AWstays)
 Step 3 - identify which AW discharges also had a DELIRIUM diagnosis
 Step 4 - identify which AW discharges also had a SEIZURE diagnosis
 Step 5 - identify which AW discharges also had an AUDIT-C completed within 1 day of admission
			Counts if survey administered on the day of admission or the next day
 Step 6 - identify which AW discharges had an AUD RX at the time of discharge
 Step 7 - Inpatient Medications Administered During Inpatient Stay
		  Lorazepam, Chlordiazepoxide, Diazepam, Phenobarbital, Gabapentin, Clonidine
 Step 8 - SUMMARY METRIC DATA
			total N of admits
			number of AW admits, AMA discharges, and inpatient deaths
			% of total admits AW
Step 9  - 30-DAY ALL-CAUSE READMISSION RATE
Step 10 - LENGTH OF STAY (LOS)
Step 11 - ICU ADMISSION OR TRANSFER
Step 12 - SUD RRTP: Percentage of AW discharges that were followed by admission to a SUD RRTP Bedsection within 7 days of discharge

	COMBINE DIFFERENT METRICS BY FACILITY, VISN, NATIONAL LEVELS

 */

/*********************************************************************************
 Step 0 - Identify the last rolling quarter
*********************************************************************************/  

DECLARE @QtrEndDate DATETIME2 = (
		SELECT DISTINCT TOP 1 CAST(DATE AS DATE)
		FROM (
			SELECT DATEADD(dd, 1, CAST(DATE AS DATE)) AS DATE
			FROM (
				SELECT *
					,ROW_NUMBER() OVER (
						PARTITION BY fiscalyear
						,fiscalquarter ORDER BY DATE DESC
						) AS lastdayofquarter
				FROM [Dim].[Date] WITH (NOLOCK)
				) AS a
			WHERE lastdayofquarter = 1
				AND calendaryear = (
					SELECT DISTINCT calendaryear
					FROM [Dim].[Date] WITH (NOLOCK)
					WHERE DATE = DATEADD(month, - 3, CAST(GETDATE() AS DATE))
					)
			) AS a
		WHERE DATE <= CAST(GETDATE()  AS DATE)
		ORDER BY DATE DESC
		);

DECLARE @YrStartDate DATETIME2 = DATEADD(mm, DATEDIFF(mm, 0, @QtrEndDate) - 12, 0);

DECLARE @FiscalQuarter VARCHAR(8) = (
		SELECT fiscalquarter
		FROM [Dim].[Date] WITH (NOLOCK)
		WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0)
		);

DECLARE @FiscalYear INT = (RIGHT((
		SELECT fiscalyear FROM [Dim].[Date] WITH (NOLOCK)
		WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0)),2)
		);

DECLARE @FYID INT = (SELECT fiscalyear FROM [Dim].[Date] WITH (NOLOCK)
WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0));

DECLARE @FYQ VARCHAR(8) = (
		SELECT 'FY' + RIGHT(fiscalyear,2) + 'Q' + @FiscalQuarter
		FROM [Dim].[Date] WITH (NOLOCK)
		WHERE DATE = DATEADD(dd, DATEDIFF(dd, 0, @QtrEndDate) - 1, 0)
		);

PRINT @QtrEndDate;
PRINT @YrStartDate;
PRINT @FiscalQuarter;
PRINT @FiscalYear;
PRINT @FYID
PRINT @FYQ;

DROP TABLE IF EXISTS #Timeframe;
SELECT 'QtrEndDate'		= @QtrEndDate
	,'YrStartDate'		= @YrStartDate
	,'FiscalQuarter'	= @FiscalQuarter
	,'FiscalYear'		= @FiscalYear
	,'FYQ' 				= @FYQ
	,'FYID'				= @FYID
INTO #Timeframe
 
 --Select * from #Timeframe

/*
DECLARE @YrStartDate DATETIME2
DECLARE @QtrEndDate DATETIME2
DECLARE @FiscalQuarter VARCHAR(8)
DECLARE @FiscalYear INT
DECLARE @FYQ VARCHAR(8)

SET @YrStartDate = '2023-04-01 00:00:00'
SET @QtrEndDate = '2024-04-01 00:00:00'
SET @FiscalQuarter = '2'
SET @FiscalYear = '2024'
SET @FYQ = 'FY24Q2'
--*/

/*********************************************************************************
 Step 1 - All inpatient discharges within the timeframe and bedsections of interest
*********************************************************************************/  
	DROP TABLE IF EXISTS #inpatient_dailyworkload;
	SELECT i.MVIPersonSID 
		,i.PatientPersonSID
		,i.InpatientEncounterSID
		,i.Sta3n_EHR
		,i.DischargeDateTime
		,i.AdmitDateTime
	    ,i.AMA
	    ,i.Sta6a
		,i.MedicalService		--Cerner
		,i.Accommodation		--Cerner
		,i.BedSection
		,i.BedSectionName
		,i.BsInDateTime
		,i.BsOutDateTime
		,i.ChecklistID
		,i.Census
		,DisDay=CONVERT(DATE,CASE WHEN i.DischargeDateTime IS NOT NULL THEN i.DischargeDateTime ELSE DATEADD(ms,-3,CONVERT(DATETIME,t.QtrEndDate)) END)
		,ch.VISN
		,d.DateOfDeath_Combined
		,InpatientDeath = CASE WHEN d.DateOfDeath_Combined >=i.AdmitDateTime and d.DateOfDeath_Combined <=i.DischargeDateTime THEN 1 ELSE 0 END
		,ICU = CASE WHEN i.Bedsection='12' THEN 1 ELSE 0 END
		,FYQ = CONCAT('FY',t.FiscalYear,'Q',CASE WHEN DATEPART(MONTH,i.DischargeDateTime) IN(1,2,3) THEN '2' 
						WHEN DATEPART(MONTH,i.DischargeDateTime) IN(4,5,6) THEN '3' 
						WHEN DATEPART(MONTH,i.DischargeDateTime) IN(7,8,9) THEN '4' 
						WHEN DATEPART(MONTH,i.DischargeDateTime) IN(10,11,12) THEN '1' 
						ELSE NULL END)
		,RollingFYQ = t.FYQ
	INTO #inpatient_dailyworkload
	FROM [Inpatient].[BedSection] i WITH (NOLOCK)
	INNER JOIN [Common].[MasterPatient] d WITH (NOLOCK)
	ON d.MVIPersonSID=i.MVIPersonSID
	LEFT JOIN [LookUp].[ChecklistID] ch WITH (NOLOCK)
	ON i.ChecklistID = ch.ChecklistID
	INNER JOIN #Timeframe as t ON (i.DischargeDateTime >= t.YrStartDate and i.DischargeDateTime < t.QtrEndDate) /*Non-Census*/
	WHERE 1=1
		AND Veteran=1
		AND i.Bedsection IN('1H',		--MEDICAL STEP DOWN
							 '12',		--MEDICAL ICU
							 '15',		--GENERAL(ACUTE MEDICINE)
							 '17',		--TELEMETRY
							 '24',		--MEDICAL OBSERVATION
							 '74'		--SUBSTANCE ABUSE TRMT UNIT
							 )
	;

/*********************************************************************************
 Step 2 - identify discharges with AW diagnosis 
*********************************************************************************/  

--Find all ICD10SID for Alcohol Withdrawal (AW) diagnoses
DROP TABLE IF EXISTS #aw_icd;
SELECT icd1.ICD10SID
		,icd1.ICD10Code
		,icd2.ICD10Description
INTO #aw_icd
FROM [Dim].[ICD10] as icd1 WITH (NOLOCK)
	INNER JOIN [Dim].[ICD10DescriptionVersion] AS icd2 WITH (NOLOCK)
	ON icd1.ICD10SID=icd2.ICD10SID
WHERE LEFT(ICD10Code,6) IN('F10.13',		--Alcohol abuse with withdrawal
							'F10.23',		--Alcohol dependence with withdrawal
							'F10.93')		--Alcohol use, unspecified with withdrawal
;

--Find all inpatient discharges with a primary or secondary AW diagnosis
DROP TABLE IF EXISTS #inp1_dx;
SELECT  inp1.MVIPersonSID		
       ,inp1.InpatientEncounterSID
       ,stdx.ICD10SID
	   ,'DXsource' = 'Inpat.SpecialtyTransferDiagnosis'
	   ,inp1.ChecklistID
	   ,inp1.VISN
	   ,inp1.FYQ
	   ,inp1.RollingFYQ
	   ,inp1.ICU
INTO   #inp1_dx
FROM   #inpatient_dailyworkload AS inp1
       INNER JOIN [Inpat].[SpecialtyTransferDiagnosis] AS stdx  WITH (NOLOCK)
       ON inp1.InpatientEncounterSID = stdx.InpatientSID
	   INNER JOIN #aw_icd AS icd  WITH (NOLOCK)
	   ON icd.ICD10SID = stdx.ICD10SID
WHERE stdx.OrdinalNumber=1 or stdx.OrdinalNumber=2

UNION 

SELECT  inp2.MVIPersonSID	
       ,inp2.InpatientEncounterSID
       ,idx.ICD10SID
	   ,'DXsource' = 'Inpat.InpatientDiagnosis'
	   ,inp2.ChecklistID
	   ,inp2.VISN
	   ,inp2.FYQ
	   ,inp2.RollingFYQ
	   ,inp2.ICU
FROM   #inpatient_dailyworkload AS inp2
       INNER JOIN [Inpat].[InpatientDiagnosis] AS idx  WITH (NOLOCK)
       ON inp2.InpatientEncounterSID = idx.InpatientSID
	   INNER JOIN #aw_icd AS icd  WITH (NOLOCK)
	   ON icd.ICD10SID = idx.ICD10SID
WHERE idx.OrdinalNumber=0 or idx.OrdinalNumber=1 --Zero is the primary diagnosis position in this CDW view (see VIREC Factbook: https://vaww.virec.research.va.gov/CDW/Factbook/FB-CDW-Inpatient-Domain.pdf)

UNION 

SELECT  inp3.MVIPersonSID
       ,inp3.InpatientEncounterSID
       ,ddx.ICD10SID
	   ,'DXsource' = 'Inpat.DischargeDiagnosis'
	   ,inp3.ChecklistID
	   ,inp3.VISN
	   ,inp3.FYQ
	   ,inp3.RollingFYQ
	   ,inp3.ICU
FROM   #inpatient_dailyworkload AS inp3
       INNER JOIN [Inpat].[InpatientDischargeDiagnosis] AS ddx  WITH (NOLOCK)
       ON inp3.InpatientEncounterSID = ddx.InpatientSID
	   INNER JOIN #aw_icd AS icd  WITH (NOLOCK)
	   ON icd.ICD10SID = ddx.ICD10SID
WHERE ddx.OrdinalNumber=1 or ddx.OrdinalNumber=2

UNION 

SELECT  inp4.MVIPersonSID
       ,inp4.InpatientEncounterSID
       ,pdx.PrincipalDiagnosisICD10SID
	   ,'DXsource' = 'Inpat.Inpatient'
	   ,inp4.ChecklistID
	   ,inp4.VISN
	   ,inp4.FYQ
	   ,inp4.RollingFYQ
	   ,inp4.ICU
FROM   #inpatient_dailyworkload AS inp4
       INNER JOIN [Inpatient].[BedSection] AS pdx  WITH (NOLOCK)
       ON inp4.InpatientEncounterSID = pdx.InpatientEncounterSID 
	   INNER JOIN #aw_icd AS icd  WITH (NOLOCK)
	   ON icd.ICD10SID = pdx.PrincipalDiagnosisICD10SID
;

--identify discharges with an alcohol withdrawal diagnosis
DROP TABLE IF EXISTS #inp1_aud;
	SELECT inp.MVIPersonSID
		,inp.InpatientEncounterSID
		,inp.ICD10SID
		,icd.ICD10Code
		,icd.ICD10Description
		,'stdx' = MAX(CASE WHEN DXsource like '%specialty%' THEN 1 ELSE 0 END)
		,'idx' = MAX(CASE WHEN DXsource like '%inpatientdiagnosis%' THEN 1 ELSE 0 END)
		,'ddx' = MAX(CASE WHEN DXsource like '%discharge%' THEN 1 ELSE 0 END)
		,'pdx' = MAX(CASE WHEN DXsource like 'Inpat.Inpatient' THEN 1 ELSE 0 END)
		,inp.ChecklistID
		,inp.VISN
		,inp.FYQ
	    ,inp.RollingFYQ
		,inp.ICU
	INTO #inp1_aud
	FROM #inp1_dx  AS inp
	INNER JOIN #aw_icd AS icd
	ON inp.ICD10SID = icd.ICD10SID
	GROUP BY inp.MVIPersonSID,inp.InpatientEncounterSID,inp.ICD10SID,icd.ICD10Code,icd.ICD10Description,inp.ChecklistID,inp.VISN,inp.FYQ,inp.RollingFYQ,inp.ICU
;

--FINAL AW STAY TABLE (ROLLED UP TO INPATIENT STAY)
	DROP TABLE IF EXISTS #AWstays;
	SELECT DISTINCT aud.MVIPersonSID
		,i.PatientPersonSID
		,aud.InpatientEncounterSID
		,i.DischargeDateTime
		,i.AdmitDateTime
		,i.ChecklistID
		,i.VISN
		,i.InpatientDeath
		,i.AMA
--		,i.ICU
		,i.FYQ
		,i.RollingFYQ
	INTO #AWstays
	FROM #inp1_aud as aud
	INNER JOIN #inpatient_dailyworkload as i 
	ON aud.InpatientEncounterSID = i.InpatientEncounterSID
	ORDER BY DischargeDateTime
;


/*********************************************************************************
 Step 3 - identify which AW discharges also had a DELIRIUM diagnosis
*********************************************************************************/  

--STEP 3A: Find all ICD10SID for Alcohol Withdrawal (AW) DELIRIUM diagnoses
----------------------------------------------------------------------------
DROP TABLE IF EXISTS #delirium_icd;
SELECT icd1.ICD10SID
	,icd1.ICD10Code
	,icd2.ICD10Description
	,Delirium = CASE WHEN icd2.ICD10Description LIKE '%delirium%' THEN 1 ELSE 0 END
INTO #delirium_icd
FROM [Dim].[ICD10] as icd1 WITH (NOLOCK)
	INNER JOIN [Dim].[ICD10DescriptionVersion] AS icd2
	ON icd1.ICD10SID=icd2.ICD10SID
WHERE ICD10Code IN('F10.131',		--Alcohol abuse with withdrawal delirium
					'F10.231',		--Alcohol dependence with withdrawal delirium
					'F10.931',		--Alcohol use, unspecified with withdrawal delirium
					'F05.')			--Delirium due to known physiological condition
;

--STEP 3B: Find all stays with a diagnosis of DELIRIUM in inpatient discharges with a primary or secondary AW diagnosis
-------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #inp1_dx_delirium;
SELECT  inp1.MVIPersonSID
       ,inp1.InpatientEncounterSID
       ,stdx.ICD10SID
	   ,'DXsource' = 'Inpat.SpecialtyTransferDiagnosis'
	   ,inp1.ChecklistID
	   ,inp1.VISN
	   ,inp1.FYQ
	   ,inp1.RollingFYQ
INTO   #inp1_dx_delirium
FROM   #inp1_aud AS inp1
     INNER JOIN [Inpat].[SpecialtyTransferDiagnosis] AS stdx  WITH (NOLOCK)
       ON inp1.InpatientEncounterSID = stdx.InpatientSID
	   INNER JOIN #delirium_icd AS icd  WITH (NOLOCK)
	   ON icd.ICD10SID = stdx.ICD10SID

UNION 

SELECT  inp2.MVIPersonSID
       ,inp2.InpatientEncounterSID
       ,idx.ICD10SID
	   ,'DXsource' = 'Inpat.InpatientDiagnosis'
	   ,inp2.ChecklistID
	   ,inp2.VISN
	   ,inp2.FYQ
	   ,inp2.RollingFYQ
FROM   #inp1_aud AS inp2
       INNER JOIN [Inpat].[InpatientDiagnosis] AS idx  WITH (NOLOCK)
       ON inp2.InpatientEncounterSID = idx.InpatientSID
	   INNER JOIN #delirium_icd AS icd  WITH (NOLOCK)
	   ON icd.ICD10SID = idx.ICD10SID

UNION 

SELECT  inp3.MVIPersonSID		
       ,inp3.InpatientEncounterSID
       ,ddx.ICD10SID
	   ,'DXsource' = 'Inpat.DischargeDiagnosis'
	   ,inp3.ChecklistID
	   ,inp3.VISN
	   ,inp3.FYQ
	   ,inp3.RollingFYQ
FROM   #inp1_aud AS inp3
       INNER JOIN [Inpat].[InpatientDischargeDiagnosis] AS ddx  WITH (NOLOCK)
       ON inp3.InpatientEncounterSID = ddx.InpatientSID
	   INNER JOIN #delirium_icd AS icd  WITH (NOLOCK)
	   ON icd.ICD10SID = ddx.ICD10SID

UNION 

SELECT  inp4.MVIPersonSID		
       ,inp4.InpatientEncounterSID
       ,pdx.PrincipalDiagnosisICD10SID
	   ,'DXsource' = 'Inpat.Inpatient'
	   ,inp4.ChecklistID
	   ,inp4.VISN
	   ,inp4.FYQ
	   ,inp4.RollingFYQ
FROM   #inp1_aud AS inp4
       INNER JOIN [Inpatient].[BedSection] AS pdx  WITH (NOLOCK)
       ON inp4.InpatientEncounterSID = pdx.InpatientEncounterSID 
	   INNER JOIN #delirium_icd AS icd  WITH (NOLOCK)
	   ON icd.ICD10SID = pdx.PrincipalDiagnosisICD10SID
;

--final table of discharges with an alcohol withdrawal DELIRIUM diagnosis
DROP TABLE IF EXISTS #inp1_delirium;
SELECT inp.MVIPersonSID
	,inp.InpatientEncounterSID
	,inp.ICD10SID
	,icd.ICD10Code
	,icd.ICD10Description
	,'stdx' = MAX(CASE WHEN DXsource like '%specialty%' THEN 1 ELSE 0 END)
	,'idx' = MAX(CASE WHEN DXsource like '%inpatientdiagnosis%' THEN 1 ELSE 0 END)
	,'ddx' = MAX(CASE WHEN DXsource like '%discharge%' THEN 1 ELSE 0 END)
	,'pdx' = MAX(CASE WHEN DXsource like 'Inpat.Inpatient' THEN 1 ELSE 0 END)
	,inp.ChecklistID
	,inp.VISN
	,inp.FYQ
	,inp.RollingFYQ
INTO #inp1_delirium
FROM #inp1_dx_delirium  AS inp
INNER JOIN #delirium_icd AS icd
on inp.ICD10SID = icd.ICD10SID
GROUP BY inp.MVIPersonSID,inp.InpatientEncounterSID,inp.ICD10SID,icd.ICD10Code,icd.ICD10Description,inp.ChecklistID,inp.VISN,inp.FYQ,inp.RollingFYQ
;


--  FYQ AND FACILITY DATA ROLL-UP FOR STEP 3
--	Roll-up Counts and Rates of AW Stays with Delirium Diagnosis
-----------------------------------------------------------------------------

--discharges with an alcohol withdrawal and delirium diagnosis BY FACILITY AND FYQ
DROP TABLE IF EXISTS #deli_facility;
SELECT	VISN
	,ChecklistID
	,FYQ
	,Delirium = COUNT(DISTINCT InpatientEncounterSID)
INTO #deli_facility
FROM #inp1_delirium
GROUP BY VISN, ChecklistID, FYQ
;

--discharges with an alcohol withdrawal and delirium diagnosis BY FACILITY YTD
DROP TABLE IF EXISTS #deli_facility_ytd;
SELECT	VISN
	,ChecklistID
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,Delirium = COUNT(DISTINCT InpatientEncounterSID)
INTO #deli_facility_ytd
FROM #inp1_delirium
GROUP BY VISN, ChecklistID
;

--discharges with an alcohol withdrawal and delirium diagnosis BY VISN AND FYQ
DROP TABLE IF EXISTS #deli_visn;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ
	,Delirium = COUNT(DISTINCT InpatientEncounterSID)
INTO #deli_visn
FROM #inp1_delirium
GROUP BY VISN, FYQ
;

--discharges with an alcohol withdrawal and delirium diagnosis BY VISN YTD
DROP TABLE IF EXISTS #deli_visn_ytd;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,Delirium = COUNT(DISTINCT InpatientEncounterSID)
INTO #deli_visn_ytd
FROM #inp1_delirium
GROUP BY VISN
;

--discharges with an alcohol withdrawal and delirium diagnosis NATIONAL AND FYQ
DROP TABLE IF EXISTS #deli_nat;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ
	,Delirium = COUNT(DISTINCT InpatientEncounterSID)
INTO #deli_nat
FROM #inp1_delirium
GROUP BY FYQ
;

--discharges with an alcohol withdrawal and delirium diagnosis NATIONAL YTD
DROP TABLE IF EXISTS #deli_nat_ytd;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,Delirium = COUNT(DISTINCT InpatientEncounterSID)
INTO #deli_nat_ytd
FROM #inp1_delirium
;

--Combine All levels of AW discharges WITH DELRIUM by FYQ
DROP TABLE IF EXISTS #deli_levels;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Delirium INTO #deli_levels FROM #deli_facility
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Delirium FROM #deli_VISN
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Delirium FROM #deli_nat
;

--Combine All levels of AW discharges WITH DELRIUM by YTD
DROP TABLE IF EXISTS #deli_levels_ytd;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Delirium INTO #deli_levels_ytd FROM #deli_facility_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Delirium FROM #deli_VISN_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Delirium FROM #deli_nat_ytd
;

--Combine All levels of AW discharges WITH DELRIUM
DROP TABLE IF EXISTS #final_deli_levels;
SELECT VISN,Facility,FYQ,Delirium INTO #final_deli_levels FROM #deli_levels
UNION ALL
SELECT VISN,Facility,FYQ,Delirium FROM #deli_levels_ytd
;

/*********************************************************************************
 Step 4 - identify which AW discharges also had a SEIZURE diagnosis
*********************************************************************************/  

--STEP 4A: Find all ICD10SID for Alcohol Withdrawal (AW) SEIZURE diagnoses
---------------------------------------------------------------------------
	DROP TABLE IF EXISTS #seizure_icd;
	SELECT icd2.ICD10SID
		,cds.Value as ICD10Code
		,icd2.ICD10Description
	INTO #seizure_icd
	FROM [XLA].[Lib_SetValues_CDS] AS cds WITH (NOLOCK)
	INNER JOIN [Dim].[ICD10] as dim WITH (NOLOCK) ON cds.Value = dim.icd10Code
	INNER JOIN [Dim].[ICD10DescriptionVersion] AS icd2  WITH (NOLOCK) ON dim.ICD10SID=icd2.ICD10SID
	WHERE ALEXGUID = 'NEUROLOGICAL_SEIZURE'
;

--STEP 4B: Find all stays with a diagnosis of SEIZURE in inpatient discharges with a primary or secondary AW diagnosis
-----------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #inp1_dx_seizure;
SELECT  inp1.MVIPersonSID		
       ,inp1.InpatientEncounterSID
       ,stdx.ICD10SID
	   ,'DXsource' = 'Inpat.SpecialtyTransferDiagnosis'
	   ,inp1.ChecklistID
	   ,inp1.VISN
	   ,inp1.FYQ
	   ,inp1.RollingFYQ
INTO   #inp1_dx_seizure
FROM   #inp1_aud AS inp1
       INNER JOIN [Inpat].[SpecialtyTransferDiagnosis] AS stdx  WITH (NOLOCK)
       ON inp1.InpatientEncounterSID = stdx.InpatientSID
	   INNER JOIN #seizure_icd AS icd  WITH (NOLOCK)
	   ON icd.ICD10SID = stdx.ICD10SID

UNION 

SELECT  inp2.MVIPersonSID	
       ,inp2.InpatientEncounterSID
       ,idx.ICD10SID
	   ,'DXsource' = 'Inpat.InpatientDiagnosis'
	   ,inp2.ChecklistID
	   ,inp2.VISN
	   ,inp2.FYQ
	   ,inp2.RollingFYQ
FROM   #inp1_aud AS inp2
       INNER JOIN [Inpat].[InpatientDiagnosis] AS idx  WITH (NOLOCK)
       ON inp2.InpatientEncounterSID = idx.InpatientSID
	   INNER JOIN #seizure_icd AS icd  WITH (NOLOCK)
	   ON icd.ICD10SID = idx.ICD10SID

UNION 

SELECT  inp3.MVIPersonSID
       ,inp3.InpatientEncounterSID
       ,ddx.ICD10SID
	   ,'DXsource' = 'Inpat.DischargeDiagnosis'
	   ,inp3.ChecklistID
	   ,inp3.VISN
	   ,inp3.FYQ
	   ,inp3.RollingFYQ
FROM   #inp1_aud AS inp3
       INNER JOIN [Inpat].[InpatientDischargeDiagnosis] AS ddx  WITH (NOLOCK)
       ON inp3.InpatientEncounterSID = ddx.InpatientSID
	   INNER JOIN #seizure_icd AS icd  WITH (NOLOCK)
	   ON icd.ICD10SID = ddx.ICD10SID

UNION 

SELECT  inp4.MVIPersonSID		
       ,inp4.InpatientEncounterSID
       ,pdx.PrincipalDiagnosisICD10SID
	   ,'DXsource' = 'Inpat.Inpatient'
	   ,inp4.ChecklistID
	   ,inp4.VISN
	   ,inp4.FYQ
	   ,inp4.RollingFYQ
FROM   #inp1_aud AS inp4
       INNER JOIN [Inpatient].[BedSection] AS pdx  WITH (NOLOCK)
       ON inp4.InpatientEncounterSID = pdx.InpatientEncounterSID 
	   INNER JOIN #seizure_icd AS icd  WITH (NOLOCK)
	   ON icd.ICD10SID = pdx.PrincipalDiagnosisICD10SID
;

--final table of discharges with an alcohol withdrawal SEIZURE diagnosis
DROP TABLE IF EXISTS #inp1_seizure;
SELECT DISTINCT inp.MVIPersonSID
	,inp.InpatientEncounterSID
	,inp.ICD10SID
	,icd.ICD10Code
	,icd.ICD10Description
	,'stdx' = MAX(CASE WHEN DXsource like '%specialty%' THEN 1 ELSE 0 END)
	,'idx' = MAX(CASE WHEN DXsource like '%inpatientdiagnosis%' THEN 1 ELSE 0 END)
	,'ddx' = MAX(CASE WHEN DXsource like '%discharge%' THEN 1 ELSE 0 END)
	,'pdx' = MAX(CASE WHEN DXsource like 'Inpat.Inpatient' THEN 1 ELSE 0 END)
	,inp.ChecklistID
	,inp.VISN
	,inp.FYQ
	,inp.RollingFYQ
INTO #inp1_seizure
FROM #inp1_dx_seizure  AS inp
INNER JOIN #seizure_icd AS icd
on inp.ICD10SID = icd.ICD10SID
GROUP BY inp.MVIPersonSID,inp.InpatientEncounterSID,inp.ICD10SID,icd.ICD10Code,icd.ICD10Description,inp.ChecklistID,inp.VISN,inp.FYQ,inp.RollingFYQ
;

--  FYQ AND FACILITY DATA ROLL-UP FOR STEP 4
--	Roll-up Counts and Rates of AW Stays with Seizure Diagnosis
-----------------------------------------------------------------------------

--discharges with an alcohol withdrawal and seizure diagnosis BY FACILITY AND FYQ
DROP TABLE IF EXISTS #seiz_facility;
SELECT	VISN
	,ChecklistID
	,FYQ = MAX(FYQ)
	,Seizure = COUNT(DISTINCT InpatientEncounterSID)
INTO #seiz_facility
FROM #inp1_seizure
GROUP BY VISN, ChecklistID, FYQ
;

--discharges with an alcohol withdrawal and seizure diagnosis BY FACILITY YTD
DROP TABLE IF EXISTS #seiz_facility_ytd;
SELECT	VISN
	,ChecklistID
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,Seizure = COUNT(DISTINCT InpatientEncounterSID)
INTO #seiz_facility_ytd
FROM #inp1_seizure
GROUP BY VISN, ChecklistID
;

--discharges with an alcohol withdrawal and seizure diagnosis BY VISN AND FYQ
DROP TABLE IF EXISTS #seiz_visn;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ = MAX(FYQ)
	,Seizure = COUNT(DISTINCT InpatientEncounterSID)
INTO #seiz_visn
FROM #inp1_seizure
GROUP BY VISN, FYQ
;

--discharges with an alcohol withdrawal and seizure diagnosis BY VISN YTD
DROP TABLE IF EXISTS #seiz_visn_ytd;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ = CONCAT('YTD',MAX(RollingFYQ)) 
	,Seizure = COUNT(DISTINCT InpatientEncounterSID)
INTO #seiz_visn_ytd
FROM #inp1_seizure
GROUP BY VISN
;

--discharges with an alcohol withdrawal and seizure diagnosis NATIONAL AND FYQ
DROP TABLE IF EXISTS #seiz_nat;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ = MAX(FYQ)
	,Seizure = COUNT(DISTINCT InpatientEncounterSID)
INTO #seiz_nat
FROM #inp1_seizure
GROUP BY FYQ
;

--discharges with an alcohol withdrawal and seizure diagnosis NATIONAL YTD
DROP TABLE IF EXISTS #seiz_nat_ytd;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,Seizure = COUNT(DISTINCT InpatientEncounterSID)
INTO #seiz_nat_ytd
FROM #inp1_seizure
;

--Combine all levels of AW discharges WITH SEIZURE AND FYQ
DROP TABLE IF EXISTS #seiz_levels;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Seizure INTO #seiz_levels FROM #seiz_facility
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Seizure FROM #seiz_VISN
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Seizure FROM #seiz_nat
;

--Combine all levels of AW discharges WITH SEIZURE AND YTD
DROP TABLE IF EXISTS #seiz_levels_ytd;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Seizure INTO #seiz_levels_ytd FROM #seiz_facility_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Seizure FROM #seiz_VISN_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Seizure FROM #seiz_nat_ytd
;

--Combine All levels of AW discharges WITH SEIZURE
DROP TABLE IF EXISTS #final_seiz_levels;
SELECT VISN,Facility,FYQ,Seizure INTO #final_seiz_levels FROM #seiz_levels
UNION ALL
SELECT VISN,Facility,FYQ,Seizure FROM #seiz_levels_ytd
;


/*********************************************************************************
 Step 5 - identify which AW discharges also had an AUDIT-C completed within 1 day of admission
			Counts if survey administered on the day of admission or the next day
*********************************************************************************/  

--STEP 5A: Get all AUDIT-C surveys in time period
--------------------------------------------------------
	DROP TABLE IF EXISTS #audit_c;
	SELECT MVIPersonSID
		,SurveyGivenDatetime
	INTO #audit_c
	FROM [OMHSP_Standard].[MentalHealthAssistant_v02] as mha WITH(NOLOCK)
	INNER JOIN #Timeframe as t ON (mha.SurveyGivenDatetime >= t.YrStartDate and mha.SurveyGivenDatetime < t.QtrEndDate)
	WHERE (display_AUDC <> -1 and display_AUDC <> -99) 
;

--STEP 5B: Join with AW stays and indicate when AUDIT-C occurred during stay
-----------------------------------------------------------------------------
DROP TABLE IF EXISTS #AWstays_audc
SELECT a.*
	,b.SurveyGivenDatetime
	,AUDIT_C = CASE WHEN CAST(b.SurveyGivenDatetime AS DATE) >= CAST(a.AdmitDateTime AS DATE) and CAST(b.SurveyGivenDatetime AS DATE) < DATEADD(D,2,CAST(a.AdmitDateTime AS DATE)) THEN 1 ELSE 0 END
INTO #AWstays_audc
FROM #AWstays a
LEFT JOIN #audit_c b on a.MVIPersonSID=b.MVIPersonSID

--Rollup
DROP TABLE IF EXISTS #AWstays_audc2
SELECT MVIPersonSID	
	,InpatientEncounterSID
	,DischargeDateTime
	,AdmitDateTime
	,ChecklistID
	,VISN
	,InpatientDeath
	,FYQ
	,RollingFYQ
	,MAX(AUDIT_C) as AUDIT_C
INTO #AWstays_audc2
FROM #AWstays_audc
GROUP BY MVIPersonSID	
	,InpatientEncounterSID
	,DischargeDateTime
	,AdmitDateTime
	,ChecklistID
	,VISN
	,InpatientDeath
	,FYQ
	,RollingFYQ
;

--  FYQ AND FACILITY DATA ROLL-UP FOR STEP 5
--  COUNTS AND RATES OF AW INPATIENT discharges WITH AUDIT-C COMPLETED
-----------------------------------------------------------------------------------

--discharges with an alcohol withdrawal and AUDIT-C BY FACILITY AND FYQ
DROP TABLE IF EXISTS #audc_facility;
SELECT	VISN
	,ChecklistID
	,FYQ
	,AUDITC = COUNT(DISTINCT InpatientEncounterSID)
INTO #audc_facility
FROM #AWstays_audc2
WHERE AUDIT_C=1
GROUP BY VISN, ChecklistID, FYQ
;


--discharges with an alcohol withdrawal and AUDIT-C BY FACILITY YTD
DROP TABLE IF EXISTS #audc_facility_ytd;
SELECT	VISN
	,ChecklistID
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,AUDITC = COUNT(DISTINCT InpatientEncounterSID)
INTO #audc_facility_ytd
FROM #AWstays_audc2
WHERE AUDIT_C=1
GROUP BY VISN, ChecklistID
;

--discharges with an alcohol withdrawal and AUDIT-C BY VISN AND FYQ
DROP TABLE IF EXISTS #audc_visn;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ
	,AUDITC = COUNT(DISTINCT InpatientEncounterSID)
INTO #audc_visn
FROM #AWstays_audc2
WHERE AUDIT_C=1
GROUP BY VISN, FYQ
;

--discharges with an alcohol withdrawal and AUDIT-C BY VISN YTD
DROP TABLE IF EXISTS #audc_visn_ytd;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,AUDITC = COUNT(DISTINCT InpatientEncounterSID)
INTO #audc_visn_ytd
FROM #AWstays_audc2
WHERE AUDIT_C=1
GROUP BY VISN
;

--discharges with an alcohol withdrawal and AUDIT-C NATIONAL AND FYQ
DROP TABLE IF EXISTS #audc_nat;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ
	,AUDITC = COUNT(DISTINCT InpatientEncounterSID)
INTO #audc_nat
FROM #AWstays_audc2
WHERE AUDIT_C=1
GROUP BY FYQ
;

--discharges with an alcohol withdrawal and AUDIT-C NATIONAL YTD
DROP TABLE IF EXISTS #audc_nat_ytd;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,AUDITC = COUNT(DISTINCT InpatientEncounterSID)
INTO #audc_nat_ytd
FROM #AWstays_audc2
WHERE AUDIT_C=1
;

--Combine all levels of AW discharges WITH AUDIT-C AND FYQ
DROP TABLE IF EXISTS #audc_levels;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AUDITC INTO #audc_levels FROM #audc_facility
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AUDITC FROM #audc_VISN
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AUDITC FROM #audc_nat
;

--Combine all levels of AW discharges WITH AUDIT-C YTD
DROP TABLE IF EXISTS #audc_levels_ytd;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AUDITC INTO #audc_levels_ytd FROM #audc_facility_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AUDITC FROM #audc_VISN_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AUDITC FROM #audc_nat_ytd
;

--Combine All levels of AW discharges WITH AUDITC
DROP TABLE IF EXISTS #final_audc_levels;
SELECT VISN,Facility,FYQ,AUDITC INTO #final_audc_levels FROM #audc_levels
UNION ALL
SELECT VISN,Facility,FYQ,AUDITC FROM #audc_levels_ytd
;


/*********************************************************************************
 Step 6 - identify which AW discharges had a prescription for AUD the time of discharge

-- Active outpatient Rx at time of d/c for: ACAMPROSATE, DISULFIRAM, NALTREXONE, TOPIRAMATE
-- Rx which are “active” outpatient meds at the time of discharge. They could have been prescribed before the admission or started new during the admission.

*********************************************************************************/  
-----------------------------------------------
--STEP 6A: Get National Drug SIDs for AUD RX
-----------------------------------------------

	DROP TABLE IF EXISTS #NationalDrugSID_AUD;
	SELECT NationalDrugSID
		,VUID
		,DrugNameWithoutDose
	INTO #NationalDrugSID_AUD
	FROM [LookUp].[NationalDrug] WITH (NOLOCK)
	WHERE AlcoholPharmacotherapy_Rx=1	--ACAMPROSATE, DISULFIRAM, NALTREXONE, TOPIRAMATE
	;

----------------------------
-- STEP 6B: Outpatient Rx
----------------------------

-- Identify all AUD RX ordered during inpatient stay (on or after AdmitDate and on or before DischargeDate)
-- AND AUD RX ordered before discharge (or even admission) where the patient still has pills on hand at DischargeDate

-- VISTA
		DROP TABLE IF EXISTS #AUDrx_vista;
		SELECT DISTINCT -- distinct required because multiple RxOutpatFillSID per RxOutpatSID
			 aw.MVIPersonSID
			,aw.InpatientEncounterSID
			,aw.ChecklistID
			,aw.VISN
			,aw.AdmitDateTime
			,aw.DischargeDateTime
			,aw.FYQ
			,aw.RollingFYQ
			,rxo.IssueDate
			,rxo.RxStatus
			,fill.DaysSupply
			,fill.ReleaseDateTime
		INTO #AUDrx_vista
		FROM #AWstays as aw
		INNER JOIN [RxOut].[RxOutpat] AS rxo WITH (NOLOCK) ON aw.PatientPersonSID = rxo.PatientSID
		INNER JOIN [RxOut].[RxOutpatFill] AS fill WITH (NOLOCK) ON rxo.RxOutpatSID = fill.RxOutpatSID
		INNER JOIN #NationalDrugSID_AUD as nd ON rxo.NationalDrugSID = nd.NationalDrugSID
		WHERE (rxo.RxStatus NOT IN ('DELETED','NON-VERIFIED')
			AND	(rxo.IssueDate <= CAST(aw.DischargeDateTime AS DATE)	--Prescribed on or before discharge  
			AND CAST(fill.ReleaseDateTime AS DATE) <= CAST(aw.DischargeDateTime AS DATE)	--Released on or before discharge  
			AND DATEADD(DAY,fill.DaysSupply,fill.ReleaseDateTime) >= CAST(aw.DischargeDateTime AS DATE))--IssueDate before AdmitDateTime is OK as long as RX still active at discharge
				)
			OR (
				 rxo.RxStatus NOT IN ('DELETED','NON-VERIFIED')
			AND (rxo.IssueDate >= CAST(aw.AdmitDateTime AS DATE) AND rxo.IssueDate <= CAST(aw.DischargeDateTime AS DATE)) --prescribed during inpatient stay, regardless of whether RX was filled
				)
			;

--Group up to inpatient stay (Vista Outpatient)
	DROP TABLE IF EXISTS #AUDrx_vista_summary;
	SELECT MVIPersonSID
		,InpatientEncounterSID
		,ChecklistID
		,VISN
		,FYQ
		,RollingFYQ
		,AUD_RX = 1
	INTO #AUDrx_vista_summary
	FROM #AUDrx_vista
	GROUP BY MVIPersonSID, InpatientEncounterSID, ChecklistID, VISN, FYQ, RollingFYQ
	;

-- ORACLE HEALTH

-- Identify all AUD RX ordered during inpatient stay (on or after AdmitDate and on or before DischargeDate)
-- AND AUD RX ordered before discharge (or even admission) where the patient still has pills on hand at DischargeDate
	DROP TABLE IF EXISTS #AUDrx_oracle;
	WITH CTE_AudRxOrder AS
(	
SELECT aw.MVIPersonSID
		,aw.InpatientEncounterSID
		,aw.ChecklistID
		,aw.VISN
		,aw.AdmitDateTime
		,aw.DischargeDateTime
		,aw.FYQ
		,aw.RollingFYQ
		,o.DerivedPersonOrderSID	-- id for original prescriber order, if exists, else pharmacy order
		,IssueDate = CAST(d.TZDerivedOrderUTCDateTime AS DATE)	-- date of initial order
		,ReleaseDateTime = MIN(d.TZDerivedCompletedUTCDateTime) OVER (PARTITION BY d.DerivedPersonOrderSID)	-- date of first dispense for an order made during stay
	FROM #awstays as aw
	INNER JOIN [Cerner].[FactPharmacyOutpatientOrder] AS o WITH(NOLOCK) 
		ON aw.MVIPersonSID = o.MVIPersonSID
	INNER JOIN #NationalDrugSID_AUD as nd 
		ON o.PrimaryMnemonic = nd.DrugNameWithoutDose
	LEFT JOIN [Cerner].[FactPharmacyOutpatientDispensed] AS d WITH(NOLOCK)  ON o.MedMgrPersonOrderSID = d.MedMgrPersonOrderSID
	WHERE 1=1
       AND CAST(aw.DischargeDateTime AS DATE) >= CAST(o.TZDerivedOrderUTCDateTime AS DATE) -- ordered before discharge
       AND CAST(aw.AdmitDateTime AS DATE) <= CAST(o.TZDerivedOrderUTCDateTime AS DATE) -- ordered after admit
),
CTE_AudRxDispense AS
(
SELECT aw.MVIPersonSID
       ,aw.InpatientEncounterSID
       ,aw.ChecklistID
       ,aw.VISN
       ,aw.AdmitDateTime
       ,aw.DischargeDateTime
	   ,aw.FYQ
	   ,aw.RollingFYQ
       ,d.DerivedPersonOrderSID
       ,IssueDate = CAST(d.TZDerivedOrderUTCDateTime AS DATE)
       ,ReleaseDateTime = MAX(d.TZDerivedCompletedUTCDateTime) OVER (PARTITION BY d.DerivedPersonOrderSID)
FROM #awstays aw WITH (NOLOCK)
INNER JOIN Cerner.FactPharmacyOutpatientDispensed d WITH (NOLOCK)
       ON aw.MVIPersonSID = d.MVIPersonSID
INNER JOIN #NationalDrugSID_AUD nd
       ON d.VUID = nd.VUID  
WHERE 1 = 1
       AND DATEADD(DAY,CAST(d.Dayssupply AS INT),d.TZDerivedCompletedUTCDateTime) >= CAST(aw.DischargeDateTime AS DATE) -- AUD RX pills on-hand at DischargeDate
) 
SELECT DISTINCT MVIPersonSID
       ,InpatientEncounterSID
       ,ChecklistID
       ,VISN
       ,AdmitDateTime
       ,DischargeDateTime
	   ,FYQ
	   ,RollingFYQ
       ,DerivedPersonOrderSID
       ,IssueDate
       ,ReleaseDateTime
INTO #AUDrx_oracle
FROM CTE_AudRxOrder
UNION 
SELECT DISTINCT MVIPersonSID
       ,InpatientEncounterSID
       ,ChecklistID
       ,VISN
       ,AdmitDateTime
       ,DischargeDateTime
	   ,FYQ
	   ,RollingFYQ
       ,DerivedPersonOrderSID
       ,IssueDate
       ,ReleaseDateTime
FROM CTE_AudRxDispense
;

--Group up to inpatient stay (Oracle Health Outpatient)
	DROP TABLE IF EXISTS #AUDrx_oracle_summary;
	SELECT MVIPersonSID
		,InpatientEncounterSID
		,ChecklistID
		,VISN
		,FYQ
	    ,RollingFYQ
		,AUD_RX = 1
	INTO #AUDrx_oracle_summary
	FROM #AUDrx_oracle
	GROUP BY MVIPersonSID, InpatientEncounterSID, ChecklistID, VISN, FYQ, RollingFYQ
;

--Combine Vista and Oracle Health data
	DROP TABLE IF EXISTS #AUDrx_final;
	SELECT MVIPersonSID
		,InpatientEncounterSID
		,ChecklistID
		,VISN
		,FYQ
	    ,RollingFYQ
		,AUD_RX
	INTO #AUDrx_final
	FROM #AUDrx_vista_summary

	UNION

	SELECT MVIPersonSID
		,InpatientEncounterSID
		,ChecklistID
		,VISN
		,FYQ
	    ,RollingFYQ
		,AUD_RX
	FROM #AUDrx_oracle_summary

--  FYQ AND FACILITY DATA ROLL-UP FOR STEP 6
-------------------------------------------

--Number of AW inpatient discharges with AUD RX at Discharge BY FACILITY AND FYQ
	DROP TABLE IF EXISTS #AUDRX_facility;
	SELECT	VISN
	,ChecklistID
	,FYQ
	,AUD_RX	= SUM(AUD_RX)
	INTO #AUDRX_facility
	FROM #AUDrx_final
	GROUP BY VISN, ChecklistID, FYQ
;

--Number of AW inpatient discharges with AUD RX at Discharge BY FACILITY YTD
	DROP TABLE IF EXISTS #AUDRX_facility_ytd;
	SELECT	VISN
	,ChecklistID
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,AUD_RX	= SUM(AUD_RX)
	INTO #AUDRX_facility_ytd
	FROM #AUDrx_final
	GROUP BY VISN, ChecklistID
;

--Number of AW inpatient discharges with AUD RX at Discharge BY VISN AND FYQ
	DROP TABLE IF EXISTS #AUDRX_VISN;
	SELECT	VISN
	,ChecklistID = VISN
	,FYQ
	,AUD_RX	= SUM(AUD_RX)
	INTO #AUDRX_VISN
	FROM #AUDrx_final
	GROUP BY VISN, FYQ
;

--Number of AW inpatient discharges with AUD RX at Discharge BY VISN YTD
	DROP TABLE IF EXISTS #AUDRX_VISN_ytd;
	SELECT	VISN
	,ChecklistID = VISN
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,AUD_RX	= SUM(AUD_RX)
	INTO #AUDRX_VISN_ytd
	FROM #AUDrx_final
	GROUP BY VISN
	;

--Number of AW inpatient discharges with AUD RX at Discharge BY NATIONAL AND FYQ
	DROP TABLE IF EXISTS #AUDRX_nat;
	SELECT	VISN = 0
	,ChecklistID = 0
	,FYQ
	,AUD_RX	= SUM(AUD_RX)
	INTO #AUDRX_nat
	FROM #AUDrx_final
	GROUP BY FYQ
;

--Number of AW inpatient discharges with AUD RX at Discharge BY NATIONAL YTD
	DROP TABLE IF EXISTS #AUDRX_nat_ytd;
	SELECT	VISN = 0
	,ChecklistID = 0
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,AUD_RX	= SUM(AUD_RX)
	INTO #AUDRX_nat_ytd
	FROM #AUDrx_final
;

--Combine all levels of AUD RX at Discharge FYQ
	DROP TABLE IF EXISTS #AUDRX_levels;
	SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AUD_RX INTO #AUDRX_levels FROM #AUDRX_facility
	UNION ALL
	SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AUD_RX FROM #AUDRX_VISN
	UNION ALL
	SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AUD_RX FROM #AUDRX_nat
	;

	--Combine all levels of AUD RX at Discharge YTD
	DROP TABLE IF EXISTS #AUDRX_levels_ytd;
	SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AUD_RX INTO #AUDRX_levels_ytd FROM #AUDRX_facility_ytd
	UNION ALL
	SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AUD_RX FROM #AUDRX_VISN_ytd
	UNION ALL
	SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AUD_RX FROM #AUDRX_nat_ytd
	;

	
-- Combine all levels of AUD RX at Discharge
	DROP TABLE IF EXISTS #final_audrx_levels;
	SELECT VISN,Facility,FYQ,AUD_RX INTO #final_audrx_levels FROM #audrx_levels
	UNION ALL
	SELECT VISN,Facility,FYQ,AUD_RX FROM #audrx_levels_ytd
	;

/**************************************************************************************
 Step 7 - Inpatient Medications Administered During Inpatient Stay
		  Lorazepam, Chlordiazepoxide, Diazepam, Phenobarbital, Gabapentin, Clonidine
**************************************************************************************/

-----------------------------------------------
-- Get National Drug SIDs for Clonidine, Chlordiazepoxide, Diazepam, Gabapentin, Lorazepam, Phenobarbital
-----------------------------------------------

	DROP TABLE IF EXISTS #NationalDrugSID_RX;
	SELECT NationalDrugSID
		,VUID
		,DrugNameWithoutDose
		,Clonidine = CASE WHEN DrugNameWithoutDose LIKE '%Clonidine%' THEN 1 ELSE 0 END
		,Chlordiazepoxide = CASE WHEN DrugNameWithoutDose LIKE '%Chlordiazepoxide%' THEN 1 ELSE 0 END
		,Diazepam = CASE WHEN DrugNameWithoutDose LIKE '%Diazepam%' THEN 1 ELSE 0 END
		,Gabapentin = CASE WHEN DrugNameWithoutDose LIKE '%Gabapentin%' THEN 1 ELSE 0 END
		,Lorazepam = CASE WHEN DrugNameWithoutDose LIKE '%Lorazepam%' THEN 1 ELSE 0 END
		,Phenobarbital = CASE WHEN DrugNameWithoutDose LIKE '%Phenobarbital%' THEN 1 ELSE 0 END
	INTO #NationalDrugSID_RX
	FROM [LookUp].[NationalDrug] WITH (NOLOCK)
	WHERE 1=1
		AND (DrugNameWithoutDose LIKE '%Clonidine%'
		OR DrugNameWithoutDose LIKE '%Chlordiazepoxide%'
		OR DrugNameWithoutDose LIKE '%Diazepam%'
		OR DrugNameWithoutDose LIKE '%Gabapentin%'
		OR DrugNameWithoutDose LIKE '%Lorazepam%'
		OR DrugNameWithoutDose LIKE '%Phenobarbital%')
	;
--select distinct DrugNameWithoutDose, Clonidine,Chlordiazepoxide,Diazepam,Gabapentin,Lorazepam,Phenobarbital from #NationalDrugSID_RX

--------------------------
-- Inpatient RX dispensed during stay
--------------------------

--VISTA BCMA Dispensed
	DROP TABLE IF EXISTS #InptRXvista_raw;
	SELECT aw.MVIPersonSID
		,aw.InpatientEncounterSID
		,aw.ChecklistID
		,aw.VISN
		,aw.FYQ
		,aw.RollingFYQ
		,a.ActionDateTime
		,a.DosesGiven
		,a.UnitOfAdministration
		,c.DrugNameWithoutDose		
		,c.Clonidine 
		,c.Chlordiazepoxide
		,c.Diazepam
		,c.Gabapentin
		,c.Lorazepam
		,c.Phenobarbital
	INTO  #InptRXvista_raw
	FROM #AWstays as AW
	INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] as mvi WITH (NOLOCK) ON aw.MVIPersonSID = mvi.MVIPersonSID
	INNER JOIN [BCMA].[BCMADispensedDrug] a WITH (NOLOCK) ON mvi.PatientPersonSID = a.PatientSID
	INNER JOIN [Dim].[LocalDrug] b WITH (NOLOCK) ON a.LocalDrugSID = b.LocalDrugSID
	INNER JOIN #NationalDrugSID_RX c ON b.NationalDrugSID = c.NationalDrugSID
	WHERE 1=1
		AND a.DosesGiven IS NOT NULL
		AND (a.ActionDateTime >= aw.AdmitDateTime AND a.ActionDateTime < aw.DischargeDateTime) 
;

--Group up to Inpatient Stay (VistA BCMA Dispensed)
	DROP TABLE IF EXISTS #InptRXvista_summary;
	SELECT MVIPersonSID
		,InpatientEncounterSID
		,ChecklistID
		,VISN
		,FYQ
		,RollingFYQ
		,Clonidine		= MAX(Clonidine)
		,Chlordiazepoxide=MAX(Chlordiazepoxide)
		,Diazepam		= MAX(Diazepam)
		,Gabapentin		= MAX(Gabapentin)
		,Lorazepam		= MAX(Lorazepam)
		,Phenobarbital	= MAX(Phenobarbital)
	INTO #InptRXvista_summary
	FROM #InptRXvista_raw 
	GROUP BY MVIPersonSID, InpatientEncounterSID, ChecklistID, VISN, FYQ, RollingFYQ
;

-- VISTA CPRS Orders

-- Get list of qualifying CPRS orders
	DROP TABLE IF EXISTS #Orderable;
	SELECT oi.OrderableItemSID
		,oi.OrderableItemName
		,dg.DisplayGroupName
		,oi.InpatientMedCode
		,oi.OutpatientMedFlag
		,oi.NonFormularyFlag
		,oi.NonVAMedsFlag
		,Clonidine = CASE WHEN oi.OrderableItemName  LIKE '%Clonidine%' THEN 1 ELSE 0 END
		,Chlordiazepoxide = CASE WHEN oi.OrderableItemName  LIKE '%Chlordiazepoxide%' THEN 1 ELSE 0 END
		,Diazepam = CASE WHEN oi.OrderableItemName  LIKE '%Diazepam%' THEN 1 ELSE 0 END
		,Gabapentin = CASE WHEN oi.OrderableItemName  LIKE '%Gabapentin%' THEN 1 ELSE 0 END
		,Lorazepam = CASE WHEN oi.OrderableItemName  LIKE '%Lorazepam%' THEN 1 ELSE 0 END
		,Phenobarbital = CASE WHEN oi.OrderableItemName  LIKE '%Phenobarbital%' THEN 1 ELSE 0 END
	INTO #Orderable
	FROM [Dim].[OrderableItem] oi WITH (NOLOCK)
	INNER JOIN [Dim].[DisplayGroup] dg WITH (NOLOCK) ON dg.DisplayGroupSID = oi.DisplayGroupSID
	WHERE 1 =1
		AND (oi.OrderableItemName  LIKE '%Clonidine%'
			OR oi.OrderableItemName  LIKE '%Chlordiazepoxide%'
			OR oi.OrderableItemName  LIKE '%Diazepam%'
			OR oi.OrderableItemName  LIKE '%Gabapentin%'
			OR oi.OrderableItemName LIKE '%LorazepamM%'
			OR oi.OrderableItemName  LIKE '%Phenobarbital%')
		AND dg.DisplayGroupName LIKE 'pharmacy'
	;

	DROP TABLE IF EXISTS #Inpat_Orders;
	SELECT aw.MVIPersonSID
		,aw.InpatientEncounterSID
		,aw.ChecklistID
		,aw.VISN
		,aw.AdmitDateTime
		,aw.DischargeDateTime
		,aw.FYQ
		,aw.RollingFYQ
		,oi.OrderStartDateTime
		,oi.OrderStopDateTime
		,dim.OrderableItemName
		,dim.Clonidine 
		,dim.Chlordiazepoxide
		,dim.Diazepam
		,dim.Gabapentin
		,dim.Lorazepam
		,dim.Phenobarbital
	INTO #Inpat_Orders
	FROM #AWstays as aw
	INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] AS mvi WITH (NOLOCK) ON aw.MVIPersonSID = mvi.MVIPersonSID	
	INNER JOIN [CPRSOrder].[OrderedItem] AS oi WITH (NOLOCK) ON mvi.PatientPersonSID = oi.PatientSID
	INNER JOIN [CPRSOrder].[CPRSOrder] a WITH (NOLOCK) ON oi.CPRSOrderSID = a.CPRSOrderSID
	INNER JOIN #Orderable AS dim ON oi.OrderableItemSID = dim.OrderableItemSID
	LEFT JOIN [Dim].[VistaPackage] d WITH (NOLOCK)	ON a.VistaPackageSID = d.VistaPackageSID AND d.VistaPackage <> 'Outpatient Pharmacy' AND d.VistaPackage NOT LIKE '%Non-VA%'
	WHERE oi.OrderStartDateTime  >= aw.AdmitDateTime 
		AND oi.OrderStartDateTime < aw.DischargeDateTime 
		AND oi.OrderStartDateTime IS NOT NULL
;

--Group up to Inpatient Stay (CPRS Orders)
	DROP TABLE IF EXISTS #Inpat_Orders2;
	SELECT MVIPersonSID
		,InpatientEncounterSID
		,ChecklistID
		,VISN
		,FYQ
		,RollingFYQ
		,Clonidine		= MAX(Clonidine)
		,Chlordiazepoxide=MAX(Chlordiazepoxide)
		,Diazepam		= MAX(Diazepam)
		,Gabapentin		= MAX(Gabapentin)
		,Lorazepam		= MAX(Lorazepam)
		,Phenobarbital	= MAX(Phenobarbital)
	INTO #Inpat_Orders2
	FROM #Inpat_Orders
	GROUP BY MVIPersonSID, InpatientEncounterSID, ChecklistID, VISN, FYQ, RollingFYQ
;

--ORACLE HEALTH Inpatient Dispensed
	DROP TABLE IF EXISTS #InptAUDmill_raw;
	SELECT distinct s1.MVIPersonSID
		,aw.InpatientEncounterSID
		,aw.ChecklistID
		,aw.VISN
		,aw.FYQ
		,aw.RollingFYQ
		,s1.TZDispenseUTCDateTime
		,s1.AdministeredDoses
		,s1.PrimaryMnemonic
		,s1.LabelDescription
		,l.Clonidine 
		,l.Chlordiazepoxide
		,l.Diazepam
		,l.Gabapentin
		,l.Lorazepam
		,l.Phenobarbital
	INTO #InptAUDmill_raw
	FROM #AWstays as AW
	INNER JOIN [Cerner].[FactPharmacyInpatientDispensed] AS s1 WITH (NOLOCK) ON aw.MVIPersonSID = s1.MVIPersonSID
	INNER JOIN #NationalDrugSID_RX as l ON s1.VUID = l.VUID
	WHERE s1.TZDispenseUTCDateTime >= aw.AdmitDateTime AND s1.TZDispenseUTCDateTime < aw.DischargeDateTime
;

--Group up to Inpatient Stay (OracleHealth Inpatient Dispensed)
	DROP TABLE IF EXISTS #InptAUDmill_summary;
	SELECT MVIPersonSID
		,InpatientEncounterSID
		,ChecklistID
		,VISN
		,FYQ
		,RollingFYQ
		,Clonidine		= MAX(Clonidine)
		,Chlordiazepoxide=MAX(Chlordiazepoxide)
		,Diazepam		= MAX(Diazepam)
		,Gabapentin		= MAX(Gabapentin)
		,Lorazepam		= MAX(Lorazepam)
		,Phenobarbital	= MAX(Phenobarbital)
	INTO #InptAUDmill_summary
	FROM #InptAUDmill_raw 
	GROUP BY MVIPersonSID, InpatientEncounterSID, ChecklistID, VISN, FYQ, RollingFYQ
;

--OracleHealth BCMA
	DROP TABLE IF EXISTS #InptAUDmill_BCMA_raw; 
	SELECT s1.MVIPersonSID
		,aw.InpatientEncounterSID
		,aw.ChecklistID
		,aw.VISN
		,aw.FYQ
		,aw.RollingFYQ
		,s1.TZOrderUTCDateTime as InstanceFromDateTime
		,s1.TZOrderUTCDateTime as InstanceToDateTime 
		,s1.AdminDosage
		,s1.DosageUnit
		,l.DrugNameWithoutDose
		,l.Clonidine
		,l.Chlordiazepoxide
		,l.Diazepam
		,l.Gabapentin
		,l.Lorazepam
		,l.Phenobarbital
	INTO #InptAUDmill_BCMA_raw
	FROM  #AWstays as AW
	INNER JOIN [Cerner].[FactPharmacyBCMA] AS s1 WITH (NOLOCK) ON aw.MVIPersonSID = s1.MVIPersonSID
	INNER JOIN [Cerner].[DimDrug] AS d1 WITH (NOLOCK) ON s1.OrderCatalogSID = d1.OrderCatalogSID
	INNER JOIN #NationalDrugSID_RX AS l ON d1.VUID = l.VUID
	WHERE s1.TZOrderUTCDateTime >= aw.AdmitDateTime AND s1.TZOrderUTCDateTime < aw.DischargeDateTime
;

--Group up to Inpatient Stay
	DROP TABLE IF EXISTS #InptAUDmill_BCMA_summary;
	SELECT MVIPersonSID
		,InpatientEncounterSID
		,ChecklistID
		,VISN
		,FYQ
		,RollingFYQ
		,Clonidine		= MAX(Clonidine)
		,Chlordiazepoxide=MAX(Chlordiazepoxide)
		,Diazepam		= MAX(Diazepam)
		,Gabapentin		= MAX(Gabapentin)
		,Lorazepam		= MAX(Lorazepam)
		,Phenobarbital	= MAX(Phenobarbital)
	INTO #InptAUDmill_BCMA_summary
	FROM #InptAUDmill_BCMA_raw 
	GROUP BY MVIPersonSID, InpatientEncounterSID, ChecklistID, VISN, FYQ, RollingFYQ
;

--Combine all Inpatient RX sources
	DROP TABLE IF EXISTS #InptRX_All;
	SELECT MVIPersonSID
		,InpatientEncounterSID
		,ChecklistID
		,VISN
		,FYQ
		,RollingFYQ
		,Clonidine 
		,Chlordiazepoxide
		,Diazepam
		,Gabapentin 
		,Lorazepam 
		,Phenobarbital 
	INTO #InptRX_All
	FROM #InptRXvista_summary
	
	UNION

	SELECT MVIPersonSID
		,InpatientEncounterSID
		,ChecklistID
		,VISN
		,FYQ
		,RollingFYQ
		,Clonidine
		,Chlordiazepoxide
		,Diazepam 
		,Gabapentin 
		,Lorazepam 
		,Phenobarbital 
	FROM #Inpat_Orders2

	UNION

	SELECT MVIPersonSID
		,InpatientEncounterSID
		,ChecklistID
		,VISN
		,FYQ
		,RollingFYQ
		,Clonidine 
		,Chlordiazepoxide
		,Diazepam
		,Gabapentin 
		,Lorazepam 
		,Phenobarbital  
	FROM #InptAUDmill_summary

	UNION
	
	SELECT MVIPersonSID
		,InpatientEncounterSID
		,ChecklistID
		,VISN
		,FYQ
		,RollingFYQ
		,Clonidine 
		,Chlordiazepoxide
		,Diazepam
		,Gabapentin 
		,Lorazepam 
		,Phenobarbital 
	FROM #InptAUDmill_BCMA_summary
	;

--Group up to inpatient stay
	DROP TABLE IF EXISTS #InptRX_All2;
	SELECT MVIPersonSID
		,InpatientEncounterSID
		,ChecklistID
		,VISN
		,FYQ
		,RollingFYQ
		,Clonidine		= MAX(Clonidine)
		,Chlordiazepoxide=MAX(Chlordiazepoxide)
		,Diazepam		= MAX(Diazepam)
		,Gabapentin		= MAX(Gabapentin)
		,Lorazepam		= MAX(Lorazepam)
		,Phenobarbital	= MAX(Phenobarbital)
	INTO #InptRX_All2
	FROM  #InptRX_All
	GROUP BY MVIPersonSID
		,InpatientEncounterSID
		,ChecklistID
		,VISN
		,FYQ
		,RollingFYQ
	;

	
--  FYQ AND FACILITY DATA ROLL-UP FOR STEP 7
-------------------------------------------

--Number of AW inpatient discharges with Inpatient RX Dispensed BY FACILITY AND FYQ
	DROP TABLE IF EXISTS #InptRX_facility;
	SELECT	VISN
	,ChecklistID
	,FYQ
	,Clonidine		= SUM(Clonidine)
	,Chlordiazepoxide=SUM(Chlordiazepoxide)
	,Diazepam		= SUM(Diazepam)
	,Gabapentin		= SUM(Gabapentin)
	,Lorazepam		= SUM(Lorazepam)
	,Phenobarbital	= SUM(Phenobarbital)
	INTO #InptRX_facility
	FROM #InptRX_All2
	GROUP BY VISN, ChecklistID, FYQ
;


--Number of AW inpatient discharges with Inpatient RX Dispensed BY FACILITY YTD
	DROP TABLE IF EXISTS #InptRX_facility_ytd;
	SELECT	VISN
	,ChecklistID
	,FYQ			= CONCAT('YTD',MAX(RollingFYQ))
	,Clonidine		= SUM(Clonidine)
	,Chlordiazepoxide=SUM(Chlordiazepoxide)
	,Diazepam		= SUM(Diazepam)
	,Gabapentin		= SUM(Gabapentin)
	,Lorazepam		= SUM(Lorazepam)
	,Phenobarbital	= SUM(Phenobarbital)
	INTO #InptRX_facility_ytd
	FROM #InptRX_All2
	GROUP BY VISN, ChecklistID
;

--Number of AW inpatient discharges with Inpatient RX Dispensed BY VISN AND FYQ
	DROP TABLE IF EXISTS #InptRX_VISN;
	SELECT	VISN
		,ChecklistID	= VISN
		,FYQ
		,Clonidine		= SUM(Clonidine)
		,Chlordiazepoxide=SUM(Chlordiazepoxide)
		,Diazepam		= SUM(Diazepam)
		,Gabapentin		= SUM(Gabapentin)
		,Lorazepam		= SUM(Lorazepam)
		,Phenobarbital	= SUM(Phenobarbital)
	INTO #InptRX_VISN
	FROM #InptRX_All2
	GROUP BY VISN, FYQ
;

--Number of AW inpatient discharges with Inpatient RX Dispensed BY VISN YTD
	DROP TABLE IF EXISTS #InptRX_VISN_ytd;
	SELECT	VISN
		,ChecklistID	= VISN
		,FYQ			= CONCAT('YTD',MAX(RollingFYQ))
		,Clonidine		= SUM(Clonidine)
		,Chlordiazepoxide=SUM(Chlordiazepoxide)
		,Diazepam		= SUM(Diazepam)
		,Gabapentin		= SUM(Gabapentin)
		,Lorazepam		= SUM(Lorazepam)
		,Phenobarbital	= SUM(Phenobarbital)
	INTO #InptRX_VISN_ytd
	FROM #InptRX_All2
	GROUP BY VISN
;

--Number of AW inpatient discharges with Inpatient RX Dispensed BY NATIONAL AND FYQ
	DROP TABLE IF EXISTS #InptRX_nat;
	SELECT VISN	= 0
		,ChecklistID	= 0
		,FYQ
		,Clonidine		= SUM(Clonidine)
		,Chlordiazepoxide=SUM(Chlordiazepoxide)
		,Diazepam		= SUM(Diazepam)
		,Gabapentin		= SUM(Gabapentin)
		,Lorazepam		= SUM(Lorazepam)
		,Phenobarbital	= SUM(Phenobarbital)
	INTO #InptRX_nat
	FROM #InptRX_All2
	GROUP BY FYQ
;

--Number of AW inpatient discharges with Inpatient RX Dispensed BY NATIONAL YTD
	DROP TABLE IF EXISTS #InptRX_nat_ytd;
	SELECT VISN	= 0
		,ChecklistID	= 0
		,FYQ			= CONCAT('YTD',MAX(RollingFYQ))
		,Clonidine		= SUM(Clonidine)
		,Chlordiazepoxide=SUM(Chlordiazepoxide)
		,Diazepam		= SUM(Diazepam)
		,Gabapentin		= SUM(Gabapentin)
		,Lorazepam		= SUM(Lorazepam)
		,Phenobarbital	= SUM(Phenobarbital)
	INTO #InptRX_nat_ytd
	FROM #InptRX_All2
;

--Combine all levels of INPATIENT RX Dispensed FYQ
	DROP TABLE IF EXISTS #InptRX_levels;
	SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Clonidine,Chlordiazepoxide,Diazepam,Gabapentin,Lorazepam,Phenobarbital INTO #InptRX_levels FROM #InptRX_facility
	UNION ALL
	SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Clonidine,Chlordiazepoxide,Diazepam,Gabapentin,Lorazepam,Phenobarbital FROM #InptRX_VISN
	UNION ALL
	SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Clonidine,Chlordiazepoxide,Diazepam,Gabapentin,Lorazepam,Phenobarbital FROM #InptRX_nat
	;

	
--Combine all levels of INPATIENT RX Dispensed YTD
	DROP TABLE IF EXISTS #InptRX_levels_ytd;
	SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Clonidine,Chlordiazepoxide,Diazepam,Gabapentin,Lorazepam,Phenobarbital INTO #InptRX_levels_ytd FROM #InptRX_facility_ytd
	UNION ALL
	SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Clonidine,Chlordiazepoxide,Diazepam,Gabapentin,Lorazepam,Phenobarbital FROM #InptRX_VISN_ytd
	UNION ALL
	SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Clonidine,Chlordiazepoxide,Diazepam,Gabapentin,Lorazepam,Phenobarbital FROM #InptRX_nat_ytd
	;
	
-- Combine all levels of INPATIENT RX Dispensed YTD
	DROP TABLE IF EXISTS #final_Inptrx_levels;
	SELECT VISN,Facility,FYQ,Clonidine,Chlordiazepoxide,Diazepam,Gabapentin,Lorazepam,Phenobarbital INTO #final_inptrx_levels FROM #Inptrx_levels
	UNION ALL
	SELECT VISN,Facility,FYQ,Clonidine,Chlordiazepoxide,Diazepam,Gabapentin,Lorazepam,Phenobarbital FROM #Inptrx_levels_ytd
	;

/*----------------------------
Step 8 - SUMMARY METRIC DATA

	total N of admits
	number of AW admits, AMA discharges, and inpatient deaths
	% of total admits AW
-------------------------------*/

	
--  FYQ AND FACILITY DATA ROLL-UP FOR INPATIENT discharges
-------------------------------------------

--Number of inpatient discharges BY FACILITY AND FYQ
DROP TABLE IF EXISTS #inp_facility;
SELECT VISN
	,ChecklistID
	,FYQ
	,Inpatients = COUNT(DISTINCT MVIPersonSID)
	,InpDischarges = COUNT(DISTINCT InpatientEncounterSID)
INTO #inp_facility
FROM #inpatient_dailyworkload
GROUP BY VISN, ChecklistID,FYQ
;

--Number of inpatient discharges BY FACILITY YTD
DROP TABLE IF EXISTS #inp_facility_ytd;
SELECT VISN
	,ChecklistID
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,Inpatients = COUNT(DISTINCT MVIPersonSID)
	,InpDischarges = COUNT(DISTINCT InpatientEncounterSID)
INTO #inp_facility_ytd
FROM #inpatient_dailyworkload
GROUP BY VISN, ChecklistID
;

--Number of inpatient discharges BY VISN AND FYQ
DROP TABLE IF EXISTS #inp_VISN;
SELECT VISN
	,ChecklistID=VISN
	,FYQ
	,Inpatients = COUNT(DISTINCT MVIPersonSID)
	,InpDischarges = COUNT(DISTINCT InpatientEncounterSID)
INTO #inp_VISN
FROM #inpatient_dailyworkload
GROUP BY VISN, FYQ
;

--Number of inpatient discharges BY VISN YTD
DROP TABLE IF EXISTS #inp_VISN_ytd;
SELECT VISN
	,ChecklistID=VISN
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,Inpatients = COUNT(DISTINCT MVIPersonSID)
	,InpDischarges = COUNT(DISTINCT InpatientEncounterSID)
INTO #inp_VISN_ytd
FROM #inpatient_dailyworkload
GROUP BY VISN
;

--Number of inpatient discharges NATIONAL and FYQ
DROP TABLE IF EXISTS #inp_nat;
SELECT VISN = 0
	,ChecklistID=0
	,FYQ
	,Inpatients = COUNT(DISTINCT MVIPersonSID)
	,InpDischarges = COUNT(DISTINCT InpatientEncounterSID)
INTO #inp_nat
FROM #inpatient_dailyworkload
GROUP BY FYQ
;

--Number of inpatient discharges NATIONAL YTD
DROP TABLE IF EXISTS #inp_nat_ytd;
SELECT VISN = 0
	,ChecklistID=0
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,Inpatients = COUNT(DISTINCT MVIPersonSID)
	,InpDischarges = COUNT(DISTINCT InpatientEncounterSID)
INTO #inp_nat_ytd
FROM #inpatient_dailyworkload
;

--Combine all levels of NUMBER OF INPATIENT discharges BY FYQ
DROP TABLE IF EXISTS #inp_levels;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Inpatients,InpDischarges INTO #inp_levels FROM #inp_facility
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Inpatients,InpDischarges FROM #inp_VISN
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Inpatients,InpDischarges FROM #inp_nat
;

--Combine all levels of NUMBER OF INPATIENT discharges YTD
DROP TABLE IF EXISTS #inp_levels_ytd;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Inpatients,InpDischarges INTO #inp_levels_ytd FROM #inp_facility_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Inpatients,InpDischarges FROM #inp_VISN_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Inpatients,InpDischarges FROM #inp_nat_ytd
;

-- Combine all levels of INPATIENT RX Dispensed YTD
DROP TABLE IF EXISTS #final_Inp_levels;
SELECT VISN,Facility,FYQ,Inpatients,InpDischarges INTO #final_inp_levels FROM #Inp_levels
UNION ALL
SELECT VISN,Facility,FYQ,Inpatients,InpDischarges FROM #Inp_levels_ytd
;

/*----------------------------------------------------------------------
NUMBER OF AW INPATIENT discharges, INPATIENT DEATHS, AND AMA DISCHARGES
-----------------------------------------------------------------------*/

--Number of AW inpatient discharges, AMA discharges, and inpatient deaths during AW stays BY FACILITY AND FYQ
DROP TABLE IF EXISTS #aud_facility;
SELECT	VISN
	,ChecklistID
	,FYQ
	,AWinpatients = COUNT(DISTINCT MVIPersonSID)
	,AWdischarges = COUNT(DISTINCT InpatientEncounterSID)
	,InpatientDeaths = SUM(InpatientDeath)
	,AMA = SUM(AMA)
INTO #aud_facility
FROM #AWstays
GROUP BY VISN, ChecklistID, FYQ
;

--Number of AW inpatient discharges, AMA discharges, and inpatient deaths during AW stays BY FACILITY YTD
DROP TABLE IF EXISTS #aud_facility_ytd;
SELECT	VISN
	,ChecklistID
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,AWinpatients = COUNT(DISTINCT MVIPersonSID)
	,AWdischarges = COUNT(DISTINCT InpatientEncounterSID)
	,InpatientDeaths = SUM(InpatientDeath)
	,AMA = SUM(AMA)
INTO #aud_facility_ytd
FROM #AWstays
GROUP BY VISN, ChecklistID
;

--Number of AW inpatient discharges, AMA discharges, and inpatient deaths during AW stays  BY VISN AND FYQ
DROP TABLE IF EXISTS #aud_visn;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ
	,AWinpatients = COUNT(DISTINCT MVIPersonSID)
	,AWdischarges = COUNT(DISTINCT InpatientEncounterSID)
	,InpatientDeaths = SUM(InpatientDeath)
	,AMA = SUM(AMA)
INTO #aud_visn
FROM #AWstays
GROUP BY VISN, FYQ
;

--Number of AW inpatient discharges, AMA discharges, and inpatient deaths during AW stays  BY VISN YTD
DROP TABLE IF EXISTS #aud_visn_ytd;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,AWinpatients = COUNT(DISTINCT MVIPersonSID)
	,AWdischarges = COUNT(DISTINCT InpatientEncounterSID)
	,InpatientDeaths = SUM(InpatientDeath)
	,AMA = SUM(AMA)
INTO #aud_visn_ytd
FROM #AWstays
GROUP BY VISN
;

--Number of AW inpatient discharges, AMA discharges, and inpatient deaths during AW stays NATIONAL FYQ
DROP TABLE IF EXISTS #aud_nat;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ
	,AWinpatients = COUNT(DISTINCT MVIPersonSID)
	,AWdischarges = COUNT(DISTINCT InpatientEncounterSID)
	,InpatientDeaths = SUM(InpatientDeath)
	,AMA = SUM(AMA)
INTO #aud_nat
FROM #AWstays
GROUP BY FYQ
;

--Number of AW inpatient discharges, AMA discharges, and inpatient deaths during AW stays NATIONAL YTD
DROP TABLE IF EXISTS #aud_nat_ytd;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,AWinpatients = COUNT(DISTINCT MVIPersonSID)
	,AWdischarges = COUNT(DISTINCT InpatientEncounterSID)
	,InpatientDeaths = SUM(InpatientDeath)
	,AMA = SUM(AMA)
INTO #aud_nat_ytd
FROM #AWstays
;

--Combine all levels of NUMBER OF AW INPATIENT discharges, AMA DISCHARGES, and INPATIENT DEATHS during AW stays FYQ
DROP TABLE IF EXISTS #aud_levels;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AWinpatients,AWdischarges,InpatientDeaths,AMA INTO #aud_levels FROM #aud_facility
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AWinpatients,AWdischarges,InpatientDeaths,AMA FROM #aud_VISN
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AWinpatients,AWdischarges,InpatientDeaths,AMA FROM #aud_nat
;

--Combine all levels of NUMBER OF AW INPATIENT discharges, AMA DISCHARGES, and INPATIENT DEATHS during AW stays YTD
DROP TABLE IF EXISTS #aud_levels_ytd;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AWinpatients,AWdischarges,InpatientDeaths,AMA INTO #aud_levels_ytd FROM #aud_facility_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AWinpatients,AWdischarges,InpatientDeaths,AMA FROM #aud_VISN_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AWinpatients,AWdischarges,InpatientDeaths,AMA FROM #aud_nat_ytd
;

-- Combine all levels of NUMBER OF AW INPATIENT discharges, AMA DISCHARGES, and INPATIENT DEATHS during AW stays
DROP TABLE IF EXISTS #final_aud_levels;
SELECT VISN,Facility,FYQ,AWinpatients,AWdischarges,InpatientDeaths,AMA  INTO #final_aud_levels FROM #aud_levels
UNION ALL
SELECT VISN,Facility,FYQ,AWinpatients,AWdischarges,InpatientDeaths,AMA  FROM #aud_levels_ytd
;

DROP TABLE IF EXISTS #all_levels;
SELECT DISTINCT inp.VISN
	,inp.Facility
	,aud.FYQ
	,Inpatients = MAX(ISNULL(inp.Inpatients,0))
	,InpDischarges = MAX(ISNULL(inp.InpDischarges,0))
	,AWinpatients = MAX(ISNULL(aud.AWinpatients,0))
	,AWdischarges = MAX(ISNULL(aud.AWdischarges,0))
	,AWdischarges_percent = MAX(CAST((ISNULL(CAST(aud.AWdischarges AS FLOAT)/CAST(inp.InpDischarges AS FLOAT),0)*100) AS DECIMAL(10,2)))
	,InpatientDeaths = MAX(ISNULL(aud.InpatientDeaths,0))
	,AMAdischarges = MAX(ISNULL(aud.AMA,0))
	,AMADisch_percent = MAX(CAST((ISNULL(CAST(aud.AMA AS FLOAT)/CAST(AUD.AWdischarges AS FLOAT),0)*100) AS DECIMAL(10,2)) )
INTO #all_levels
FROM #final_inp_levels as inp
LEFT JOIN #final_aud_levels as aud ON inp.Facility = aud.Facility and inp.FYQ = aud.FYQ
GROUP by inp.VISN, inp.facility, aud.FYQ
;

/*-----------------------------------------------------
Step 9:		30-DAY ALL-CAUSE READMISSION RATE
------------------------------------------------------*/


--STEP 9A: Identify qualifying AW inpatient stays (Denominator)
------------------------------------------------------------------
--	Exclude stays where patient died (InpatientDeath=1)
--	Exclude stays where patients discharged AMA (AMA=1; based on IPEC/CMS criteria; calculating both ways for sensitivity analysis)
--	Exclude stays with same-day admission & discharge (based on IPEC/CMS criteria)

DROP TABLE IF EXISTS #Readmit_DEN_prep;
SELECT *
INTO #Readmit_DEN_prep
FROM #AWstays 
WHERE 1=1
	AND InpatientDeath = 0		--Remove stays where patient died (InpatientDeath=1)
--	AND a.AMA = 0				--Remove stays where patients discharged AMA (based on IPEC/CMS criteria; but also testing to see what difference this makes so calculating both ways)
	AND CAST(AdmitDateTime AS DATE) <> CAST(DischargeDateTime AS DATE)	--Exclude same-day admission & discharge (based on IPEC/CMS criteria)
;

--STEP 9B: All-cause unplanned readmissions (Numerator)	
----------------------------------------------------------------------
--Find all inpatient stays for patients in the denominator (limit to same bedsections as initial cohort)
--Mark stays with an admission date within 30 days of a qualifying AW stay discharge day as a Readmission
--Roll up Numerator to 1/0 binary per patient, was patient re-admitted in 30 days following AW stay discharge?

DROP TABLE IF EXISTS #Readmit;
SELECT a.*
	  ,i.InpatientEncounterSID as InpatientEncounterSID_30d
	  ,i.Sta3n_EHR as Sta3n_EHR_30d
	  ,i.DischargeDateTime as DischargeDateTime_30d
	  ,i.AdmitDateTime as AdmitDateTime_30d
	  ,CASE WHEN DATEDIFF(DAY,a.DischargeDateTime,i.AdmitDateTime) > 0 AND DATEDIFF(DAY,a.DischargeDateTime,i.AdmitDateTime) < 31 THEN 1 ELSE 0 END as Readmission
INTO #Readmit
FROM [Inpatient].[BedSection] AS i WITH (NOLOCK) 
INNER JOIN #Readmit_DEN_prep AS a ON a.MVIPersonSID = i.MVIPersonSID
INNER JOIN #Timeframe as t ON  (i.AdmitDateTime >= t.YrStartDate and i.AdmitDateTime < DATEADD(DAY,31,t.QtrEndDate)) 
WHERE 1=1
	AND i.Bedsection IN('15',		--GENERAL(ACUTE MEDICINE)
						 '12',		--MEDICAL ICU
						 '1H',		--MEDICAL STEP DOWN
						 '17',		--TELEMETRY
						 '24',		--MEDICAL OBSERVATION
						 '74'		--SUBSTANCE ABUSE TRMT UNIT
						 )
	AND a.InpatientEncounterSID <> i.InpatientEncounterSID
;

--Get CPTSIDs for planned or potentially planned inpatient procedures (e.g. colonoscopy, kidney transplant, chemotherapy, treatment of fractures, etc. )
DROP TABLE IF EXISTS #CPT;
SELECT dim.CPTSID
INTO #CPT
FROM [Dim].[CPT] as dim WITH(NOLOCK)
INNER JOIN [Config].[AWinpatient_Readmission_CPT] as cpt WITH(NOLOCK) ON cpt.CPTCode = dim.CPTCode	
;

--Identify planned Readmissions
DROP TABLE IF EXISTS #Planned;
SELECT DISTINCT a.InpatientEncounterSID_30d
INTO #Planned
FROM #Readmit as a 
INNER JOIN [Inpat].[InpatientCPTProcedure] as i WITH(NOLOCK) ON a.InpatientEncounterSID_30d = i.InpatientSID
INNER JOIN #CPT as cpt WITH(NOLOCK) ON i.CPTSID = cpt.CPTSID
	WHERE 1 = 1
	AND a.Readmission = 1
;	

--Exclude planned or potentially planned readmissions (Numerator)
DROP TABLE IF EXISTS #Readmit_NUM;	
SELECT DISTINCT a.MVIPersonSID
	,a.InpatientEncounterSID
	,a.InpatientEncounterSID_30d
	,a.ChecklistID
	,a.VISN
	,a.FYQ
	,a.RollingFYQ
INTO #Readmit_NUM
FROM #Readmit AS a 
LEFT JOIN #Planned as p ON a.InpatientEncounterSID_30d = p.InpatientEncounterSID_30d
WHERE 1 = 1
	AND a.Readmission=1 
	AND p.InpatientEncounterSID_30d IS NULL		--Removes planned or potentially planned readmissions
;

--STEP 9C: Roll up Readmissions by Facility
----------------------------------------------

--Assign readmissions to AW stay facility
DROP TABLE IF EXISTS #Readmit_DEN;
SELECT a.MVIPersonSID
		,a.InpatientEncounterSID
		,a.ChecklistID
		,a.VISN
		,a.AMA
		,a.FYQ
		,a.RollingFYQ
INTO #Readmit_DEN
FROM #AWstays a
INNER JOIN #readmit_DEN_prep as b on a.MVIPersonSID=b.MVIPersonSID and a.InpatientEncounterSID=b.InpatientEncounterSID
GROUP BY a.MVIPersonSID
		,a.InpatientEncounterSID
		,a.ChecklistID
		,a.VISN
		,a.AMA
		,a.FYQ
		,a.RollingFYQ
;

--30-Day Readmission Denominator BY FACILITY FYQ
DROP TABLE IF EXISTS #readmit_DEN_facility;
SELECT	VISN
	,ChecklistID
	,FYQ
	,Readmit_DEN = COUNT(InpatientEncounterSID)
	,Readmit_DEN_AMA = SUM(CASE WHEN AMA=0 THEN 1 ELSE 0 END)
INTO #readmit_DEN_facility
FROM #Readmit_DEN
GROUP BY VISN, ChecklistID, FYQ
;

--30-Day Readmission Denominator BY FACILITY YTD
DROP TABLE IF EXISTS #readmit_DEN_facility_ytd;
SELECT	VISN
	,ChecklistID
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,Readmit_DEN = COUNT(InpatientEncounterSID)
	,Readmit_DEN_AMA = SUM(CASE WHEN AMA=0 THEN 1 ELSE 0 END)
INTO #readmit_DEN_facility_ytd
FROM #Readmit_DEN
GROUP BY VISN, ChecklistID
;

--30-Day Readmission Denominator BY VISN AND FYQ
DROP TABLE IF EXISTS #readmit_DEN_visn;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ
	,Readmit_DEN = COUNT(InpatientEncounterSID)
	,Readmit_DEN_AMA = SUM(CASE WHEN AMA=0 THEN 1 ELSE 0 END)
INTO #readmit_DEN_visn
FROM #Readmit_DEN
GROUP BY VISN, FYQ
;

--30-Day Readmission Denominator BY VISN YTD
DROP TABLE IF EXISTS #readmit_DEN_visn_ytd;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,Readmit_DEN = COUNT(InpatientEncounterSID)
	,Readmit_DEN_AMA = SUM(CASE WHEN AMA=0 THEN 1 ELSE 0 END)
INTO #readmit_DEN_visn_ytd
FROM #Readmit_DEN
GROUP BY VISN
;

--30-Day Readmission Denominator NATIONAL AND FYQ
DROP TABLE IF EXISTS #readmit_DEN_nat;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ
	,Readmit_DEN = COUNT(InpatientEncounterSID)
	,Readmit_DEN_AMA = SUM(CASE WHEN AMA=0 THEN 1 ELSE 0 END)
INTO #readmit_DEN_nat
FROM #Readmit_DEN
GROUP BY FYQ
;

--30-Day Readmission Denominator NATIONAL YTD
DROP TABLE IF EXISTS #readmit_DEN_nat_ytd;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,Readmit_DEN = COUNT(InpatientEncounterSID)
	,Readmit_DEN_AMA = SUM(CASE WHEN AMA=0 THEN 1 ELSE 0 END)
INTO #readmit_DEN_nat_ytd
FROM #Readmit_DEN
;

--Combine all levels of 30-Day Readmission Denominator FYQ
DROP TABLE IF EXISTS #readmit_DEN_levels;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Readmit_DEN,Readmit_DEN_AMA INTO #readmit_DEN_levels FROM #readmit_DEN_facility
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Readmit_DEN,Readmit_DEN_AMA FROM #readmit_DEN_VISN
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Readmit_DEN,Readmit_DEN_AMA FROM #readmit_DEN_nat
;

--Combine all levels of 30-Day Readmission Denominator YTD
DROP TABLE IF EXISTS #readmit_DEN_levels_ytd;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Readmit_DEN,Readmit_DEN_AMA INTO #readmit_DEN_levels_ytd FROM #readmit_DEN_facility_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Readmit_DEN,Readmit_DEN_AMA FROM #readmit_DEN_VISN_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Readmit_DEN,Readmit_DEN_AMA FROM #readmit_DEN_nat_ytd
;

-- Combine all levels of 30-Day Readmission Denominator
DROP TABLE IF EXISTS #final_readmit_DEN_levels;
SELECT VISN,Facility,FYQ,Readmit_DEN,Readmit_DEN_AMA INTO #final_readmit_DEN_levels FROM #readmit_DEN_levels
UNION ALL
SELECT VISN,Facility,FYQ,Readmit_DEN,Readmit_DEN_AMA FROM #readmit_DEN_levels_ytd
;

--Roll up Readmission NUMERATOR to binary (1/0) if any readmission per person
------------------------------------------------------------------------------

--30-Day Readmission Numerator BY FACILITY AND FYQ
DROP TABLE IF EXISTS #readmit_NUM_facility;
SELECT	VISN
	,ChecklistID
	,FYQ
	,Readmit_NUM = COUNT(DISTINCT InpatientEncounterSID)
INTO #readmit_NUM_facility
FROM #Readmit_NUM
GROUP BY VISN, ChecklistID, FYQ
;

--30-Day Readmission Numerator BY FACILITY YTD
DROP TABLE IF EXISTS #readmit_NUM_facility_ytd;
SELECT	VISN
	,ChecklistID
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,Readmit_NUM = COUNT(DISTINCT InpatientEncounterSID)
INTO #readmit_NUM_facility_ytd
FROM #Readmit_NUM
GROUP BY VISN, ChecklistID
;

--30-Day Readmission Denominator BY VISN AND FYQ
DROP TABLE IF EXISTS #readmit_NUM_visn;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ 
	,Readmit_NUM = COUNT(DISTINCT InpatientEncounterSID)
INTO #readmit_NUM_visn
FROM #Readmit_NUM
GROUP BY VISN, FYQ
;

--30-Day Readmission Denominator BY VISN YTD
DROP TABLE IF EXISTS #readmit_NUM_visn_ytd;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,Readmit_NUM = COUNT(DISTINCT InpatientEncounterSID)
INTO #readmit_NUM_visn_ytd
FROM #Readmit_NUM
GROUP BY VISN
;

--30-Day Readmission Denominator NATIONAL AND FYQ
DROP TABLE IF EXISTS #readmit_NUM_nat;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ
	,Readmit_NUM = COUNT(DISTINCT InpatientEncounterSID)
INTO #readmit_NUM_nat
FROM #Readmit_NUM
GROUP BY FYQ
;

--30-Day Readmission Denominator NATIONAL 
DROP TABLE IF EXISTS #readmit_NUM_nat_ytd;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,Readmit_NUM = COUNT(DISTINCT InpatientEncounterSID)
INTO #readmit_NUM_nat_ytd
FROM #Readmit_NUM
;

--Combine all levels of 30-Day Readmission Numerator FYQ
DROP TABLE IF EXISTS #readmit_NUM_levels;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Readmit_NUM INTO #readmit_NUM_levels FROM #readmit_NUM_facility
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Readmit_NUM FROM #readmit_NUM_VISN
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Readmit_NUM FROM #readmit_NUM_nat
;

--Combine all levels of 30-Day Readmission Numerator YTD
DROP TABLE IF EXISTS #readmit_NUM_levels_ytd;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Readmit_NUM INTO #readmit_NUM_levels_ytd FROM #readmit_NUM_facility_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Readmit_NUM FROM #readmit_NUM_VISN_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,Readmit_NUM FROM #readmit_NUM_nat_ytd
;

-- Combine all levels of 30-Day Readmission Numerator
DROP TABLE IF EXISTS #final_readmit_NUM_levels;
SELECT VISN,Facility,FYQ,Readmit_NUM INTO #final_readmit_NUM_levels FROM #readmit_NUM_levels
UNION ALL
SELECT VISN,Facility,FYQ,Readmit_NUM FROM #readmit_NUM_levels_ytd
;

DROP TABLE IF EXISTS #readmit_final_levels;
SELECT a.VISN
	,a.Facility
	,a.FYQ
	,Readmit_NUM
	,Readmit_DEN
	,Readmit_DEN_AMA 
	,Readmit_rate =  CASE WHEN Readmit_DEN=0 THEN 0 ELSE CAST((ISNULL(CAST(Readmit_NUM AS FLOAT)/CAST(Readmit_DEN AS FLOAT),0)*100) AS DECIMAL(10,2)) END
	,Readmit_rate_AMA =  CASE WHEN Readmit_DEN_AMA=0 THEN 0 ELSE CAST((ISNULL(CAST(Readmit_NUM AS FLOAT)/CAST(Readmit_DEN_AMA AS FLOAT),0)*100) AS DECIMAL(10,2)) END
INTO #readmit_final_levels
FROM #final_readmit_DEN_levels as a
INNER JOIN #final_readmit_NUM_levels as b ON a.Facility = b.Facility AND a.FYQ = b.FYQ
;

 /*-----------------------------
Step 10:	  LENGTH OF STAY (LOS)   
-----------------------------*/

--STEP 10a: Calculate LOS (admit day-discharge day to the hour)
---------------------------------------------------------------
DROP TABLE IF EXISTS #los_hour;
SELECT MVIPersonSID
	  ,InpatientEncounterSID
	  ,AdmitDateTime
	  ,DischargeDateTime
	  ,LOS_hours = DATEDIFF(HOUR,AdmitDateTime,DischargeDateTime)
	  ,ChecklistID
	  ,VISN
	  ,FYQ
	  ,RollingFYQ
INTO #los_hour
FROM #AWstays
WHERE CAST(AdmitDateTime AS DATE) <> CAST(DischargeDateTime AS DATE)
;

--STEP 10B: Roll-up LOS by Facility
-----------------------------------------
--roll up to day (2 decimals)
DROP TABLE IF EXISTS #los;
SELECT MVIPersonSID
	  ,InpatientEncounterSID
	  ,AdmitDateTime
	  ,DischargeDateTime
	  ,'LOS' = CAST(CAST(LOS_hours AS FLOAT)/24 AS DECIMAL (10,2))
	  ,ChecklistID
	  ,VISN
	  ,FYQ
	  ,RollingFYQ
INTO #los
FROM #los_hour
;

--Average LOS of AW stay BY FACILITY AND FYQ
DROP TABLE IF EXISTS #los_facility;
SELECT	VISN
	,ChecklistID
	,FYQ
	,AverageLOS = AVG(LOS)
INTO #los_facility
FROM #los
GROUP BY VISN, ChecklistID, FYQ
;

--Average LOS of AW stay BY FACILITY YTD
DROP TABLE IF EXISTS #los_facility_ytd;
SELECT	VISN
	,ChecklistID
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,AverageLOS = AVG(LOS)
INTO #los_facility_ytd
FROM #los
GROUP BY VISN, ChecklistID
;

--Average LOS of AW stay BY VISN AND FYQ
DROP TABLE IF EXISTS #los_visn;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ
	,AverageLOS = AVG(LOS)
INTO #los_visn
FROM #los
GROUP BY VISN, FYQ
;

--Average LOS of AW stay BY VISN YTD
DROP TABLE IF EXISTS #los_visn_ytd;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,AverageLOS = AVG(LOS)
INTO #los_visn_ytd
FROM #los
GROUP BY VISN
;

--Average LOS of AW stay NATIONAL  AND FYQ
DROP TABLE IF EXISTS #los_nat;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ
	,AverageLOS = AVG(LOS)
INTO #los_nat
FROM #los
GROUP BY FYQ
;

--Average LOS of AW stay NATIONAL YTD
DROP TABLE IF EXISTS #los_nat_ytd;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,AverageLOS = AVG(LOS)
INTO #los_nat_ytd
FROM #los
;

--Combine all levels of AW INPATIENT STAY LOS FYQ
DROP TABLE IF EXISTS #los_levels;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AverageLOS=CAST(ISNULL(AverageLOS,0) as DECIMAL(10,2)) INTO #los_levels FROM #los_facility
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AverageLOS=CAST(ISNULL(AverageLOS,0) as DECIMAL(10,2)) FROM #los_VISN
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AverageLOS=CAST(ISNULL(AverageLOS,0) as DECIMAL(10,2)) FROM #los_nat
;

--Combine all levels of AW INPATIENT STAY LOS YTD
DROP TABLE IF EXISTS #los_levels_ytd;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AverageLOS=CAST(ISNULL(AverageLOS,0) as DECIMAL(10,2)) INTO #los_levels_ytd FROM #los_facility_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AverageLOS=CAST(ISNULL(AverageLOS,0) as DECIMAL(10,2)) FROM #los_VISN_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,AverageLOS=CAST(ISNULL(AverageLOS,0) as DECIMAL(10,2)) FROM #los_nat_ytd
;

-- Combine all levels of AW INPATIENT STAY LOS 
DROP TABLE IF EXISTS #final_los_levels;
SELECT VISN,Facility,FYQ,AverageLOS INTO #final_los_levels FROM #los_levels
UNION ALL
SELECT VISN,Facility,FYQ,AverageLOS FROM #los_levels_ytd
;

/*-----------------------------
--	STEP 11: ICU Admission or Transfer during AW inpatient stay
-----------------------------*/

--STEP 11A: Find AW stays with ICU bedsection
------------------------------------------------
--Find all unique AW Stays with ICU bedsection
DROP TABLE IF EXISTS #ICUstays;
SELECT DISTINCT InpatientEncounterSID, FYQ, RollingFYQ
INTO #ICUstays
FROM #inp1_aud
WHERE ICU=1
;

--Get all bedsections for AW stays with ICU and order bedsections chronologically
DROP TABLE IF EXISTS #AllICU;
SELECT DISTINCT i.MVIPersonSID
	  ,i.InpatientEncounterSID
	  ,AdmitDate = CAST(i.AdmitDateTime AS DATE)
	  ,DischargeDate = CAST(i.DischargeDateTime AS DATE)
	  ,i.BsInDateTime
	  ,i.BsOutDateTime
	  ,StayNumber = row_number() OVER(PARTITION BY i.MVIPersonSID, I.InpatientEncounterSID ORDER BY i.BsOutDateTime)
	  ,ICU = CASE WHEN i.Bedsection='12' THEN 1 ELSE 0 END
	  ,i.ChecklistID
	  ,ch.VISN
	  ,c.FYQ
	  ,c.RollingFYQ
INTO #AllICU
FROM [Inpatient].[BedSection] as i WITH (NOLOCK)
INNER JOIN #ICUstays as c
ON i.InpatientEncounterSID = c.InpatientEncounterSID
LEFT JOIN [LookUp].[ChecklistID] ch WITH (NOLOCK)
ON i.ChecklistID = ch.ChecklistID
;

--Step 11B: ICU Admission (ICU is first or only bedsection in AW stay)
----------------------------------------------------------------------
DROP TABLE IF EXISTS #ICUadmit;
SELECT DISTINCT MVIPersonSID
	,InpatientEncounterSID
	,ChecklistID
	,VISN
	,FYQ
	,RollingFYQ
INTO #ICUadmit
FROM #AllICU 
WHERE StayNumber=1 and ICU=1
;

--STEP 11C: Roll-up ICU Admissions to Facility
--------------------------------------------

--ICU admission BY FACILITY AND FYQ
DROP TABLE IF EXISTS #ICUadmit_facility;
SELECT	VISN
	,ChecklistID
	,FYQ
	,ICU_Admit = COUNT(DISTINCT InpatientEncounterSID)
INTO #ICUadmit_facility
FROM #ICUadmit
GROUP BY VISN, ChecklistID, FYQ
;

--ICU admission BY FACILITY YTD
DROP TABLE IF EXISTS #ICUadmit_facility_ytd;
SELECT	VISN
	,ChecklistID
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,ICU_Admit = COUNT(DISTINCT InpatientEncounterSID)
INTO #ICUadmit_facility_ytd
FROM #ICUadmit
GROUP BY VISN, ChecklistID
;


--ICU admission BY VISN AND FYQ
DROP TABLE IF EXISTS #ICUadmit_visn;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ
	,ICU_Admit = COUNT(DISTINCT InpatientEncounterSID)
INTO #ICUadmit_visn
FROM #ICUadmit
GROUP BY VISN, FYQ
;

--ICU admission BY VISN YTD
DROP TABLE IF EXISTS #ICUadmit_visn_ytd;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,ICU_Admit = COUNT(DISTINCT InpatientEncounterSID)
INTO #ICUadmit_visn_ytd
FROM #ICUadmit
GROUP BY VISN
;

--ICU admission NATIONAL AND FYQ
DROP TABLE IF EXISTS #ICUadmit_nat;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ
	,ICU_Admit = COUNT(DISTINCT InpatientEncounterSID)
INTO #ICUadmit_nat
FROM #ICUadmit
GROUP BY FYQ
;

--ICU admission NATIONAL YTD
DROP TABLE IF EXISTS #ICUadmit_nat_YTD;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,ICU_Admit = COUNT(DISTINCT InpatientEncounterSID)
INTO #ICUadmit_nat_ytd
FROM #ICUadmit
;

--Combine all levels of ICU admission FYQ
DROP TABLE IF EXISTS #ICUadmit_levels;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,ICU_Admit INTO #ICUadmit_levels FROM #ICUadmit_facility
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,ICU_Admit FROM #ICUadmit_VISN
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,ICU_Admit FROM #ICUadmit_nat
;

--Combine all levels of ICU admission YTD
DROP TABLE IF EXISTS #ICUadmit_levels_ytd;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,ICU_Admit INTO #ICUadmit_levels_ytd FROM #ICUadmit_facility_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,ICU_Admit FROM #ICUadmit_VISN_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,ICU_Admit FROM #ICUadmit_nat_ytd
;

-- Combine all levels of ICU admission
DROP TABLE IF EXISTS #final_ICUadmit_levels;
SELECT VISN,Facility,FYQ,ICU_Admit INTO #final_ICUadmit_levels FROM #ICUadmit_levels
UNION ALL
SELECT VISN,Facility,FYQ,ICU_Admit FROM #ICUadmit_levels_ytd
;


--STEP 11D: ICU Transfer (ICU is a subsequent bedsection in AW stay)
--------------------------------------------------------------------
DROP TABLE IF EXISTS #ICUtransfer;
SELECT DISTINCT MVIPersonSID
	,InpatientEncounterSID
	,ChecklistID
	,VISN
	,FYQ
	,RollingFYQ
INTO #ICUtransfer
FROM #AllICU
WHERE StayNumber>1 and ICU=1
;

--STEP 11E: Roll-up ICU Transfer to Facility
-------------------------------------------------------
--ICU transfer BY FACILITY AND FYQ
DROP TABLE IF EXISTS #ICUtransfer_facility;
SELECT	VISN
	,ChecklistID
	,FYQ
	,ICU_transfer = COUNT(DISTINCT InpatientEncounterSID)
INTO #ICUtransfer_facility
FROM #ICUtransfer
GROUP BY VISN, ChecklistID,FYQ
;

--ICU transfer BY FACILITY YTD
DROP TABLE IF EXISTS #ICUtransfer_facility_ytd;
SELECT	VISN
	,ChecklistID
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,ICU_transfer = COUNT(DISTINCT InpatientEncounterSID)
INTO #ICUtransfer_facility_ytd
FROM #ICUtransfer
GROUP BY VISN, ChecklistID
;

--ICU admission BY VISN AND FYQ
DROP TABLE IF EXISTS #ICUtransfer_visn;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ
	,ICU_transfer = COUNT(DISTINCT InpatientEncounterSID)
INTO #ICUtransfer_visn
FROM #ICUtransfer
GROUP BY VISN, FYQ
;

--ICU admission BY VISN YTD 
DROP TABLE IF EXISTS #ICUtransfer_visn_ytd;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,ICU_transfer = COUNT(DISTINCT InpatientEncounterSID)
INTO #ICUtransfer_visn_ytd
FROM #ICUtransfer
GROUP BY VISN
;

--ICU admission NATIONAL AND FYQ
DROP TABLE IF EXISTS #ICUtransfer_nat;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ
	,ICU_transfer = COUNT(DISTINCT InpatientEncounterSID)
INTO #ICUtransfer_nat
FROM #ICUtransfer
GROUP BY FYQ
;

--ICU admission NATIONAL YTD
DROP TABLE IF EXISTS #ICUtransfer_nat_ytd;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,ICU_transfer = COUNT(DISTINCT InpatientEncounterSID)
INTO #ICUtransfer_nat_ytd
FROM #ICUtransfer
;


--Combine all levels of ICU transfer FYQ
DROP TABLE IF EXISTS #ICUtransfer_levels;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,ICU_transfer INTO #ICUtransfer_levels FROM #ICUtransfer_facility
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,ICU_transfer FROM #ICUtransfer_VISN
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,ICU_transfer FROM #ICUtransfer_nat
;

--Combine all levels of ICU transfer YTD
DROP TABLE IF EXISTS #ICUtransfer_levels_ytd;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,ICU_transfer INTO #ICUtransfer_levels_ytd FROM #ICUtransfer_facility_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,ICU_transfer FROM #ICUtransfer_VISN_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,ICU_transfer FROM #ICUtransfer_nat_ytd
;

-- Combine all levels of ICU transfer
DROP TABLE IF EXISTS #final_ICUtransfer_levels;
SELECT VISN,Facility,FYQ,ICU_transfer INTO #final_ICUtransfer_levels FROM #ICUtransfer_levels
UNION ALL
SELECT VISN,Facility,FYQ,ICU_transfer FROM #ICUtransfer_levels_ytd
;

--Combine all levels of ICU and calcuate percent
DROP TABLE IF EXISTS #ICU_final_levels;
SELECT inp.VISN
	,inp.Facility
	,inp.FYQ
	,ICUadmissions = MAX(ISNULL(a.ICU_Admit,0))
	,ICUadmissions_percent = MAX(CAST((ISNULL(CAST(a.ICU_Admit AS FLOAT)/CAST(inp.AWdischarges AS FLOAT),0)*100) AS DECIMAL(10,2)))
	,ICUtransfer = MAX(ISNULL(t.ICU_transfer,0))
	,ICUtransfer_percent = MAX(CAST((ISNULL(CAST(t.ICU_transfer AS FLOAT)/CAST(inp.AWdischarges AS FLOAT),0)*100) AS DECIMAL(10,2)))
INTO #ICU_final_levels
FROM #final_ICUadmit_levels as a
INNER JOIN #final_ICUtransfer_levels as t ON a.Facility = t.Facility and a.FYQ = t.FYQ
INNER JOIN #all_levels as inp
ON (a.Facility = inp.Facility and a.FYQ = inp.FYQ) OR (t.Facility = inp.Facility and t.FYQ = inp.FYQ)
GROUP by inp.VISN, inp.facility, inp.FYQ
;

/***************************************************************************************************************************************************
--Step 12: SUD RRTP: Percentage of AW discharges that were followed by admission to a SUD RRTP Bedsection within 7 days after discharge
****************************************************************************************************************************************************/

--Find SUD RRTP stays for AW Inpatients
  DROP TABLE IF EXISTS #RRTP;
  SELECT aw.MVIPersonSID
		,aw_InpatientEncounterSID = aw.InpatientEncounterSID
		,aw_DischargeDateTime = aw.DischargeDateTime
		,rrtp_InpatientEncounterSID = i.InpatientEncounterSID
		,rrtp_AdmitDateTime = i.AdmitDateTime
		--,DaysBetween = DATEDIFF(day,aw.DischargeDateTime,i.AdmitDateTime)	--for debugging
		,OneWeek = CASE WHEN DATEDIFF(day,aw.DischargeDateTime,i.AdmitDateTime)>=0 AND DATEDIFF(day,aw.DischargeDateTime,i.AdmitDateTime)<8 THEN 1 ELSE 0 END
		,i.BedSection
  INTO #RRTP
  FROM [Inpatient].[BedSection] as i WITH (NOLOCK)
  INNER JOIN (SELECT DISTINCT MVIPersonSID, InpatientEncounterSID, DischargeDateTime FROM #AWstays) as aw
  ON i.MVIPersonSID = aw.MVIPersonSID
  WHERE i.BedSection in('1M',	--SUBSTANCE ABUSE RESID PROG
						'27',	--SUBSTANCE ABUSE RES TRMT PROG
						'86')	--DOMICILIARY SUBSTANCE ABUSE
;

  DROP TABLE IF EXISTS #FinalRRTP7;
  SELECT DISTINCT aw.MVIPersonSID
		,aw.DischargeDateTime AS AWDischargeDateTime
		,InpatientEncounterSID = r.aw_InpatientEncounterSID
		,aw.ChecklistID
		,aw.VISN
		,aw.FYQ
		,aw.RollingFYQ
  INTO #FinalRRTP7
  FROM #RRTP as r
  LEFT JOIN #AWstays as aw
  on r.aw_InpatientEncounterSID = aw.InpatientEncounterSID
  WHERE OneWeek=1
;

--SUD RRTP Admission within 7 days of an AW discharge BY FACILITY AND FYQ
DROP TABLE IF EXISTS #RRTP7_facility;
SELECT	VISN
	,ChecklistID
	,FYQ
	,RRTP7 = COUNT(DISTINCT InpatientEncounterSID)
INTO #RRTP7_facility
FROM #FinalRRTP7
GROUP BY VISN, ChecklistID,FYQ
;

--SUD RRTP Admission within 7 days of an AW discharge BY FACILITY YTD
DROP TABLE IF EXISTS #RRTP7_facility_ytd;
SELECT	VISN
	,ChecklistID
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,RRTP7 = COUNT(DISTINCT InpatientEncounterSID)
INTO #RRTP7_facility_ytd
FROM #FinalRRTP7
GROUP BY VISN, ChecklistID
;

--SUD RRTP Admission within 7 days of an AW discharge BY VISN AND FYQ
DROP TABLE IF EXISTS #RRTP7_visn;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ
	,RRTP7 = COUNT(DISTINCT InpatientEncounterSID)
INTO #RRTP7_visn
FROM #FinalRRTP7
GROUP BY VISN, FYQ
;

--SUD RRTP Admission within 7 days of an AW discharge BY VISN YTD
DROP TABLE IF EXISTS #RRTP7_visn_ytd;
SELECT	VISN
	,ChecklistID = VISN
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,RRTP7 = COUNT(DISTINCT InpatientEncounterSID)
INTO #RRTP7_visn_ytd
FROM #FinalRRTP7
GROUP BY VISN
;
--SUD RRTP Admission within 7 days of an AW discharge NATIONAL AND FYQ
DROP TABLE IF EXISTS #RRTP7_nat;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ
	,RRTP7 = COUNT(DISTINCT InpatientEncounterSID)
INTO #RRTP7_nat
FROM  #FinalRRTP7
GROUP BY FYQ
;

--SUD RRTP Admission within 7 days of an AW discharge NATIONAL YTD
DROP TABLE IF EXISTS #RRTP7_nat_ytd;
SELECT DISTINCT  
     VISN = 0
	,ChecklistID = 0
	,FYQ = CONCAT('YTD',MAX(RollingFYQ))
	,RRTP7 = COUNT(DISTINCT InpatientEncounterSID)
INTO #RRTP7_nat_ytd
FROM  #FinalRRTP7
;

--Combine all levels of SUD RRTP admission within 7 days of AW discharge FYQ
DROP TABLE IF EXISTS #RRTP7_levels;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,RRTP7 INTO #RRTP7_levels FROM #RRTP7_facility
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,RRTP7 FROM #RRTP7_VISN
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,RRTP7 FROM #RRTP7_nat
;

--Combine all levels of SUD RRTP admission within 7 days of AW discharge YTD
DROP TABLE IF EXISTS #RRTP7_levels_ytd;
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,RRTP7 INTO #RRTP7_levels_ytd FROM #RRTP7_facility_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,RRTP7 FROM #RRTP7_VISN_ytd
UNION ALL
SELECT VISN,Facility=CAST(ChecklistID as varchar),FYQ,RRTP7 FROM #RRTP7_nat_ytd
;

--Combine all levels of SUD RRTP admission within 7 days of AW discharge 
DROP TABLE IF EXISTS #final_RRTP7_levels;
SELECT VISN,Facility,FYQ,RRTP7 INTO #final_RRTP7_levels FROM #RRTP7_levels
UNION ALL
SELECT VISN,Facility,FYQ,RRTP7 FROM #RRTP7_levels_ytd
;

/*-------------------------------------------------------------
	COMBINE DIFFERENT METRICS BY FACILITY, VISN, NATIONAL LEVELS
---------------------------------------------------------------*/

-- *** Pull in any facilities with no data and asign them a zero (otherwise those facilities would drop off from the list entirely) ***

--All possible combinations of Facility/VISN/National and Latest FYQ/YTD
DROP TABLE IF EXISTS #all_fac;
SELECT DISTINCT l.VISN
	,Facility = l.ChecklistID
	,FacilityName = l.AdmParent_FCDM
	,l.IOCDate
	,a.FYQ
	,Complexity = c.MCGKey
	,MCGName = CASE WHEN c.MCGName IS NULL THEN 'N/A' ELSE c.MCGName END
INTO #all_fac
FROM [LookUp].[ChecklistID] AS l WITH (NOLOCK)
CROSS JOIN (SELECT FYQ,FYID FROM #TIMEFRAME UNION SELECT FYQ=CONCAT('YTD',FYQ),FYID FROM #TIMEFRAME) AS A
LEFT JOIN (SELECT * FROM [PDW].[SHRED_dbo_DimSHREDFacility] WITH (NOLOCK) WHERE (FacilityLevelID IN('1','2') OR (FacilityLevelID=3 AND MCGKey <> '99'))
			) as c ON l.ADMPARENT_FCDM = c.ADMPARENT_FCDM AND c.FYID=a.FYID
;

--Combine all facilities with summary data
DROP TABLE IF EXISTS #final_inpatient;
SELECT DISTINCT f.VISN
	,f.Facility
	,f.FacilityName
	,f.IOCDate
	,f.Complexity
	,f.MCGName
	,f.FYQ

	--Inpatient data (for comparison)
	,Inpatients = ISNULL(inp.Inpatients,0)
	,InpDischarges = ISNULL(inp.InpDischarges,0)

	--Inpatient stays with AW Dx
	,AWinpatients = ISNULL(inp.AWinpatients,0)
	,AWdischarges = ISNULL(inp.AWdischarges,0)
	,AWdischarges_percent = ISNULL(inp.AWdischarges_percent,0)
	,AverageLOS = ISNULL(los.AverageLOS,0)					--Length of Stay (LOS)
	,InpatientDeaths = ISNULL(inp.InpatientDeaths,0)

	--AMA discharges
	,AMAdischarges = ISNULL(inp.AMAdischarges,0)
	,AMADisch_percent = ISNULL(inp.AMADisch_percent,0)
	
	--30-day Readmission Rate
	,Readmissions = ISNULL(r.Readmit_NUM,0)
	,Readmission_Denominator = ISNULL(r.Readmit_DEN,0)
	,Readmission_Denominator_AMA = ISNULL(r.Readmit_DEN_AMA,0)
	,ReadmissionRate = ISNULL(r.Readmit_rate,0)
	,ReadmissionRate_AMA = ISNULL(r.Readmit_rate_AMA,0)

	--AW stays with Delirium Dx
	,Delirium = ISNULL(deli.Delirium,0)
	,Delirium_percent = CAST((ISNULL(CAST(deli.Delirium AS FLOAT)/CAST(inp.AWdischarges AS FLOAT),0)*100) AS DECIMAL(10,2))

	--AW stays with Seizure Dx
	,Seizure = ISNULL(s.Seizure,0)
	,Seizure_percent = CAST((ISNULL(CAST(s.Seizure AS FLOAT)/CAST(inp.AWdischarges AS FLOAT),0)*100) AS DECIMAL(10,2))

	--AUDIT-C completed withn 1 day of admission
	,AUDITC = ISNULL(a.AUDITC,0)
	,AUDITC_percent = CAST((ISNULL(CAST(a.AUDITC AS FLOAT)/CAST(inp.AWdischarges AS FLOAT),0)*100) AS DECIMAL(10,2))

	--Outpatient AUD RX at time of discharge
	,AUD_RX = ISNULL(aud.AUD_RX,0)
	,AUDrx_percent = CAST((ISNULL(CAST(aud.AUD_RX AS FLOAT)/CAST(inp.AWdischarges AS FLOAT),0)*100) AS DECIMAL(10,2))

	--Inpatient RX Administered During AW Stay
	,Clonidine = ISNULL(rx.Clonidine ,0)
	,Clonidine_percent = CAST((ISNULL(CAST(rx.Clonidine AS FLOAT)/CAST(inp.AWdischarges AS FLOAT),0)*100) AS DECIMAL(10,2))
	,Chlordiazepoxide = ISNULL(rx.Chlordiazepoxide,0)
	,Chlordiazepoxide_percent = CAST((ISNULL(CAST(rx.Chlordiazepoxide AS FLOAT)/CAST(inp.AWdischarges AS FLOAT),0)*100) AS DECIMAL(10,2))
	,Diazepam = ISNULL(rx.Diazepam,0)
	,Diazepam_percent = CAST((ISNULL(CAST(rx.Diazepam AS FLOAT)/CAST(inp.AWdischarges AS FLOAT),0)*100) AS DECIMAL(10,2))
	,Gabapentin = ISNULL(rx.Gabapentin ,0)
	,Gabapentin_percent = CAST((ISNULL(CAST(rx.Gabapentin AS FLOAT)/CAST(inp.AWdischarges AS FLOAT),0)*100) AS DECIMAL(10,2))
	,Lorazepam = ISNULL(rx.Lorazepam,0)
	,Lorazepam_percent = CAST((ISNULL(CAST(rx.Lorazepam AS FLOAT)/CAST(inp.AWdischarges AS FLOAT),0)*100) AS DECIMAL(10,2))
	,Phenobarbital = ISNULL(rx.Phenobarbital,0)
	,Phenobarbital_percent = CAST((ISNULL(CAST(rx.Phenobarbital AS FLOAT)/CAST(inp.AWdischarges AS FLOAT),0)*100) AS DECIMAL(10,2))

	--ICU Admission or Transfer during AW stay
	,ICUadmissions = ISNULL(icu.ICUadmissions, 0)
	,ICUadmissions_percent = ISNULL(icu.ICUadmissions_percent,0)
	,ICUtransfer = ISNULL(icu.ICUtransfer,0)
	,ICUtransfer_percent = ISNULL(ICUtransfer_percent,0)

	--admission to  SUD RRTP Bedsection within 7 days of discharge
	,SUD_RRTP7 = ISNULL(rr7.RRTP7,0)
	,SUD_RRTP7_percent = CAST((ISNULL(CAST(rr7.rrtp7 AS FLOAT)/CAST(inp.AWdischarges AS FLOAT),0)*100) AS DECIMAL(10,2))

INTO #final_inpatient
FROM #all_fac as f
LEFT JOIN #all_levels as inp
ON f.Facility = inp.Facility AND f.FYQ = inp.FYQ
LEFT JOIN #final_deli_levels as deli
ON f.Facility = deli.Facility AND f.FYQ = deli.FYQ
LEFT JOIN #final_seiz_levels as s
ON f.Facility = s.Facility AND f.FYQ = s.FYQ
LEFT JOIN #final_audc_levels as a
ON f.Facility = a.Facility AND f.FYQ = a.FYQ
LEFT JOIN #readmit_final_levels as r
ON f.Facility = r.Facility AND f.FYQ = r.FYQ
LEFT JOIN #final_los_levels as los
ON f.Facility = los.Facility AND f.FYQ = los.FYQ
LEFT JOIN #final_InptRX_levels as rx
ON f.Facility = rx.Facility AND f.FYQ = rx.FYQ
LEFT JOIN #final_AUDRX_levels as aud
ON f.Facility = aud.Facility AND f.FYQ = aud.FYQ
LEFT JOIN #ICU_final_levels as icu
ON f.Facility = icu.Facility AND f.FYQ = icu.FYQ
LEFT JOIN #final_RRTP7_levels as rr7
ON f.Facility = rr7.Facility AND f.FYQ = rr7.FYQ

DECLARE @RowCount INT = (SELECT COUNT(*) FROM #final_inpatient)
	IF @RowCount > 0
	BEGIN 

			DELETE FROM [SUD].[AW_Inpatient_Metrics]
			WHERE [FYQ] = (SELECT FYQ from #Timeframe) OR [FYQ] = (SELECT CONCAT('YTD',FYQ) FROM #Timeframe)

			INSERT INTO [SUD].[AW_Inpatient_Metrics]
			SELECT VISN
				,Facility
				,FacilityName
				,IOCDate
				,Complexity
				,MCGName
				,FYQ
				,Inpatients
				,InpDischarges
				,AWinpatients
				,AWdischarges
				,AWdischarges_percent
				,AverageLOS
				,InpatientDeaths
				,AMAdischarges
				,AMADisch_percent
				,Readmissions
				,Readmission_Denominator
				,Readmission_Denominator_AMA 
				,ReadmissionRate 
				,ReadmissionRate_AMA
				,Delirium
				,Delirium_percent
				,Seizure
				,Seizure_percent
				,AUDITC
				,AUDITC_percent
				,AUD_RX
				,AUDrx_percent
				,Clonidine 
				,Clonidine_percent
				,Chlordiazepoxide
				,Chlordiazepoxide_percent
				,Diazepam
				,Diazepam_percent
				,Gabapentin
				,Gabapentin_percent
				,Lorazepam 
				,Lorazepam_percent
				,Phenobarbital
				,Phenobarbital_percent
				,ICUadmissions
				,ICUadmissions_percent
				,ICUtransfer
				,ICUtransfer_percent
				,SUD_RRTP7
				,SUD_RRTP7_percent	
			FROM #final_inpatient
;

EXEC [Log].[PublishTable] 'SUD','AW_Inpatient_Metrics','#final_inpatient','Append',@RowCount

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END