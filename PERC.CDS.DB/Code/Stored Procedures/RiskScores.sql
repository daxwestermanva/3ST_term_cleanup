
/********************************************************************************************************************
CREATE DATE: 2019-01-17
DESCRIPTION: Table-Driven Risk Score process that calculates standard and hypothetical risk scores for all models.   
			 The calculations were previously done in Code.ORM_RiskScores AND Code.Reach_RiskScore.
TEST:
	EXEC [Code].[RiskScoreImport]
UPDATE:
	2020-02-12	RAS	Replaced insert to RiskScore.Variable with MERGE.  Allows for deletions and additions - logged in MessageLog.
					Replaces model criteria logic only for standard risk score models:
					Want to include anyone who meets any of the inclusion criteria, but exlude anyone who meets 
					any exlusion criteria (even if they met inclusion criteria).  Exclusion trumps inclusion.
********************************************************************************************************************/

CREATE PROCEDURE [Code].[RiskScores]	
	-- Pass in a single ModelName or multiple comma separated ModelNames to process.
	-- Default value of 'ALLModels' will run for all models in RiskScore.RiskModel.
	--	Ex:  Single:  @ModelName = 'Storm Overdose'  Multiple:  @ModelName = 'Storm Overdose,Storm Any'
	@ModelName VARCHAR(1000) = 'AllModels'
AS
BEGIN	
	-- Populate #Model table with the values in the @ModelID parameter.
	-- Risk scores will only be calculated for these models.
	-- DECLARE @ModelName VARCHAR(1000) = 'STORM Overdose,STORM Any'
	DROP TABLE IF EXISTS #Model
	CREATE TABLE #Model(ModelID SMALLINT Primary Key, Criteria1VariableID SMALLINT, Criteria1Method VARCHAR(100), Criteria2VariableID SMALLINT, Criteria2Method VARCHAR(100), Criteria3VariableID SMALLINT, Criteria3Method VARCHAR(100), Intercept DECIMAL(9,7))
	IF @ModelName = 'AllModels'
		INSERT INTO #Model([ModelID],[Criteria1VariableID], [Criteria1Method], [Criteria2VariableID], [Criteria2Method],[Criteria3VariableID], [Criteria3Method],[Intercept]) 
		SELECT [ModelID],[Criteria1VariableID], [Criteria1Method], [Criteria2VariableID], [Criteria2Method],[Criteria3VariableID], [Criteria3Method],[Intercept] 
		FROM [RiskScore].[RiskModel]
	ELSE
		INSERT INTO #Model([ModelID],[Criteria1VariableID], [Criteria1Method], [Criteria2VariableID], [Criteria2Method],[Intercept]) 
		SELECT [ModelID],[Criteria1VariableID], [Criteria1Method], [Criteria2VariableID], [Criteria2Method],[Intercept]
		FROM [RiskScore].[RiskModel]
		WHERE ModelName IN (SELECT VALUE FROM STRING_SPLIT(@ModelName,','))

	-- Populate #ModelVariable with each model and all variables associated with the model.
	DROP TABLE IF EXISTS #ModelVariable
	CREATE TABLE #ModelVariable(ModelID SMALLINT, VariableID INT CONSTRAINT PK_ModelVariableTTemp PRIMARY KEY (ModelID,VariableID))
	INSERT INTO #ModelVariable
	SELECT ModelID,Variable1ID AS VariableID FROM RiskScore.Predictor WHERE ModelID IN(SELECT ModelID FROM #Model)
	UNION 
	SELECT ModelID,Variable2ID AS VariableID FROM RiskScore.Predictor WHERE Variable2ID IS NOT NULL AND ModelID IN(SELECT ModelID FROM #Model)			

	--Create Inclusion and Exclusion flags for variables in each model 
	DROP TABLE IF EXISTS #ModelVariableIE;
	SELECT mv.ModelID
		,VariableID
		,CASE WHEN (M.Criteria1Method='INCLUDE' AND mv.VariableID=m.Criteria1VariableID)
				OR (M.Criteria2Method='INCLUDE' AND mv.VariableID=m.Criteria2VariableID)
				OR (M.Criteria3Method='INCLUDE' AND mv.VariableID=m.Criteria3VariableID)
			THEN 1 ELSE 0 END AS Inclusion
		,CASE WHEN (M.Criteria1Method='EXCLUDE' AND mv.VariableID=m.Criteria1VariableID)
				OR (M.Criteria2Method='EXCLUDE' AND mv.VariableID=m.Criteria2VariableID)
				OR (M.Criteria3Method='EXCLUDE' AND mv.VariableID=m.Criteria3VariableID)
			THEN 1 ELSE 0 END AS Exclusion
	INTO #ModelVariableIE
	FROM #ModelVariable mv 
	INNER JOIN #Model m ON m.ModelID=mv.ModelID
	
	-- Populate #Pop with each eligible Patient, Model and whether they meet required model criteria or not.
	/*Need to add something to account for excluding Hospice from STORM*/
	DROP TABLE IF EXISTS #Pop
	SELECT mv.ModelID
		,pv.MVIPersonSID
		,MAX(Inclusion) AS InclusionCriteria
		,MAX(Exclusion) AS ExclusionCriteria
	INTO #Pop
	FROM [RiskScore].[PatientVariable] pv
	INNER JOIN #ModelVariableIE mv ON mv.VariableID = pv.VariableID
	INNER JOIN #Model M ON M.ModelID = mv.ModelID
	GROUP BY mv.ModelID,pv.MVIPersonSID
	----Go ahead and exlude those explicitly meeting exlusion criteria (e.g., Cancer and Hospice in STOMR). Need others (Inclusion=0) for hypothetical
	----This doesn't have an effect currently, but we may want it in the future
	----HAVING MAX(Exclusion)=0 

	CREATE NONCLUSTERED INDEX IX_Pop_MVIPersonSID_ModelID	ON [#Pop] ([MVIPersonSID], [ModelID])
	CREATE NONCLUSTERED INDEX IX_Pop_ModelID ON [#Pop] ([ModelID])

	-- Populate #RawScore with each patient and raw predictor score.  	
	DROP TABLE IF EXISTS #RawScore
	SELECT p.ModelID
		,pv.MVIPersonSID
		,SUM(ISNULL(pv.VariableValue,0) * ISNULL(p.Coefficient,0) * CASE WHEN IsInteraction = 1 THEN ISNULL(Interactions.VariableValue,0) ELSE 1 END ) AS RawScoreValue		
	INTO #RawScore
	FROM [RiskScore].[PatientVariable] pv	
	INNER JOIN [RiskScore].[Predictor] P ON 
		p.Variable1ID = pv.VariableID 
		AND ModelID IN (SELECT ModelID FROM #Model)	
	LEFT JOIN [RiskScore].[PatientVariable] Interactions ON 
		Interactions.MVIPersonSID = pv.MVIPersonSID 
		AND Interactions.VariableID = p.Variable2ID 	
	GROUP BY p.ModelID, pv.MVIPersonSID

	--Define population for hypothetical models based on criteria from RiskScore.HypotheticalModel
	DROP TABLE IF EXISTS #HypPop
	SELECT Pop.MVIPersonSID
		,hm.ModelID
		,hm.HypotheticalModelID
	INTO #HypPop
	FROM #Pop Pop
	INNER JOIN [RiskScore].[HypotheticalModel] hm ON hm.ModelID = Pop.ModelID
	LEFT JOIN [RiskScore].[PatientVariable] pvc ON 
		pvc.VariableID = hm.Criteria1VariableID 
		AND pvc.MVIPersonSID = pop.MVIPersonSID	
	WHERE (
			-- Only calculate hypothetical raw score adjustments if the patient meets the include/exclude criteria. 
			(pvc.VariableValue IS NULL AND hm.Criteria1Method = 'Exclude')
			OR
			(pvc.VariableValue IS NOT NULL AND hm.Criteria1Method = 'Include')
		)	
	GROUP BY pop.MVIPersonSID,hm.ModelID,hm.HypotheticalModelID


	-- Populate #Hypothetical with each patient and the hypothetical model raw score adjustment.
	-- The RawScoreAdjustment is the inverse of the applied hypothetical value.  This will later be added to the RawScore from #Pop to calculate the final RawScore.
	DROP TABLE IF EXISTS #Hypothetical
	SELECT Pop.MVIPersonSID
		,Pop.ModelID
		,hv.HypotheticalModelID
		,SUM(CASE WHEN HypotheticalOperator = 'Multiply' AND pv.VariableValue IS NOT NULL  THEN (hv.HypotheticalValue-1) * pv.VariableValue
				  WHEN HypotheticalOperator = 'Replace' AND pv.VariableValue IS NULL THEN (hv.HypotheticalValue) 
				END				
				* ISNULL(p.Coefficient,0) 
				* CASE WHEN IsInteraction = 1 THEN ISNULL(Interactions.VariableValue,0) ELSE 1 END)  AS RawScoreAdjustment			
	INTO #Hypothetical
	FROM #HypPop Pop
	INNER JOIN [RiskScore].[HypotheticalVariable] hv ON hv.HypotheticalModelID = Pop.HypotheticalModelID
	INNER JOIN [RiskScore].[Predictor] P ON 
		p.ModelID = Pop.ModelID 
		AND p.Variable1ID = hv.VariableID
	LEFT JOIN [RiskScore].[PatientVariable] pv ON 
		pv.MVIPersonSID = Pop.MVIPersonSID 
		AND pv.VariableID = p.Variable1ID
	LEFT JOIN [RiskScore].[PatientVariable] Interactions ON p.IsInteraction = 1 
		AND Interactions.VariableID = p.Variable2ID 
		AND Interactions.MVIPersonSID = Pop.MVIPersonSID	
	GROUP BY Pop.MVIPersonSID
		,Pop.ModelID
		,hv.HypotheticalModelID	

		--SELECT * FROM  #Hypothetical WHERE RawScoreAdjustment=0 --No results

	-- Calculate RawScoreCombined which combines the standard(RawScoreValue) and hypothetical(RawScoreAdjustment) risk scores.
	DROP TABLE IF EXISTS #Final
	CREATE TABLE #Final(MVIPersonSID INT, ModelID SMALLINT, HypotheticalModelID SMALLINT, RawScoreCombined DECIMAL(15,8) )
	INSERT INTO #Final WITH(TABLOCK)
	SELECT C.MVIPersonSID
		,C.ModelID
		,NULL AS HypotheticalModelID
		,C.RawScoreValue		
	FROM #RawScore C	
	-- Only calculate standard risk scores for patients that meet the variable criteria defined by the model
	INNER JOIN #Pop P ON 
		p.MVIPersonSID = C.MVIPersonSID 
		AND p.ModelID = p.ModelID 
		AND (p.InclusionCriteria=1 AND p.ExclusionCriteria=0)	
	UNION ALL
	SELECT H.MVIPersonSID		
		,H.ModelID
		,H.HypotheticalModelID 
		,C.RawScoreValue + H.RawScoreAdjustment AS RawScoreValue
	FROM #RawScore C 	
	INNER JOIN #Hypothetical H ON H.MVIPersonSID = C.MVIPersonSID AND H.ModelID = C.ModelID
	
	-- Save keeper rows to temp table and insert new data. Add all data back to permanent table
	DROP TABLE IF EXISTS #StageRiskScore
	SELECT MVIPersonSID,ModelID,HypotheticalModelID,RiskScore 
	INTO #StageRiskScore 
	FROM [RiskScore].[PatientRiskScore]
	WHERE ModelID NOT IN (SELECT ModelID FROM #Model)
	
	INSERT INTO #StageRiskScore (MVIPersonSID,ModelID,HypotheticalModelID,RiskScore)
	SELECT C.MVIPersonSID
		,C.ModelID
		,HypotheticalModelID
		,EXP(C.RawScoreCombined + Intercept.Intercept) / (1 + EXP(C.RawScoreCombined + Intercept.Intercept)) AS RiskScore
	FROM #Final C
	INNER JOIN #Model Intercept ON Intercept.ModelID = C.ModelID 

	EXEC [Maintenance].[PublishTable] 'RiskScore.PatientRiskScore','#StageRiskScore'

END