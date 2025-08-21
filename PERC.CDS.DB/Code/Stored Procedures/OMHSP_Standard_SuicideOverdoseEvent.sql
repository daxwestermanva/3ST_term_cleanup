
/*=============================================
Author:		<Liam Mina>
Create date: <03/15/2019>
Description:	Dataset pulls data from SBOR and SPAN tables for information on suicide and overdose events

	2019-03-28 - RAS - Made list of fields explicit for final union
	2019-04-05 - LM - Added MVIPersonSID to initial select statement
	2019-04-16 - LM - Added logic to remove duplicates
	2019-05-03 - LM - Removed Outcome1 from code that removes duplicate events
	2019-05-21 - LM - Added columns for PreparatoryBehavior, UndeterminedSDV, and SuicidalSDV
	2019-07-23 - LM - Added PatientID from SPAN to allow for more accurate dropping of duplicates; changed order by statement when dropping duplicates so if the event is entered in SPAN and SBOR, the SBOR record will be kept
	2019-08-14 - LM - Added code to drop cases where multiple fatal events were reported, or multiple events on the same day with the same method, removed exclusions for non-suicidal and/or non-SDV events from SPAN
	2019-10-30 - LM - Changed reference to SPatient.SPatient instead of Present.StationAssignments to capture ICNs for deceased patients
	2020-09-09 - LM - Overlay of Cerner data
	2021-03-03 - LM - Added overdose flag and fatal flag
	2021-08-26 - JEB - Enclave Refactoring - Counts confirmed; Some additional formatting; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; Added logging
	2023-05-02 - LM - When there are duplicates, prioritize reports from SBORs because they generally contain more details
	2024-08-19 - LM - Correction to death deduplication

	Testing execution:
		EXEC [Code].[OMHSP_Standard_SuicideOverdoseEvent]

	Helpful Auditing Scripts

		SELECT TOP 5 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
		FROM [Log].[ExecutionLog] WITH (NOLOCK)
		WHERE name = 'EXEC Code.OMHSP_Standard_SuicideOverdoseEvent'
		ORDER BY ExecutionLogID DESC

		SELECT TOP 6 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE TableName = 'SuicideOverdoseEvent' ORDER BY 1 DESC

  =============================================*/

CREATE PROCEDURE [Code].[OMHSP_Standard_SuicideOverdoseEvent]
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] 'EXEC Code.OMHSP_Standard_SuicideOverdoseEvent','Execution of Code.OMHSP_Standard_SuicideOverdoseEvent SP'
	
	--Step 1a: Find SBOR events
	DROP TABLE IF EXISTS #SBOR
	SELECT DISTINCT 
		h.MVIPersonSID
		,mp.PatientICN
		,h.Sta3n
		,h.ChecklistID
		,h.VisitSID
		,h.DocFormActivitySID
		,CAST(h.EntryDateTime AS DATE) AS EntryDateTime
		,h.TIUDocumentDefinition AS DataSource
		,h.EventDate
		,h.EventDateFormatted
		,CASE 
			WHEN h.EventType IN ('Suicide Event','Possible Suicide Event (Intent Undetermined)') THEN 'Suicide Event'
			WHEN h.EventType = 'Accidental Overdose' THEN 'Accidental Overdose'
			WHEN h.EventType = 'Adverse Effect Overdose' THEN 'Severe Adverse Drug Event'
			ELSE 'Other' END 
		AS EventType
		,CASE 
			WHEN h.EventType = 'Suicide Event' THEN 'Yes'
			WHEN h.EventType = 'Possible Suicide Event (Intent Undetermined)' THEN 'Undetermined'
			ELSE 'No' 
		END AS Intent
		,h.Setting
		,h.SettingComments
		,h.SDVClassification
		,h.VAProperty
		,h.SevenDaysDx
		,h.Preparatory
		,h.Interrupted
		,h.InterruptedComments
		,h.Injury
		,h.InjuryComments
		,CASE WHEN h.Outcome1 = 'Died' THEN 'Death' ELSE h.Outcome1 END AS Outcome1
		,h.Outcome1Comments
		,CASE WHEN h.Outcome2 = 'Died' THEN 'Death' ELSE h.Outcome2 END AS Outcome2
		,h.Outcome2Comments
		,h.MethodType1
		,h.Method1
		,h.MethodComments1
		,h.MethodType2
		,h.Method2
		,h.MethodComments2
		,h.MethodType3
		,h.Method3
		,h.MethodComments3
		,h.AdditionalMethodsReported
		,h.ODProvReview
		,h.ODReviewDate
		,CAST(NULL AS VARCHAR) AS Comments
		,s.SPANPatientID
		,CAST(NULL AS INT) AS SPANEventID
	INTO #SBOR
	FROM [OMHSP_Standard].[SBOR] h WITH (NOLOCK) 
	LEFT JOIN [Present].[SPAN] s WITH (NOLOCK)
		ON h.MVIPersonSID = s.MVIPersonSID
	LEFT JOIN [Common].[MasterPatient] mp WITH (NOLOCK)
		ON h.MVIPersonSID = mp.MVIPersonSID 

	--Step 1b: Find SPAN Events
	DROP TABLE IF EXISTS #SPAN
	SELECT 
		h.MVIPersonSID
		,PatientICN
		,Sta3n
		,ChecklistID
		,NULL AS VisitSID
		,NULL AS DocFormActivitySID
		,CAST(DtEntered AS DATE) AS EntryDateTime
		,'SPAN' AS DataSource
		,EventDate
		,EventDate AS EventDateFormatted
		,CASE WHEN EventType IN ('Suicide Event','Possible Suicide Event (Intent Undetermined)') THEN 'Suicide Event' ELSE EventType END AS EventType
		,CASE 
			WHEN EventType = 'Suicide Event' THEN 'Yes'
			WHEN EventType = 'Possible Suicide Event (Intent Undetermined)'  THEN 'Undetermined'
		END AS Intent
		,CAST(NULL AS VARCHAR) AS Setting
		,CAST(NULL AS VARCHAR) AS SettingComments
		,SDVClassification
		,VAProperty
		,CAST(NULL AS VARCHAR) AS SevenDaysDx
		,CASE WHEN SDVClassification LIKE '%Preparatory' THEN 'Yes' ELSE 'No' END AS Preparatory
		,CASE WHEN SDVClassification LIKE '%Interrupted%' THEN 'Yes' ELSE 'No' END AS Interrupted
		,CAST(NULL AS VARCHAR) AS InterruptedComments
		,CASE WHEN SDVClassification LIKE '%With Injury%' THEN 'Yes' ELSE 'No' END AS Injury
		,CAST(NULL AS VARCHAR) AS InjuryComments
		,CASE 
			WHEN Outcome = 'Hospital Admission' THEN 'Hospitalized'
			WHEN Outcome = 'Outpatient Treatment' THEN 'Remained Outpatient' 
			ELSE Outcome 
		END AS Outcome1
		,OutcomeComments AS Outcome1Comments
		,CAST(NULL AS VARCHAR) AS Outcome2
		,CAST(NULL AS VARCHAR) AS Outcome2Comments
		,MethodType1
		,Method1
		,MethodComments1
		,MethodType2
		,Method2
		,MethodComments2
		,MethodType3
		,Method3
		,MethodComments3
		,AdditionalMethodsReported    
		,Comments
		,SPANPatientID 
		,EventID AS SPANEventID
	INTO #SPAN
	FROM [Present].[SPAN] h WITH (NOLOCK)
	;
	
	--Step 2: Union SBOR and SPAN tables
	DROP TABLE IF EXISTS #CombinedStage
	SELECT 
		 MVIPersonSID
		,PatientICN
		,Sta3n
		,ChecklistID
		,VisitSID
		,DocFormActivitySID
		,EntryDateTime
		,DataSource
		,EventDate
		,EventDateFormatted
		,EventType
		,Intent
		,Setting
		,SettingComments
		,SDVClassification
		,VAProperty
		,SevenDaysDx
		,Preparatory
		,Interrupted
		,InterruptedComments
		,Injury
		,InjuryComments
		,Outcome1
		,Outcome1Comments
		,Outcome2
		,Outcome2Comments
		,MethodType1
		,Method1
		,MethodComments1
		,MethodType2
		,Method2
		,MethodComments2
		,MethodType3
		,Method3
		,MethodComments3
		,AdditionalMethodsReported
		,Comments
		,ODProvReview
		,ODReviewDate
		,SPANPatientID
		,SPANEventID
	INTO #CombinedStage
	FROM #SBOR
	UNION ALL
	SELECT 
		 MVIPersonSID 
		,PatientICN
		,Sta3n
		,ChecklistID
		,VisitSID
		,DocFormActivitySID
		,EntryDateTime
		,DataSource
		,EventDate
		,EventDateFormatted
		,EventType
		,Intent
		,Setting
		,SettingComments
		,SDVClassification
		,VAProperty
		,SevenDaysDx
		,Preparatory
		,Interrupted
		,InterruptedComments
		,Injury
		,InjuryComments
		,Outcome1
		,Outcome1Comments
		,Outcome2
		,Outcome2Comments
		,MethodType1
		,Method1
		,MethodComments1
		,MethodType2
		,Method2
		,MethodComments2
		,MethodType3
		,Method3
		,MethodComments3
		,AdditionalMethodsReported
		,Comments 
		,ODProvReview=NULL
		,CAST(NULL AS DATE) AS ODReviewDate
		,SPANPatientID
		,SPANEventID
	FROM #SPAN

	DROP TABLE IF EXISTS #Combined
	SELECT * 
		,ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNumber --assign a unique number to each row
		,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, EventType, SDVClassification, EventDateFormatted, SPANPatientID 
											,CASE WHEN MethodType1='Physical Injury' AND MethodType1 <> Method1 THEN Method1 
												ELSE MethodType1 END
												ORDER BY CAST(EntryDateTime AS date) DESC --most recently reported record
														,CASE WHEN DataSource LIKE '%SUICIDE BEHAVIOR%' THEN 1 --prioritize reports from SBORs
															WHEN DataSource LIKE '%RISK EVALUATION%' THEN 2
															ELSE 3 END) AS RN
	INTO #Combined
	FROM #CombinedStage

	DELETE FROM #Combined
	WHERE RN > 1
	
	DROP TABLE IF EXISTS #CombinedStage
	DROP TABLE IF EXISTS #SBOR
	DROP TABLE IF EXISTS #SPAN

	--Step 3: Drop cases where multiple reports were made for a fatal event
	--Step 3a: Find all the cases where events are reported in both SBOR and SPAN that both were reported to have occurred on the same day, where at least one ended in death
	DROP TABLE IF EXISTS #SameDateDeath
	(
		SELECT a.* INTO #SameDateDeath
		FROM 
			(
				SELECT * FROM #Combined WHERE Outcome1  IN ('Death','Died') OR Outcome2 IN ('Death','Died')
			) a
		INNER JOIN 
			(
				SELECT * FROM #Combined
			) b 
			ON a.MVIPersonSID = b.MVIPersonSID 
			AND a.EventDateFormatted = b.EventDateFormatted)
		UNION
			(
				SELECT b.* 
				FROM 
					(
						SELECT * FROM #Combined WHERE Outcome1  IN ('Death','Died') OR Outcome2 IN ('Death','Died')
					) a
				INNER JOIN 
					(
						SELECT * FROM #Combined
					) b 
					ON a.MVIPersonSID = b.MVIPersonSID 
					AND a.EventDateFormatted = b.EventDateFormatted
			)

	--Step 3b: Assign row numbers, with the most recently reported first
	DROP TABLE IF EXISTS #SameDateDeathAddRows
	SELECT *
		,ROW_NUMBER() OVER 
			(
				PARTITION BY MVIPersonSID, SPANPatientID, EventDateFormatted 
				ORDER BY 
					CASE WHEN Outcome1 IN ('Death','Died') OR Outcome2 IN ('Death','Died') THEN 1 ELSE 2 END  --first prioiritize cases where outcome is death
					,CAST(EntryDateTime AS DATE) DESC  -- then get most recently entered records
					,CASE WHEN SDVClassification LIKE 'Suicid%' THEN 1 ELSE 2 END --then prioritize records with Suicide-related SDV clasification 
					,CASE WHEN DataSource LIKE '%SUICIDE BEHAVIOR AND OVERDOSE REPORT%' THEN 1 --then prioritize based on data source
						WHEN DataSource LIKE '%RISK EVALUATION%' THEN 2 
						WHEN DataSource = 'SPAN' THEN 3 
						ELSE 4 END
			) AS RN2
	INTO #SameDateDeathAddRows
	FROM #SameDateDeath 

	--Step 3c: In cases where the same event was reported multiple times, combine info from both reports to minimize uses of 'unknown'
	DROP TABLE IF EXISTS #MergeSameDateDeath
	SELECT 
		 a.MVIPersonSID 
		,a.PatientICN
		,a.Sta3n
		,a.ChecklistID
		,a.VisitSID
		,a.DocFormActivitySID
		,a.EntryDateTime
		,a.DataSource
		,ISNULL(a.EventDate, b.EventDate) AS EventDate
		,ISNULL(a.EventDateFormatted, b.EventDateFormatted) AS EventDateFormatted
		,ISNULL(a.EventType, b.EventType) AS EventType
		,ISNULL(a.Intent, b.Intent) AS Intent
		,CASE WHEN (a.Setting IS NULL OR a.Setting = 'Unknown') THEN b.Setting ELSE a.Setting END AS Setting
		,CASE WHEN (a.SettingComments IS NULL OR a.SettingComments = 'Unknown') THEN b.SettingComments ELSE a.SettingComments END AS SettingComments
		,a.SDVClassification
		,CASE WHEN (a.VAProperty IS NULL OR a.VAProperty = 'Unknown') THEN b.VAProperty ELSE a.VAProperty END AS VAProperty
		,CASE WHEN (a.SevenDaysDx IS NULL OR a.SevenDaysDx = 'Unknown') THEN b.SevenDaysDx ELSE a.SevenDaysDx END AS SevenDaysDx
		,ISNULL(a.Preparatory, b.Preparatory) AS Preparatory
		,ISNULL(a.Interrupted, b.Interrupted) AS Interrupted
		,ISNULL(a.InterruptedComments, b.InterruptedComments) AS InterruptedComments
		,ISNULL(a.Injury, b.Injury) AS Injury
		,ISNULL(a.InjuryComments, b.InjuryComments) AS InjuryComments
		,ISNULL(a.Outcome1, b.Outcome1) AS Outcome1
		,ISNULL(a.Outcome1Comments, b.Outcome1Comments) AS Outcome1Comments
		,ISNULL(a.Outcome2, b.Outcome2) AS Outcome2
		,ISNULL(a.Outcome2Comments, b.Outcome2Comments) AS Outcome2Comments
		,ISNULL(a.MethodType1, b.MethodType1) AS MethodType1
		,ISNULL(a.Method1, b.Method1) AS Method1
		,ISNULL(a.MethodComments1, b.MethodComments1) AS MethodComments1
		,ISNULL(a.MethodType2, b.MethodType2) AS MethodType2
		,ISNULL(a.Method2, b.Method2) AS Method2
		,ISNULL(a.MethodComments2, b.MethodComments2) AS MethodComments2
		,ISNULL(a.MethodType3, b.MethodType3) AS MethodType3
		,ISNULL(a.Method3, b.Method3) AS Method3
		,ISNULL(a.MethodComments3, b.MethodComments3) AS MethodComments3
		,ISNULL(a.AdditionalMethodsReported, b.AdditionalMethodsReported) AS AdditionalMethodsReported
		,ISNULL(a.Comments, b.Comments) AS Comments
		,ISNULL(a.ODProvReview, b.ODProvReview) AS ODProvReview
		,ISNULL(a.ODReviewDate, b.ODReviewDate) AS ODReviewDate
		,ISNULL(a.SPANPatientID, b.SPANPatientID) AS SPANPatientID
		,ISNULL(a.SPANEventID, b.SPANEventID) AS SPANEventID
		,a.rownumber
		,a.RN2 AS RN
	INTO #MergeSameDateDeath
	FROM
		(
			SELECT * FROM #SameDateDeathAddRows where RN2 = 1
		) a
	LEFT JOIN 
		(
			SELECT * FROM #SameDateDeathAddRows where RN2 = 2
		) b 
		ON a.MVIPersonSID = b.MVIPersonSID 
		AND a.EventDateFormatted = b.EventDateFormatted
	WHERE a.rn2 = 1

	--Step 3d: Drop second (and subsequent) rows for duplicate reports
	DROP TABLE IF EXISTS #DropSameDateDeath
	SELECT a.* 
	INTO #DropSameDateDeath
	FROM #Combined a
	LEFT JOIN #SameDateDeath b ON a.RowNumber = b.RowNumber
	WHERE b.RowNumber is null
	
	DROP TABLE IF EXISTS #Combined2
	SELECT *
	INTO #Combined2
	FROM #DropSameDateDeath
	UNION
	SELECT *
	FROM #MergeSameDateDeath

	DROP TABLE IF EXISTS #SameDateDeath
	DROP TABLE IF EXISTS #SameDateDeathAddRows
	DROP TABLE IF EXISTS #Combined
	DROP TABLE IF EXISTS #DropSameDateDeath
	DROP TABLE IF EXISTS #MergeSameDateDeath

	--Step 4: Drop cases where multiple events were reported with the same date and method
	--Step 4a: Find all the cases where events are reported in both SBOR and SPAN and have the same date and the same method
	DROP TABLE IF EXISTS #SameDateMethod
	(
		SELECT a.* INTO #SameDateMethod
		FROM 
			(
				SELECT * FROM #Combined2 WHERE DataSource = 'SPAN'
			) a
		INNER JOIN 
			(
				SELECT * FROM #Combined2 WHERE DataSource <> 'SPAN'
			) b 
			ON a.MVIPersonSID = b.MVIPersonSID 
			AND a.SPANPatientID = b.SPANPatientID 
			AND a.EventDateFormatted = b.EventDateFormatted 
			AND (a.MethodType1 = b.MethodType1 OR a.MethodType1 = b.MethodType2 OR a.MethodType1 = b.MethodType3)
			AND ((a.Method1 = b.Method1 OR a.MethodType1 = a.Method1 OR b.MethodType1 = b.Method1 
				OR a.Method1 = 'Not Provided' OR b.Method1 = 'Not Provided'
				OR a.Method1 LIKE '%Unknown%' OR b.Method1 LIKE '%Unknown%'
				OR a.Method2 = 'Not Provided' OR b.Method2 = 'Not Provided'
				OR a.Method2 LIKE '%Unknown%' OR b.Method2 LIKE '%Unknown%'))
	)
	UNION ALL
	(
		SELECT b.* 
		FROM 
			(
				SELECT * FROM #Combined2 WHERE DataSource = 'SPAN'
			) a
		INNER JOIN 
			(
				SELECT * FROM #Combined2 WHERE DataSource <> 'SPAN'
			) b 
			ON a.MVIPersonSID = b.MVIPersonSID 
			AND a.SPANPatientID = b.SPANPatientID 
			AND a.EventDateFormatted = b.EventDateFormatted 
			AND (a.MethodType1 = b.MethodType1 OR a.MethodType1 = b.MethodType2 OR a.MethodType1 = b.MethodType3)
			AND ((a.Method1 = b.Method1 OR a.MethodType1 = a.Method1 OR b.MethodType1 = b.Method1 
				OR a.Method1 = 'Not Provided' OR b.Method1 = 'Not Provided'
				OR a.Method1 LIKE '%Unknown%' OR b.Method1 LIKE '%Unknown%'
				OR a.Method2 = 'Not Provided' OR b.Method2 = 'Not Provided'
				OR a.Method2 LIKE '%Unknown%' OR b.Method2 LIKE '%Unknown%'))
	)
	UNION ALL
	(
		SELECT a.* 
		FROM 
			(
				SELECT * FROM #Combined2 WHERE DataSource LIKE '%Suicide Behavior%'
			) a
		INNER JOIN 
			(
				SELECT * FROM #Combined2 WHERE DataSource LIKE '%COMPREHENSIVE%'
			) b 
			ON a.MVIPersonSID = b.MVIPersonSID 
			AND a.EventDateFormatted = b.EventDateFormatted 
			AND (a.MethodType1 = b.MethodType1 OR a.MethodType1 = b.MethodType2 OR a.MethodType1 = b.MethodType3)
			AND ((a.Method1 = b.Method1 OR a.MethodType1 = a.Method1 OR b.MethodType1 = b.Method1 
				OR a.Method1 = 'Not Provided' OR b.Method1 = 'Not Provided'
				OR a.Method1 LIKE '%Unknown%' OR b.Method1 LIKE '%Unknown%'
				OR a.Method2 = 'Not Provided' OR b.Method2 = 'Not Provided'
				OR a.Method2 LIKE '%Unknown%' OR b.Method2 LIKE '%Unknown%'))
			)

	--Step 4b: Assign row numbers, with the most recently reported event first; if events were reported on the same date, order first by SBOR, then CSRE, then SPAN
	DROP TABLE IF EXISTS #SameDateMethodAddRows
	SELECT *
		,ROW_NUMBER() OVER 
			(
				PARTITION BY MVIPersonSID, SPANPatientID, EventDateFormatted 
				ORDER BY CAST(EntryDateTime AS DATE) DESC
					,CASE WHEN SDVClassification LIKE 'Suicid%' THEN 1 ELSE 2 END
					,CASE WHEN DataSource LIKE '%SUICIDE BEHAVIOR AND OVERDOSE REPORT%' THEN 1 
						WHEN DataSource LIKE '%RISK EVALUATION%' THEN 2 
						WHEN DataSource = 'SPAN' THEN 3 
						ELSE 4 END
			) AS RN2
	INTO #SameDateMethodAddRows
	FROM #SameDateMethod

	--Step 4c: In cases where the same event was reported multiple times, combine info from both reports to minimize uses of 'unknown' or NULL
	DROP TABLE IF EXISTS #MergeSameDateMethod
	SELECT 
		a.MVIPersonSID 
		,a.PatientICN
		,a.Sta3n
		,a.ChecklistID
		,a.VisitSID
		,a.DocFormActivitySID
		,a.EntryDateTime
		,a.DataSource
		,ISNULL(a.EventDate, b.EventDate) AS EventDate
		,ISNULL(a.EventDateFormatted, b.EventDateFormatted) AS EventDateFormatted
		,ISNULL(a.EventType, b.EventType) AS EventType
		,ISNULL(a.Intent, b.Intent) AS Intent
		,CASE WHEN (a.Setting IS NULL OR a.Setting = 'Unknown') THEN b.Setting ELSE a.Setting END AS Setting
		,CASE WHEN (a.SettingComments IS NULL OR a.SettingComments = 'Unknown') THEN b.SettingComments ELSE a.SettingComments END AS SettingComments
		,a.SDVClassification
		,CASE WHEN (a.VAProperty IS NULL OR a.VAProperty = 'Unknown') THEN b.VAProperty ELSE a.VAProperty END AS VAProperty
		,CASE WHEN (a.SevenDaysDx IS NULL OR a.SevenDaysDx = 'Unknown') THEN b.SevenDaysDx ELSE a.SevenDaysDx END AS SevenDaysDx
		,ISNULL(a.Preparatory, b.Preparatory) AS Preparatory
		,ISNULL(a.Interrupted, b.Interrupted) AS Interrupted
		,ISNULL(a.InterruptedComments, b.InterruptedComments) AS InterruptedComments
		,ISNULL(a.Injury, b.Injury) AS Injury
		,ISNULL(a.InjuryComments, b.InjuryComments) AS InjuryComments
		,ISNULL(a.Outcome1, b.Outcome1) AS Outcome1
		,ISNULL(a.Outcome1Comments, b.Outcome1Comments) AS Outcome1Comments
		,ISNULL(a.Outcome2, b.Outcome2) AS Outcome2
		,ISNULL(a.Outcome2Comments, b.Outcome2Comments) AS Outcome2Comments
		,ISNULL(a.MethodType1, b.MethodType1) AS MethodType1
		,ISNULL(a.Method1, b.Method1) AS Method1
		,ISNULL(a.MethodComments1, b.MethodComments1) AS MethodComments1
		,ISNULL(a.MethodType2, b.MethodType2) AS MethodType2
		,ISNULL(a.Method2, b.Method2) AS Method2
		,ISNULL(a.MethodComments2, b.MethodComments2) AS MethodComments2
		,ISNULL(a.MethodType3, b.MethodType3) AS MethodType3
		,ISNULL(a.Method3, b.Method3) AS Method3
		,ISNULL(a.MethodComments3, b.MethodComments3) AS MethodComments3
		,ISNULL(a.AdditionalMethodsReported, b.AdditionalMethodsReported) AS AdditionalMethodsReported
		,ISNULL(a.Comments, b.Comments) AS Comments
		,ISNULL(a.ODProvReview, b.ODProvReview) AS ODProvReview
		,ISNULL(a.ODReviewDate, b.ODReviewDate) AS ODReviewDate
		,ISNULL(a.SPANPatientID, b.SPANPatientID) AS SPANPatientID
		,ISNULL(a.SPANEventID, b.SPANEventID) AS SPANEventID
		,a.rownumber
		,a.RN2 AS RN
	INTO #MergeSameDateMethod
	FROM
		(
			SELECT * FROM #SameDateMethodAddRows WHERE RN2 = 1
		) a
	INNER JOIN 
		(
			SELECT * FROM #SameDateMethodAddRows WHERE RN2 = 2
		) b 
		ON a.MVIPersonSID = b.MVIPersonSID 
		AND a.EventDateFormatted = b.EventDateFormatted
	WHERE a.RN2 = 1
	
	--Step 4d: Drop second (and subsequent) rows for duplicate reports
	DROP TABLE IF EXISTS #DropSameDateMethod
	SELECT a.* 
	INTO #DropSameDateMethod
	FROM #Combined2 a
	LEFT JOIN #SameDateMethod b 
		ON a.rownumber = b.rownumber
	WHERE b.RowNumber IS NULL

	DROP TABLE IF EXISTS #Combined3
	SELECT *
	INTO #Combined3
	FROM #DropSameDateMethod
	UNION
	SELECT *
	FROM #MergeSameDateMethod

	DROP TABLE IF EXISTS #Combined2
	DROP TABLE IF EXISTS #SameDateMethod
	DROP TABLE IF EXISTS #SameDateMethodAddRows
	DROP TABLE IF EXISTS #DropSameDateMethod
	DROP TABLE IF EXISTS #MergeSameDateMethod
	
	--Step 5: Form Final Table
	DROP TABLE IF EXISTS #StageSuicideEvent
	SELECT DISTINCT 
		 MVIPersonSID 
		,SPANPatientID
		,SPANEventID
		,PatientICN
		,VisitSID
		,DocFormActivitySID
		,Sta3n
		,ChecklistID
		,EntryDateTime
		,DataSource
		,EventDate
		,EventDateFormatted
		,EventType
		,Intent
		,Setting
		,SettingComments
		,SDVClassification
		,VAProperty
		,SevenDaysDx
		,Preparatory
		,Interrupted
		,InterruptedComments
		,Injury
		,InjuryComments
		,Outcome1
		,Outcome1Comments
		,Outcome2
		,Outcome2Comments
		,MethodType1
		,Method1
		,MethodComments1
		,MethodType2
		,Method2
		,MethodComments2
		,MethodType3
		,Method3
		,MethodComments3
		,AdditionalMethodsReported
		,Comments  
		,ODProvReview
		,ODReviewDate
		,CASE WHEN Outcome1='Death' OR Outcome2='Death' THEN 1 ELSE 0 END AS Fatal
		,CASE 
			WHEN (EventType IN ('Accidental Overdose','Severe Adverse Drug Event') OR MethodType1='Overdose' OR MethodType2='Overdose' OR MethodType3='Overdose')
				AND EventType NOT IN ('Ideation') THEN 1 ELSE 0 
		END AS Overdose --all overdose events regardless of intent, excluding 'ideation'
		,CASE WHEN SDVClassification LIKE '%Preparatory' THEN 1 ELSE 0 END AS PreparatoryBehavior --preparatory behaviors for suicidal, undetermined and non-suicidal SDV
		,CASE WHEN SDVClassification LIKE 'Undetermined%' THEN 1 ELSE 0 END AS UndeterminedSDV
		,CASE WHEN SDVClassification LIKE 'Suicide%' AND EventType = 'Suicide Event' THEN 1 ELSE 0 END AS SuicidalSDV
		,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID,EventType ORDER BY ISNULL(EventDateFormatted,EntryDateTime) DESC ,EntryDateTime DESC) AS EventOrderDesc
		,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY ISNULL(EventDateFormatted,EntryDateTime) DESC,EntryDateTime DESC) AS AnyEventOrderDesc
	INTO #StageSuicideEvent
	FROM #Combined3
	;
	DROP TABLE IF EXISTS #Combined3

	EXEC [Maintenance].[PublishTable] 'OMHSP_Standard.SuicideOverdoseEvent','#StageSuicideEvent'

	DROP TABLE IF EXISTS #StageSuicideEvent

	EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END