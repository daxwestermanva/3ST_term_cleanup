
/***-- =============================================
-- Author:		Rebecca Stephens
-- Create date: 2020-09-04
-- ColumnDescription:	LookUp list for Activity Type in Cerner Millenium data (similar to VistA stop code categorizations) 
-- Modification:
	2020-09-08	RAS	Created code for ActivityType. Including all categories defined per JT.
					Excluding MHOC HBPC from code and ListMappingRule table since no ActivityTypes have been identified in this category.
	2020-09-18	RAS Pointed code to synonym CDW2.CDS_DimActivityType instead of App.CDW2_NDimMill_OrderCatalog
	2020-12-04	RAS	Added MHOC_MH to LookUp.ListMappingRule. This category encompasses all other MHOC categories EXCEPT homeless.
					Changed Attribute to "Display" in order for joins to search term to work correctly.

-- QUESTIONS:
-- Should 'VA Acute Psych' be included in MHOC GMH?
-- ============================================= */ 
/*
Previous LookUp.StopCode column name and new ActivityType List name:
	GeneralMentalHealth_Stop	-->	MHOC_GMH
	N/A							-->	MHOC_Homeless
	N/A							-->	MHOC_MHICM
	N/A							-->	MHOC_PCMHI
	N/A							-->	MHOC_PCT
	N/A							-->	MHOC_PRRC
	N/A							-->	MHOC_PTSD
	N/A							-->	MHOC_RRTP
	N/A							-->	MHOC_SUD
	N/A							-->	MHOC_TSES
	MHOC_MentalHealth_Stop		-->	MHOC_MH
	Reach_Homeless_Stop			-->	Reach_Homeless_Stop
	Reach_MH_Stop				-->	Reach_MH_Stop
*/
/*
These VA Activity Types are NOT included in any CDS definitions and
will therefore not appear in LookUp.ListMappingRule or LookUp.ListMember (2020-09-04)
	VA Nursing Workload
	VA Palliative Care
	VA Surgery Coding Charges
	VA UC Professional Charges
	Whole Health Well-Being
	Whole Health Treatment 
*/

CREATE PROCEDURE [Code].[LookUpList_ActivityType]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.LookUpList_ActivityType', @Description = 'Execution of Code.LookUpList_ActivityType SP'

----------------------------------------------------------------------------
-- PHASE 1:  Get all the standard Mappings
-- Exact Match and Patttern Match will get Auto Approved
----------------------------------------------------------------------------
EXEC [Code].[LookUpList_ListMember] @Domain='ActivityType'
	,@SourceTable='[Cerner].[DimActivityType]'
	,@ItemIDName='CodeValueSID'
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
-- Exact Match and Patttern Match will get Pending  Approval
----------------------------------------------------------------------------
----2020-09-18: There are no custom mappings for ActivityType at this time

----------------------------------------------------------------------------
-- PHASE 3: Find Members with No Mappings
 ----------------------------------------------------------------------------
 ----NOTE: This architecture is NOT currently being used, but we could activate it 
 ----in order to keep track of items from Cerner that we are not mapping to any categories
 /*
	INSERT INTO #ListMember (List,Domain,Attribute,ItemID,AttributeValue,CreatedDateTime,MappingSource,ApprovalStatus,ApprovedDateTime)
	SELECT DISTINCT
		List				='Unknown'
		,Domain				= 'ActivityType'
		,Attribute			= 'ActivityType'
		,ItemID				= dim.ActivityTypeCodeValueSID
		,AttributeValue		= ActivityType
		,CreatedDateTime	= GETDATE()
		,MappingSource		= 'No Match'
		,ApprovalStatus		= 'Pending'
		,ApprovedDateTime	= NULL
	FROM [Cerner].[FactDimActivityType] dim
	LEFT OUTER JOIN #ListMember TMP ON TMP.ItemID = dim.ActivityTypeCodeValueSID
	WHERE TMP.ItemID IS NULL 
	ORDER BY AttributeValue
	*/
----------------------------------------------------------------------------
-- PHASE 4: Load Lookup.ListMember
-- Insert and Delete
 ----------------------------------------------------------------------------
 
	--MERGE [Lookup].[ListMember] AS TARGET
	--USING (SELECT DISTINCT * FROM #ListMember) AS SOURCE
	--		ON	TARGET.List = SOURCE.List
	--		AND TARGET.Domain = SOURCE.Domain
	--		AND TARGET.ItemID = SOURCE.ItemID
	--WHEN NOT MATCHED BY TARGET THEN
	--	INSERT ([List], [Domain], [Attribute], [ItemID],[AttributeValue],[CreatedDateTime],[MappingSource],[ApprovalStatus],[ApprovedDateTime] ) 
	--	VALUES (SOURCE.[List], SOURCE.[Domain], SOURCE.[Attribute], SOURCE.[ItemID],SOURCE.[AttributeValue],SOURCE.[CreatedDateTime],SOURCE.[MappingSource],SOURCE.[ApprovalStatus],SOURCE.[ApprovedDateTime]) 
	--WHEN NOT MATCHED BY SOURCE AND TARGET.Domain = 'ActivityType' AND TARGET.List IN (SELECT DISTINCT List FROM #ListMember)
	--	THEN DELETE;

EXEC [Log].[ExecutionEnd]

END