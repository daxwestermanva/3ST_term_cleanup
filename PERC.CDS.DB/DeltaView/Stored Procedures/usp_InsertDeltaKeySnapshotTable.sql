






-- =============================================
-- Author:		Mark Swiderski
-- Create date: 2024.05.03
-- Description:	Creates and fills delta key non-persisted snapshot tables scoped to a template routine and data source.
-- =============================================

/*

	EXEC DeltaView.usp_InsertDeltaKeySnapshotTable  'OMHSP_PERC_CDSDev.DeltaView.Common_InpatientRecords_002_POCTestOnly', 'Vista', '1610321293', '2024-05-13 11:01:40.417', '1610323097', '2024-05-13 11:01:40.417', '1610319996', '2024-05-13 11:01:40.417', 0, -999;
	
	EXEC DeltaView.usp_InsertDeltaKeySnapshotTable  'OMHSP_PERC_CDSDev.DeltaView.Common_InpatientRecords_002_POCTestOnly', 'Mill', '1610321293', '2024-05-13 11:01:40.417', '1610323097', '2024-05-13 11:01:40.417', '1610319996', '2024-05-13 11:01:40.417', 0, -999;

*/

CREATE PROCEDURE [DeltaView].[usp_InsertDeltaKeySnapshotTable] 
(
	@RoutineName VARCHAR(255),
	@DeltaEntitySource VARCHAR(50),
	@VistaETLBatchIDHWMValue VARCHAR(255),
	@VistaDateTimeHWMValue VARCHAR(255),
	@MillETLBatchIDHWMValue VARCHAR(255),
	@MillDateTimeHWMValue VARCHAR(255),
	@MVIETLBatchIDHWMValue VARCHAR(255),
	@MVIDateTimeHWMValue VARCHAR(255),
	@IsIgnoreWhereClause BIT,
	@ExecutionLogID INT
)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	
	DECLARE @DeltaEntityName VARCHAR(255);
	DECLARE @DeltaKeySnapshotTableName VARCHAR(255);
	DECLARE @NameOnlyDeltaKeySnapshotTable VARCHAR(255);
	DECLARE @DeltaKeySQL VARCHAR(MAX);
	DECLARE @BaseTablePK VARCHAR(255);
	DECLARE @DeltaEntityRoutineMapIdCount INT;

	/*DECLARE @InsertDeltaKeySnapshotTableSQLTemplate VARCHAR(MAX) = '
		DROP TABLE IF EXISTS $DeltaKeySnapshotTable;

		SELECT
			L.*
		INTO $DeltaKeySnapshotTable
		FROM
		(
			$DeltaKeySQL
		) L ;
		CREATE CLUSTERED INDEX IDX_C_$IDXDeltaKeySnapshotTable ON $DeltaKeySnapshotTable($BaseTablePK);';
		*/


	DECLARE @InsertDeltaKeySnapshotTableSQLTemplate VARCHAR(MAX) = '
		DECLARE @InsertCount INT = 0;
		DECLARE @InsertCountString VARCHAR(20);
		
		
		DROP TABLE IF EXISTS $DeltaKeySnapshotTable;

		SELECT
			L.*,
			IDENTITY(INT) AS DKSeq /*,
			ExecutionLogID = $ExecutionLogID,
			CreateDate = GETDATE()*/
		INTO $DeltaKeySnapshotTable
		FROM
		(
			$DeltaKeySQL
		) L ;

		SET @InsertCount += @@ROWCOUNT;
		SET @InsertCountString = CAST(@InsertCount AS VARCHAR(20));

		EXEC [Log].[Message] @Type = ''Information'',  @Name = ''$NameOnlyDeltaKeySnapshotTable Insert Count'', @Message = @InsertCountString, @ExecutionLogID = $ExecutionLogID; 

		CREATE CLUSTERED INDEX IDX_C_$IDXDeltaKeySnapshotTable ON $DeltaKeySnapshotTable($BaseTablePK);';

	
	SELECT 
		@DeltaEntityRoutineMapIdCount = COUNT(M.DeltaEntityRoutineMapId)
	FROM 
		[DeltaView].[RoutineMasterETL] R WITH(NOLOCK)
		INNER JOIN [DeltaView].[DeltaEntityRoutineMap] M WITH(NOLOCK)
			ON M.RoutineName = R.RoutineName	
	WHERE
		1=1
		AND R.IsEnabled = 1
		AND R.RoutineName = @RoutineName
		AND R.ExtractType = 'Incremental'
		AND M.DeltaEntitySource = @DeltaEntitySource;

	IF(@DeltaEntityRoutineMapIdCount = 0)
	BEGIN
		PRINT'Warning:  This routine and source system is not found.  As this may be by desgin, snapshot insert logic has been skipped.'
		RETURN
	END


	SELECT DISTINCT
		@DeltaEntityName = M.DeltaEntityName,
		@DeltaKeySnapshotTableName = M.DeltaKeySnapshotTableName,
		@BaseTablePK = BTR.BaseTablePK,
		@NameOnlyDeltaKeySnapshotTable = PARSENAME(M.DeltaKeySnapshotTableName, 1)
	FROM 
		[DeltaView].[RoutineMasterETL] R WITH(NOLOCK)
		INNER JOIN [DeltaView].[DeltaEntityRoutineMap] M WITH(NOLOCK)
			ON M.RoutineName = R.RoutineName
		INNER JOIN [DeltaView].[BTRTConfig] BTR WITH(NOLOCK)
			ON BTR.DeltaEntityName = M.DeltaEntityName
			AND BTR.IsBaseTableRootEntity = 1
	WHERE
		1=1
		AND R.IsEnabled = 1
		AND R.RoutineName = @RoutineName
		AND R.ExtractType = 'Incremental'
		AND M.DeltaEntitySource = @DeltaEntitySource;
	
	/*
	SELECT
		DeltaEntityName = @DeltaEntityName,
		DeltaKeySnapshotTableName = @DeltaKeySnapshotTableName;
	*/

	DROP TABLE IF EXISTS #DeltaKeySQL;
	CREATE TABLE #DeltaKeySQL(DeltaKeySQL VARCHAR(MAX) NULL);

	INSERT INTO #DeltaKeySQL
	EXECUTE[DeltaView].[usp_GenerateDeltaSQL] 
	   @DeltaEntityName
	  ,@VistaETLBatchIDHWMValue
	  ,@VistaDateTimeHWMValue
	  ,@MillETLBatchIDHWMValue
	  ,@MillDateTimeHWMValue
	  ,@MVIETLBatchIDHWMValue
	  ,@MVIDateTimeHWMValue
	  ,@IsIgnoreWhereClause
	  ,@ExecutionLogID;

	--SELECT * FROM #DeltaKeySQL;

	SELECT
		@DeltaKeySQL = DeltaKeySQL
	FROM 
		#DeltaKeySQL;

	----SELECT DeltaKeySQL = @DeltaKeySQL;


	SET @InsertDeltaKeySnapshotTableSQLTemplate = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@InsertDeltaKeySnapshotTableSQLTemplate, '$DeltaKeySnapshotTable', @DeltaKeySnapshotTableName), '$DeltaKeySQL', @DeltaKeySQL), '$BaseTablePK', @BaseTablePK), '$IDXDeltaKeySnapshotTable', REPLACE(@DeltaKeySnapshotTableName, '.', '')  ), '$ExecutionLogID', CAST(@ExecutionLogID AS VARCHAR(20)) ), '$NameOnlyDeltaKeySnapshotTable', @NameOnlyDeltaKeySnapshotTable) ;

	SELECT InsertDeltaKeySnapshotTableSQLTemplate = @InsertDeltaKeySnapshotTableSQLTemplate;

	
	BEGIN TRY

		EXEC(@InsertDeltaKeySnapshotTableSQLTemplate);

	END TRY
	BEGIN CATCH

		DECLARE @ErrorMessage NVARCHAR(4000);
		DECLARE @ErrorSeverity INT;
		DECLARE @ErrorState INT;

		DECLARE @InsertDeltaKeySnapshotTableSQLErrorMessageLog VARCHAR(1000) = 'EXEC [Log].[Message] @Type = ''Error'',  @Name = ''Delta Key Insert Error'', @Message = ''INSERT INTO $NameOnlyDeltaKeySnapshotTable failed:  $ErrorMessage'', @ExecutionLogID = $ExecutionLogID;'
	

		SELECT
			@ErrorMessage = ERROR_MESSAGE(),
			@ErrorSeverity = ERROR_SEVERITY(),
			@ErrorState = ERROR_STATE();

		SET @InsertDeltaKeySnapshotTableSQLErrorMessageLog = REPLACE(REPLACE(REPLACE(@InsertDeltaKeySnapshotTableSQLErrorMessageLog, '$NameOnlyDeltaKeySnapshotTable', @NameOnlyDeltaKeySnapshotTable), '$ErrorMessage', @ErrorMessage), '$ExecutionLogID', CAST(@ExecutionLogID AS VARCHAR(20)));

		EXEC(@InsertDeltaKeySnapshotTableSQLErrorMessageLog);

		RAISERROR (@ErrorMessage, 
				   @ErrorSeverity, 
				   @ErrorState 
				   );

	END CATCH
	


END