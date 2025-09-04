
/*--=============================================
-- Author:		Liam Mina
-- Create date: 2020-08-06
-- Description: PowerForm lookup
--Modifications:
--	2020-11-10	LM	Added pattern matching


--=============================================*/ 


CREATE PROCEDURE [Code].[LookUpList_PowerForm]
AS
BEGIN

--SET NOCOUNT ON added to prevent extra result sets FROM interfering with SELECT statements.
SET NOCOUNT ON;

	
	DROP TABLE IF EXISTS #ListMember

	CREATE TABLE #ListMember(
		[List] VARCHAR(50),
		[Domain] VARCHAR(50),
		[Attribute] VARCHAR(50),
		[ItemID] INT,
		[ItemIDName] VARCHAR(50),
		[AttributeValue] VARCHAR(500),
		[CreatedDateTime] SMALLDATETIME,
		[MappingSource]  VARCHAR(50),
		[ApprovalStatus]  VARCHAR(50),
		[ApprovedDateTime] SMALLDATETIME
	 )

----------------------------------------------------------------------------
-- PHASE 1:  Get all the standard PowerForm Mappings
-- Exact Match and Patttern Match will get Auto Approved
----------------------------------------------------------------------------

	/*
		--Mapping rules have been setup for each ListMappingRule.Attribute
		SELECT DISTINCT Attribute
		FROM [Lookup].[ListMappingRule] 
		WHERe Domain = 'PowerForm'
	*/
	--For Cerner PowerForms
	INSERT INTO #ListMember
	SELECT DISTINCT
		L.List
		,L.Domain
		,L.Attribute
		,P.DerivedDtaEventCodeValueSID AS ItemID
		,ItemIDName='DerivedDtaEventCodeValueSID'
		,P.DerivedDtaEventResult AS AttributeValue
		,GETDATE() AS [CreatedDateTime]
		,'Exact Match' AS [MappingSource]
		,'Approved' AS [ApprovalStatus]
		,GETDATE() AS [ApprovedDateTime]
	FROM [Cerner].[FactPowerForm] P
	INNER JOIN [LookUp].[ListMappingRule] L
		ON P.DerivedDtaEvent = L.SearchTerm AND P.DerivedDtaEventResult = L.SearchTerm2
	WHERE 	L.Domain = 'PowerForm'
	AND		L.Attribute = 'DTA' 
	AND		L.SearchType = 'E'  

	INSERT INTO #ListMember
	--Pattern match on DTAEventResult
	SELECT DISTINCT
		L.List
		,L.Domain
		,L.Attribute
		,P.DerivedDtaEventCodeValueSID AS ItemID
		,ItemIDName='DerivedDtaEventCodeValueSID'
		,CASE WHEN P.DerivedDTAEventResult LIKE 'Other:%' THEN NULL ELSE P.DerivedDtaEventResult END AS AttributeValue--=NULL
		,GETDATE() AS [CreatedDateTime]
		,'Pattern Match' AS [MappingSource]
		,'Approved' AS [ApprovalStatus]
		,GETDATE() AS [ApprovedDateTime]
	FROM [Cerner].[FactPowerForm] P WITH (NOLOCK)
	INNER JOIN [LookUp].[ListMappingRule] L WITH (NOLOCK)
		ON P.DerivedDtaEvent = L.SearchTerm AND P.DerivedDtaEventResult LIKE L.SearchTerm2
	WHERE 	L.Domain = 'PowerForm'
	AND		L.Attribute = 'DTA' 
	AND		L.SearchType = 'P' 
	UNION
	--Pattern match on DTAEvent
	SELECT DISTINCT
		L.List
		,L.Domain
		,L.Attribute
		,P.DerivedDtaEventCodeValueSID AS ItemID
		,ItemIDName='DerivedDtaEventCodeValueSID'
		,CASE WHEN P.DerivedDTAEventResult LIKE 'Other:%' THEN NULL ELSE P.DerivedDtaEventResult END AS AttributeValue--=NULL
		,GETDATE() AS [CreatedDateTime]
		,'Pattern Match' AS [MappingSource]
		,'Approved' AS [ApprovalStatus]
		,GETDATE() AS [ApprovedDateTime]
	FROM [Cerner].[FactPowerForm] P WITH (NOLOCK)
	INNER JOIN [LookUp].[ListMappingRule] L WITH (NOLOCK)
		ON P.DerivedDtaEvent LIKE L.SearchTerm AND P.DerivedDtaEventResult = L.SearchTerm2
	WHERE 	L.Domain = 'PowerForm'
	AND		L.Attribute = 'DTA' 
	AND		L.SearchType = 'P' 

	INSERT INTO #ListMember
	SELECT DISTINCT
		L.List
		,L.Domain
		,L.Attribute
		,P.DerivedDtaEventCodeValueSID AS ItemID
		,ItemIDName='DerivedDtaEventCodeValueSID'
		,NULL AS AttributeValue
		,GETDATE() AS [CreatedDateTime]
		,'Exact Match' AS [MappingSource]
		,'Approved' AS [ApprovalStatus]
		,GETDATE() AS [ApprovedDateTime]
	FROM [Cerner].[FactPowerForm] P
	INNER JOIN [Lookup].[ListMappingRule] L 
		ON P.DerivedDtaEvent = L.SearchTerm 
	WHERE 	L.Domain = 'PowerForm'
	AND		L.Attribute = 'Comment' 
	AND		L.SearchType = 'E' 

	INSERT INTO #ListMember
	SELECT DISTINCT
		L.List
		,L.Domain
		,L.Attribute
		,P.DerivedDtaEventCodeValueSID AS ItemID
		,ItemIDName='DerivedDtaEventCodeValueSID'
		,NULL AS AttributeValue
		,GETDATE() AS [CreatedDateTime]
		,'Exact Match' AS [MappingSource]
		,'Approved' AS [ApprovalStatus]
		,GETDATE() AS [ApprovedDateTime]
	FROM [Cerner].[FactPowerForm] P
	INNER JOIN [Lookup].[ListMappingRule] L 
		ON P.DerivedDtaEvent = L.SearchTerm
	WHERE 	L.Domain = 'PowerForm'
	AND		L.Attribute = 'FreeText' 
	AND		L.SearchType = 'E' 

	INSERT INTO #ListMember
	SELECT DISTINCT
		L.List
		,L.Domain
		,L.Attribute
		,P.DCPFormsReferenceSID AS ItemID
		,ItemIDName='DCPFormsReferenceSID'
		,DocFormDescription AS AttributeValue
		,GETDATE() AS [CreatedDateTime]
		,'Exact Match' AS [MappingSource]
		,'Approved' AS [ApprovalStatus]
		,GETDATE() AS [ApprovedDateTime]
	FROM [Cerner].[FactPowerForm] P
	INNER JOIN [Lookup].[ListMappingRule] L 
		ON P.DocFormDescription = L.SearchTerm
	WHERE 	L.Domain = 'PowerForm'
	AND		L.Attribute = 'DocFormDescription' 
	AND		L.SearchType = 'E' 
----------------------------------------------------------------------------
-- PHASE 4: Load Lookup.ListMember
-- Insert and Delete
 ----------------------------------------------------------------------------

	MERGE [Lookup].[ListMember] AS TARGET
	USING (SELECT DISTINCT * FROM #ListMember) AS SOURCE
			ON	TARGET.List = SOURCE.List
			AND TARGET.Domain = SOURCE.Domain
			AND TARGET.ItemID = SOURCE.ItemID
			AND (TARGET.AttributeValue = SOURCE.AttributeValue OR SOURCE.Attribute IS NULL)
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([List], [Domain], [Attribute], [ItemID],[ItemIDName],[AttributeValue],[CreatedDateTime],[MappingSource],[ApprovalStatus],[ApprovedDateTime] ) 
		VALUES (SOURCE.[List], SOURCE.[Domain], SOURCE.[Attribute], SOURCE.[ItemID],SOURCE.[ItemIDName],SOURCE.[AttributeValue],SOURCE.[CreatedDateTime],SOURCE.[MappingSource],SOURCE.[ApprovalStatus],SOURCE.[ApprovedDateTime]) 
	WHEN NOT MATCHED BY SOURCE AND TARGET.Domain = 'PowerForm' AND TARGET.List IN (SELECT List FROM #ListMember)
		THEN DELETE;

	DELETE FROM [Lookup].[ListMember]
	WHERE List NOT IN (SELECT List FROM [Lookup].[ListMappingRule] WHERE Domain='PowerForm')
	AND Domain='PowerForm'
	AND MappingSource IN ('Exact Match','Pattern Match')

	UPDATE [Lookup].[ListMember]
	SET ItemIDName='DerivedDtaEventCodeValueSID'
	WHERE ItemIDName IS NULL AND Domain = 'PowerForm' AND Attribute IN ('DTA','FreeText','Comment')

	UPDATE [Lookup].[ListMember]
	SET ItemIDName='DCPFormsReferenceSID'
	WHERE ItemIDName IS NULL AND Domain = 'PowerForm' AND Attribute='DocFormDescription' 

END