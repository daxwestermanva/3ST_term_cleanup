/*--=============================================
-- Author:		Matt Wollner
-- Create date: 2018-08-30
-- Description: Add List Members for TIUDocumentDefinition 
-- Current Categories:
		TIUDocumentDefinition
--Modifications:
	2020-09-22	- RAS	- Refactored to use LookUpList_ListMember SP
	2023-11-29	- LM	- Migrated note titles from Lookup.TIUDocumentDefinition; added pattern matching and Cerner note titles

--=============================================*/ 

CREATE PROCEDURE [Code].[LookUpList_TIUDocumentDefinition]
AS
BEGIN

--SET NOCOUNT ON added to prevent extra result sets FROM interfering with SELECT statements.
SET NOCOUNT ON;

	/*
		--Mapping rules have been setup for each ListMappingRule.Attribute
		SELECT DISTINCT Attribute
		FROM [Lookup].[ListMappingRule] 
		WHERe Domain = 'TIUDocumentDefinition'
	*/


----------------------------------------------------------------------------
-- PHASE 1:  Get all the standard TIUDocumentDefinition
-- Exact Match and Patttern Match will get Auto Approved
----------------------------------------------------------------------------
--CPRS clinical documents
EXEC [Code].[LookUpList_ListMember] @Domain='TIUDocumentDefinition'
	,@SourceTable='[Dim].[TIUDocumentDefinition]'
	,@ItemIDName='TIUDocumentDefinitionSID'
	--,@Debug = 1 --Use this line to see the printed results of the dynamic SQL from LookUpList_ListMember

--Cerner clinical documents
EXEC [Code].[LookUpList_ListMember] @Domain='mdoc'
	,@SourceTable='[Cerner].[DimPowerFormNoteTitle]'
	,@ItemIDName='TIUDocumentDefinitionSID'
	--,@Debug = 1 --Use this line to see the printed results of the dynamic SQL from LookUpList_ListMember

----------------------------------------------------------------------------
--Create temp table for use in Phase 2 and 3
----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #ListMember

	CREATE TABLE #ListMember(
		[List] VARCHAR(50),
		[Domain] VARCHAR(50),
		[Attribute] VARCHAR(50),
		[ItemID] INT,
		[ItemIDName] VARCHAR(50),
		[AttributeValue] VARCHAR(100),
		[CreatedDateTime] SMALLDATETIME,
		[MappingSource]  VARCHAR(50),
		[ApprovalStatus]  VARCHAR(50),
		[ApprovedDateTime] SMALLDATETIME
	 )
----------------------------------------------------------------------------
-- PHASE 2: Get the Custom TIUDocumentDefinition Mappings
----------------------------------------------------------------------------
		-- updating definition information
		INSERT INTO #ListMember (List,ItemID,AttributeValue)
		SELECT DISTINCT 
			 'SuicidePrevention_SafetyPlan_TIU' 
			,T.TIUDocumentDefinitionSID
			,T.TIUDocumentDefinition
		FROM  [Dim].[TIUDocumentDefinition] T
		INNER JOIN [Dim].[TIUStandardTitle] S
			ON T.TIUStandardTitleSID = S.TIUStandardTitleSID
		LEFT OUTER JOIN #ListMember TMP 
			ON TMP.List =  'SuicidePrevention_SafetyPlan_TIU'
			AND TMP.ItemID = T.TIUDocumentDefinitionSID 
		WHERE 	(TIUDocumentDefinition LIKE '%SUICIDE PREVENTION SAFETY PLAN%') --includes historical, review/decline, and site prefix/suffix
			AND S.TIUStandardTitle='SUICIDE PREVENTION NOTE'
			AND T.TIUDocumentDefinition NOT LIKE '%TEST'
			AND T.TIUDocumentDefinition NOT LIKE '%DECLINE' --remove review/decline notes
			AND T.TIUDocumentDefinition NOT LIKE '%REVIEW/DEC%' --double ensure removal of review/decline notes - found some cases where the note title text cut off at '... REVIEW/DECL'
		--Historical Local VistA Titles: 
		UNION
		SELECT
			'SuicidePrevention_SafetyPlan_TIU' 
			,T.TIUDocumentDefinitionSID
			,T.TIUDocumentDefinition
		FROM [Dim].[TIUDocumentDefinition] T 
		INNER JOIN [Dim].[TIUStandardTitle] S
			ON T.TIUStandardTitleSID = S.TIUStandardTitleSID
		INNER JOIN [PRF_HRS].[LookUp_NoteTitles] as b ON
			T.Sta3n=b.Sta3n 
			AND (T.TIUDocumentDefinition=b.DocumentDefinition OR T.TIUDocumentDefinitionPrintName=b.DocumentDefinition)
			AND S.TIUStandardTitle=StandardTitle
		WHERE b.NoteTopic like '%Safety Plan%'
		UNION
		SELECT
			'TobaccoCounseling_TIU'
			,T.TIUDocumentDefinitionSID
			,T.TIUDocumentDefinition
		FROM [Dim].[TIUDocumentDefinition] T 	
		WHERE ((([TIUDocumentDefinition] like '%Smok%' or [TIUDocumentDefinition] like '%Tobacc%' or [TIUDocumentDefinition] like '%nicot%')  
		  and ([TIUDocumentDefinition] like '%cessation%' or ([TIUDocumentDefinition] like '%Group%' or [TIUDocumentDefinition] like '%Couns%' 
			  or [TIUDocumentDefinition] like '%Indiv%'))) 
		and [TIUDocumentDefinition] not like '%Cons%' and [TIUDocumentDefinition] not like '%Contact%' 
		and [TIUDocumentDefinition] not like '%Letter%' and [TIUDocumentDefinition] not like '%No Show%' 
		and [TIUDocumentDefinition] not like '%Discharge%' and [TIUDocumentDefinition] not like 'ZZ%' 
		or (sta3n = '663' and [TIUDocumentDefinition] like 'ATC Group Note%'))-- added these for American Lake Dom.
		UNION
		SELECT
			'ORM_PDMP_TIU'
			,T.TIUDocumentDefinitionSID
			,T.TIUDocumentDefinition
		FROM [Dim].[TIUDocumentDefinition] T 
		INNER JOIN [Dim].[TIUStandardTitle] S
			ON T.TIUStandardTitleSID = S.TIUStandardTitleSID
		WHERE ([TIUDocumentDefinition] LIKE '%STATE%PRESCRIPTION%DRUG%MONITOR%'
			OR [TIUDocumentDefinition] LIKE 'Z%STATE%PRESCRIPTION%DRUG%MONITORING%PROGRAM%'
			OR [TIUDocumentDefinition] LIKE '%CONTROLLED%SUBSTANCE%ORDER%'
			OR [TIUDocumentDefinition] LIKE '%OPIOID%RISK%REVIEW%PDMP%'
			)
			AND [TIUStandardTitle] LIKE '%ACCOUNT%DISCLOSURE%'
		UNION
		SELECT
			'ORM_DatabasedReview_TIU'
			,T.TIUDocumentDefinitionSID
			,T.TIUDocumentDefinition
		FROM [Dim].[TIUDocumentDefinition] T 	
		WHERE (TIUDocumentDefinition LIKE '%Data%'  
		AND TIUDocumentDefinition LIKE '%based%'  
		AND TIUDocumentDefinition LIKE '%risk%'  
		AND TIUDocumentDefinition LIKE '%review%')

		--Standard Title mappings
		INSERT INTO #ListMember (List,ItemID,AttributeValue)
		SELECT DISTINCT 
			 L.List
			,T.TIUDocumentDefinitionSID
			,T.TIUDocumentDefinition
		FROM  [Dim].[TIUDocumentDefinition] T
		INNER JOIN [Dim].[TIUStandardTitle] S
			ON T.TIUStandardTitleSID = S.TIUStandardTitleSID
		INNER JOIN [Lookup].[ListMappingRule] l
			ON S.TIUStandardTitle LIKE L.SearchTerm
		WHERE L.Domain LIKE 'TIUStandardTitle' 
	
	--Fill in additional fields for all of the above custom mappings
		UPDATE #ListMember
		SET  Domain = 'TIUDocumentDefinition'
		,Attribute = 'TIUDocumentDefinition'
		,ItemIDName= 'TIUDocumentDefinitionSID'
		,CreatedDateTime = GETDATE()
		,MappingSource = 'LookUp_TIUDocumentDefinition'
		,ApprovalStatus = 'Pending'
----------------------------------------------------------------------------
-- PHASE 3: Load Lookup.ListMember
 ----------------------------------------------------------------------------

	MERGE [Lookup].[ListMember] AS TARGET
	USING (SELECT DISTINCT * FROM #ListMember) AS SOURCE
			ON	TARGET.List = SOURCE.List
			AND TARGET.Domain = SOURCE.Domain
			AND TARGET.[ItemID] = SOURCE.[ItemID]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([List], [Domain], [Attribute], [ItemID],[ItemIDName],[AttributeValue],[CreatedDateTime],[MappingSource],[ApprovalStatus],[ApprovedDateTime] ) 
		VALUES (SOURCE.[List], SOURCE.[Domain], SOURCE.[Attribute], SOURCE.[ItemID],SOURCE.[ItemIDName],SOURCE.[AttributeValue],SOURCE.[CreatedDateTime],SOURCE.[MappingSource],SOURCE.[ApprovalStatus],SOURCE.[ApprovedDateTime]) 
	WHEN NOT MATCHED BY SOURCE AND (TARGET.Domain ='TIUDocumentDefinition') AND TARGET.List IN (SELECT List FROM #ListMember)
		THEN DELETE;


	DELETE FROM [Lookup].[ListMember]
	WHERE List NOT IN (SELECT List FROM [Lookup].[ListMappingRule] WHERE Domain='TIUDocumentDefinition')
	AND Domain='TIUDocumentDefinition' 
	AND MappingSource IN ('Exact Match','Pattern Match')

	DELETE FROM [Lookup].[ListMember]
	WHERE ItemID IN (SELECT TIUDocumentDefinitionSID FROM Dim.TIUDocumentDefinition WHERE TIUDocumentDefinitionType<>'TITLE')
	AND Domain='TIUDocumentDefinition' 

	--DELETE FROM [Lookup].[ListMember]
	--WHERE List NOT IN (SELECT List FROM [Lookup].[ListMappingRule] WHERE Domain='TIUStandardTitle')
	--AND Domain='TIUStandardTitle' 
	--AND MappingSource IN ('Exact Match','Pattern Match')

	--DELETE FROM [Lookup].[ListMember]
	--WHERE List NOT IN (SELECT List FROM [Lookup].[ListMappingRule] WHERE Domain='mdoc')
	--AND Domain='mdoc' 
	--AND MappingSource IN ('Exact Match','Pattern Match')

END