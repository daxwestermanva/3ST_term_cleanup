
-- =============================================
-- Author:		Liam Mina
-- Create date: 03.08.2019
-- Description:	Pulls together information from SPAN tables
-- MODIFICATIONS
	--2019-04-17	RAS	Added MVIPersonSID. Changed cohort join to use MasterPatient instead of CDW SPatient
	--2019-07-23    LM removed references to SPAN 'History' tables after learning from the SPAN content experts that these tables should not be included because the duplicate other tables
	--2019-08-09	LM modified methods to align with SBOR methods
	--2019-12-02	LM merged records for Bath (528A6) and Canandaigua (528A5)
	--2020-06-03	LM Fixed issue with multiple matches on PatientSSN
	--2020-09-09	LM Added Sta3n
	--2021-05-18    JEB Enclave work - updated [SStaff].[SStaff] Synonym use. No logic changes made.
	--2021-07-21	AI  Enclave Refactoring - Counts confirmed
	--2021-11-29	LM	Corrected errors in Sta6aID mapping between SPAN and CDS lookup tables
	--2022-02-08	LM	Added VAProperty field
	--2022-07-08	JEB Updated Synonym references to point to Synonyms from Core
	--					Note: No logging present
	--2023-08-08	LM	Use network username to get checklistID when it is null
	--2024-06-12	LM	Use SVeteran to get SSN matches instead of SPatient
-- =============================================
CREATE   PROCEDURE [Code].[Present_SPAN] 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--Step 1: Pull and union relevant fields from SPAN event history tables
DROP TABLE IF EXISTS #SPANEventLog
SELECT [Comments]
      ,CAST([DtEntered] AS DATE) AS DtEntered
      ,[EnteredBy]
      ,[EventID]
	  ,CAST([EventDate] AS date) AS EventDate
      ,[EventType]
      ,[MethodUsedOther]
      ,[OutCome]
      ,[OutcomeOther]
	  ,[OccuredOnVAProperty] AS VAProperty
      ,[PatientID]
      ,[PrimaryVAMC]
      ,[SdvSubClassification]
INTO #SPANEventLog
FROM [PDW].[SpanExport_tbl_SPANEventLog] WITH (NOLOCK)
WHERE enteredinerror = 0 

--cleaning up the SDVsubclassification variable that had some duplicates/misspelling and creating a new variable called SDVClassification to clean up certain cases with a 'null' sdvsubclassification 
DROP TABLE IF EXISTS #SPANEventLogCleaned
SELECT [Comments]
      ,[DtEntered]
      ,[EnteredBy]
      ,[EventID]
	  ,[EventDate]
      ,[EventType]
      ,[MethodUsedOther]
      ,[OutCome]
      ,[OutcomeOther]
	  ,[VAProperty]
      ,[PatientID]
      ,[PrimaryVAMC]
	  ,SdvSubClassification
      ,CASE WHEN [SdvSubClassification] IN ('Suicide','Suicide with wife','Suicide- double suicide with wife') THEN 'Suicide'
			WHEN [EventType] = 'Attempt' AND [Outcome] = 'Death' THEN 'Suicide'
			WHEN [SdvSubClassification] like 'Suicide%' AND Outcome = 'Death' THEN 'Suicide'
			WHEN [Outcome] = 'Death' AND (Comments LIKE '%died by suicide%' OR Comments LIKE '%died of suicide%' OR Comments LIKE '%committed suicide%' OR Comments LIKE '%completed suicide%' OR Comments LIKE '%suicide completion%' 
				OR Comments = 'suicide' OR Comments LIKE '%murder%suicide%' OR Comments LIKE '%death by suicide%' OR Comments LIKE '%confirmed suicide%' OR Comments LIKE '%suicidal sdv: suicide%') THEN 'Suicide'
			WHEN [SdvSubClassification] = 'Undetermined SDV, Fatal' THEN 'Undetermined Self-Directed Violence, Fatal'
			WHEN [SdvSubClassification] = 'Non-Suicidal SDV, Fatal' THEN 'Non-Suicidal Self-Directed Violence, Fatal'
			WHEN [Outcome] = 'Death' THEN 'Undetermined Self-Directed Violence, Fatal'
			WHEN [SdvSubClassification] LIKE 'Suicide attempt%with injury%interrupted%' THEN 'Suicide Attempt, With Injury, Interrupted by Self or Other'
			WHEN [SdvSubClassification] LIKE 'Suicide Attempt%with Injury' THEN 'Suicide Attempt, With Injury'
			WHEN [SdvSubClassification] LIKE 'Suicide attempt%without injury%interrupted%' OR [SdvSubClassification] IN ('Suicide attempt without injury, interupted by self','Suicide attempt w/o injury interrupted by other','unharmed suicide attempt interrupted by another person') THEN 'Suicide Attempt, Without Injury, Interrupted by Self or Other'
			WHEN [SdvSubClassification] IN  ('suicide attempt w/o injury','Suicide attempt without injury','Suicide attempt, no injury','Suicide Attempt, Without Injury','self reported suicide attempt no injury') THEN 'Suicide Attempt, Without Injury'
			WHEN [SdvSubClassification] IN ('Self Directed Violence, Prepatory','suicidal self directed violence, preparatory','Suicidal SDV, Preparatory') THEN 'Suicidal Self-Directed Violence, Preparatory'
			WHEN [SdvSubClassification] LIKE 'Undetermined SDV, With Injury, Interrupted%' THEN 'Undetermined Self-Directed Violence, With Injury, Interrupted by Self or Other'
			WHEN [SdvSubClassification] IN ('Undetermined SDV, With Injury','SDV with injury','self-directed violence with injury not fatal') THEN 'Undetermined Self-Directed Violence, With Injury'
			WHEN [SdvSubClassification] LIKE 'Undetermined SDV, Without Injury, Interrupted%' THEN 'Undetermined Self-Directed Violence, Without Injury, Interrupted by Self or Other'
			WHEN [SdvSubClassification] IN ('Undetermined SDV, Without Injury','SDV without injury','Undetermined Self Directed Violence without injury') THEN 'Undetermined Self-Directed Violence, Without Injury' 
			WHEN [SdvSubClassification] IN ('Undetermined SDV, Preparatory','Prepatory SDV','Prepatory','Self Directed Violence, Prepatory, ') THEN 'Undetermined Self-Directed Violence, Preparatory'
			WHEN [SdvSubClassification] LIKE 'Suicidal Ideation% Without Suicidal Intent' or SdvSubClassification in ('Suicidal ideaton without suicidal intent') THEN 'Suicidal Ideation, Without Suicidal Intent'
			WHEN [SdvSubClassification] LIKE 'Suicidal Ideation% With Undetermined%Intent' OR SdvSubClassification = 'Ideation' THEN 'Suicidal Ideation, With Undetermined Suicidal Intent'
			WHEN [SdvSubClassification] LIKE '%Ideation%With%Intent%' THEN 'Suicidal Ideation, With Suicidal Intent'
			WHEN [SdvSubClassification] = 'Non-Suicidal SDV Ideation' THEN 'Non-Suicidal Self-Directed Violence Ideation'
			WHEN [SdvSubClassification] = 'Non-Suicidal SDV, Without Injury' THEN 'Non-Suicidal Self-Directed Violence, Without Injury'
			WHEN [SdvSubClassification] = 'Non-Suicidal SDV, Without Injury, Interrupted by Self/Other' THEN 'Non-Suicidal Self-Directed Violence, Without Injury, Interrupted by Self or Other'
			WHEN [SdvSubClassification] = 'Non-Suicidal SDV, Preparatory' THEN 'Non-Suicidal Self-Directed Violence, Preparatory'
			WHEN [SdvSubClassification] = 'Non-Suicidal SDV, With Injury' THEN 'Non-Suicidal Self-Directed Violence, With Injury'
			WHEN [SdvSubClassification] = 'Non-Suicidal SDV, With Injury, Interrupted by Self/Others' THEN 'Non-Suicidal Self Directed Violence, With Injury, Interrupted by Self or Other'
			WHEN [SdvSubClassification] LIKE 'Non-Suicidal SDV%' THEN 'Non-Suicidal Self-Directed Violence'
			WHEN [SdvSubClassification] = 'Insufficient evidence to suggest self-directed violence' THEN 'Insufficient evidence to suggest self-directed violence'
			ELSE 'Undetermined Self-Directed Violence' END AS SDVClassification
	  ,row_number() OVER (PARTITION BY patientid, eventid ORDER BY dtentered DESC) AS RowNum
INTO #SPANEventLogCleaned
FROM #SPANEventLog

--Step 2: Pull and union relevant fields from SPAN method tables
DROP TABLE IF EXISTS #SPANMethod
SELECT EventID
      ,PatientID
      ,CASE WHEN MethodUsed = 'With Police' THEN 'Injury by Other'
		WHEN MethodCat = 'Gun' THEN 'Firearm'
		WHEN MethodUsed = 'Carbon Monoxide' THEN 'Physical Injury'
		WHEN MethodCat = 'Auto' THEN 'Motor Vehicle'
		ELSE MethodCat END AS MethodCat
      ,CASE WHEN MethodUsed = 'Suffication' THEN 'Suffocation'
		WHEN MethodCat = 'Other' AND MethodUsed = 'Other (nos)' THEN 'Other'
		WHEN MethodUsed = 'Tylenol' THEN 'Acetaminophen/Tylenol/NSAID'
		WHEN MethodUsed = 'Heroin' THEN 'Non-Rx Opioids'
		WHEN MethodUsed = 'Lithium' THEN 'Mood Stabilizers'
		WHEN MethodUsed = 'Benzodiazepine' THEN 'Benzodiazepines'
		WHEN MethodUsed in ('Rx Meds','Pills (nos)') THEN 'Other'
		WHEN MethodCat = 'Overdose' AND MethodUsed = 'Other (nos)' THEN 'Other'
		WHEN MethodUsed = 'Explosion' THEN 'Physical Injury-Other'
		WHEN MethodUsed = 'Self-Immolation' THEN 'Burned Self'
		WHEN MethodUsed in ('Stabbed/Cut Self','Slit Wrist','Cut Neck') THEN 'Stabbed/Cut Self or Slit Wrist'
		WHEN MethodUsed = 'Gun to Body' THEN 'Firearm to Body'
		WHEN MethodUsed = 'Gun to Head' THEN 'Firearm to Head'
		WHEN MethodUsed = 'With Police' THEN 'Patient Induced Law Enforcement into Killing Him/Her'
		WHEN MethodCat = 'Gun' THEN 'Firearm (Other than to Body or Head)'
		WHEN MethodUsed in ('Run into Object', 'Run into Tree','With other Auto') THEN 'Drove Into Object'
		WHEN MethodCat = 'Auto' AND MethodUsed = 'Other (nos)' THEN 'Automobile-Other'
		ELSE MethodUsed END AS MethodUsed
      ,CASE WHEN MethodUsedOther IS NOT NULL THEN MethodUsedOther
		WHEN MethodUsed in ('Tylenol','Heroin','Lithium','Rx Meds','Pills (nos)','Explosion','Stabbed/Cut Self','Slit Wrist','Cut Neck'
			,'Gun to Body','Gun to Head','Run into Object','Run into Tree','With other Auto') THEN MethodUsed
		END AS MethodUsedOther
INTO #SPANMethod
FROM [PDW].[SpanExport_tbl_SPANClientMethodUsed] WITH (NOLOCK)

DROP TABLE IF EXISTS #SPANMethodCleaned
SELECT EventID
      ,PatientID
      ,MethodCat
      ,MethodUsed
      ,MethodUsedOther
	  ,row_number() OVER (PARTITION BY eventid ORDER BY MethodCat) AS RowNum
INTO #SPANMethodCleaned
FROM #SPANMethod

--select distinct eventid from #SPANMethodCombined1 where rownum >3
--total events as of 3.15.19: 158309
-->1: 30096 (19%)
-->2: 5272 (3.3%)
-->3: 936 (0.6%)
-->4: 185 (0.1%)

--Step 3: Join SPAN cohort table to SVeteran table to get ICNs
DROP TABLE IF EXISTS #SPANCohort
SELECT TOP 1 WITH TIES
	b.PatientICN
	,b.MVIPersonSID
	,a.SSN
	,b.PatientSSN
	,b.SSNVerificationStatus
	,a.PatientID
INTO #SPANCohort
FROM [PDW].[SpanExport_tbl_Patient] a WITH (NOLOCK)
LEFT JOIN (
	SELECT
		r.MVIPersonSID
		,r.PatientICN
		,s.PersonSSN AS PatientSSN
		,s.SSNVerificationStatus
		,s.PersonModifiedDateTime
	FROM [Common].[MasterPatient] r WITH (NOLOCK)
	INNER JOIN 	[SVeteran].[SMVIPerson] s WITH (NOLOCK)
		ON r.MVIPersonSID = s.MVIPersonSID
		) b
ON a.SSN = b.PatientSSN 
WHERE b.SSNVerificationStatus IS NULL OR b.SSNVerificationStatus NOT IN ('INVALID PER SSA','RESEND TO SSA')
ORDER BY ROW_NUMBER() OVER (PARTITION BY a.PatientID ORDER BY CASE WHEN b.SSNVerificationStatus = 'VERIFIED'	THEN 1
																		  WHEN b.SSNVerificationStatus = 'IN-PROCESS' THEN 2
																		  WHEN b.SSNVerificationStatus = 'NEW RECORD' THEN 3 
																		  WHEN b.SSNVerificationStatus IS NULL OR b.SSNVerificationStatus LIKE '*%' THEN 4 END
																	,b.PersonModifiedDateTime DESC)

--Get facility info
DROP TABLE IF EXISTS #Facility
SELECT UniqueID
	  ,Sta3n
	  ,CASE WHEN STA6AID = '663A4' THEN '663' --Seattle
			WHEN STA6AID = '619A4' THEN '619' --Central AL
			WHEN STA6AID = '610A4' THEN '610' --Northern Indiana (Marion Indiana - not to be confused with Marion Illinois HCS!)
			WHEN STA6AID = '589A0' THEN '589'  --Kansas City
			WHEN STA6AID = '573A4' THEN '573' --Gainesville
			WHEN STA6AID = '657A0' THEN '657' --St. Louis MO
			WHEN STA6AID = '630A4' THEN '630' --NY Harbor
			WHEN STA6AID = '612' THEN '612A4' --N California
			WHEN STA6AID = '528A5' THEN '528A6' --To reflect the merging of Bath & Canandaigua in FY20
			WHEN STA6AID = '596A4' THEN '596' --Lexington KY
			ELSE sta6aid END AS Sta6aID
INTO #Facility
FROM [PDW].[SpanExport_VA_VHASites] WITH (NOLOCK)

DROP TABLE IF EXISTS #CheckID
SELECT a.UniqueID
	  ,a.Sta3n
	  ,a.Sta6aID
	  ,b.ChecklistID
INTO #CheckID 
FROM #Facility A
INNER JOIN [LookUp].[ChecklistID] b WITH (NOLOCK)
ON a.Sta6aid = b.Sta6aid

--For cases where there are multiple matches on PatientSSN, find a match on Sta3n
DROP TABLE IF EXISTS #AddRows
SELECT * 
,ROW_NUMBER() over (partition by PatientID order by PatientID) as rn
INTO #AddRows
FROM #SPANCohort

DROP TABLE IF EXISTS #MatchSSNSta3n
SELECT DISTINCT
	a.*
INTO #MatchSSNSta3n
FROM #AddRows a 
INNER JOIN (SELECT * FROM #AddRows WHERE rn > 1) b 
	ON a.PatientID = b.PatientID
INNER JOIN [PDW].[SpanExport_tbl_SPANEventLog] c WITH (NOLOCK)
	ON a.PatientID = c.PatientID
INNER JOIN #Facility d 
	ON c.PrimaryVAMC = d.UniqueID
INNER JOIN (
			[SPatient].[SPatient] e WITH (NOLOCK)
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
				ON e.PatientSID = mvi.PatientPersonSID)
	ON e.Sta3n = d.Sta3n
	AND mvi.MVIPersonSID = a.MVIPersonSID

DROP TABLE IF EXISTS #SPANCohortFinal
SELECT a.PatientICN
	  ,a.MVIPersonSID
	  ,a.SSN
	  ,a.PatientSSN
	  ,a.SSNVerificationStatus
	  ,a.PatientID
INTO #SPANCohortFinal
FROM #SPANCohort a
LEFT OUTER JOIN #MatchSSNSta3n b on a.PatientSSN=b.PatientSSN
WHERE b.PatientSSN IS NULL
UNION
SELECT PatientICN
	  ,MVIPersonSID
	  ,SSN
	  ,PatientSSN
	  ,SSNVerificationStatus
	  ,PatientID
FROM #MatchSSNSta3n


--Step 4: Form final SPAN table
--Only pulling 3 method groups per event here. In a small % (appx 0.6%) of cases, there are more than 3 method groups reported
DROP TABLE IF EXISTS #SPANEventFinal
SELECT DISTINCT PatientICN
	  ,MVIPersonSID
	  ,b.PatientID AS SPANPatientID
	  ,ISNULL(f.Sta3n,s.InferredSta3n) AS Sta3n
	  ,CASE WHEN PrimaryVAMC = '168' THEN '528A7' --Syracuse
			WHEN PrimaryVAMC = '161' THEN '598' --Little Rock
			WHEN f.ChecklistID IS NOT NULL THEN f.ChecklistID
			ELSE CAST(s.InferredSta3n as varchar)
			END AS ChecklistID
	  ,b.[EventID]
      ,CASE WHEN a1.MethodCat IS NULL THEN 'Unknown' 
			ELSE a1.[MethodCat] 
			END AS MethodType1
      ,CASE WHEN a1.MethodUsed IS NULL THEN 'Unknown' 
			ELSE a1.[MethodUsed] 
			END AS Method1
      ,a1.[MethodUsedOther] AS MethodComments1
	  ,a2.[MethodCat] AS MethodType2
	  ,a2.[MethodUsed] AS Method2 
      ,a2.[MethodUsedOther] AS MethodComments2 
	  ,a3.[MethodCat] AS MethodType3
	  ,a3.[MethodUsed] AS Method3
      ,a3.[MethodUsedOther] AS MethodComments3
	  ,CASE WHEN a4.MethodUsed IS NOT NULL THEN 'Yes'
			ELSE 'No' END AS AdditionalMethodsReported
      ,b.[DtEntered]
      ,b.[EnteredBy]
      ,b.[EventDate]
	  --matching eventtype to sdvclassification
      ,CASE WHEN SDVClassification LIKE '%Ideation%' THEN 'Ideation'
			WHEN SdvClassification LIKE 'Undetermined%' THEN 'Possible Suicide Event (Intent Undetermined)'
			WHEN SdvClassification LIKE 'Suicid%' THEN 'Suicide Event'
			WHEN SDVClassification LIKE 'Non-Suicidal%' THEN 'Non-Suicidal SDV'
			ELSE 'Other' END AS [EventType]
      ,b.[Outcome]
      ,b.[OutcomeOther] AS OutcomeComments
	  ,b.[VAProperty]
      ,b.[Comments]
      ,b.SDVClassification
	  ,NULL AS ReportedBy
INTO #SPANEventFinal
FROM (SELECT * FROM #SpanEventLogCleaned WHERE rownum = 1) b
LEFT JOIN #CheckID f 
	ON b.PrimaryVAMC = f.UniqueID
LEFT JOIN #SPANCohortFinal c 
	ON b.PatientID = c.PatientID
LEFT JOIN (SELECT * FROM #SPANMethodCleaned WHERE rownum = 1) a1  
	ON a1.PatientID = c.PatientID 
	AND b.EventID = a1.EventID
LEFT JOIN (SELECT * FROM #SPANMethodCleaned WHERE rownum = 2) a2 
	ON a2.PatientID = c.PatientID 
	AND b.EventID = a2.EventID
LEFT JOIN (SELECT * FROM #SPANMethodCleaned WHERE rownum = 3) a3  
	ON a3.PatientID = c.PatientID 
	AND b.EventID = a3.EventID
LEFT JOIN (SELECT * FROM #SPANMethodCleaned WHERE rownum = 4) a4  
	ON a4.PatientID = c.PatientID 
	AND b.EventID = a4.EventID
LEFT JOIN [LCustomer].[LCustomer] AS s WITH (NOLOCK)
	ON CONCAT(s.ADDomain,'\',TRIM(s.ADLogin)) = b.EnteredBy
;

 EXEC [Maintenance].[PublishTable] '[Present].[SPAN]', '#SPANEventFinal'
;
  
END