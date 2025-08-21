
/*--=============================================
-- Author:		Rebecca Stephens
-- Create date: 2022-04-17
-- Description: Lookup List for CPT to replace LookUp CPT_VM

-- Current Categories:
		
--Modifications:
	2022-04-27	RAS	Created procedure based on other LookUpList templates and overlay code from LookUp_CPT_VM

-- Testing:
	EXEC [Code].[LookUpList_CPT]
	SELECT * FROM [LookUp].[ListMember] WHERE Domain = 'CPT'
--=============================================*/ 


CREATE PROCEDURE [Code].[LookUpList_CPT]
AS
BEGIN
	
----------------------------------------------------------------------------
-- PHASE 1:  Get all the standard CPT Mappings
-- Exact Match and Pattern Match will get Auto Approved
----------------------------------------------------------------------------

CREATE TABLE ##DimCPT  (
	CPTSID INT
	,Sta3n INT
	,CPTName VARCHAR(100)
	,CPTCode VARCHAR(50)
	,InactiveFlag VARCHAR(12)
	)

	INSERT ##DimCPT
	SELECT CPTSID
		  ,Sta3n
		  ,CPTName
		  ,CPTCode
		  ,InactiveFlag
	FROM (
		SELECT nom.NomenclatureSID as CPTSID
			,200 AS Sta3n
			,MAX(dc.CPTName) as CPTName
			,nom.SourceString as CPTDescription
			,nom.SourceIdentifier as CPTCode
			,nom.InactiveFlag
		FROM [Cerner].[DimNomenclature] nom
		LEFT JOIN [Dim].[CPT] dc ON nom.SourceIdentifier = dc.CPTCode
		WHERE nom.SourceVocabulary IN ('CPT4','HCPCS')
			AND nom.PrincipleType = 'Procedure'
		GROUP BY nom.NomenclatureSID
				,nom.SourceString 
				,nom.SourceIdentifier
				,nom.InactiveFlag
		UNION ALL
		SELECT CPTSID,Sta3n,CPTName,CPTDescription,CPTCode,InactiveFlag
		FROM [Dim].[CPT]
		) a

EXEC [Code].[LookUpList_ListMember] @Domain='CPT'
	,@SourceTable= '##DimCPT'
	,@ItemIDName='CPTSID'
	--,@Debug = 1 --Use this line to see the printed results of the dynamic SQL from LookUpList_ListMember
	
	DROP TABLE ##DimCPT

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