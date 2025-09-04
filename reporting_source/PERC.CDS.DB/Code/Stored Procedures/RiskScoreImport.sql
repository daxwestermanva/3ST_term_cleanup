
/********************************************************************************************************************
CREATE DATE:	2019-01-10
DESCRIPTION:	This code should be executed when importing a new model.
				Import staging data to the final RiskScore model tables.
TEST:
	EXEC [Code].[RiskScoreImport]
UPDATE:
	2020-02-12	RAS	Replaced insert to RiskScore.Variable with MERGE.  Allows for deletions and additions - logged in MessageLog.
	2020-07-28	RAS	Replaced first section with MERGE instead of only adding new model names.  This way we can update the model information in the table after it already exists.
********************************************************************************************************************/
CREATE PROCEDURE [Code].[RiskScoreImport]
AS
BEGIN
	---- Insert RiskModel - if it doesn't exist
	--INSERT INTO [RiskScore].[RiskModel]
	--	  (ModelName,RegressionType,ModelDescription,Intercept,Criteria1Method,Criteria2Method,Criteria3Method)
	--SELECT ModelName,RegressionType,ModelDescription,Intercept,Criteria1Method,Criteria2Method,Criteria3Method
	--FROM [Stage].[RiskModel]
	--WHERE ModelName NOT IN (SELECT ModelName FROM [RiskScore].[RiskModel])

	--Replaced above with MERGE
	MERGE [RiskScore].[RiskModel] as m
	USING [Stage].[RiskModel] as s ON  m.ModelName=s.ModelName
	WHEN MATCHED THEN 
		UPDATE SET RegressionType=s.RegressionType
				,ModelDescription=s.ModelDescription
				,Intercept		 =s.Intercept
				,Criteria1Method =s.Criteria1Method
				,Criteria2Method =s.Criteria2Method
				,Criteria3Method =s.Criteria3Method
	WHEN NOT MATCHED BY TARGET THEN 
		INSERT (ModelName,RegressionType,ModelDescription,Intercept,Criteria1Method,Criteria2Method,Criteria3Method)
		VALUES (s.ModelName,s.RegressionType,s.ModelDescription,s.Intercept,s.Criteria1Method,s.Criteria2Method,s.Criteria3Method)
	;

	-- Store the ModelID to process
	DROP TABLE IF EXISTS #Model
	CREATE TABLE #Model(ModelID INT, ModelName VARCHAR(100))	
	INSERT INTO #Model(ModelID,ModelName)
	SELECT ModelID,ModelName
	FROM [RiskScore].[RiskModel] RM
	WHERE ModelName IN (SELECT ModelName FROM [Stage].[RiskModel])
	
	-- If updating an existing model, delete any existing patient and model data.	
	DELETE [RiskScore].[PatientRiskScore]	  WITH(TABLOCK) WHERE ModelID IN (SELECT ModelID FROM #Model)
	DELETE [RiskScore].[Predictor]			  WITH(TABLOCK) WHERE ModelID IN (SELECT ModelID FROM #Model)
	DELETE [RiskScore].[HypotheticalModel]	  WITH(TABLOCK) WHERE ModelID IN (SELECT ModelID FROM #Model)
	DELETE [RiskScore].[HypotheticalVariable] WITH(TABLOCK) WHERE HypotheticalModelID IN 
		(SELECT HypotheticalModelID FROM [RiskScore].[HypotheticalModel] WHERE ModelID IN (SELECT ModelID FROM #Model))

	-- Insert any new variables, delete any that have been removed
	DECLARE @VariableUpdates TABLE
	(
	   ActionType VARCHAR(50),
	   VariableName VARCHAR(100)
	);
	MERGE [RiskScore].[Variable] AS v
	USING [Stage].[Variable]  AS s ON v.VariableName=s.VariableName 
	WHEN MATCHED THEN 
		UPDATE SET VariableDescription=s.VariableDescription
			,VariableType		=s.VariableType
			,Domain				=s.Domain
			,TimeFrameUnit		=s.TimeFrameUnit
			,TimeFrame			=s.TimeFrame
			,ImputeValue		=s.ImputeValue
			,Impute1Method		=s.Impute1Method
			,Impute2Method		=s.Impute2Method
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (VariableName,VariableDescription,VariableType,Domain,TimeFrameUnit,TimeFrame,ImputeValue,Impute1Method,Impute2Method)
		VALUES (s.VariableName,s.VariableDescription,s.VariableType,s.Domain,s.TimeFrameUnit,s.TimeFrame,s.ImputeValue,s.Impute1Method,s.Impute2Method)
	WHEN NOT MATCHED BY SOURCE THEN DELETE
	OUTPUT $action as ActionType, 
	ISNULL(DELETED.VariableName,INSERTED.VariableName) as VariableName
	INTO @VariableUpdates
	;
	IF (SELECT count(*) FROM @VariableUpdates WHERE ActionType ='INSERT')>0 
	BEGIN
	DECLARE @VAdded VARCHAR(MAX) = (SELECT STRING_AGG(VariableName,',') FROM @VariableUpdates WHERE ActionType ='INSERT'	)
	EXEC [Log].[Message] 'Information','Variables added to RiskScore.Variable',@VAdded
	END

	IF (SELECT count(*) FROM @VariableUpdates WHERE ActionType ='DELETE')>0 
	BEGIN
	DECLARE @VDeleted VARCHAR(MAX) = (SELECT STRING_AGG(VariableName,',') FROM @VariableUpdates WHERE ActionType ='DELETE')
	EXEC [Log].[Message] 'Information','Variables deleted from RiskScore.Variable',@VDeleted
	END

	-- 2020-02-12 RAS replaced this with above MERGE code.
	--INSERT INTO [RiskScore].[Variable] 
	--	  (VariableName,VariableDescription,VariableType,Domain,TimeFrameUnit,TimeFrame,ImputeValue,Impute1Method,Impute2Method)
	--SELECT VariableName,VariableDescription,VariableType,Domain,TimeFrameUnit,TimeFrame,ImputeValue,Impute1Method,Impute2Method
	--FROM [Stage].[Variable] V
	--WHERE V.VariableName NOT IN (SELECT VariableName FROM [RiskScore].[Variable])

	-- Map imputation variable names to IDs
	UPDATE Trg
	SET  Impute1UsingVariableID = V1.VariableID
		,Impute2UsingVariableID = V2.VariableID
	FROM [RiskScore].[Variable] Trg
	INNER JOIN [Stage].[Variable] Src ON Src.VariableName = Trg.VariableName
	LEFT OUTER JOIN [RiskScore].[Variable] V1 ON V1.VariableName = Src.Impute1UsingVariableName
	LEFT OUTER JOIN [RiskScore].[Variable] V2 ON V2.VariableName = Src.Impute2UsingVariableName
	WHERE Trg.ImputeValue IS NOT NULL
	
	-- Map criteria variable names to ids
	UPDATE Trg
	SET  Criteria1VariableID = V1.VariableID
		,Criteria2VariableID = V2.VariableID
		,Criteria3VariableID = V3.VariableID
	FROM [RiskScore].[RiskModel] Trg
	INNER JOIN [Stage].[RiskModel] Src ON Src.ModelName = Trg.ModelName
	LEFT OUTER JOIN [RiskScore].[Variable] V1 ON V1.VariableName = Src.Criteria1VariableName
	LEFT OUTER JOIN [RiskScore].[Variable] V2 ON V2.VariableName = Src.Criteria2VariableName
	LEFT OUTER JOIN [RiskScore].[Variable] V3 ON V3.VariableName = Src.Criteria3VariableName
	 
	--Update subset and aggregate data (variables computed using pre-existing variables)
	DROP TABLE IF EXISTS #aggsub
	SELECT a.*
		  ,v1.VariableID
		  ,v2.VariableID as ReferenceVariableID
	INTO #aggsub
	FROM [Stage].[VariableAggSub] a
	INNER JOIN [RiskScore].[Variable] v1 on a.VariableName=v1.VariableName
	INNER JOIN [RiskScore].[Variable] v2 on a.ReferenceVariableName=v2.VariableName

	EXEC [Maintenance].[PublishTable] 'RiskScore.VariableAggSub','#aggsub'

	-- Insert predictors and map variable names to ids
	INSERT INTO [RiskScore].[Predictor]
		  (ModelID,Variable1ID,Variable2ID,IsInteraction,Coefficient)
	SELECT M.ModelID
		  ,V1.VariableID AS Variable1ID
		  ,CASE WHEN IsInteraction = 1 THEN V2.VariableID ELSE NULL END AS Variable2ID
		  ,IsInteraction
		  -- Need to handle Excel's conversion of decimals to scientific notation
		  ,CASE WHEN Coefficient like '%E-%' THEN CAST(CAST(Coefficient AS FLOAT) AS DECIMAL(15,8))
				WHEN Coefficient like '%E+%' THEN CAST(CAST(Coefficient AS FLOAT) AS DECIMAL)
		  		ELSE Coefficient
			END	
	FROM [Stage].[Predictor] P
	INNER JOIN #Model M ON M.ModelName = P.ModelName
	LEFT OUTER JOIN [RiskScore].[Variable] V1 ON V1.VariableName = P.Variable1Name
	LEFT OUTER JOIN [RiskScore].[Variable] V2 ON V2.VariableName = P.Variable2Name	
	
	-- Insert HypotheticalModel
	INSERT INTO [RiskScore].[HypotheticalModel] 
		(HypotheticalModelName,ModelID,HypotheticalModelDescription,Criteria1VariableID,Criteria1Method)
	SELECT HM.HypotheticalModelName
		  ,M.ModelID
		  ,HM.HypotheticalModelDescription
		  ,V1.VariableID
		  ,HM.Criteria1Method
	FROM [Stage].[HypotheticalModel] HM
	INNER JOIN #Model M ON M.ModelName = HM.ModelName
	LEFT JOIN [RiskScore].[Variable] V1 ON V1.VariableName = HM.Criteria1VariableName

	-- Insert HypotheticalVariable
	INSERT INTO [RiskScore].[HypotheticalVariable]
		  (HypotheticalModelID,VariableID,HypotheticalValue,HypotheticalOperator)
	SELECT HM.HypotheticalModelID
		  ,V.VariableID
		  ,HV.HypotheticalValue
		  ,HV.HypotheticalOperator
	FROM [Stage].[HypotheticalVariable] HV
	INNER JOIN [RiskScore].[HypotheticalModel] HM ON HM.HypotheticalModelName = HV.HypotheticalModelName
	LEFT JOIN [RiskScore].[Variable] V ON V.VariableName = HV.VariableName

	-- SELECT * FROM [RiskScore].RiskModel WHERE ModelID = @ModelID
	-- SELECT * FROM [RiskScore].PatientRiskScore WHERE ModelID = @ModelID
	-- SELECT * FROM [RiskScore].HypotheticalVariable WHERE HypotheticalModelID IN(SELECT HypotheticalModelID FROM [RiskScore].HypotheticalModel WHERE ModelID = @ModelID)
	-- SELECT * FROM [RiskScore].HypotheticalModel WHERE ModelID = @ModelID
	-- SELECT * FROM [RiskScore].Predictor WHERE ModelID = @ModelID

END
	
	--Reset incremental value of HypotheticalModelID and HypotheticalVariableID (if tables are truncated and you are starting over)
	--DBCC CHECKIDENT ('[RiskScore].[HypotheticalModel]', RESEED, 0)
	--DBCC CHECKIDENT ('[RiskScore].[HypotheticalVariable]', RESEED, 0)