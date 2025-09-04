
/*--=============================================
-- Author:           Matt Wollner
-- Create date: 2018-08-30
-- Description: Add List Members for TIUDocumentDefinition 
-- Current Categories:
              TIUDocumentDefinition
--Modifications:
       2018-08-08    - xxx  -      
       2018-10-11    Catherine Barry; description: use original code for TIUDocumentDefinition and repurposed for MHA C-SSRS items
	   2020-09-18	RAS - Refactored to use shared SP for exact and pattern matched. Commented out the rest of the code since there were no custom mappings to account for.
--=============================================*/ 


CREATE PROCEDURE [Code].[LookUpList_MHA]
AS
BEGIN

     
---------------------------------------------------------------------------
-- PHASE 1:  Get all the MHA Mappings
----------------------------------------------------------------------------
EXEC [Code].[LookUpList_ListMember] @Domain='SurveyQuestion'
	,@SourceTable='[Dim].[SurveyQuestion]'
	,@ItemIDName='SurveyQuestionSID'

EXEC [Code].[LookUpList_ListMember] @Domain='SurveyChoice'
	,@SourceTable='[Dim].[SurveyChoice]'
	,@ItemIDName='SurveyChoiceSID'

EXEC [Code].[LookUpList_ListMember] @Domain='Survey'
	,@SourceTable='[Dim].[Survey]'
	,@ItemIDName='SurveySID'

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
-- PHASE 2: Get the Custom Mappings
----------------------------------------------------------------------------
       --Not applicable at this time

----------------------------------------------------------------------------
-- PHASE 3: Load Lookup.ListMember
----------------------------------------------------------------------------

       --MERGE [Lookup].[ListMember] AS TARGET
       --USING (SELECT DISTINCT * FROM #ListMember) AS SOURCE
       --              ON     TARGET.List = SOURCE.List
       --              AND TARGET.Domain = SOURCE.Domain
       --              AND TARGET.ItemID = SOURCE.MemberID
       --WHEN NOT MATCHED BY TARGET THEN
       --       INSERT ([List], [Domain], [Attribute], [ItemID],[AttributeValue],[CreatedDateTime],[MappingSource],[ApprovalStatus],[ApprovedDateTime] ) 
       --       VALUES (SOURCE.[List], SOURCE.[Domain], SOURCE.[Attribute], SOURCE.[MemberID],SOURCE.[AttributeValue], SOURCE.[CreatedDateTime],SOURCE.[MappingSource],SOURCE.[ApprovalStatus],SOURCE.[ApprovedDateTime]) 
	   --WHEN NOT MATCHED BY SOURCE AND TARGET.Domain = 'HealthFactorType' AND TARGET.List IN (SELECT DISTINCT List FROM #ListMember)
       --       THEN DELETE;

END