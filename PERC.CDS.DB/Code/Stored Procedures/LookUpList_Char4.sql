
/*--=============================================
-- Author:		Rebecca Stephens
-- Create date: 2022-05-06
-- Description: Lookup List for Char4 to replace LookUp Char4
		
--Modifications:
	2022-05-06	RAS	Created procedure based on other LookUpList templates and overlay code from LookUp_Char4

-- Testing:
	EXEC [Code].[LookUpList_Char4]
	SELECT * FROM [LookUp].[ListMember] WHERE Domain = 'Char4'
	SELECT DISTINCT List FROM [LookUp].[ListMember] WHERE Domain = 'Char4'
--=============================================*/ 
CREATE PROCEDURE [Code].[LookUpList_Char4]
AS
BEGIN
	
----------------------------------------------------------------------------
-- PHASE 1:  Get all the standard Char4 Mappings
-- Exact Match and Pattern Match will get Auto Approved
----------------------------------------------------------------------------
DROP TABLE IF EXISTS ##DimChar4
CREATE TABLE ##DimChar4  (
	LocationSID INT
	,Sta3n INT
	,NationalChar4 VARCHAR(100)
	,NationalChar4Description VARCHAR(1000)
	)

	INSERT ##DimChar4
	SELECT l.LocationSID
		,lsc.Sta3n
		,lsc.DSSLocationStopCode AS NationalChar4
		,lsc.DSSLocationStopCodeDescription AS NationalChar4Description
	FROM  [Dim].[DSSLocation] as l WITH (NOLOCK)
	INNER JOIN [Dim].[DSSLocationStopCode] as lsc WITH (NOLOCK) ON l.[DSSLocationStopCodeSID] = lsc.[DSSLocationStopCodeSID]

EXEC [Code].[LookUpList_ListMember] @Domain='Char4'
	,@SourceTable= '##DimChar4'
	,@ItemIDName='LocationSID'
	--,@Debug = 1 --Use this line to see the printed results of the dynamic SQL from LookUpList_ListMember
	
	DROP TABLE ##DimChar4

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