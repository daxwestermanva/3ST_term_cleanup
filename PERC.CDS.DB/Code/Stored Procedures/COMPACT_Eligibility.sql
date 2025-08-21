
/*******************************************************************
AUTHOR:			Liam Mina

DESCRIPTION:	Log history of changes to administrative eligibility for COMPACT
			
MODIFICATIONS:
*******************************************************************/
CREATE PROCEDURE [Code].[COMPACT_Eligibility]
AS
BEGIN

	--EXEC [Log].[ExecutionBegin] 'EXEC Code.COMPACT_Eligibility','Execution of Code.COMPACT_Eligibility Stored Procedure'



	DROP TABLE IF EXISTS #COMPACT
	CREATE TABLE #COMPACT(
	[MVIPersonSID] [int] NOT NULL,
	[CompactEligible] [tinyint] NULL,
	[StartDate] [datetime2] NULL,
	[EndDate] [datetime2] NULL,
	[ActiveRecord] [tinyint] NULL
	)
	---------------------
	-- FIND ENROLLMENT PRIORITY GROUPS AND PRIORITY SUB GROUPS
	---------------------
	-- Get only most recent record for each patient
	DROP TABLE IF EXISTS #ADR_MostRecent
	SELECT 
		 a.MVIPersonSID
		,MAX(a.RecordModifiedDate) MaxRecordModifiedDate
	INTO #ADR_MostRecent
	FROM [ADR].[ADREnrollHistory] a WITH (NOLOCK) 
	GROUP BY a.MVIPersonSID
	
	-- Get details and make sure there is only 1 possible record with rank=1
	DROP TABLE IF EXISTS #ADRPriority;
	SELECT MVIPersonSID
		,ADRPriorityGroupSID
		,PrioritySubGroupName
		,ADRPrioritySubGroupSID
	INTO #ADRPriority
	FROM (
		SELECT a.MVIPersonSID
			,a.ADRPriorityGroupSID
			,c.PrioritySubGroupName
			,a.ADRPrioritySubGroupSID
			,a.RecordModifiedDate
			,b.EnrollStatusName
			,b.EnrollCategoryName
			,RANK() OVER (
				PARTITION BY a.MVIPersonSID ORDER BY a.RecordModifiedDate DESC, a.RecordModifiedCount DESC 
				) RecordRank
		FROM [ADR].[ADREnrollHistory] a WITH (NOLOCK) 
		INNER JOIN #ADR_MostRecent mr 
			ON mr.MVIPersonSID = a.MVIPersonSID 
			AND mr.MaxRecordModifiedDate = a.RecordModifiedDate
		INNER JOIN [NDim].[ADREnrollStatus] b WITH (NOLOCK) 
			ON a.ADREnrollStatusSID = b.ADREnrollStatusSID
		INNER JOIN [NDim].[ADRPrioritySubGroup] c WITH (NOLOCK) 
			ON a.ADRPrioritySubGroupSID = c.ADRPrioritySubGroupSID
		) Ranked
	WHERE Ranked.RecordRank=1

	---------------------
	-- GET COMPACT ACT ELIGIBILITY
	---------------------

	INSERT INTO #COMPACT
	SELECT TOP 1 WITH TIES
		 MVIPersonSID
		,COMPACTEligible = MAX(CompactEligible) OVER (PARTITION BY MVIPersonSID)
		,StartDate = GetDate()
		,EndDate= GetDate()
		,ActiveRecord = 1
	FROM (
		SELECT a.MVIPersonSID
			,CompactEligible = CASE WHEN b.Eligibility = 'COMPACT ACT ELIGIBLE' THEN 1 ELSE 0 END
		FROM Common.vwMVIPersonSIDPatientPersonSID a WITH (NOLOCK)
		LEFT JOIN PatSub.SecondaryEligibility c WITH (NOLOCK)
			ON a.PatientPersonSID=c.PatientSID
		LEFT JOIN Dim.Eligibility b WITH (NOLOCK) on c.EligibilitySID=b.EligibilitySID
			
		UNION

		SELECT MVIPersonSID
			,CompactEligible = 1
		FROM #ADRPriority 
		WHERE ADRPriorityGroupSID BETWEEN 1 AND 8
			AND PrioritySubGroupName NOT IN ('e','g')
		) a
	ORDER BY ROW_NUMBER() OVER(PARTITION BY a.MVIPersonSID ORDER BY a.CompactEligible DESC)
	
	--drop table if exists #proddata
	--select *,updatesource=-1 into #proddata from compact.eligibility

	DECLARE @rows int = (SELECT COUNT(*) FROM [COMPACT].[Eligibility])

	--DECLARE @rows int = (SELECT COUNT(*) FROM #proddata)
	;
	--If there are rows in the table, merge updated data with existing data
	IF @rows >0
	BEGIN TRY
		BEGIN TRANSACTION
						
		MERGE [COMPACT].[Eligibility] WITH(TABLOCK) t USING #COMPACT s
				ON (s.MVIPersonSID = t.MVIPersonSID AND s.ActiveRecord = t.ActiveRecord) 
			WHEN MATCHED 
				AND NOT EXISTS ( -- only update if a value in the row has changed
					SELECT t.MVIPersonSID, t.COMPACTEligible
					INTERSECT
					SELECT s.MVIPersonSID, s.COMPACTEligible
					)
				THEN 
				UPDATE 
				SET MVIPersonSID = t.MVIPersonSID
					,COMPACTEligible = t.COMPACTEligible
					,StartDate = t.StartDate
					,EndDate = s.EndDate
					,ActiveRecord=0
					--,UpdateSource=1
			WHEN NOT MATCHED BY TARGET --If patient had no previous COMPACT eligibility records, add active row into table
				THEN
				INSERT (MVIPersonSID, COMPACTEligible, StartDate, EndDate, ActiveRecord)--,UpdateSource)
				VALUES (s.MVIPersonSID, s.COMPACTEligible, s.StartDate, CAST(NULL AS datetime2), 1)--,3)
			WHEN NOT MATCHED BY SOURCE --If patient no longer exists in data, set end date on active record
				AND t.ActiveRecord=1
				AND t.EndDate IS NULL
				THEN UPDATE			
				SET EndDate = Getdate()
				--,UpdateSource=2
				;
	
			MERGE [COMPACT].[Eligibility] WITH(TABLOCK) t USING #COMPACT s
				ON (s.MVIPersonSID = t.MVIPersonSID AND s.ActiveRecord = t.ActiveRecord AND s.CompactEligible = t.COMPACTEligible)
				WHEN NOT MATCHED BY TARGET --If patient's COMPACT eligibility has changed, insert current record (previous record was updated in previous merge)
				THEN
				INSERT (MVIPersonSID, COMPACTEligible, StartDate, EndDate, ActiveRecord)--,UpdateSource)
				VALUES (s.MVIPersonSID, s.COMPACTEligible, s.StartDate, CAST(NULL AS datetime2), 1)--,4)
				;
		
		;
		COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
			PRINT 'Error occurred within transaction; transaction rolled back';
			EXEC [Log].[ExecutionEnd] @Status = 'Error';
			THROW; 
		END CATCH


	--If there are no rows in the table (e.g., first time the data is being run), insert data into table
	IF @rows = 0 
	BEGIN
	INSERT INTO [COMPACT].[Eligibility]
	SELECT MVIPersonSID
		,COMPACTEligible
		,StartDate = '2023-01-17'
		,EndDate = NULL
		,ActiveRecord
	FROM #COMPACT
	END
		

	EXEC [Log].[ExecutionEnd]

END