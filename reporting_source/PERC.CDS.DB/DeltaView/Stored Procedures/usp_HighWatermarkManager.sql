-- =============================================
-- Author:		Mark Swiderski
-- Create date: 2024.06.03
-- Description:	Inserts high watermark values for each source table, source system and Delta Entity Name combination.  Scoped to an ExecutionLogID.  
	---- Downstream logic will fetch HWM values for the last successful execution.
-- Updates:
--	2024/06/06 - JEB -	Formatting, WITH (NOLOCK)s, plus use of SQL database variables
-- =============================================

/*
[DeltaView].[usp_HighWatermarkManager] -72, -1000
*/

CREATE PROCEDURE [DeltaView].[usp_HighWatermarkManager] 
(
	@ExtractBatchLookBackHours INT,
	@ExecutionLogID INT
)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	WITH CTE_BTRTDetail AS (
		SELECT 
			M.DeltaEntitySource,
			BTR.*
		FROM 
			[DeltaView].[RoutineMasterETL] R WITH (NOLOCK)
			INNER JOIN [DeltaView].[DeltaEntityRoutineMap] M WITH (NOLOCK)
				ON M.RoutineName = R.RoutineName
			INNER JOIN [DeltaView].[BTRTConfig] BTR WITH (NOLOCK)
				ON BTR.DeltaEntityName = M.DeltaEntityName
				AND BTR.IsBaseTableRootEntity = 1
		WHERE
			1=1
			AND R.IsEnabled = 1
		
	),

	CTE_DistinctVista AS (
		SELECT
			D.DeltaEntitySource,
			D.DeltaEntityName,
			SourceTable = D.BaseTableName
		FROM 
			CTE_BTRTDetail D
		WHERE
			1=1
			AND D.DeltaEntitySource = 'Vista' 

		UNION

		SELECT
			D.DeltaEntitySource,
			D.DeltaEntityName,
			D.RelatedTableName
		FROM 
			CTE_BTRTDetail D
		WHERE
			1=1
			AND D.DeltaEntitySource = 'Vista'
	),
	CTE_DistinctMill AS (
		SELECT
			D.DeltaEntitySource,
			D.DeltaEntityName,
			SourceTable = D.BaseTableName
		FROM 
			CTE_BTRTDetail D
		WHERE
			1=1
			AND D.DeltaEntitySource = 'Mill' 

		UNION

		SELECT
			D.DeltaEntitySource,
			D.DeltaEntityName,
			D.RelatedTableName
		FROM 
			CTE_BTRTDetail D
		WHERE
			1=1
			AND D.DeltaEntitySource = 'Mill'
	),
	CTE_AllSourceTables AS(

		SELECT * FROM CTE_DistinctVista
	
		UNION ALL
	
		SELECT * FROM CTE_DistinctMill

	),
	CTE_LatestETLBatchIDByTable AS
	(
		SELECT
			L.*
		FROM
		(
			SELECT
				AST.DeltaEntityName,
				AST.SourceTable,
				Seq = ROW_NUMBER() OVER (PARTITION BY V.SourceSystem, V.DWPhysicalTableName ORDER BY EB.ETLBatchID DESC),
				V.SourceSystem,
				EB.*
			FROM 
				[$(CDWLocal)].[Extract].[ExtractBatch] EB WITH (NOLOCK)
				LEFT JOIN [$(CDW02)].[Meta].[DWViewT] V WITH (NOLOCK)
					ON V.DWPhysicalTableName = EB.DWPhysicalTableName
				INNER JOIN CTE_AllSourceTables AST
					ON AST.SourceTable = EB.DWFullTableName
			WHERE
				1=1
				--AND EB.DWFullTableName IN (SELECT SourceTable FROM CTE_AllSourceTables)

				AND EB.ETLBatchLoadedDateTime >=  DATEADD(HH, ABS(@ExtractBatchLookBackHours) * -1, GETDATE() )
		) L
		WHERE
			1=1
			AND L.Seq = 1
	)

	SELECT 
		LT.DeltaEntityName,
		LT.SourceTable,
		------LT.Seq,
		LT.SourceSystem,
		LT.ExtractBatchID,
		LT.ETLBatchID,
		LT.DWPhysicalTableName,
		LT.ETLBatchLoadedDateTime,
		LT.ExtractBatchLoadedDateTime,
		LT.DWFullTableName,
		ExecutionLogID = @ExecutionLogID
	INTO #LatestETLBatchIDByTable
	FROM 
		CTE_LatestETLBatchIDByTable LT;
	
	BEGIN TRY

		BEGIN TRAN

		MERGE INTO [DeltaView].[HighWatermarkConfig] TRG
		USING #LatestETLBatchIDByTable SRC
		ON (
			TRG.DeltaEntityName = SRC.DeltaEntityName
			AND TRG.SourceTable = SRC.SourceTable
			AND TRG.SourceSystem = SRC.SourceSystem
			AND TRG.ExecutionLogID = SRC.ExecutionLogID
		)
		WHEN NOT MATCHED THEN
		INSERT
		(
			[DeltaEntityName],
			[SourceTable],
			[SourceSystem],
			[ExtractBatchID],
			[ETLBatchID],
			[DWPhysicalTableName],
			[ETLBatchLoadedDateTime],
			[ExtractBatchLoadedDateTime],
			[DWFullTableName],
			[ExecutionLogID],
			[CreateDate],
			[EditDate]
		)
		VALUES
		(
			SRC.[DeltaEntityName],
			SRC.[SourceTable],
			SRC.[SourceSystem],
			SRC.[ExtractBatchID],
			SRC.[ETLBatchID],
			SRC.[DWPhysicalTableName],
			SRC.[ETLBatchLoadedDateTime],
			SRC.[ExtractBatchLoadedDateTime],
			SRC.[DWFullTableName],
			SRC.[ExecutionLogID],
			GETDATE(), ----[CreateDate],
			GETDATE() -----[EditDate]
		);

		COMMIT

	END TRY
	BEGIN CATCH

		ROLLBACK

		DECLARE @ErrorMessage NVARCHAR(4000);
		DECLARE @ErrorSeverity INT;
		DECLARE @ErrorState INT;

		DECLARE @MergeHighWatermarkConfigErrorMessageLog VARCHAR(1000) = 'EXEC [Log].[Message] @Type = ''Error'',  @Name = ''HighWatermarkConfig Insert Error'', @Message = ''INSERT INTO [DeltaView].[HighWatermarkConfig] failed:  $ErrorMessage'', @ExecutionLogID = $ExecutionLogID;'
	

		SELECT
			@ErrorMessage = ERROR_MESSAGE(),
			@ErrorSeverity = ERROR_SEVERITY(),
			@ErrorState = ERROR_STATE();

		SET @MergeHighWatermarkConfigErrorMessageLog = REPLACE(REPLACE(@MergeHighWatermarkConfigErrorMessageLog, '$ErrorMessage', @ErrorMessage), '$ExecutionLogID', CAST(@ExecutionLogID AS VARCHAR(20)));

		EXEC(@MergeHighWatermarkConfigErrorMessageLog);

		RAISERROR (@ErrorMessage, 
				   @ErrorSeverity, 
				   @ErrorState 
				   );

	END CATCH
	
END
