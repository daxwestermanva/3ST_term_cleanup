

/*--=============================================
-- Author:		Liam Mina
-- Create date: 2024-09-16
-- Description: BHL lookup from Cerner data
--Modifications:


--=============================================*/ 


CREATE PROCEDURE [Code].[LookUpList_BHL]
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
-- PHASE 1:  Get all the standard BHL Mappings
-- Exact Match and Patttern Match will get Auto Approved
----------------------------------------------------------------------------

	/*
		--Mapping rules have been setup for each ListMappingRule.Attribute
		SELECT DISTINCT Attribute
		FROM [Lookup].[ListMappingRule] 
		WHERe Domain = 'BHL'
	*/
	INSERT INTO #ListMember
	SELECT DISTINCT
		L.List
		,L.Domain
		,L.Attribute
		,P.EventCodeValueSID AS ItemID
		,'EventCodeValueSID' AS ItemIDName
		,P.ResultValue AS AttributeValue
		,GETDATE() AS [CreatedDateTime]
		,'Exact Match' AS [MappingSource]
		,'Approved' AS [ApprovalStatus]
		,GETDATE() AS [ApprovedDateTime]
	FROM [Cerner].[FactBHL] P
	INNER JOIN [LookUp].[ListMappingRule] L
		ON P.Event = L.SearchTerm AND P.ResultValue = L.SearchTerm2
	WHERE 	L.Domain = 'BHL'
	AND		L.Attribute = 'ResultValue' 
	AND		L.SearchType = 'E'  

	INSERT INTO #ListMember
	SELECT DISTINCT
		L.List
		,L.Domain
		,L.Attribute
		,P.EventCodeValueSID AS ItemID
		,'EventCodeValueSID' AS ItemIDName
		,P.ResultValue AS AttributeValue
		,GETDATE() AS [CreatedDateTime]
		,'Exact Match' AS [MappingSource]
		,'Approved' AS [ApprovalStatus]
		,GETDATE() AS [ApprovedDateTime]
	FROM [Cerner].[FactBHL] P
	INNER JOIN [LookUp].[ListMappingRule] L
		ON P.Event = L.SearchTerm AND P.ResultValue LIKE L.SearchTerm2
	WHERE 	L.Domain = 'BHL'
	AND		L.Attribute = 'ResultValue' 
	AND		L.SearchType = 'P'  


	INSERT INTO #ListMember
	SELECT DISTINCT
		L.List
		,L.Domain
		,L.Attribute
		,P.EventCodeValueSID AS ItemID
		,'EventCodeValueSID' AS ItemIDName
		,P.ResultValue AS AttributeValue
		,GETDATE() AS [CreatedDateTime]
		,'Exact Match' AS [MappingSource]
		,'Approved' AS [ApprovalStatus]
		,GETDATE() AS [ApprovedDateTime]
	FROM [Cerner].[FactBHL] P
	INNER JOIN [LookUp].[ListMappingRule] L
		ON P.Event = L.SearchTerm
	WHERE 	L.Domain = 'BHL'
	AND		L.Attribute = 'FreeText' 
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
	WHEN NOT MATCHED BY SOURCE AND TARGET.Domain = 'BHL' AND TARGET.List IN (SELECT List FROM #ListMember)
		THEN DELETE;

	DELETE FROM [Lookup].[ListMember]
	WHERE List NOT IN (SELECT List FROM [Lookup].[ListMappingRule] WHERE Domain='BHL')
	AND Domain='BHL'
	AND MappingSource IN ('Exact Match','Pattern Match')

	UPDATE [Lookup].[ListMember]
	SET ItemIDName='EventCodeValueSID'
	WHERE ItemIDName IS NULL AND Domain = 'BHL'

END