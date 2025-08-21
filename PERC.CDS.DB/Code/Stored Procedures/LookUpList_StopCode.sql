/*--=============================================
-- Author:		Rebecca Stephens
-- Create date: 2022-05-05
-- Description: Lookup List for StopCode to replace LookUp StopCode

-- Current categories:	
	CIH
	RM_ActiveTherapies
	RM_ChiropracticCare
	RM_OccupationalTherapy
	RM_OtherTherapy
	RM_PainClinic
	RM_PhysicalTherapy
	RM_SpecialtyTherapy
	Rx_MedManagement	

--Modifications:
	2022-05-05	RAS	Created procedure based on other LookUpList templates and LookUp_StopCode SP
					Only added ORM rehab and risk mitigation codes for now.

-- Testing:
	EXEC [Code].[LookUpList_StopCode]
	SELECT * FROM [LookUp].[ListMember] WHERE Domain = 'StopCode'
	SELECT DISTINCT List FROM [LookUp].[ListMember] WHERE Domain = 'StopCode'
--=============================================*/ 


CREATE PROCEDURE [Code].[LookUpList_StopCode]
AS
BEGIN
	
----------------------------------------------------------------------------
-- PHASE 1:  Get all the standard StopCode Mappings
-- Exact Match and Pattern Match will get Auto Approved
----------------------------------------------------------------------------

EXEC [Code].[LookUpList_ListMember] @Domain='StopCode'
	,@SourceTable= 'Dim.StopCode'
	,@ItemIDName='StopCodeSID'
	--,@Debug = 1 --Use this line to see the printed results of the dynamic SQL from LookUpList_ListMember
	

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