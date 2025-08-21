








-- =============================================
-- Author:		Mark Swiderski
-- Create date: 2024.05.02
-- Description:	Traverses base table/ related table relationships and generates SQL that returns root node delta keys.
-- =============================================

/*

	EXEC DeltaView.[usp_GenerateDeltaSQL] 'Vista_UpdateMVIPersonSIDPatientPersonSID', '1', '2024-05-13 11:01:40.417', '2', '2024-05-13 11:01:40.417', '3', '2024-05-13 11:01:40.417', 0, -99;

	EXEC DeltaView.[usp_GenerateDeltaSQL] 'Mill_UpdateMVIPersonSIDPatientPersonSID', '1', '2024-05-13 11:01:40.417', '2', '2024-05-13 11:01:40.417', '3', '2024-05-13 11:01:40.417', 0, -99;
	
	-------EXEC DeltaView.[usp_GenerateDeltaSQL] 'Mill_UpdateMVIPersonSIDPatientPersonSID', NULL, '2024-05-13 11:01:40.417', '2', '2024-05-13 11:01:40.417', '3', '2024-05-13 11:01:40.417', 0, -99;
	

	EXEC DeltaView.[usp_GenerateDeltaSQL] 'Vista_UpdateMVIPersonSIDPatientPersonSID', '1610321293', '2024-05-13 11:01:40.417', '1610323097', '2024-05-13 11:01:40.417', '1610319996', '2024-05-13 11:01:40.417', 0, -99;
	EXEC DeltaView.[usp_GenerateDeltaSQL] 'Mill_UpdateMVIPersonSIDPatientPersonSID', '1610321293', '2024-05-13 11:01:40.417', '1610323097', '2024-05-13 11:01:40.417', '1610319996', '2024-05-13 11:01:40.417', 0, -99;

	EXEC DeltaView.[usp_GenerateDeltaSQL] 'Vista_COMPACT_Eligibility', '1610321293', '2024-05-13 11:01:40.417', '1610323097', '2024-05-13 11:01:40.417', '1610319996', '2024-05-13 11:01:40.417', 0, -99;


*/


CREATE PROCEDURE [DeltaView].[usp_GenerateDeltaSQL] 
(
	@DeltaEntityName VARCHAR(255),
	@VistaETLBatchIDHWMValue VARCHAR(255),
	@VistaDateTimeHWMValue VARCHAR(255),
	@MillETLBatchIDHWMValue VARCHAR(255),
	@MillDateTimeHWMValue VARCHAR(255),
	@MVIETLBatchIDHWMValue VARCHAR(255),
	@MVIDateTimeHWMValue VARCHAR(255),
	@IsIgnoreWhereClause BIT = 0,
	@ExecutionLogID INT
)
AS
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @AllPathNodeSQL VARCHAR(MAX);
	DECLARE @BaseTableTemplateSQL VARCHAR(MAX) = 'SELECT $BaseTablePK FROM $BaseTableName B WITH(NOLOCK) $WHEREClause';
	DECLARE @ReferencedByJoinMaxNodeTemplateSQL VARCHAR(MAX) = 'SELECT $BaseTablePK FROM $BaseTableName B WITH(NOLOCK) INNER JOIN $RelatedTableName R WITH(NOLOCK) ON $JoinSpec $WHEREClause';
	DECLARE @ReferencedByJoinIntermediateNodeTemplateSQL VARCHAR(MAX) = 'SELECT $BaseTablePK FROM $BaseTableName B WITH(NOLOCK) INNER JOIN ( $PriorNodeSQL ) R ON $JoinSpec';
	DECLARE @ReferencingTableWithCompositePKJoinMaxNodeTemplateSQL VARCHAR(MAX) = 'SELECT $BaseTablePK FROM $RelatedTableName R WITH(NOLOCK) $WHEREClause';
	DECLARE @ReferencingTableWithCompositePKJoinIntermediateNodeTemplateSQL VARCHAR(MAX) = 'SELECT $BaseTablePK FROM ( $PriorNodeSQL ) R';

	DECLARE @ReferencingTableWithSurrogateKeyJoinMaxNodeTemplateSQL VARCHAR(MAX) = '
	SELECT
		$BaseTablePK
	FROM
	(
	SELECT
		$RelatedTablePK
	FROM
		$RelatedTableName R WITH(NOLOCK)
	$WHEREClause
	) L
	INNER JOIN $RelatedTableName R WITH(NOLOCK) ON $SelfJoinSpec 
	
	/*Delete Exception*/

	UNION (SELECT $BaseTablePK FROM $RelatedTableName R WITH(NOLOCK) $DELETEWHEREClause) ';

	DECLARE @ReferencingTableWithSurrogateKeyJoinIntermediateNodeTemplateSQL VARCHAR(MAX) = '
	SELECT
		$BaseTablePK
	FROM
	(
		$PriorNodeSQL	
	) L
	INNER JOIN $RelatedTableName R WITH(NOLOCK) ON $SelfJoinSpec 
	
	/*Delete Exception*/

	UNION (SELECT $BaseTablePK FROM $RelatedTableName R WITH(NOLOCK) $DELETEWHEREClause) ';

	DECLARE @RootEntityTemplateSQL VARCHAR(MAX) = 'SELECT $BaseTablePK FROM $BaseTableName B WITH(NOLOCK) $WHEREClause';

    DECLARE @BaseTableActiveSQL VARCHAR(MAX) = @BaseTableTemplateSQL;

	DECLARE @ReferencedByJoinMaxNodeActiveSQL VARCHAR(MAX) = @ReferencedByJoinMaxNodeTemplateSQL;
	DECLARE @ReferencedByJoinIntermediateNodeActiveSQL VARCHAR(MAX) = @ReferencedByJoinIntermediateNodeTemplateSQL

	DECLARE @ReferencingTableWithCompositePKJoinMaxNodeActiveSQL VARCHAR(MAX) = @ReferencingTableWithCompositePKJoinMaxNodeTemplateSQL;
	DECLARE @ReferencingTableWithCompositePKJoinIntermediateNodeActiveSQL VARCHAR(MAX) = @ReferencingTableWithCompositePKJoinIntermediateNodeTemplateSQL

	DECLARE @ReferencingTableWithSurrogateKeyJoinMaxNodeActiveSQL VARCHAR(MAX) = @ReferencingTableWithSurrogateKeyJoinMaxNodeTemplateSQL;
	DECLARE @ReferencingTableWithSurrogateKeyJoinIntermediateNodeActiveSQL  VARCHAR(MAX) = @ReferencingTableWithSurrogateKeyJoinIntermediateNodeTemplateSQL;

	DECLARE @RootEntityActiveSQL VARCHAR(MAX) = @RootEntityTemplateSQL;

	DECLARE @DeltaViewSQL_Cumulative VARCHAR(MAX) = '';
	DECLARE @DeltaViewSQL_CurrentPath VARCHAR(MAX) = '';
	DECLARE @DeltaViewSQL_CurrentNode VARCHAR(MAX) = '';
	DECLARE @DeltaViewSQL_PreviousNode VARCHAR(MAX) = '';


	DROP TABLE IF EXISTS tempdb..#BaseToRelatedPaths;

	--using recursive CTE, assemble all possible base/related table paths from root entity
	WITH CTE_BaseToRelatedPaths AS 
	(
		SELECT
			PathNumber = ROW_NUMBER() OVER (ORDER BY C.BTRTConfigId),
			C.BTRTConfigId,
			C.DeltaEntityName,
			C.BaseTableName,
			C.BaseTablePK,
			C.RelatedTableName,
			C.RelatedTablePK,
			C.BaseToRelatedType,
			C.BaseToRelatedJoinSpec,
			C.IsReferencingTableCompositePK,
			C.IsBaseTableRootEntity,
			BaseTableWhere = CASE WHEN @IsIgnoreWhereClause = 1 THEN NULL ELSE C.BaseTableWhere END,
			RelatedTableWhere =  CASE WHEN @IsIgnoreWhereClause = 1 THEN NULL ELSE C.RelatedTableWhere END,
			C.RelatedTableWhereDELETE,
			NodeLevel = 0,
			PreviousConfigId = CAST(NULL AS INT),
			RootPath = CAST(C.BTRTConfigId AS VARCHAR(1000))
		FROM
			[DeltaView].[BTRTConfig] C WITH(NOLOCK) 
		WHERE
			1=1
			AND C.DeltaEntityName = @DeltaEntityName
			AND C.IsBaseTableRootEntity = 1

		UNION ALL
	
		SELECT
			BTR.PathNumber,
			C2.BTRTConfigId,
			C2.DeltaEntityName,
			C2.BaseTableName,
			C2.BaseTablePK,
			C2.RelatedTableName,
			C2.RelatedTablePK,
			C2.BaseToRelatedType,
			C2.BaseToRelatedJoinSpec,
			C2.IsReferencingTableCompositePK,
			C2.IsBaseTableRootEntity,
			BaseTableWhere = CASE WHEN @IsIgnoreWhereClause = 1 THEN NULL ELSE C2.BaseTableWhere END,
			RelatedTableWhere =  CASE WHEN @IsIgnoreWhereClause = 1 THEN NULL ELSE C2.RelatedTableWhere END,
			C2.RelatedTableWhereDELETE,
			NodeLevel = BTR.NodeLevel + 1,
			PreviousConfigId = BTR.BTRTConfigId,
			RootPath = CAST(CONCAT_WS(',', BTR.RootPath, CAST(C2.BTRTConfigId AS VARCHAR(10))) AS VARCHAR(1000))
		FROM
			CTE_BaseToRelatedPaths BTR  
			INNER JOIN [DeltaView].[BTRTConfig] C2 WITH(NOLOCK) 
				ON BTR.RelatedTableName = C2.BaseTableName
		WHERE
			1=1
			AND C2.DeltaEntityName = @DeltaEntityName
			AND ISNULL(C2.IsBaseTableRootEntity,0) = 0
	),
	CTE_BaseToRelatedPathsWithSeq AS
	(
		
		SELECT
			L.*,
			MaxPathNodeLevelSeq = MAX(L.PathNodeLevelSeq) OVER (PARTITION BY L.PathNumber, L.NodeLevel),
			PathNodeLevelId = CAST(CAST(L.PathNumber AS VARCHAR) + '.' + CAST(L.NodeLevel AS VARCHAR) + '.' + CAST(L.PathNodeLevelSeq AS VARCHAR) AS VARCHAR(10))
		FROM
		(
			SELECT 
				*,
				PathNodeLevelSeq = ROW_NUMBER() OVER (PARTITION BY PathNumber, NodeLevel ORDER BY ISNULL(CAST(IsReferencingTableCompositePK AS INT),1) DESC ),
				MaxNodeLevel = MAX(NodeLevel) OVER (PARTITION BY PathNumber)
			FROM 
				CTE_BaseToRelatedPaths
		) L
		
	),
	CTE_BaseToRelatedPathsWithSQL AS
	(
		SELECT  
			L.*,
			BaseTableActiveSQL = 
			CASE 
				WHEN L.PathNodeLevelSeq = 1 AND ISNULL(L.IsBaseTableRootEntity, 0) = 0 THEN REPLACE(REPLACE(@BaseTableTemplateSQL, '$BaseTablePK', DeltaView.[fn_BTRT_PrependAliasFromDelimitedColumns](L.BaseTablePK, 'B')), '$BaseTableName', L.BaseTableName)				
				ELSE NULL
			END,
			BaseToRelatedActiveSQL = 
			CASE
				WHEN L.NodeLevel = L.MaxNodeLevel THEN
					CASE
						
						WHEN L.BaseToRelatedType = 'ReferencedBy' THEN REPLACE(REPLACE(REPLACE(REPLACE(@ReferencedByJoinMaxNodeTemplateSQL, '$BaseTablePK', DeltaView.[fn_BTRT_PrependAliasFromDelimitedColumns](L.BaseTablePK, 'B')), '$BaseTableName', L.BaseTableName), '$RelatedTableName', L.RelatedTableName), '$JoinSpec', L.BaseToRelatedJoinSpec)						
						WHEN L.BaseToRelatedType = 'Referencing' AND L.IsReferencingTableCompositePK = 1 THEN REPLACE(REPLACE(@ReferencingTableWithCompositePKJoinMaxNodeTemplateSQL, '$BaseTablePK', REPLACE(REPLACE(L.BaseToRelatedJoinSpec, 'B.', ''), ' AND ', ',') ), '$RelatedTableName', L.RelatedTableName)						
						WHEN L.BaseToRelatedType = 'Referencing' AND L.IsReferencingTableCompositePK = 0 THEN 
							
							REPLACE(
							REPLACE(
							REPLACE
							(
								REPLACE(REPLACE(@ReferencingTableWithSurrogateKeyJoinMaxNodeTemplateSQL, '$RelatedTableName', L.RelatedTableName), '$RelatedTablePK', DeltaView.[fn_BTRT_PrependAliasFromDelimitedColumns](L.RelatedTablePK, 'R')),
								'$SelfJoinSpec', DeltaView.fn_BTRT_GetJoinSpecFromDelimitedColumns(L.RelatedTablePK, 'L', 'R')
							),
							'$BaseTablePK', REPLACE(REPLACE(L.BaseToRelatedJoinSpec, 'B.', ''), ' AND ', ',')
							),
							'$DELETEWHEREClause', L.RelatedTableWhereDELETE
							)

					END
			END
		FROM 
			CTE_BaseToRelatedPathsWithSeq L
	)
	

	SELECT * 
	INTO #BaseToRelatedPaths
	FROM CTE_BaseToRelatedPathsWithSQL;

	-------SELECT * FROM #BaseToRelatedPaths ORDER BY PathNumber, NodeLevel;
	
	
	DROP TABLE IF EXISTS tempdb..#BaseToRelatedPathsTopDownTraverse;

	WITH CTE_MaxNodesTopDownTraverse AS
	(
		SELECT
			BTR.PathNumber,
			BTR.BTRTConfigId,
			BTR.DeltaEntityName,
			BTR.BaseTableName,
			BTR.BaseTablePK,
			BTR.RelatedTableName,
			BTR.RelatedTablePK,
			BTR.BaseToRelatedType,
			BTR.BaseToRelatedJoinSpec,
			BTR.IsReferencingTableCompositePK,
			BTR.IsBaseTableRootEntity,
			BTR.BaseTableWhere,
			BTR.RelatedTableWhere,
			BTR.RelatedTableWhereDELETE,
			BTR.NodeLevel,
			BTR.PreviousConfigId,
			BTR.RootPath,
			BTR.PathNodeLevelSeq,
			BTR.MaxNodeLevel,
			BTR.MaxPathNodeLevelSeq,
			BTR.PathNodeLevelId,
			BTR.BaseTableActiveSQL,
			BTR.BaseToRelatedActiveSQL,
			IsAppendToActiveSQL = CAST(NULL AS INT)
		FROM 
			#BaseToRelatedPaths BTR
		WHERE
			1=1
			AND BTR.NodeLevel = BTR.MaxNodeLevel

		UNION ALL

		SELECT
			BTR.PathNumber,
			BTR.BTRTConfigId,
			BTR.DeltaEntityName,
			BTR.BaseTableName,
			BTR.BaseTablePK,
			BTR.RelatedTableName,
			BTR.RelatedTablePK,
			BTR.BaseToRelatedType,
			BTR.BaseToRelatedJoinSpec,
			BTR.IsReferencingTableCompositePK,
			BTR.IsBaseTableRootEntity,
			BTR.BaseTableWhere,
			BTR.RelatedTableWhere,
			BTR.RelatedTableWhereDELETE,
			BTR.NodeLevel,
			BTR.PreviousConfigId,
			BTR.RootPath,
			BTR.PathNodeLevelSeq,
			BTR.MaxNodeLevel,
			BTR.MaxPathNodeLevelSeq,
			BTR.PathNodeLevelId,
			BaseTableActiveSQL = 
			CASE 
				WHEN BTR.PathNodeLevelSeq = 1 AND ISNULL(BTR.IsBaseTableRootEntity,0) = 0 THEN REPLACE(REPLACE(@BaseTableTemplateSQL, '$BaseTablePK', DeltaView.[fn_BTRT_PrependAliasFromDelimitedColumns](BTR.BaseTablePK, 'B')), '$BaseTableName', BTR.BaseTableName)				
				ELSE NULL
			END,
			BaseToRelatedActiveSQL = 
				CASE
					WHEN BTR.BaseToRelatedType = 'ReferencedBy' AND ISNULL(C.PreviousConfigId, -99) != BTR.BTRTConfigId THEN REPLACE(REPLACE(REPLACE(REPLACE(@ReferencedByJoinMaxNodeTemplateSQL, '$BaseTablePK', DeltaView.[fn_BTRT_PrependAliasFromDelimitedColumns](BTR.BaseTablePK, 'B')), '$BaseTableName', BTR.BaseTableName), '$RelatedTableName', BTR.RelatedTableName), '$JoinSpec', BTR.BaseToRelatedJoinSpec)
					WHEN BTR.BaseToRelatedType = 'ReferencedBy' AND C.PreviousConfigId = BTR.BTRTConfigId THEN REPLACE(REPLACE(REPLACE(@ReferencedByJoinIntermediateNodeTemplateSQL, '$BaseTablePK', DeltaView.[fn_BTRT_PrependAliasFromDelimitedColumns](BTR.BaseTablePK, 'B')), '$BaseTableName', BTR.BaseTableName), '$JoinSpec', BTR.BaseToRelatedJoinSpec)					
					WHEN BTR.BaseToRelatedType = 'Referencing' AND BTR.IsReferencingTableCompositePK = 1 AND ISNULL(C.PreviousConfigId, -99) != BTR.BTRTConfigId THEN REPLACE(REPLACE(@ReferencingTableWithCompositePKJoinMaxNodeTemplateSQL, '$BaseTablePK', REPLACE(REPLACE(BTR.BaseToRelatedJoinSpec, 'B.', ''), ' AND ', ',') ), '$RelatedTableName', BTR.RelatedTableName)					
					WHEN BTR.BaseToRelatedType = 'Referencing' AND BTR.IsReferencingTableCompositePK = 1 AND C.PreviousConfigId = BTR.BTRTConfigId THEN REPLACE(@ReferencingTableWithCompositePKJoinIntermediateNodeActiveSQL, '$BaseTablePK', REPLACE(REPLACE(BTR.BaseToRelatedJoinSpec, 'B.', ''), ' AND ', ',') )					
					WHEN BTR.BaseToRelatedType = 'Referencing' AND BTR.IsReferencingTableCompositePK = 0 AND ISNULL(C.PreviousConfigId, -99) != BTR.BTRTConfigId THEN 
						
						REPLACE(
						REPLACE(
							REPLACE
							(
								REPLACE(REPLACE(@ReferencingTableWithSurrogateKeyJoinMaxNodeTemplateSQL, '$RelatedTableName', BTR.RelatedTableName), '$RelatedTablePK', DeltaView.[fn_BTRT_PrependAliasFromDelimitedColumns](BTR.RelatedTablePK, 'R')),
								'$SelfJoinSpec', DeltaView.fn_BTRT_GetJoinSpecFromDelimitedColumns(BTR.RelatedTablePK, 'L', 'R')
							),
							'$BaseTablePK', REPLACE(REPLACE(BTR.BaseToRelatedJoinSpec, 'B.', ''), ' AND ', ',')
							),
							'$DELETEWHEREClause', BTR.RelatedTableWhereDELETE
							)
					WHEN BTR.BaseToRelatedType = 'Referencing' AND BTR.IsReferencingTableCompositePK = 0 AND C.PreviousConfigId = BTR.BTRTConfigId THEN
						
						REPLACE(
						REPLACE(							
								REPLACE
								(
									-------HERE!!!!: REPLACE(@ReferencingTableWithSurrogateKeyJoinIntermediateNodeTemplateSQL, '$BaseTablePK', DeltaView.[fn_BTRT_PrependAliasFromDelimitedColumns](BTR.BaseTablePK, 'R')),
									REPLACE(@ReferencingTableWithSurrogateKeyJoinIntermediateNodeTemplateSQL, '$BaseTablePK', REPLACE(REPLACE(BTR.BaseToRelatedJoinSpec, 'B.', ''), ' AND ', ',') ),
									
									'$SelfJoinSpec', DeltaView.fn_BTRT_GetJoinSpecFromDelimitedColumns(BTR.RelatedTablePK, 'L', 'R')
								),
							'$RelatedTableName', BTR.RelatedTableName
						),
						'$DELETEWHEREClause', BTR.RelatedTableWhereDELETE
						)
				END,
			IsAppendToActiveSQL = CASE WHEN C.PreviousConfigId = BTR.BTRTConfigId THEN 1 ELSE 0 END
		FROM 
			#BaseToRelatedPaths BTR
			INNER JOIN CTE_MaxNodesTopDownTraverse C
				ON C.PathNumber = BTR.PathNumber
				AND C.NodeLevel = BTR.NodeLevel + 1	
		WHERE
			1=1
	)
	
	SELECT DISTINCT * 
	INTO #BaseToRelatedPathsTopDownTraverse
	FROM CTE_MaxNodesTopDownTraverse;
	
	/*
	SELECT  *
	FROM #BaseToRelatedPathsTopDownTraverse
	ORDER BY PathNumber, NodeLevel;
	*/	

	----update $WhereClause tags in BaseTableActiveSQL and BaseToRelatedActiveSQL columns in #BaseToRelatedPathsTopDownTraverse table
	UPDATE TD
	SET		
		TD.BaseTableActiveSQL = REPLACE(    REPLACE(     REPLACE(REPLACE( REPLACE(REPLACE(REPLACE(TD.BaseTableActiveSQL, '$WhereClause', ISNULL(TD.BaseTableWhere, '')), '$VistaETLBatchIDHWMValue',  @VistaETLBatchIDHWMValue), '$VistaDateTimeHWMValue', '''' + @VistaDateTimeHWMValue + ''''), '$MillETLBatchIDHWMValue', @MillETLBatchIDHWMValue), '$MillDateTimeHWMValue',  '''' + @MillDateTimeHWMValue + ''''), '$MVIETLBatchIDHWMValue',  @MVIETLBatchIDHWMValue), '$MVIDateTimeHWMValue', '''' + @MVIDateTimeHWMValue + '''') ,
		TD.BaseToRelatedActiveSQL = REPLACE(    REPLACE( REPLACE(REPLACE( REPLACE(REPLACE(REPLACE(TD.BaseToRelatedActiveSQL, '$WhereClause', ISNULL(TD.RelatedTableWhere, '')), '$VistaETLBatchIDHWMValue', @VistaETLBatchIDHWMValue), '$VistaDateTimeHWMValue', '''' + @VistaDateTimeHWMValue + ''''), '$MillETLBatchIDHWMValue', @MillETLBatchIDHWMValue), '$MillDateTimeHWMValue',  '''' + @MillDateTimeHWMValue + ''''), '$MVIETLBatchIDHWMValue',  @MVIETLBatchIDHWMValue), '$MVIDateTimeHWMValue', '''' + @MVIDateTimeHWMValue + '''')	
	FROM
		#BaseToRelatedPathsTopDownTraverse TD
	WHERE
		1=1;

	/*
	SELECT *
	FROM #BaseToRelatedPathsTopDownTraverse
	ORDER BY PathNumber, NodeLevel;
	*/


	/*---------------------------------------------------------------------------*/

	DROP TABLE IF EXISTS tempdb..#DistinctPathNodes;
	
	SELECT DISTINCT
		PathNumber,
		NodeLevel,
		MaxNodeLevel,
		PathNodeCount = MaxNodeLevel + 1,
		PathNodeLevelSeqCount = MaxPathNodeLevelSeq,
		PreviousConfigId,
		----IsAppendToActiveSQL,
		NodeCumulativeSQL = CAST(NULL AS VARCHAR(MAX)) 
	INTO #DistinctPathNodes
	FROM
		#BaseToRelatedPathsTopDownTraverse
	WHERE
		1=1
	ORDER BY PathNumber, NodeLevel;

	------SELECT * FROM #DistinctPathNodes;


	
	SELECT
		@RootEntityActiveSQL = REPLACE(    REPLACE(  REPLACE(REPLACE( REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@RootEntityTemplateSQL, '$BaseTablePK', DeltaView.[fn_BTRT_PrependAliasFromDelimitedColumns](L.BaseTablePK, 'B')), '$BaseTableName', L.BaseTableName), '$WHEREClause', ISNULL(L.BaseTableWhere, '')), '$VistaETLBatchIDHWMValue', @VistaETLBatchIDHWMValue), '$VistaDateTimeHWMValue', '''' + @VistaDateTimeHWMValue + ''''), '$MillETLBatchIDHWMValue', @MillETLBatchIDHWMValue), '$MillDateTimeHWMValue',  '''' + @MillDateTimeHWMValue + ''''), '$MVIETLBatchIDHWMValue',  @MVIETLBatchIDHWMValue), '$MVIDateTimeHWMValue', '''' + @MVIDateTimeHWMValue + '''')		
	FROM
	(
		SELECT DISTINCT TOP 1
			BaseTableName,
			BaseTablePK,
			BaseTableWhere
		FROM
			#BaseToRelatedPathsTopDownTraverse
		WHERE
			IsBaseTableRootEntity = 1
	) L
	
	-------SELECT RootEntityActiveSQL = @RootEntityActiveSQL;

	--variables related to looping 
	DECLARE @CurrentPathNumber INT = 1;
	DECLARE @TotalPathCount INT;
	DECLARE @CurrentNodeLevel INT;
	----DECLARE @PathNodeCount INT;
	DECLARE @PreviousPathNumber INT = NULL;
	DECLARE @PreviousNodeLevel INT = NULL;
	DECLARE @PathNodeLevelSeqCount INT;
	DECLARE @CurrentPathNodeLevelSeq INT = 1;
	DECLARE @NodeCumulativeSQL VARCHAR(MAX) = '';  --must be initialized to empty string
	
	DECLARE @MaxNodeLevel INT;
	DECLARE @IsAppendToActiveSQL INT;
	--DECLARE @MaxPathNodeLevelSeq INT;
	
	
	SELECT @TotalPathCount = MAX(PathNumber) FROM #DistinctPathNodes;

	WHILE (@CurrentPathNumber <= @TotalPathCount)
	BEGIN
		
		-------SELECT @PathNodeCount = MAX(PathNodeCount) FROM #DistinctPathNodes WHERE PathNumber = @CurrentPathNumber;
		
		--logic will start with largest node in a path and iterate down

		SELECT @MaxNodeLevel = MAX(NodeLevel) FROM #DistinctPathNodes WHERE PathNumber = @CurrentPathNumber;
		SELECT @CurrentNodeLevel = @MaxNodeLevel;

		WHILE (@CurrentNodeLevel >= 0)
		BEGIN
			

			SELECT @PathNodeLevelSeqCount = PathNodeLevelSeqCount FROM #DistinctPathNodes WHERE PathNumber = @CurrentPathNumber AND NodeLevel = @CurrentNodeLevel;
			SET @CurrentPathNodeLevelSeq = 1;

			WHILE (@CurrentPathNodeLevelSeq <= @PathNodeLevelSeqCount)
			BEGIN
				
				--Logic for max nodes handled within this IF routine. Max nodes do not require inheritance from a prior node in a top-down traversal
				IF(@CurrentNodeLevel = @MaxNodeLevel)
				BEGIN
				
					IF(@CurrentPathNodeLevelSeq = 1)
					BEGIN

						SELECT 
							@NodeCumulativeSQL = @NodeCumulativeSQL + BaseTableActiveSQL +  CASE WHEN BaseToRelatedActiveSQL IS NULL THEN '' ELSE ' UNION ' + BaseToRelatedActiveSQL END 
						FROM 
							#BaseToRelatedPathsTopDownTraverse 
						WHERE 
							1=1
							AND PathNumber = @CurrentPathNumber 
							AND NodeLevel = @CurrentNodeLevel 
							AND PathNodeLevelSeq = @CurrentPathNodeLevelSeq;
						
					

					END  ---- end IF(@CurrentPathNodeLevelSeq = 1)

					IF(@CurrentPathNodeLevelSeq > 1)
					BEGIN

						SELECT 
							@NodeCumulativeSQL = @NodeCumulativeSQL + CASE WHEN BaseToRelatedActiveSQL IS NULL THEN '' ELSE ' UNION ' + BaseToRelatedActiveSQL END 
						FROM 
							#BaseToRelatedPathsTopDownTraverse 
						WHERE 
							1=1
							AND PathNumber = @CurrentPathNumber 
							AND NodeLevel = @CurrentNodeLevel 
							AND PathNodeLevelSeq = @CurrentPathNodeLevelSeq;


					END  ------- end IF(@CurrentPathNodeLevelSeq > 1)
					
					

					IF(@CurrentPathNodeLevelSeq = @PathNodeLevelSeqCount)
					BEGIN
					
						UPDATE PN
							SET NodeCumulativeSQL = @NodeCumulativeSQL
						FROM
							#DistinctPathNodes PN
						WHERE
							PN.PathNumber = @CurrentPathNumber
							AND PN.NodeLevel = @CurrentNodeLevel;

					END  ----end IF(@CurrentPathNodeLevelSeq = @PathNodeLevelSeqCount)

				END    ----end IF(@CurrentNodeLevel = @MaxNodeLevel)

				--Logic for intermediate and root nodes handled within this IF routine. These nodes DO require inheritance from a prior node in a top-down traversal
				--by design, all values of @NodeCumulativeSQL will be NULL in the root nodes
				IF(@CurrentNodeLevel < @MaxNodeLevel)
				BEGIN
					
					SELECT
						@IsAppendToActiveSQL = IsAppendToActiveSQL
					FROM 
						#BaseToRelatedPathsTopDownTraverse 
					WHERE 
						1=1
						AND PathNumber = @CurrentPathNumber 
						AND NodeLevel = @CurrentNodeLevel 
						AND PathNodeLevelSeq = @CurrentPathNodeLevelSeq;


					IF(@IsAppendToActiveSQL = 1)
					BEGIN
						
						UPDATE TD
							SET TD.BaseToRelatedActiveSQL = 
							CASE 
								WHEN PN.NodeCumulativeSQL IS NOT NULL THEN REPLACE(TD.BaseToRelatedActiveSQL, '$PriorNodeSQL', PN.NodeCumulativeSQL)
								ELSE TD.BaseToRelatedActiveSQL
							END
						/*SELECT 
							TD.*,
							BaseToRelatedActiveSQLREPLACE = REPLACE(BaseToRelatedActiveSQL, '$PriorNodeSQL', PN.NodeCumulativeSQL),
							PN.PreviousConfigId,
							PN.NodeCumulativeSQL*/
						FROM
							#BaseToRelatedPathsTopDownTraverse TD
							INNER JOIN #DistinctPathNodes PN
								ON TD.PathNumber = PN.PathNumber
								AND TD.BTRTConfigId = PN.PreviousConfigId
						WHERE
							TD.PathNumber = @CurrentPathNumber
							AND TD.NodeLevel = @CurrentNodeLevel;

					END  ----end IF(@IsAppendToActiveSQL = 1)

					/**************************/
					IF(@CurrentPathNodeLevelSeq = 1)
					BEGIN

						SELECT 
							@NodeCumulativeSQL = @NodeCumulativeSQL + BaseTableActiveSQL +  CASE WHEN BaseToRelatedActiveSQL IS NULL THEN '' ELSE ' UNION ' + BaseToRelatedActiveSQL END 
						FROM 
							#BaseToRelatedPathsTopDownTraverse 
						WHERE 
							1=1
							AND PathNumber = @CurrentPathNumber 
							AND NodeLevel = @CurrentNodeLevel 
							AND PathNodeLevelSeq = @CurrentPathNodeLevelSeq;
					END  ---- end IF(@CurrentPathNodeLevelSeq = 1)


					IF(@CurrentPathNodeLevelSeq > 1)
					BEGIN

						SELECT 
							@NodeCumulativeSQL = @NodeCumulativeSQL + CASE WHEN BaseToRelatedActiveSQL IS NULL THEN '' ELSE ' UNION ' + BaseToRelatedActiveSQL END 
						FROM 
							#BaseToRelatedPathsTopDownTraverse 
						WHERE 
							1=1
							AND PathNumber = @CurrentPathNumber 
							AND NodeLevel = @CurrentNodeLevel 
							AND PathNodeLevelSeq = @CurrentPathNodeLevelSeq;


					END  ------- end IF(@CurrentPathNodeLevelSeq > 1)
					

					IF(@CurrentPathNodeLevelSeq = @PathNodeLevelSeqCount)
					BEGIN
					
						UPDATE PN
							SET NodeCumulativeSQL = @NodeCumulativeSQL
						FROM
							#DistinctPathNodes PN
						WHERE
							PN.PathNumber = @CurrentPathNumber
							AND PN.NodeLevel = @CurrentNodeLevel;

					END  ----end IF(@CurrentPathNodeLevelSeq = @PathNodeLevelSeqCount)


				END ----end IF(@CurrentNodeLevel < @MaxNodeLevel)

				/*
				SELECT
					PN.*
				FROM
					#DistinctPathNodes PN
				WHERE
					PN.PathNumber = @CurrentPathNumber
					AND PN.NodeLevel = @CurrentNodeLevel;
				*/
				/*
				SELECT 
					LoopCurrentPathNumber = @CurrentPathNumber,
					LoopCurrentNodeLevel = @CurrentNodeLevel,
					LoopCurrentPathNodeLevelSeq = @CurrentPathNodeLevelSeq,
					LoopPathNodeLevelSeqCount = @PathNodeLevelSeqCount,
					LoopNodeCumulativeSQL = @NodeCumulativeSQL;
				*/
				


				SET @CurrentPathNodeLevelSeq += 1;


			END ------end WHILE (@CurrentPathNodeLevelSeq <= @PathNodeLevelSeqCount)


			SET @CurrentNodeLevel = @CurrentNodeLevel - 1;
			SET @NodeCumulativeSQL = '';


		END  ------- end WHILE (@CurrentNodeLevel >= 0)


		SET @CurrentPathNumber += 1;

	END  --(@CurrentPathNumber <= @TotalPathCount)

	------SELECT * FROM #DistinctPathNodes ORDER BY PathNumber, NodeLevel;

	/*
	SELECT *
	FROM #BaseToRelatedPathsTopDownTraverse
	ORDER BY PathNumber, NodeLevel;
	*/
	
	SELECT 
		@AllPathNodeSQL = @RootEntityActiveSQL + ' UNION ' + STRING_AGG(BaseToRelatedActiveSQL, ' UNION ')
	FROM
		#BaseToRelatedPathsTopDownTraverse
	WHERE
		NodeLevel = 0;

	
	
	--if primary HWM params are NULL or empty string, fail the sproc
	IF( ISNULL(@AllPathNodeSQL, '') = '' )
	BEGIN		
		
		DECLARE @AllPathNodeSQLErrorMessage VARCHAR(1000) = 'The value of @AllPathNodeSQL for $DeltaEntityName is NULL/emptry string.';
		DECLARE @AllPathNodeSQLErrorMessageLog VARCHAR(1000) = 'EXEC [Log].[Message] @Type = ''Error'',  @Name = ''Delta Key SQL Error'', @Message = ''$AllPathNodeSQLErrorMessage'', @ExecutionLogID = $ExecutionLogID;'

		SET @AllPathNodeSQLErrorMessage = REPLACE(@AllPathNodeSQLErrorMessage, '$DeltaEntityName', @DeltaEntityName);   
		SET @AllPathNodeSQLErrorMessageLog = REPLACE(@AllPathNodeSQLErrorMessageLog, '$AllPathNodeSQLErrorMessage', @AllPathNodeSQLErrorMessage);	

		EXEC(@AllPathNodeSQLErrorMessageLog);
		
		THROW 60000, @AllPathNodeSQLErrorMessage, 1;
		

	END

	--final result value
	SELECT
		AllPathNodeSQL = @AllPathNodeSQL;
	


END