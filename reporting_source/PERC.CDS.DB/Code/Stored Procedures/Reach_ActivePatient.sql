-- =============================================
-- Author:		<Susana Martins>
-- Create date: 11/16/2016
-- Description: Active Patients for Reach Vet and Station Assignments
--
-- Last Updated:
/*	2018-06-05 JB:  Removed commented code where double pound sign was used
	2018-06-07 RAS: Removed sections querying OP and IP activity in past 2 years and moved 
                    to Present_ActivePatient code. SPatient table then informs this code.
	2018-10-02 RAS: Changed DisplayedPatients references to synonym.
    2018-10-03 HES: Added validation code at end of SP.
    2018-10-05 SM:  adding code to update REACH.Active assignment to align with coordinator health factor
	2018-10-05 RAS: Merged previous 2018-10-05 update with existing portion that was meant to update 
					station with coordinator station
	2018-11-02 HES: Added past patients from DisplayedPatient table and added them to the initial cohort.
	2018-11-06 SM	Revamped code to remove MVIPersonSID and separated out subqueries and removed functions. Not sure what is going on in DEV environment today.
	20190219   RAS	Refactored to use publish table - change table to drop demographic columns. Added Log SPs.
	20190730   RAS  Implemented MVIPersonSID, removed PatientSID joins. 
	2020-10-26 RAS	Added PatientPersonSID and changed previous reach patient section to use REACH.History.
	2021-04-14 RAS	Removed Rec-Recruit exclusion section. We will now only use filtering of Enrollment Priority Groups
					which is done is Code.REACH_RiskScore
	2021-04-19 RAS	Correction to filling in PersonSID for Cerner Mill patients found in homestation table.
	2021-09-17 BTW - Enclave Refactoring - Counts Confirmed.
	2021-09-17 JEB - Enclave Refactoring - Refactored comment
	2021-09-23 JEB - Enclave Refactoring - Removed use of Partition ID
	2022-07-06 HES - Added "AND STAPA IS NOT NULL" to the where clause of the Cerner Millenium Outpat Visits section of the code
					 to filter unassigned patients.
	2022-07-12 HES - Added code to the where clause of the #StageReachActivePatient creation statement to delete
					 any patient that has requested exclusion from ReachVet calculations.
	2022-08-15 SAA_JJR - Updated source of facility location from [MillCDS].[DimVALocation] to [MillCDS].[DimLocations];New table includes DoD location data	
	2022-09-08 RAS	Updated Homestation section to pull PatientPersonSID and Sta3n_EHR directly from the homestation table.
	2023-09-19 LM	Change to reflect new homestation rules to prioritize location of most recent PCP over MHTC
	2023-10-12 LM	Updated source of Cerner IOC date from [MillCDS].[DimLocations] to [Lookup].[ChecklistID]
	2024-27-03 AER	Added a validation for checklistid to reach run results
	2024-08-15 LM	Added additional patient who opted out of risk score calculation
	2025-05-06 LM - Updated references to point to REACH 2.0 objects

TESTING:
	EXEC [Code].[Reach_ActivePatient]
	SELECT TOP 100 * FROM [REACH].[ReachRunResults] ORDER BY RunDate DESC
*/
-- =============================================

/*DEPENDENCIES
Present.HomestationMonthly
Inpatient.BedSection
Present.Provider*

*/

CREATE PROCEDURE [Code].[Reach_ActivePatient]
	-- Add the parameters for the stored procedure here
AS
BEGIN

	EXEC [Log].[ExecutionBegin] 'EXEC Code.Reach_ActivePatient','Execution of Code.Reach_ActivePatient SP'

-----------------------------------------------
-- CHECK PREREQUISITES
-----------------------------------------------
	/**Make sure HomeStation is current for the month**/
	IF	(SELECT substring(max(FYM), 6, 2) FROM [Present].[HomestationMonthly]) 
		<>
		(SELECT CASE 
				WHEN month(getdate()) > 9 THEN month(getdate()) - 9
				WHEN month(getdate()) < 10 THEN month(getdate()) + 3
				END
		)
	BEGIN
		DECLARE @ErrorMsg varchar(500)=
			'HomestationMonthly has not been updated this month. Reach_ActivePatient requires this before it can execute.'
		EXEC [Log].[Message] 'Error','Missing dependency',@ErrorMsg
		PRINT @ErrorMsg;
		THROW 51000,@ErrorMsg,1
	END

-----------------------------------------------
-- IP AND OP ACTIVITY IN PAST 2 YEARS 
-----------------------------------------------
	--Get possible patients (appt or inpatient in past 2 years)

	/** Inpatients in past 2 years **/
	DROP TABLE IF EXISTS #INPATIENT; 
	SELECT DISTINCT i.MVIPersonSID
		,i.PatientPersonSID
		,i.ChecklistID
		,i.Sta3n_EHR
	INTO #INPATIENT
	FROM [Inpatient].[BedSection] i WITH (NOLOCK)
	WHERE (AdmitDateTime BETWEEN DATEADD(DAY,-731,CAST(GETDATE() AS DATE)) AND DATEADD(DAY,1,CAST(GETDATE() AS DATE))
		OR DischargeDateTime BETWEEN DATEADD(DAY,-731,CAST(GETDATE() AS DATE)) AND DATEADD(DAY,1,CAST(GETDATE() AS DATE))
		) 
		AND LastRecord = 1

	/** Outpatient in past 2 years**/
	--VistA data - get visits
	DROP TABLE IF EXISTS #Visit1
	SELECT TOP 1 WITH TIES
		mvi.MVIPersonSID
		,v.PatientSID
		,v.Sta3n
		,v.DivisionSID
		,v.VisitDateTime
		,v.VisitSID
	INTO #Visit1
	FROM [Outpat].[Visit] as v WITH(NOLOCK)
	INNER JOIN [Dim].[AppointmentStatus] as sts WITH(NOLOCK) ON v.AppointmentStatusSID=sts.AppointmentStatusSID
	LEFT JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON v.PatientSID = mvi.PatientPersonSID 
	WHERE sts.AppointmentStatusAbbreviation IN ('CO','CI','PEND','X')
		AND v.VisitDateTime BETWEEN DATEADD(YEAR,-2,CAST(GETDATE() AS DATE)) AND DATEADD(DAY,1,CAST(GETDATE() AS DATE)) 
		AND v.WorkloadLogicFlag='Y'
	ORDER BY ROW_NUMBER() OVER(PARTITION BY mvi.MVIPersonSID ORDER BY v.VisitDateTime DESC)

	--VistA data - add location
	DROP TABLE IF EXISTS #VisitsV
	SELECT v.MVIPersonSID
		,v.PatientSID
		,v.VisitDateTime
		,ISNULL(div.ChecklistID,CAST(v.Sta3n as VARCHAR)) ChecklistID
		,v.Sta3n
	INTO #VisitsV
	FROM #Visit1 v
	LEFT JOIN  [LookUp].[DivisionFacility] as div WITH(NOLOCK) on div.DivisionSID=v.DivisionSID

	--Cerner Millenium Outpat Visits
	DROP TABLE IF EXISTS #VisitsM
	SELECT TOP 1 WITH TIES
		MVIPersonSID
		,PersonSID
		,STAPA
		,TZDerivedVisitDateTime
		,Sta3n=200
	INTO #VisitsM
	FROM [Cerner].[FactUtilizationOutpatient] WITH (NOLOCK)
	WHERE TZDerivedVisitDateTime BETWEEN DATEADD(YEAR,-2,CAST(GETDATE() AS DATE)) AND CAST(GETDATE() AS DATE) 
			 AND STAPA IS NOT NULL
	ORDER BY ROW_NUMBER() OVER(PARTITION BY PersonSID ORDER BY TZRegistrationDateTime DESC)
	
	--Final Outpatient
	DROP TABLE IF EXISTS #Visits
	SELECT TOP 1 WITH TIES
		MVIPersonSID
		,PatientSID AS PatientPersonSID
		,VisitDateTime
		,ChecklistID
		,Sta3n as Sta3n_EHR
	INTO #Visits
	FROM (
		SELECT MVIPersonSID,PatientSID,VisitDateTime,ChecklistID,Sta3n FROM #VisitsV
		UNION ALL 
		SELECT MVIPersonSID,PersonSID,TZDerivedVisitDateTime,STAPA,Sta3n FROM #VisitsM
		) vm
	ORDER BY ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY VisitDateTime DESC)
			  				
/** Initial Cohort**/
	--No deaths, no test patients
	DROP TABLE IF EXISTS #ActivePatientCurrent;
	SELECT DISTINCT 
		mp.MVIPersonSID
	INTO  #ActivePatientCurrent
	FROM [Common].[MasterPatient] as mp WITH (NOLOCK)
	LEFT JOIN #Visits AS o ON mp.MVIPersonSID = o.MVIPersonSID
	LEFT JOIN #INPATIENT  AS i ON mp.MVIPersonSID = i.MVIPersonSID
	WHERE mp.TestPatient = 0 
		AND mp.DateOfDeath IS NULL
		AND (i.MVIPersonSID IS NOT NULL --where the patient was either seen inpat  
			OR o.MVIPersonSID IS NOT NULL) --or the patient was seen outpat

-----------------------------------------------
-- EXISTING REACH PATIENTS
-----------------------------------------------
DROP TABLE IF EXISTS #displayed;
SELECT DISTINCT h.MVIPersonSID
	,h.ChecklistID
	,h.PatientPersonSID
	,h.Sta3n_EHR
INTO #displayed
FROM [REACH].[History] h WITH (NOLOCK) --this table updates nightly to get most recent facility where patient is assigned for REACH VET
INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK) ON mp.MVIPersonSID = h.MVIPersonSID
WHERE mp.DateOfDeath IS NULL

/** Active cohort + past Reach **/
DROP TABLE IF EXISTS #ActivePatient;
SELECT MVIPersonSID
	  ,ISNULL(MAX(PatientPersonSID),NULL) as PatientPersonSID
	  ,ISNULL(MAX(ChecklistID),NULL) as ChecklistID_ReachAssign	--Past REACH Patient data will be here if exists
	  ,ISNULL(MAX(AssignmentSource),NULL) as AssignmentSource	--Past REACH Patient data will be here if exists
	  ,ISNULL(MIN(Sta3n_EHR),NULL) AS Sta3n_EHR
INTO  #ActivePatient
FROM (
	SELECT MVIPersonSID
		  ,PatientPersonSID=NULL
		  ,ChecklistID=NULL
		  ,AssignmentSource=NULL
		  ,Sta3n_EHR=NULL
	FROM #ActivePatientCurrent
  UNION ALL
	SELECT MVIPersonSID
		  ,PatientPersonSID
		  ,ChecklistID --added past assignment here to avoid doing this update afer assigning stations
		  ,'Past REACH Patient'
		  ,Sta3n_EHR
	FROM #displayed
	) as A
GROUP BY MVIPersonSID

	CREATE INDEX ix_ap_PatientICN ON #ActivePatient (MVIPersonSID);
-----------------------------------------------------------
/*******REACH VET STATION ASSIGNMENT*********/
-----------------------------------------------------------
--Assign 1 REACH VET station  per patient based on providers, last vists, or previously assigned RV station
	
	/*Newest PCP*/
	UPDATE #ActivePatient
	SET ChecklistID_ReachAssign =  pcp.ChecklistID 
		,PatientPersonSID = pcp.PatientSID
		,AssignmentSource = 'PCP'
		,Sta3n_EHR = pcp.Sta3n
	FROM #ActivePatient a
	INNER JOIN [Present].[Provider_PCP_ICN] pcp WITH (NOLOCK) on a.MVIPersonSID=pcp.MVIPersonSID
	WHERE ChecklistID_ReachAssign IS NULL --keep previous ChecklistID assignment if exists
	
	/*MHTC*/
	UPDATE #ActivePatient
	SET ChecklistID_ReachAssign = mhtc.ChecklistID
		,PatientPersonSID = mhtc.PatientSID
		,AssignmentSource = 'MHTC'
		,Sta3n_EHR = LEFT(mhtc.ChecklistID,3)
	FROM  #ActivePatient  ap
	INNER JOIN [Present].[Provider_MHTC_ICN] mhtc WITH (NOLOCK) on ap.MVIPersonSID=mhtc.MVIPersonSID
	WHERE ChecklistID_ReachAssign IS NULL --keep previous ChecklistID assignment if exists

	--SELECT count(*) from #ActivePatient WHERE ChecklistID_ReachAssign is null	--1224101
	
	/*Homestation*/
	UPDATE #ActivePatient
	SET ChecklistID_ReachAssign = hm.ChecklistID
		,PatientPersonSID = hm.PatientPersonSID 
		,AssignmentSource = 'HOMESTATION'
		,Sta3n_EHR = hm.Sta3n_EHR 
	FROM #ActivePatient a
	INNER JOIN [Present].[HomestationMonthly] hm WITH (NOLOCK) on a.MVIPersonSID=hm.MVIPersonSID
	WHERE a.ChecklistID_ReachAssign IS NULL --keep previous ChecklistID assignment if exists
	 ;

	/*Last Visit*/
	UPDATE #ActivePatient
	SET ChecklistID_ReachAssign =  v.ChecklistID
		,PatientPersonSID = v.PatientPersonSID
		,AssignmentSource = 'Visit'
		,Sta3n_EHR = v.Sta3n_EHR
	FROM #ActivePatient a
	INNER JOIN #Visits v ON a.MVIPersonSID = v.MVIPersonSID
	WHERE ChecklistID_ReachAssign IS NULL --keep previous ChecklistID assignment if exists
	;

	/*Inpatient Stay*/
	UPDATE #ActivePatient
	SET ChecklistID_ReachAssign =  i.ChecklistID
		,PatientPersonSID = i.PatientPersonSID
		,AssignmentSource = 'Inpatient'
		,Sta3n_EHR = i.Sta3n_EHR
	FROM #ActivePatient a
	INNER JOIN #INPATIENT i ON a.MVIPersonSID = i.MVIPersonSID
	WHERE a.ChecklistID_ReachAssign IS NULL --keep previous ChecklistID assignment if exists
	;

-----------------------------------------------
-- UPDATE ASSIGNMENT FOR PAST REACH VET PATIENTS
-----------------------------------------------
--Set PatientPersonSID to Mill PersonSID for assignments to a station that has implemented Cerner
-- and to VistA PatientSID for all others
UPDATE #ActivePatient
SET PatientPersonSID = ps.PatientPersonSID
	,Sta3n_EHR = ps.Sta3n -- this must come from ps so that all Cerner patients have Sta3n_EHR = 200
FROM #ActivePatient ap
INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] ps WITH (NOLOCK) ON 
	ps.MVIPersonSID = ap.MVIPersonSID
	AND ps.Sta3n = (
		-- match ps.Sta3n to value of 200 for all Cerner sites,
		-- otherwise match to the original value
		CASE WHEN ap.Sta3n_EHR = 200 
			OR ap.ChecklistID_ReachAssign IN (
				SELECT ChecklistID FROM [Lookup].[ChecklistID] WITH (NOLOCK)
				WHERE IOCDate < GETDATE()
				)
			THEN 200 ELSE ap.Sta3n_EHR END
		)

DROP TABLE IF EXISTS #StageReachActivePatient
SELECT MVIPersonSID
	,PatientPersonSID
	,ChecklistID_ReachAssign AS ChecklistID
	,AssignmentSource
	,Sta3n_EHR
INTO #StageReachActivePatient
FROM #ActivePatient
WHERE ChecklistID_ReachAssign IS NOT NULL
AND MVIPersonSID NOT IN (19766070,55367540) -- Additional patients that want to be excluded from ReachVet calculation can be added here.


	/* validation check:
	SELECT COUNT(distinct MVIPersonSID) FROM #StageReachActivePatient
	SELECT * FROM (
	SELECT MVIPersonSID,Count(PatientPersonSID) patcount
	FROM #StageReachActivePatient
	GROUP BY MVIPersonSID
	HAVING count(patientpersonsid) > 1
	) a
	*/

-- DOUBLE CHECK THAT WE DON'T NEED THIS SECTION
----I think this is unnecessary now that we are pulling patientsids from source tables and not adding at end
		----Deal with multiple SIDs
		--DELETE i FROM #StageReachActivePatient i
		--INNER JOIN [SPatient].[SPatient] c on c.PatientSID=i.PatientSID
		--WHERE c.PatientName LIKE 'MERGING%'	
		--	AND i.MVIPersonSID IN (
		--		SELECT MVIPersonSID 
		--		FROM #StageReachActivePatient
		--		GROUP BY MVIPersonSID,ChecklistID
		--		HAVING count(PatientSID)>1
		--		)

	EXEC [Maintenance].[PublishTable] 'REACH.ActivePatient','#StageReachActivePatient' 

	--Warning that NULL ChecklistID records were excluded.
	DECLARE @NullCount smallint = (SELECT count(*) FROM #ActivePatient WHERE ChecklistID_ReachAssign IS NULL)
	IF @NullCount>0
	BEGIN
   		DECLARE @msg varchar(100) = cast(@NullCount as varchar)+' record(s) are missing a REACH station assignment.'
		EXEC [Log].[Message] 'Warning', @msg
    END

-------------------------------
--UPDATE PRESENT.STATIONASSIGNMENTS --Do Not Include in v02 until other validation complete
-------------------------------
	--Update StationAssignment table just to be sure it has the most recent data
	
	/*
	UPDATE [Present].[StationAssignments]
	SET REACH = 0;

	UPDATE [Present].[StationAssignments]
	SET REACH = 1
	FROM [Present].[StationAssignments] AS st
	INNER JOIN [REACH].[ActivePatient] AS rv ON rv.MVIPersonSID = st.MVIPersonSID
		AND rv.ChecklistID = st.Checklistid
	*/

EXEC [Log].[Message] 'Information','Section Complete','Completed Reach.ActivePatients, beginning validation steps.'

-------------------------------
-- BEGIN VALIDATION REACH.ACTIVEPATIENT
-------------------------------
	-- CREATE VARIABLES
	DECLARE @ProcedureName NVARCHAR(256) = NULL
	DECLARE @ValidationType NVARCHAR(256) = NULL
	DECLARE @Results NVARCHAR(256) = NULL
	DECLARE @RunDate SMALLDATETIME = CAST(GETDATE() AS SMALLDATETIME)
	DECLARE @ErrorFlag INT = 0
	DECLARE @ErrorResolution NVARCHAR(256) = NULL

	SET @ProcedureName = 'Code.Reach_ActivePatient'





	--Get patient count from last run
	----count(*) will be the distinct patient count FROM THE LAST RUN, however to compare
	----patient by patient you would need to join to get distinct MVIPersonSID
	DECLARE @OldPatientCount INT = (
		SELECT --ReleaseDate,
			count(*) 
		FROM [REACH].[RiskScoreHistoric] WITH (NOLOCK)
		WHERE ReleaseDate = (SELECT MAX(ReleaseDate) FROM [Reach].[RiskScoreHistoric])
		--GROUP BY ReleaseDate
		) 

	-- A pre-test to just to get a sense that the amount of patients is similar to the past
	-- tolerance levels are roughly +- 4000
	SET @ValidationType = 'Patient Count Change'
	SET @Results = (
			SELECT count(*)
			FROM [REACH].[ActivePatient] WITH (NOLOCK)
			) - @OldPatientCount

		IF ABS(@Results)>4000 
			SELECT @ErrorFlag=1
				  ,@ErrorResolution='Error'
		ELSE 
			SELECT @ErrorFlag=0
				  ,@ErrorResolution='OK'

	INSERT INTO [REACH].[ReachRunResults] (
		ProcedureName
		,ValidationType
		,Results
		,RunDate
		,ErrorFlag
		,ErrorResolution
		)
	VALUES (
		@ProcedureName
		,@ValidationType
		,@Results
		,@RunDate
		,@ErrorFlag
		,@ErrorResolution
		);

	-- Check that all patients have assignment for checklistID
	-- This is the count of patients with null assignment (the results should be null) 
	SET @ValidationType = 'Patients with NULL ChecklistID'
	SET @Results = (
			SELECT count(DISTINCT MVIPersonSID)
			FROM #ActivePatient --RAS changed this to temp table because inner join for staging table would eliminate NULLs
			WHERE ChecklistID_ReachAssign IS NULL
			)
	SET @ErrorFlag = (
			SELECT CASE 
					WHEN @Results > 0
						THEN 1
					ELSE 0
					END
			);
	SET @ErrorResolution = (
			SELECT CASE 
					WHEN @Results > 0
						THEN 'Error'
					ELSE 'OK'
					END
			);


	-- Check that all patients in reach history have their checklist displaying correctly in active patient 
	-- This is the count of patients with different checklistid in history vs active patient
	SET @ValidationType = 'Patients with ChecklistID mismatch between history and active patient'
	SET @Results = (
			SELECT count(DISTINCT a.MVIPersonSID)
			FROM #ActivePatient as a 
      inner join reach.history as b on a.mvipersonsid = b.MVIPersonSID
			WHERE ChecklistID_ReachAssign <> b.checklistid
			)
	SET @ErrorFlag = (
			SELECT CASE 
					WHEN @Results > 0
						THEN 1
					ELSE 0
					END
			);
	SET @ErrorResolution = (
			SELECT CASE 
					WHEN @Results > 0
						THEN 'Error'
					ELSE 'OK'
					END
			);


	INSERT INTO  [REACH].[ReachRunResults] (
		ProcedureName
		,ValidationType
		,Results
		,RunDate
		,ErrorFlag
		,ErrorResolution
		)
	VALUES (
		@ProcedureName
		,@ValidationType
		,@Results
		,@RunDate
		,@ErrorFlag
		,@ErrorResolution
		);

	-- make sure there are no checklist id duplicates for reach stations
	-- Check all patients have only 1 station assignment
	SET @ValidationType = 'Multiple ChecklistID Assignments'
	DROP TABLE IF EXISTS #temp1
	
		SELECT MVIPersonSID
			  ,count(ChecklistID) AS 'CountChecklistIDs'
		INTO #temp1
		FROM [REACH].[ActivePatient] WITH (NOLOCK)
		GROUP BY MVIPersonSID
		HAVING count(ChecklistID) > 1

	IF EXISTS (SELECT CountChecklistIDs FROM #temp1)
		SELECT @ErrorFlag = 1
			,@Results = (
				SELECT COUNT(DISTINCT MVIPersonSID)
				FROM #temp1
				)
			,@ErrorResolution = 'Error'
	ELSE
		SELECT @ErrorFlag = 0
			,@Results = '0'
			,@ErrorResolution = 'OK';

	INSERT INTO [REACH].[ReachRunResults] (
		ProcedureName
		,ValidationType
		,Results
		,RunDate
		,ErrorFlag
		,ErrorResolution
		)
	VALUES (
		@ProcedureName
		,@ValidationType
		,@Results
		,@RunDate
		,@ErrorFlag
		,@ErrorResolution
		);

--SELECT * FROM [REACH].[ReachRunResults]
--ORDER BY RunDate DESC

	EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END