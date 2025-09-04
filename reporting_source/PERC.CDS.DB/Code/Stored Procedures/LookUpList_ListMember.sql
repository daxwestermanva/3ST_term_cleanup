/***-- =============================================
-- Author:		Rebecca Stephens
-- Create date: 2020-09-18
-- Description: Procedure to run exact and pattern matches to populate LookUp.ListMember.  This procedure automatically runs 
				exact and pattern match queries for each attribute in the domain based on parameters so logic does not need 
				to be duplicated across multiple LookUpList procedures.

-- EXAMPLE EXECUTION:
	EXEC [Code].[[LookUpList_ListMember]] @Domain='HealthFactorType'
		,@SourceTable='[Dim].[HealthFactorType]'
		,@ItemIDName='HealthFactorTypeSID'

-- Modification:
	2020-09-08	RAS	Created procedure to populate ListMember based on specific Domain and SourceTable. SP used in Code.LookUpList_HealthFactor, Code.LookUpList_ActivityType, etc.
	2020-09-28	RAS	Added limitation on merge delete condition to only delete items in the specific lists in order to avoid conflict with other items in specific domain list SPs.
	2021-10-18	RAS	Added Log.PublishTable
-- ============================================= */ 

CREATE PROCEDURE [Code].[LookUpList_ListMember]
	 @Domain VARCHAR(100)
	,@SourceTable VARCHAR(100)
	,@ItemIDName VARCHAR(100)
	,@Debug BIT =  0
AS
BEGIN

----FOR TESTING
--DECLARE @Domain			VARCHAR(100)	= 'HealthFactorType'
--DECLARE @SourceTable	VARCHAR(100)	= '[Dim].[HealthFactorType]'
--DECLARE @ItemIDName		VARCHAR(100)	= 'HealthFactorTypeSID'
--DECLARE @Debug BIT =  0

--DECLARE @Domain			VARCHAR(100)	= 'ActivityType'
--DECLARE @SourceTable	VARCHAR(100)	= '[Cerner].[FactDimActivityType]'
--DECLARE @ItemIDName		VARCHAR(100)	= 'ActivityTypeCodeValueSID'
--DECLARE @Debug BIT =  0

--PRINT @Domain 
--PRINT @SourceTable
--PRINT @ItemIDName		


	DROP TABLE IF EXISTS #ListMember;
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

	 DROP TABLE IF EXISTS #ItemIDName
	 SELECT  @ItemIDName AS ItemIDName INTO #ItemIDName

--Get all attributes in temp table
DROP TABLE IF EXISTS #AllAttributes
SELECT DISTINCT 
	ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY Attribute) as ID
	,Attribute 
INTO #AllAttributes
FROM (
	SELECT DISTINCT Attribute 
	FROM [LookUp].[ListMappingRule] 
	WHERE Domain=@Domain
	) a

--Create loop that will run pattern and exact matches for all of the attributes identified for the domain
DECLARE @Counter INT = 1

WHILE @Counter <= (SELECT MAX(ID) FROM #AllAttributes)
BEGIN
	DECLARE @Attribute VARCHAR(100) = (SELECT Attribute FROM #AllAttributes WHERE ID = @Counter)
	PRINT @Counter
	PRINT @Attribute

	DECLARE @ExactMatchSQL VARCHAR(2000) = '
		INSERT INTO #ListMember (List,Domain,Attribute,ItemID,ItemIDName,AttributeValue,CreatedDateTime,MappingSource,ApprovalStatus,ApprovedDateTime)
		SELECT DISTINCT 
			 List				=	mr.List
			,Domain				=	mr.Domain
			,Attribute			=	mr.Attribute
			,ItemID				=	dim.' + @ItemIDName + '
			,ItemIDName			=	(SELECT * FROM #ItemIDName)
			,AttributeValue		=	dim.' + @Attribute + '
			,CreatedDateTime	=	GETDATE()
			,MappingSource		=	''Exact Match''
			,ApprovalStatus		=	''Approved'' --auto approval for exact and pattern match
			,ApprovedDateTime	=	GETDATE()						
		FROM ' + @SourceTable +' dim
		INNER JOIN [Lookup].[ListMappingRule] mr ON dim.' + @Attribute + '= mr.SearchTerm
		WHERE 	mr.Domain = '''+ @Domain + '''
			AND mr.Attribute = ''' + @Attribute + ''' 
			AND mr.SearchType = ''E''
		'

	DECLARE @PatternMatchSQL VARCHAR(2000) = '
		INSERT INTO #ListMember (List,Domain,Attribute,ItemID,ItemIDName,AttributeValue,CreatedDateTime,MappingSource,ApprovalStatus,ApprovedDateTime)
		SELECT DISTINCT 
			 List				=	mr.List
			,Domain				=	mr.Domain
			,Attribute			=	mr.Attribute
			,ItemID				=	dim.' + @ItemIDName + '
			,ItemIDName			=	(SELECT * FROM #ItemIDName)
			,AttributeValue		=	dim.' + @Attribute + '
			,CreatedDateTime	=	GETDATE()
			,MappingSource		=	''Pattern Match''
			,ApprovalStatus		=	''Approved'' --auto approval for exact and pattern match
			,ApprovedDateTime	=	GETDATE()						
		FROM ' + @SourceTable +' dim
		INNER JOIN [Lookup].[ListMappingRule] mr ON dim.' + @Attribute + ' LIKE mr.SearchTerm
		LEFT OUTER JOIN #ListMember lm ON
				lm.List =  mr.List
				AND lm.ItemID = dim.' + @ItemIDName + '
		WHERE mr.Domain = '''+ @Domain + '''
			AND mr.Attribute = ''' + @Attribute + ''' 
			AND mr.SearchType = ''P''
			AND lm.Domain IS NULL --only add if it has not already been included
		'

	IF @Debug=1 
	BEGIN
		PRINT @ExactMatchSQL
		PRINT @PatternMatchSQL
		--RETURN
	END
	ELSE 
	BEGIN
		EXEC (@ExactMatchSQL)
		EXEC (@PatternMatchSQL)
	END
	SET @Counter = @Counter + 1
END

----------------------------------------------------------------------------
-- PHASE 4: Load Lookup.ListMember
-- Insert and Delete
 ----------------------------------------------------------------------------
	MERGE [Lookup].[ListMember] AS TARGET
	USING (SELECT DISTINCT * FROM #ListMember) AS SOURCE
			ON	TARGET.List = SOURCE.List
			AND TARGET.Domain = SOURCE.Domain
			AND TARGET.ItemID = SOURCE.ItemID
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([List], [Domain], [Attribute], [ItemID],[ItemIDName],[AttributeValue],[CreatedDateTime],[MappingSource],[ApprovalStatus],[ApprovedDateTime] ) 
		VALUES (SOURCE.[List], SOURCE.[Domain], SOURCE.[Attribute], SOURCE.[ItemID],SOURCE.[ItemIDName],SOURCE.[AttributeValue],SOURCE.[CreatedDateTime],SOURCE.[MappingSource],SOURCE.[ApprovalStatus],SOURCE.[ApprovedDateTime]) 
	WHEN NOT MATCHED BY SOURCE AND TARGET.Domain = @Domain AND TARGET.List IN (SELECT DISTINCT List FROM #ListMember)
		THEN DELETE;

	DELETE FROM [Lookup].[ListMember]
	WHERE List NOT IN (SELECT List FROM [Lookup].[ListMappingRule] WHERE Domain=@Domain)
	AND Domain=@Domain
	AND MappingSource IN ('Exact Match','Pattern Match')
	;

	UPDATE [Lookup].[ListMember]
	SET ItemIDName = @ItemIDName
	WHERE ItemIDName IS NULL AND Domain=@Domain AND Attribute=@Attribute

DECLARE @RowCount INT = (SELECT COUNT(*) FROM #ListMember)
DECLARE @SourceName VARCHAR(100) = CONCAT('#ListMember_',@Domain)

EXEC [Log].[PublishTable] 'LookUp','ListMember',@SourceName,'Merge',@RowCount

DROP TABLE #ListMember

END