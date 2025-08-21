
/*--=============================================
-- Author:		Rebecca Stephens
-- Create date: 2022-05-05
-- Description: Lookup List for ICD10PCS to replace LookUp ICD10Proc
		
--Modifications:
	2022-04-27	RAS	Created procedure based on other LookUpList templates and overlay code from LookUp_ICD10Proc

-- Testing:
	EXEC [Code].[LookUpList_ICD10PCS]
	SELECT * FROM [LookUp].[ListMember] WHERE Domain = 'ICD10PCS'
	SELECT DISTINCT List FROM [LookUp].[ListMember] WHERE Domain = 'ICD10PCS'
--=============================================*/ 


CREATE PROCEDURE [Code].[LookUpList_ICD10PCS]
AS
BEGIN
	
----------------------------------------------------------------------------
-- PHASE 1:  Get all the standard ICD10PCS Mappings
-- Exact Match and Pattern Match will get Auto Approved
----------------------------------------------------------------------------
DROP TABLE IF EXISTS ##DimICD10PCS
CREATE TABLE ##DimICD10PCS  (
	ICD10ProcedureSID INT
	,Sta3n INT
	,ICD10ProcedureDescription VARCHAR(1000)
	,ICD10ProcedureShort VARCHAR(100)
	,ICD10ProcedureCode VARCHAR(50)
	)

	INSERT ##DimICD10PCS
	SELECT ICD10ProcedureSID
		,Sta3n
		,ICD10ProcedureDescription
		,ICD10ProcedureShort 
		,ICD10ProcedureCode 
	FROM (
		/*##SHAREMILL BEGIN##*/
		SELECT DISTINCT 
			NomenclatureSID as ICD10ProcedureSID
			,Sta3n = CAST(200 AS SMALLINT)
			,SourceString as ICD10ProcedureDescription
			,LEFT(SourceString, 100) as ICD10ProcedureShort
			,SourceIdentifier as ICD10ProcedureCode
		FROM [Cerner].[DimNomenclature]
		WHERE SourceVocabulary IN ('ICD-10-PCS')
			AND PrincipleType ='Procedure'
			AND ContributorSystem = 'Centers for Medicare & Medicaid Services'
		UNION ALL 
		SELECT DISTINCT 
			p.ICD10ProcedureSID
			,p.Sta3n
			,d.ICD10ProcedureDescription
			,LEFT(d.ICD10ProcedureDescription, 100) as ICD10ProcedureShort
			,p.ICD10ProcedureCode
		FROM [Dim].[ICD10Procedure] as p
		INNER JOIN [Dim].[ICD10ProcedureDescriptionVersion] as d on d.ICD10ProcedureSID=p.ICD10ProcedureSID
		WHERE d.CurrentVersionFlag LIKE 'Y'
		/*##SHAREMILL END##*/
		) a

EXEC [Code].[LookUpList_ListMember] @Domain='ICD10PCS'
	,@SourceTable= '##DimICD10PCS'
	,@ItemIDName='ICD10ProcedureSID'
	--,@Debug = 1 --Use this line to see the printed results of the dynamic SQL from LookUpList_ListMember
	
	DROP TABLE ##DimICD10PCS

----------------------------------------------------------------------------
--Create temp table for use in Phase 2 and 3
----------------------------------------------------------------------------
	--DROP TABLE IF EXISTS #ListMember

	--CREATE TABLE #ListMember(
	--	[List] VARCHAR(50),
	--	[Domain] VARCHAR(50),
	--	[Attribute] VARCHAR(50),
	--	[ItemID] INT,
	--	[AttributeValue] VARCHAR(100),
	--	[CreatedDateTime] SMALLDATETIME,
	--	[MappingSource]  VARCHAR(50),
	--	[ApprovalStatus]  VARCHAR(50),
	--	[ApprovedDateTime] SMALLDATETIME
	-- )
----------------------------------------------------------------------------
-- PHASE 2: Get the Custom Health Factor Mappings
-- Eact Match and Patttern Match will get Pending  Approval
----------------------------------------------------------------------------
	-- No custom mappings for CPT at this time
	
----------------------------------------------------------------------------
-- PHASE 3: Find Members with No Mappings
 ----------------------------------------------------------------------------
 ----NOTE: This architecture is NOT currently being used, but we could activate it 
 ----in order to keep track of items that we are not mapping to any categories

----------------------------------------------------------------------------
-- PHASE 4: Load Lookup.ListMember
-- Insert and Delete
 ----------------------------------------------------------------------------
 -- only needed is phase 2 and/or 3 are used

	--MERGE [Lookup].[ListMember] AS TARGET
	--USING (SELECT DISTINCT * FROM #ListMember) AS SOURCE
	--		ON	TARGET.List = SOURCE.List
	--		AND TARGET.Domain = SOURCE.Domain
	--		AND TARGET.ItemID = SOURCE.ItemID
	--WHEN NOT MATCHED BY TARGET THEN
	--	INSERT (List,Domain,ItemID,Attribute,AttributeValue,CreatedDateTime,MappingSource,ApprovalStatus,ApprovedDateTime) 
	--	VALUES (SOURCE.List,SOURCE.Domain,SOURCE.ItemID,SOURCE.Attribute,SOURCE.AttributeValue
	--		,SOURCE.CreatedDateTime,SOURCE.MappingSource,SOURCE.ApprovalStatus,SOURCE.ApprovedDateTime) 
	--WHEN NOT MATCHED BY SOURCE AND TARGET.Domain = 'CPTCode' AND TARGET.List IN (SELECT List FROM #ListMember)
	--	THEN DELETE;

END