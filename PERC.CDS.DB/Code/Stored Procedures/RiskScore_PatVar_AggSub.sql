	 

/********************************************************************************
CREATE DATE: 2020-02-12
AUTHOR:	Rebecca Stephens (RAS)
MODIFICATIONS:
	-- 20200811	RAS	Branched to VM version.
	-- 20201204	RAS	Added SourceEHR to temp table and final merge.
********************************************************************************/

CREATE PROCEDURE [Code].[RiskScore_PatVar_AggSub]

AS
BEGIN

	-- Create #PatientVariable table
	DROP TABLE IF EXISTS #PatientVariableAgg
	CREATE TABLE #PatientVariableAgg (
		MVIPersonSID INT NOT NULL, 
		VariableID INT NOT NULL, 
		VariableValue DECIMAL(15,8), 
		ImputedFlag BIT,
		SourceEHR VARCHAR(2)
		)

--------------------------------------------------------------------------------------------------------------
-- Compute aggregates
--------------------------------------------------------------------------------------------------------------

--Aggregates MAX
INSERT INTO #PatientVariableAgg (MVIPersonSID,VariableID,VariableValue,SourceEHR)
SELECT p.MVIPersonSID
	  ,a.VariableID
	  ,max(p.VariableValue) as VariableValue
	  ,CASE WHEN COUNT(DISTINCT p.SourceEHR) = 1 AND MAX(p.SourceEHR) = 'V' THEN 'V'
			WHEN COUNT(DISTINCT p.SourceEHR) = 1 AND MAX(p.SourceEHR) = 'M' THEN 'M'
			WHEN COUNT(DISTINCT p.SourceEHR) = 2 THEN 'VM' ELSE NULL END as SourceEHR
FROM [RiskScore].[PatientVariable] p WITH (NOLOCK)
INNER JOIN [RiskScore].[VariableAggSub] a WITH (NOLOCK) on p.VariableID=a.ReferenceVariableID
WHERE VariableMethod='Max'
GROUP BY p.MVIPersonSID
	,a.VariableID

--Aggregates SUM
INSERT INTO #PatientVariableAgg (MVIPersonSID,VariableID,VariableValue,SourceEHR)
SELECT p.MVIPersonSID
	  ,a.VariableID
	  ,sum(p.VariableValue) as VariableValue
	  ,CASE WHEN COUNT(DISTINCT p.SourceEHR) = 1 AND MAX(p.SourceEHR) = 'V' THEN 'V'
			WHEN COUNT(DISTINCT p.SourceEHR) = 1 AND MAX(p.SourceEHR) = 'M' THEN 'M'
			WHEN COUNT(DISTINCT p.SourceEHR) = 2 THEN 'VM' ELSE NULL END as SourceEHR
FROM [RiskScore].[PatientVariable] p WITH (NOLOCK)
INNER JOIN [RiskScore].[VariableAggSub] a WITH (NOLOCK) on p.VariableID=a.ReferenceVariableID
WHERE VariableMethod='Sum'
GROUP BY p.MVIPersonSID
	,a.VariableID

--"Aggregates" SQUARE
INSERT INTO #PatientVariableAgg (MVIPersonSID,VariableID,VariableValue,SourceEHR)
SELECT p.MVIPersonSID
	  ,a.VariableID
	  ,square(p.VariableValue) as VariableValue
	  ,p.SourceEHR
FROM [RiskScore].[PatientVariable] p WITH (NOLOCK)
INNER JOIN [RiskScore].[VariableAggSub] a WITH (NOLOCK) on p.VariableID=a.ReferenceVariableID
WHERE VariableMethod='Square'

--------------------------------------------------------------------------------------------------------------
-- Compute subsets
--------------------------------------------------------------------------------------------------------------	
--Compute ranges
INSERT INTO #PatientVariableAgg (MVIPersonSID,VariableID,VariableValue,SourceEHR)
SELECT p.MVIPersonSID
	  ,s.VariableID
	  ,VariableValue=1
	  ,p.SourceEHR
FROM [RiskScore].[PatientVariable] p WITH (NOLOCK)
INNER JOIN [RiskScore].[VariableAggSub] s WITH (NOLOCK) on s.ReferenceVariableID=p.VariableID
WHERE p.VariableValue BETWEEN s.LowerLimit AND s.UpperLimit
	AND s.VariableMethod='Range'

--Compute matches
INSERT INTO #PatientVariableAgg (MVIPersonSID,VariableID,VariableValue,SourceEHR)
SELECT p.MVIPersonSID
	  ,s.VariableID
	  ,VariableValue=1
	  ,p.SourceEHR
FROM [RiskScore].[PatientVariable] p WITH (NOLOCK)
INNER JOIN [RiskScore].[VariableAggSub] s WITH (NOLOCK) on s.ReferenceVariableID=p.VariableID
WHERE p.VariableValue = s.LowerLimit
	AND s.VariableMethod='Match'

--------------------------------------------------------------------------------------------------------------
/****************************************ADD TO PATIENT VARIABLES TABLE***************************************/
--------------------------------------------------------------------------------------------------------------
MERGE [RiskScore].[PatientVariable] AS t
	USING #PatientVariableAgg AS s 
	ON t.MVIPersonSID=s.MVIPersonSID 
		AND t.VariableID=s.VariableID
	WHEN MATCHED THEN 
		UPDATE SET VariableValue=s.VariableValue
			,SourceEHR=s.SourceEHR
	WHEN NOT MATCHED THEN
		INSERT (MVIPersonSID, VariableID, VariableValue,SourceEHR)
		VALUES (s.MVIPersonSID,s.VariableID,s.VariableValue,s.SourceEHR)
	--WHEN NOT MATCHED BY SOURCE
	--	AND t.VariableID IN (SELECT VariableID FROM #PatientVariableAgg) 
	--THEN DELETE
	;

	--Remove rows for those patients who previously had the variable, but now do not
	----this was faster than including the deletion in the merge statement
	DELETE t
	--SELECT t.MVIPersonSID,t.VariableID,t.VariableValue,s.VariableValue,v.VariableID
	FROM [RiskScore].[PatientVariable] AS t
	LEFT JOIN #PatientVariableAgg s ON 
		s.MVIPersonSID=t.MVIPersonSID
		AND s.VariableID=t.VariableID
	LEFT JOIN (
		SELECT DISTINCT VariableID 
		FROM #PatientVariableAgg
		) v ON v.VariableID=t.VariableID
	WHERE v.VariableID IS NOT NULL
		AND s.VariableID IS NULL

END