

-- =============================================
-- Author:		<Liam Mina>
-- Create date: <12/23/2019>
-- Description:	Full text of Veteran's most recent suicide prevention safety plan-- used in CRISTAL
-- Updates
--  2020-09-22 - LM - Changed initial query to use MasterPatient instead of StationAssignments.
--	2021-03-10 - LM - Added Cerner DTAs for safety plan (since we do not have full text of the note from Cerner)
--  2021-09-13 - Jason Bacani - Enclave Refactoring - Counts confirmed; Some formatting; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- EXEC [App].[MBC_FullSafetyPlan_LSV] @User = 'VHAMASTER\VHAISBBACANJ'	, @Patient = '1000717526'
-- EXEC [App].[MBC_FullSafetyPlan_LSV] @User = 'vha21\vhapalminal'		, @Patient = '1002133470'
-- =============================================
CREATE PROCEDURE [App].[MBC_FullSafetyPlan_LSV]
(
	@User VARCHAR(MAX),
	@Patient VARCHAR(1000)
)  
AS
BEGIN
	SET NOCOUNT ON;
 	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	--For inline testing only
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'vha21\vhapalminal'	; SET @Patient = '1000750877'
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'vha21\vhapalminal'	; SET @Patient = '1018612230'

	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient
	SELECT 
		a.MVIPersonSID
		,CASE 
			WHEN MAX(f.TZFormUTCDateTime) OVER (PARTITION BY a.MVIPersonSID) > MAX(t.EntryDateTime) OVER (PARTITION BY a.MVIPersonSID) OR t.EntryDateTime IS NULL THEN 'C'
			ELSE 'V' 
		END AS Source
	INTO #Patient
	FROM [Common].[MasterPatient] a WITH (NOLOCK)
	INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON a.MVIPersonSID = mvi.MVIPersonSID
	LEFT JOIN [PDW].[CRISTAL_TIU_SafetyPlanNotes] t WITH (NOLOCK)
		ON t.PatientSID = mvi.PatientPersonSID
	LEFT JOIN 
		(
			SELECT MVIPersonSID, TZFormUTCDateTime 
			FROM [Cerner].[FactPowerForm] WITH (NOLOCK)
			WHERE DocFormDescription = 'VA Safety Plan'
				AND DerivedDtaEventResult IN ('New Safety Plan','Update to Safety Plan')
		) f
		ON f.MVIPersonSID = a.MVIPersonSID
	WHERE a.PatientICN = @Patient
		AND EXISTS(SELECT mvi.Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
		
	DROP TABLE IF EXISTS #VistA
	SELECT TOP (1) mvi.PatientICN
		,c.Facility
		,b.Sta3n
		,b.EntryDateTime
		,b.ReportText
	INTO #VistA
	FROM #Patient p
	INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON p.MVIPersonSID = mvi.MVIPersonSID
	INNER JOIN [PDW].[CRISTAL_TIU_SafetyPlanNotes] b WITH (NOLOCK)
		ON b.PatientSID = mvi.PatientPersonSID
	INNER JOIN [Lookup].[ChecklistID] c WITH (NOLOCK)
		ON b.Sta3n = c.Sta3n
	WHERE p.Source = 'V'
	ORDER BY b.EntryDateTime desc
	-- Get Cerner safety plan DTAs

	--Step 2a: Find most recent suicide prevention health factors for the patient. First get max date of HFs in specific category
	DROP TABLE IF EXISTS #MaxDate;
	SELECT TOP (1) 
		FormDateTime = pf.TZFormUTCDateTime
		,pf.DocFormActivitySID
	INTO #MaxDate
	FROM #Patient p
	INNER JOIN [Cerner].[FactPowerForm] pf WITH (NOLOCK) ON p.MVIPersonSID = pf.MVIPersonSID
	WHERE pf.DocFormDescription = 'VA Safety Plan'
		AND pf.DerivedDTAEventResult IN ('New Safety Plan','Update to Safety Plan')
		AND p.Source = 'C'
	ORDER BY pf.TZFormUTCDateTime DESC

	DROP TABLE IF EXISTS #CernerSafetyPlanDetails;
	SELECT pf.MVIPersonSID
		,pf.StaPa
		,DerivedDtaEvent as DTAEvent
		,DerivedDtaEventResult as DTAEventResult
		,FormDateTime = pf.TZFormUTCDateTime
	INTO #CernerSafetyPlanDetails
	FROM #Patient p
	INNER JOIN [Cerner].[FactPowerForm] pf WITH (NOLOCK) ON p.MVIPersonSID = pf.MVIPersonSID 
	INNER JOIN #MaxDate mx ON mx.DocFormActivitySID=pf.DocFormActivitySID
	;

	DROP TABLE IF EXISTS #Cerner
	SELECT DISTINCT MVIPersonSID
		,StaPa
		,FormDateTime
		,Header='Safety Plan Documentation Status'
		,CASE WHEN DTAEvent='Safety Plan Documentation Status' THEN '1- Documentation Status' --rewording these for clarity and order on report
			WHEN DTAEvent='Veteran provided copy of Safety Plan' THEN '2- Copy of Safety Plan Provided to Veteran?'
			WHEN DTAEvent='Reason Safety plan not provided Veteran' THEN '2a- Reason Not Provided'
			WHEN DTAEvent='Family Caregiver Friend participation' THEN '3- Did Family Member/Caregiver/Friend participate in safety planning session?'
			WHEN DTAEvent='Caregiver provided copy of Safety Plan' THEN '3a- Copy of Safety Plan Provided to Family Member/Caregiver/Friend?'
			WHEN DTAEvent='Reason Safety plan not given Caregiver' THEN '3b- Reason Not Provided'
			WHEN DTAEvent='Vet Physical Add Up to Date' THEN '4- Physical Address Up-To-Date in Patient Registration?'
			WHEN DTAEvent='Vet Physical address' THEN '4a- Physical Address'
			WHEN DTAEvent='Emergency Contact Status' THEN '5- Emergency Contact Up-To-Date in Patient Registration?'
			WHEN DTAEvent='Emergency Contact (Local) Name' THEN '5a- Emergency Contact Name'
			WHEN DTAEvent='Emergency Contact (Local) Phone#' THEN '5b- Emergency Contact Phone Number'
			ELSE DTAEvent END AS DTAEvent
		,DTAEventResult 
	INTO #Cerner
	FROM #CernerSafetyPlanDetails WITH (NOLOCK)
	WHERE DTAEvent in ('Safety Plan Documentation Status','Veteran provided copy of Safety Plan','Caregiver provided copy of Safety Plan','Family Caregiver Friend participation')
	OR DTAEvent LIKE 'Reason Safety plan not%' OR DTAEvent LIKE 'Vet Physical Add%' OR DTAEvent LIKE 'Emergency Contact%'
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,StaPa
		,FormDateTime
		,Header='Step 1: Triggers, Risk Factors, and Warning Signs'
		,DtaEvent
		,DTAEventResult 
	FROM #CernerSafetyPlanDetails WITH (NOLOCK)
	WHERE DTAEvent LIKE 'Crisis Warning Sign%'
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,StaPa
		,FormDateTime
		,Header='Step 2: Internal Coping Strategies to Utilize During a Crisis'
		,CASE WHEN DTAEvent = 'CopingStrategy 1' THEN 'Coping Strategy 1' ELSE DTAEvent END AS DTAEvent
		,DTAEventResult 
	FROM #CernerSafetyPlanDetails WITH (NOLOCK)
	WHERE DTAEvent LIKE 'Coping%Strateg%'
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,StaPa
		,FormDateTime
		,Header='Step 3a: Social Contacts Who May Distract From the Crisis'
		,REPLACE(DTAEvent, 'Family / Friend', 'Contact') AS DTAEvent
		,DTAEventResult 
	FROM #CernerSafetyPlanDetails WITH (NOLOCK)
	WHERE DTAEvent LIKE 'Family / Friend%'
		OR (DTAEvent = 'Social Contacts Documentation Status' AND DTAEventResult<>'Enter Social Contacts here')
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,StaPa
		,FormDateTime
		,Header='Step 3b: Public Places, Groups, or Social Events Which Help Me Feel Better'
		,REPLACE(DTAEvent, 'Coping Group', 'Place/Group/Event') AS DTAEvent
		,DTAEventResult 
	FROM #CernerSafetyPlanDetails WITH (NOLOCK)
	WHERE DTAEvent LIKE 'Coping Group%'
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,StaPa
		,FormDateTime
		,Header='Step 4: Family Members or Friends who May Offer Help'
		,REPLACE(DTAEvent, 'Crisis Helper', 'Contact') AS DTAEvent
		,DTAEventResult 
	FROM #CernerSafetyPlanDetails WITH (NOLOCK)
	WHERE DTAEvent LIKE 'Crisis Helper%'
		OR (DTAEvent = 'Family and Friends Documentation' AND DTAEventResult <> 'Enter friends and family here')
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,StaPa
		,FormDateTime
		,Header='Step 5a: Professionals and Agencies to Contact for Help'
		,DTAEvent
		,DTAEventResult 
	FROM #CernerSafetyPlanDetails WITH (NOLOCK)
	WHERE DTAEvent LIKE 'Professional%'
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,StaPa
		,FormDateTime
		,Header='Step 5b: Local Urgent Care/Emergency Room Information'
		,DTAEvent
		,DTAEventResult 
	FROM #CernerSafetyPlanDetails WITH (NOLOCK)
	WHERE DTAEvent = 'ED or Urgent Care Facility'
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,StaPa
		,FormDateTime
		,Header='Step 5c: Local VA Facility Information'
		,DTAEvent
		,DTAEventResult 
	FROM #CernerSafetyPlanDetails WITH (NOLOCK)
	WHERE DTAEvent in ('local VA emergency numbers','Facility Address','Facility city/state/zip')
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,StaPa
		,FormDateTime
		,Header='Step 6a: Ways to Make My Environment Safer'
		,DTAEvent
		,DTAEventResult 
	FROM #CernerSafetyPlanDetails WITH (NOLOCK)
	WHERE DTAEvent in ('Ways to make environment safer','Access to Firearms','Access to Opioids','Firearms safety discussed'
		,'Opioid safety discussed','Naloxone offered','Environmental Safety Follow Up Date','Veteran offered a gunlock','Refuses gunlock reason','Naloxone offered')
	UNION ALL
	SELECT DISTINCT MVIPersonSID
		,StaPa
		,FormDateTime
		,Header='Step 6b: People who will help protect me from access to dangerous items'
		,REPLACE(DTAEvent, 'Protector Friend', 'Contact') AS DTAEvent
		,DTAEventResult 
	FROM #CernerSafetyPlanDetails WITH (NOLOCK)
	WHERE DTAEvent LIKE 'Protector Friend%'
	;

	SELECT PatientICN
			,Facility
			,Sta3n
			,EntryDateTime
			,NULL AS Header
			,ReportText
			,NULL AS DTAEvent
			,NULL AS DTAEventResult
	FROM #VistA 
	UNION ALL
	SELECT p.PatientICN
			,Facility
			,Sta3n=200
			,FormDateTime
			,Header
			,NULL AS ReportText
			,DTAEvent
			,DTAEventResult
	FROM #Cerner c
	INNER JOIN [Common].[MasterPatient] p WITH (NOLOCK) ON c.MVIPersonSID=p.MVIPersonSID
	INNER JOIN [LookUp].[ChecklistID] ci WITH (NOLOCK) ON c.StaPA=ci.ChecklistID
	;


END