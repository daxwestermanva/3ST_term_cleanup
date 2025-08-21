
/*=============================================
Author:		Susana Martins
Create date: 2/26/18
Purpose: Identify if active diagnosis was last entered for AUD and OUD
Updates:
	2018-06-07	Jason Bacani - Removed hard coded database references
	2019-02-16	Jason Bacani - Refactored to use [Maintenance].[PublishTable]; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
	2020-08-10	RAS - Updated to use Present.Diagnosis.
	2020-10-30	RAS - Pointed to VM tables.
	2021-03-08	MCP - removed PatientSID in favor of MVIPersonSID
	2021-09-09	JEB	- Enclave Refactoring - Counts confirmed; Some additional formatting; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	2021-10-12	LM:  Specifying outpat, inpat, and DoD diagnoses (excluding dx only from community care or problem list)
	2022-02-14	MCP - switch to Present.Diagnosis
	2022-03-21	MCP - Simplified using existing Present.DiagnosisDate for most recent dx dates
	2024-02-22	MCP - Changing reference to AUD to AUD_ORM to match ALC_top measure def

	Testing execution:
		EXEC [Code].[PDSI_OUD_AUD_Active]

	Helpful Auditing Scripts

		SELECT TOP 5 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
		FROM [Log].[ExecutionLog] WITH (NOLOCK)
		WHERE name = 'Code.PDSI_OUD_AUD_Active'
		ORDER BY ExecutionLogID DESC

		SELECT TOP 6 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE TableName = 'AUD_OUD_Active' ORDER BY 1 DESC

===============================================*/
CREATE PROCEDURE [Code].[PDSI_OUD_AUD_Active]
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] @Name = 'Code.PDSI_OUD_AUD_Active', @Description = 'Execution of Code.PDSI_OUD_AUD_Active SP'

	 --<FilterExpression>=Switch(Parameters!Remission.Value=0,1, Parameters!Remission.Value=1 and Fields!AUDdx_Active.Value=1 ,1,  Parameters!Remission.Value=2 and Fields!OUDdx_Active.Value=1,1,Parameters!Remission.Value=3 and Fields!OUD_OpioidUse.Value=0,1)</FilterExpression>

	--All patients with OUD or AUD
	DROP TABLE IF EXISTS #Pts
	SELECT
		 MVIPersonSID
		,DxCategory
	INTO #Pts
	FROM [Present].[Diagnosis] WITH (NOLOCK)
	WHERE (Outpat = 1 or Inpat = 1 or DoD = 1) AND (DxCategory like 'OUD' or DxCategory like 'AUD_ORM')

	-----------------------------------------------------------------------------
	-- OUD
	-----------------------------------------------------------------------------
	-- All active OUD dates
	DROP TABLE IF EXISTS #OUD_active
	SELECT DISTINCT
		 d.MVIPersonSID
		,d.ICD10Code
		,MostRecentDate as ActiveDate
	INTO #OUD_active
	FROM [Present].[DiagnosisDate] d WITH (NOLOCK)
	INNER JOIN [LookUp].[ICD10] li WITH (NOLOCK)
		ON li.ICD10Code = d.ICD10Code 
	INNER JOIN #Pts p
		ON p.MVIPersonSID = d.MVIPersonSID 
	WHERE OUD = 1 AND p.DxCategory like 'OUD' and d.ICD10Code NOT IN ('F11.11','F11.21')

	--All remission OUD dates
	DROP TABLE IF EXISTS #OUD_remission
	SELECT DISTINCT
		 d.MVIPersonSID
		,d.ICD10Code
		,MostRecentDate as RemissionDate
	INTO #OUD_remission
	FROM [Present].[DiagnosisDate] d WITH (NOLOCK)
	INNER JOIN [LookUp].[ICD10] li WITH (NOLOCK)
		ON li.ICD10Code = d.ICD10Code 
	INNER JOIN #Pts p
		ON p.MVIPersonSID = d.MVIPersonSID 
	WHERE OUD = 1 AND p.DxCategory like 'OUD' and d.ICD10Code IN ('F11.11','F11.21')

	--Join and grab most recent active date if not in remission
	DROP TABLE IF EXISTS #OUDactivemostrecent
	SELECT MVIPersonSID
		  ,OUDActiveMostRecent = 1
		  ,MAX(ActiveDate) as MaxActiveDate
	INTO #OUDactivemostrecent
	FROM (
		SELECT ISNULL(a.MVIPersonSID,b.MVIPersonSID) as MVIPersonSID
			  ,ActiveDate
			  ,RemissionDate
		FROM #OUD_active a
		FULL OUTER JOIN #OUD_remission b
			ON a.MVIPersonSID=b.MVIPersonSID
		) a
	WHERE ActiveDate > RemissionDate OR RemissionDate IS NULL
	GROUP BY MVIPersonSID

	-----------------------------------------------------------------------------
	-- AUD
	-----------------------------------------------------------------------------
	-- All active AUD dates
	DROP TABLE IF EXISTS #AUD_active
	SELECT DISTINCT
		 d.MVIPersonSID
		,d.ICD10Code
		,MostRecentDate as ActiveDate
	INTO #AUD_active
	FROM [Present].[DiagnosisDate] d WITH (NOLOCK)
	INNER JOIN [LookUp].[ICD10] li WITH (NOLOCK)
		ON li.ICD10Code = d.ICD10Code 
	INNER JOIN #Pts p
		ON p.MVIPersonSID = d.MVIPersonSID 
	WHERE AUD = 1 AND p.DxCategory like 'AUD_ORM' and d.ICD10Code NOT IN ('F10.11','F10.21')

	--All remission AUD dates
	DROP TABLE IF EXISTS #AUD_remission
	SELECT DISTINCT
		 d.MVIPersonSID
		,d.ICD10Code
		,MostRecentDate as RemissionDate
	INTO #AUD_remission
	FROM [Present].[DiagnosisDate] d WITH (NOLOCK)
	INNER JOIN [LookUp].[ICD10] li WITH (NOLOCK)
		ON li.ICD10Code = d.ICD10Code 
	INNER JOIN #Pts p
		ON p.MVIPersonSID = d.MVIPersonSID 
	WHERE AUD = 1 AND p.DxCategory like 'AUD_ORM' and d.ICD10Code IN ('F10.11','F10.21')

	--Join and grab most recent active date if not in remission
	DROP TABLE IF EXISTS #AUDactivemostrecent
	SELECT MVIPersonSID
		  ,AUDActiveMostRecent = 1
		  ,MAX(ActiveDate) as MaxActiveDate
	INTO #AUDactivemostrecent
	FROM (
		SELECT ISNULL(a.MVIPersonSID,b.MVIPersonSID) as MVIPersonSID
			  ,ActiveDate
			  ,RemissionDate
		FROM #AUD_active a
		FULL OUTER JOIN #AUD_remission b
			ON a.MVIPersonSID=b.MVIPersonSID
		) a
	WHERE ActiveDate > RemissionDate OR RemissionDate IS NULL
	GROUP BY MVIPersonSID

	-----------------------------------------------------------------------------
	-- staging table with active most recent patients flagged
	-----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #AUD_OUD_Active
	SELECT DISTINCT sa.MVIpersonSID
		,ISNULL(aud.AUDActiveMostrecent,0) as AUDActiveMostrecent
		,ISNULL(oud.OUDActiveMostRecent,0) as OUDActiveMostRecent
	INTO #AUD_OUD_Active
	FROM [Present].[StationAssignments] sa WITH (NOLOCK)
	LEFT JOIN #AUDactivemostrecent aud ON sa.MVIPersonSID = aud.MVIPersonSID 
	LEFT JOIN #OUDactivemostrecent oud ON sa.MVIPersonSID = oud.MVIPersonSID
	WHERE sa.PDSI = 1 
		AND (aud.MVIPersonSID IS NOT NULL OR oud.MVIPersonSID IS NOT NULL)

	--FINAL TABLE
	EXEC [Maintenance].[PublishTable] 'PDSI.AUD_OUD_Active', '#AUD_OUD_Active'

	EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END