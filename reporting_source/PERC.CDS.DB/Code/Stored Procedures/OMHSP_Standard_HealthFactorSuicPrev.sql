


-- =============================================
-- Author:		<Susana Martins>
-- Create date: <10/23/18>
-- Description:	Health factors that relate to suicide prevention monitoring
-- Modifications:
--		2019-01-08 LM: added columns for VisitSID and HealthFactorTypeSID, and commented out HealthFactorDateTimeSec
--		2019-01-28 LM: added 'Safety Plan Decline' category
--		2019-01-30 LM: added 'Safety Plan Lethal Means' category
--		2019-02-25 LM: Change to pull in Category like 'SBOR%' due to many SBOR-related categories
--		2019-05-08 RS: Renamed to OMHSP_Standard_HealthFactor; altered to included decedents
--		2019-05-30 RAS: Temp fix for missing MVIPersonSIDs in HF.HealthFactor 
--					    Added join to SPatient and DISTINCT
--		2020-03-18 LM: Added Suicide Risk Management Follow-Up category
--		2020-07-07 LM: Removed join on SPatient.SPatient
--		2020-08-07 LM: Added Cerner PowerForm data
--		2021-08-24 JEB: Enclave Refactoring - Counts confirmed; Some additional formatting; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; Added logging
--		2023-11-15 LM: Added initial build parameter to only look back 1 year and replace that data instead of doing full reload nightly.
--		2025-03-17 LM: Exclude "injury by other" DTA responses from step that gets comment value for "Other: " DTA responses
--
-- Testing execution:
--		EXEC [Code].[OMHSP_Standard_HealthFactorSuicPrev]
--
-- Helpful Auditing Scripts
--
--		SELECT TOP 5 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
--		FROM [Log].[ExecutionLog] WITH (NOLOCK)
--		WHERE name = 'Code.OMHSP_Standard_HealthFactorSuicPrev'
--		ORDER BY ExecutionLogID DESC
--
--		SELECT TOP 2 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE TableName = 'HealthFactorSuicPrev' ORDER BY 1 DESC
--
-- =============================================
CREATE PROCEDURE [Code].[OMHSP_Standard_HealthFactorSuicPrev]
	@InitialBuild BIT = 0
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] @Name = 'Code.OMHSP_Standard_HealthFactorSuicPrev', @Description = 'Execution of Code.OMHSP_Standard_HealthFactorSuicPrev SP'
	
	--DECLARE @InitialBuild BIT = 0
	DECLARE @BeginDate DATE 

	IF (SELECT COUNT(*) FROM OMHSP_Standard.HealthFactorSuicPrev)=0 --if table is empty, populate with all data
	BEGIN SET @InitialBuild = 1
	END;

	IF @InitialBuild = 1 
	BEGIN
		SET @BeginDate = '2018-01-01' --(mindatetime available for these categories is 2/27/2018 11:49:53 AM)
	END
	ELSE 
	BEGIN
		SET @BeginDate = DATEADD(DAY,-365,CAST(GETDATE() AS DATE))
	END

	-- Creating view to identify relevant SID's
	DROP TABLE IF EXISTS #HealthFactors;
	SELECT 
		 c.Category
		,m.List
		,m.ItemID
		,m.AttributeValue
		,m.Attribute
		,c.Printname
	INTO #HealthFactors
	FROM [Lookup].[ListMember] m WITH (NOLOCK)
	INNER JOIN [Lookup].[List] c WITH (NOLOCK) 
		ON m.List = c.List
	WHERE c.Category IN ('CSRE','NALOXONE','Safety Plan','Safety Plan Decline','Safety Plan Lethal Means','Standalone I9','Suicide Risk Management','HRS-PRF Review') 
		OR c.Category like 'SBOR%'			
	;	

	-- First get VistA Health Factor SIDs
	DROP TABLE IF EXISTS #PatientHealthFactorSuicideVistA; 
	SELECT 
		 ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
		,h.VisitSID 
		,h.Sta3n
		,h.HealthFactorSID
		,NULL AS DocFormActivitySID
		,CONVERT(VARCHAR(16),h.HealthFactorDateTime) AS HealthFactorDateTime --removing the seconds from the HF date since the note date doesnt have seconds
		,h.Comments
		,HF.Category
		,HF.List
		,HF.PrintName
	INTO  #PatientHealthFactorSuicideVistA
	FROM [HF].[HealthFactor] h WITH (NOLOCK) 
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON h.PatientSID = mvi.PatientPersonSID 
	INNER JOIN #HealthFactors HF WITH (NOLOCK) 
		ON HF.ItemID = h.HealthFactorTypeSID
	WHERE h.HealthFactorDateTime >= @BeginDate
		AND HF.Attribute = 'HealthFactorType'
	
	-- Pulling in data required to expose Suicide Related Health Factors
	DROP TABLE IF EXISTS #AddLocationsVistA; 
	SELECT 
		 h.MVIPersonSID
		,ISNULL(dd.ChecklistID,h.Sta3n) AS ChecklistID
		,h.VisitSID 
		,h.Sta3n
		,h.HealthFactorSID
		,h.DocFormActivitySID
		,h.HealthFactorDateTime
		,h.Comments
		,h.Category
		,h.List
		,h.PrintName
	INTO  #AddLocationsVistA
	FROM #PatientHealthFactorSuicideVistA h WITH (NOLOCK) 
	INNER JOIN [Outpat].[Visit] v WITH (NOLOCK) 
		ON h.VisitSID = v.VisitSID
	LEFT JOIN [Lookup].[DivisionFacility] dd WITH (NOLOCK) 
		ON dd.DivisionSID = v.DivisionSID
	;
	DROP TABLE IF EXISTS #PatientHealthFactorSuicideVistA

	DROP TABLE IF EXISTS #Comments
	SELECT 
		 c.Category
		,c.List
		,c.ItemID
		,p.DerivedDtaEventResult AS AttributeValue
		,c.Attribute
		,p.DocFormActivitySID
	INTO #Comments
	FROM #HealthFactors c 
	INNER JOIN [Cerner].[FactPowerForm] p WITH (NOLOCK) 
		ON c.ItemID = p.DerivedDtaEventCodeValueSID
	WHERE c.Attribute = 'Comment'
	;

	DROP TABLE IF EXISTS #PatientHealthFactorSuicideCerner; 
	SELECT  
		 h.MVIPersonSID
		,ISNULL(ch.ChecklistID,s.checklistID) AS ChecklistID
		,h.EncounterSID 
		,200 AS Sta3n
		,h.DerivedDtaEventCodeValueSID as DtaEventCodeValueSID 
		,h.DocFormActivitySID
		,CONVERT(VARCHAR(16),h.TZFormUTCDateTime) AS HealthFactorDateTime 
		,c.AttributeValue AS Comments
		,HF.Category
		,HF.List
		,HF.PrintName
	INTO #PatientHealthFactorSuicideCerner
	FROM [Cerner].[FactPowerForm] h WITH (NOLOCK) 
	INNER JOIN #HealthFactors HF WITH (NOLOCK) 
		ON HF.ItemID = h.DerivedDtaEventCodeValueSID 
		AND HF.AttributeValue = h.DerivedDtaEventResult
	LEFT JOIN #Comments c WITH (NOLOCK) 
		ON HF.List = c.List
		AND h.DocFormActivitySID = c.DocFormActivitySID
	LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
		ON h.StaPa = ch.StaPa
	LEFT JOIN (SELECT sc.EncounterSID, l.ChecklistID, sc.TZServiceDateTime FROM [Cerner].[FactUtilizationStopCode] sc WITH (NOLOCK)
				INNER JOIN [Lookup].[Sta6a] l WITH (NOLOCK)
				ON sc.DerivedSta6a = l.Sta6a
				) s
		ON s.EncounterSID = h.EncounterSID AND CAST(s.TZServiceDateTime as date)=CAST(h.TZClinicalSignificantModifiedDateTime as date)
	WHERE HF.Attribute ='DTA'
	AND h.TZFormUTCDateTime >= @BeginDate
	UNION ALL 
	SELECT  
		 h.MVIPersonSID
		,ISNULL(ch.ChecklistID,s.checklistID) AS ChecklistID
		,h.EncounterSID 
		,200 AS Sta3n
		,h.DerivedDtaEventCodeValueSID as DtaEventCodeValueSID
		,h.DocFormActivitySID
		,CONVERT(VARCHAR(16),h.TZFormUTCDateTime) AS HealthFactorDateTime 
		,h.DerivedDTAEventResult AS Comments
		,HF.Category
		,HF.List
		,HF.PrintName
	FROM [Cerner].[FactPowerForm] h WITH (NOLOCK) 
	INNER JOIN #HealthFactors HF WITH (NOLOCK) 
		ON HF.ItemID = h.DerivedDtaEventCodeValueSID
	LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
		ON h.StaPa = ch.StaPa
	LEFT JOIN (SELECT sc.EncounterSID, l.ChecklistID, sc.TZServiceDateTime FROM [Cerner].[FactUtilizationStopCode] sc WITH (NOLOCK)
				INNER JOIN [Lookup].[Sta6a] l WITH (NOLOCK)
				ON sc.DerivedSta6a = l.Sta6a
				) s
		ON s.EncounterSID = h.EncounterSID AND CAST(s.TZServiceDateTime as date)=CAST(h.TZClinicalSignificantModifiedDateTime as date)
	WHERE (HF.Attribute ='DTA' AND ((h.DerivedDTAEventResult LIKE 'Other:%' AND List LIKE '%Other%' AND List <>'SBOR_MethodTypeInjByOther_HF') --"injury by other" is handled in step above; excluding it in this step prevents duplicate/erroneous rows
		OR (h.DerivedDTAEventResult like 'Overdose,%' AND List='SBOR_MethodTypeOverdose_HF')))
	AND h.TZFormUTCDateTime >= @BeginDate
	UNION ALL
	SELECT  
		h.MVIPersonSID
		,ISNULL(ch.ChecklistID,s.checklistID) AS ChecklistID
		,h.EncounterSID 
		,200 AS Sta3n
		,h.DerivedDtaEventCodeValueSID as DtaEventCodeValueSID
		,h.DocFormActivitySID
		,CONVERT(VARCHAR(16),h.TZFormUTCDateTime) AS HealthFactorDateTime 
		,h.DerivedDTAEventResult AS Comments
		,HF.Category
		,HF.List
		,HF.PrintName
	FROM [Cerner].[FactPowerForm] h WITH (NOLOCK) 
	INNER JOIN #HealthFactors HF WITH (NOLOCK) 
		ON HF.ItemID = h.DerivedDtaEventCodeValueSID
	LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
		ON h.StaPa = ch.StaPa
	LEFT JOIN (SELECT sc.EncounterSID, l.ChecklistID, sc.TZServiceDateTime FROM [Cerner].[FactUtilizationStopCode] sc WITH (NOLOCK)
				INNER JOIN [Lookup].[Sta6a] l WITH (NOLOCK)
				ON sc.DerivedSta6a = l.Sta6a
				) s
		ON s.EncounterSID = h.EncounterSID AND CAST(s.TZServiceDateTime as date)=CAST(h.TZClinicalSignificantModifiedDateTime as date)
	WHERE HF.Attribute ='FreeText'
	AND h.TZFormUTCDateTime >= @BeginDate
	;
	DROP TABLE IF EXISTS #HealthFactors
	DROP TABLE IF EXISTS #Comments

	DROP TABLE IF EXISTS #PatientHealthFactorSuicide
	SELECT * 
	INTO #PatientHealthFactorSuicide
	FROM #AddLocationsVistA
	UNION ALL
	SELECT * 
	FROM #PatientHealthFactorSuicideCerner
	;

	DROP TABLE IF EXISTS #AddLocationsVistA
	DROP TABLE IF EXISTS #PatientHealthFactorSuicideCerner;

	DROP TABLE IF EXISTS #StageHealthFactorSuicide;
	SELECT * 
		,DENSE_RANK() OVER (PARTITION BY MVIPersonSID, Category ORDER BY HealthFactorDateTime DESC) AS OrderDesc
	INTO #StageHealthFactorSuicide
	FROM (
		SELECT DISTINCT
			 r.PatientICN
			,h.MVIPersonSID
			,h.Sta3n
			,h.ChecklistID
			,h.VisitSID
			,h.HealthFactorSID
			,h.DocFormActivitySID
			,h.HealthFactorDateTime
			,h.Comments
			,h.Category
			,h.List  
			,h.PrintName
		FROM #PatientHealthFactorSuicide AS h
		INNER JOIN [Common].[MasterPatient] r WITH (NOLOCK) 
			ON r.MVIPersonSID = h.MVIPersonSID
		) x
	;
	DROP TABLE IF EXISTS #PatientHealthFactorSuicide

	--	DECLARE @InitialBuild BIT = 0, @BeginDate DATE = DATEADD(Day,-365,CAST(GETDATE() AS DATE))
	IF @InitialBuild = 1 
	BEGIN
		EXEC [Maintenance].[PublishTable] 'OMHSP_Standard.HealthFactorSuicPrev','#StageHealthFactorSuicide'
	END
	ELSE
	BEGIN
	BEGIN TRY
		BEGIN TRANSACTION
			DELETE [OMHSP_Standard].[HealthFactorSuicPrev] WITH (TABLOCK)
			WHERE HealthFactorDateTime >= @BeginDate
			INSERT INTO [OMHSP_Standard].[HealthFactorSuicPrev] WITH (TABLOCK) (
				PatientICN,MVIPersonSID,Sta3n,ChecklistID,VisitSID,HealthFactorSID,DocFormActivitySID
				,HealthFactorDateTime,Comments,Category,List,PrintName,OrderDesc
				)
			SELECT PatientICN,MVIPersonSID,Sta3n,ChecklistID,VisitSID,HealthFactorSID,DocFormActivitySID
				,HealthFactorDateTime,Comments,Category,List,PrintName,OrderDesc
			FROM #StageHealthFactorSuicide 
	
			DECLARE @AppendRowCount INT = (SELECT COUNT(*) FROM #StageHealthFactorSuicide)
			EXEC [Log].[PublishTable] 'OMHSP_Standard','HealthFactorSuicPrev','#StageHealthFactorSuicide','Append',@AppendRowCount
		COMMIT TRANSACTION
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION
		PRINT 'Error publishing to HealthFactorSuicPrev; transaction rolled back';
			DECLARE @ErrorMsg VARCHAR(1000) = ERROR_MESSAGE()
		EXEC [Log].[ExecutionEnd] 'Error' -- Log end of SP
		;THROW 	
	END CATCH

	END;

	DROP TABLE IF EXISTS #StageHealthFactorSuicide
	
	
	
	
	
	
	
	EXEC [Log].[ExecutionEnd] @Status = 'Completed' ;

END