-- =============================================
-- Author:		Mark Swiderski
-- Create date: 2024.05.03
-- Description:	Takes template routine as input and adds joins to DeltaKey tables.
-- =============================================

/*

	EXEC DeltaView.usp_CreateRoutineFromTemplate 'OMHSP_PERC_CDSDev.DeltaView.Common_InpatientRecords_002_POCTestOnly';
	EXEC DeltaView.usp_CreateRoutineFromTemplate 'OMHSP_PERC_CDSDev.DeltaView.UpdateMVIPersonSIDPatientPersonSID_POCTestOnly';

*/

CREATE PROCEDURE [DeltaView].[usp_CreateRoutineFromTemplate]
(
	@RoutineName VARCHAR(255)
)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @ReplacedRoutineName VARCHAR(255) = QUOTENAME(PARSENAME(@RoutineName , 2)) + '.' + QUOTENAME(PARSENAME(@RoutineName , 1) + '_REPLACED' );

	DECLARE @DeltaEntityName VARCHAR(255);------- = 'Vista_Common_InpatientRecords_002';
	DECLARE @CreateRoutineString VARCHAR(1000) = 'CREATE PROCEDURE ' +  QUOTENAME(PARSENAME(@RoutineName , 2)) + '.' + QUOTENAME(PARSENAME(@RoutineName , 1)) ;	
	DECLARE @CreateReplacedRoutineString VARCHAR(1000) = 'CREATE OR ALTER PROCEDURE ' +  @ReplacedRoutineName;
	-------DECLARE @CreateReplacedRoutineString VARCHAR(1000) = 'CREATE OR ALTER PROCEDURE ' +  QUOTENAME(PARSENAME(@RoutineName , 2)) + '.' + QUOTENAME(PARSENAME(@RoutineName , 1) + '_REPLACED' ) ;

	DECLARE @DeltaKeySnapshotTableName VARCHAR(255);
	DECLARE @RoutineDefinitionTemplate VARCHAR(MAX);
	DECLARE @RoutineDefinitionActive VARCHAR(MAX);
	DECLARE @SearchTermStart VARCHAR(50);
	DECLARE @SearchTermEnd VARCHAR(50);

	DECLARE @ReplacementCounter INT = 0;
	DECLARE @LoopCounter INT = 1;
	DECLARE @PositionStart INT;
	DECLARE @PositionStop INT;
	DECLARE @CurrentString VARCHAR(MAX);


	DROP TABLE IF EXISTS #Map;

	SELECT
		M.*
	INTO #Map
	FROM 
		[DeltaView].[DeltaEntityRoutineMap] M WITH(NOLOCK)
		INNER JOIN [DeltaView].[RoutineMasterETL] R WITH(NOLOCK)
			ON M.RoutineName = R.RoutineName
	WHERE
		1=1
		AND R.RoutineName = @RoutineName
		AND R.IsEnabled = 1;

	--SELECT * FROM #Map;

	SELECT DISTINCT 
		@RoutineDefinitionTemplate = OBJECT_DEFINITION(OBJECT_ID(M.RoutineName))
	FROM 
		#Map M;

	----SELECT @RoutineDefinitionTemplate


	SET @RoutineDefinitionActive = @RoutineDefinitionTemplate;


	DECLARE DECursor CURSOR FOR
	SELECT DeltaEntityName FROM #Map;

	OPEN DECursor

	FETCH NEXT FROM DECursor INTO @DeltaEntityName;

	WHILE @@FETCH_STATUS = 0
	BEGIN

	
		SET @LoopCounter = 1;

		SELECT
			@SearchTermStart = '/*<' + M.DeltaEntitySource + '>',
			@SearchTermEnd = '</' + M.DeltaEntitySource + '>*/',
			@DeltaKeySnapshotTableName = DeltaKeySnapshotTableName
			-------------------@RoutineDefinitionTemplate = OBJECT_DEFINITION(OBJECT_ID(M.RoutineName))
		FROM 
			#Map M --[OMHSP_PERC_CDSDev].[DeltaView].[DeltaEntityRoutineMap] M
		WHERE
			1=1
			AND M.DeltaEntityName = @DeltaEntityName;


		------SELECT @SearchTermStart, @SearchTermEnd

		--count instances of strings to be replaced
		SELECT 
			@ReplacementCounter = (LEN(@RoutineDefinitionActive) - LEN(REPLACE(@RoutineDefinitionActive,@SearchTermStart,'')) ) / LEN(@SearchTermStart);

		-------SELECT @ReplacementCounter;


		WHILE (@LoopCounter <= @ReplacementCounter)
		BEGIN

			SELECT @PositionStart = CHARINDEX(@SearchTermStart, @RoutineDefinitionActive);
			SELECT @PositionStop = CHARINDEX(@SearchTermEnd, @RoutineDefinitionActive);


			SELECT @CurrentString = SUBSTRING(@RoutineDefinitionActive, @PositionStart, (@PositionStop - @PositionStart) + LEN(@SearchTermEnd) );

			SET @CurrentString = REPLACE(REPLACE(REPLACE(@CurrentString, '$DeltaKeyTable', @DeltaKeySnapshotTableName), @SearchTermStart, ''), @SearchTermEnd, '');

			/*
			SELECT 
				PositionStart = @PositionStart, 
				PositionStop = @PositionStop, 
				LEN(@RoutineDefinitionActive),
				CurrentString = @CurrentString;
			*/


			SET @RoutineDefinitionActive = STUFF(@RoutineDefinitionActive , @PositionStart , (@PositionStop - @PositionStart) + LEN(@SearchTermEnd) , @CurrentString )


			SET @LoopCounter += 1;

	

		END  ----END WHILE @LoopCounter <= @ReplacementCounter


		FETCH NEXT FROM DECursor INTO @DeltaEntityName;

	

	END  ----end cursor

	CLOSE DECursor;
	DEALLOCATE DECursor;

	SET @RoutineDefinitionActive = REPLACE(@RoutineDefinitionActive, @CreateRoutineString, @CreateReplacedRoutineString);



	--SELECT RoutineDefinitionActive = @RoutineDefinitionActive;


	EXEC(@RoutineDefinitionActive);

	--final result value
	SELECT
		ReplacedRoutineName = @ReplacedRoutineName;

END