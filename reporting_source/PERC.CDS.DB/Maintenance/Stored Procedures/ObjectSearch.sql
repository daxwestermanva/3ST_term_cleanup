
/*******************************************************************************************************
* Procedure:		dbo.ObjectSearch
* Created By:		Matt Wollner
* Date Created:		05/07/2007
* Description:		Searches SQL System tables for the @SearchString
*						In Table Name, Column Names, and inside Stored Procedures
*
*					@SearchString - What you are searching for
*					@SearchObject - Choose from {All, Proc, Table, Column, Function, View, Trigger}
* Updates:	Updated By	-	Update Date	-	Notes	
*			
*******************************************************************************************************/



CREATE PROCEDURE  [Maintenance].[ObjectSearch]
	@SearchString VARCHAR(200),
	@SearchObject VARCHAR(50) = 'All'
AS 

/*
@SearchObject
	All, Proc, Table, Column, Function, View, Trigger
*/

--DECLARE @SearchString VARCHAR(200)
--DECLARE @SearchObject VARCHAR(50)

--SELECT @SearchString = 'test',
--	@SearchObject = 'All'

--Wrap the SearchString with a wildcard
DECLARE @SearchStringWild VARCHAR(200)
SELECT @SearchStringWild = '%' + @SearchString + '%'

--Set the SearchObjectName to the type_desc in SYS.objects
DECLARE @SearchObjectName VARCHAR(50)
SELECT @SearchObjectName =
	CASE 
		WHEN @SearchObject IN ('All', 'Table','Column','View') THEN @SearchObject
		WHEN @SearchObject = 'Proc' THEN 'SQL_STORED_PROCEDURE'
		WHEN @SearchObject = 'Procedure' THEN 'SQL_STORED_PROCEDURE'
		WHEN @SearchObject = 'Function' THEN 'SQL_SCALAR_FUNCTION'
		WHEN @SearchObject = 'Trigger' THEN 'SQL_TRIGGER'
	END 
	
--Search All objects
IF @SearchObjectName = 'All'
	BEGIN
		--Column
		SELECT  'Column' AS SearchObject,
				C.TABLE_CATALOG, C.TABLE_SCHEMA, C.TABLE_NAME, T.TABLE_TYPE,
				C.COLUMN_NAME, C.ORDINAL_POSITION, C.COLUMN_DEFAULT, C.IS_NULLABLE,
				C.DATA_TYPE, C.CHARACTER_MAXIMUM_LENGTH, C.CHARACTER_OCTET_LENGTH, C.NUMERIC_PRECISION,
				C.NUMERIC_PRECISION_RADIX, C.NUMERIC_SCALE, C.DATETIME_PRECISION, C.CHARACTER_SET_CATALOG,
				C.CHARACTER_SET_SCHEMA, C.CHARACTER_SET_NAME, C.COLLATION_CATALOG, C.COLLATION_SCHEMA,
				C.COLLATION_NAME, C.DOMAIN_CATALOG, C.DOMAIN_SCHEMA,C.DOMAIN_NAME
		FROM    INFORMATION_SCHEMA.COLUMNS AS C
		INNER JOIN INFORMATION_SCHEMA.TABLES AS T 
			ON T.TABLE_NAME = C.TABLE_NAME
			AND T.TABLE_SCHEMA = C.TABLE_SCHEMA
			AND T.TABLE_CATALOG = C.TABLE_CATALOG
		WHERE   C.COLUMN_NAME LIKE @SearchStringWild
		ORDER BY T.TABLE_NAME

		--Table
		SELECT 'Table' AS SearchObject, *
		FROM INFORMATION_SCHEMA.TABLES
		WHERE TABLE_NAME Like @SearchStringWild
		ORDER BY TABLE_NAME

		--Synonym
		SELECT 'Synonym'AS SearchObject
			,name
			,base_object_name 
		FROM sys.synonyms 
		WHERE name Like @SearchStringWild
		ORDER BY name

		----Stored Proc / Function / View / Trigger
		SELECT  O.type_desc AS SearchObject,
				S.Name AS SchemaName,
				O.Name AS ObjectName,
				C.[text] AS ObjectText,
				SUBSTRING(C.[text], CHARINDEX(@SearchString, C.[Text]) - 25, 150) AS ObjectSubsetText,
				O.Create_date, O.modify_date
		FROM    sys.SYSCOMMENTS C
		JOIN	SYS.objects O ON O.object_id = C.id
		JOIN	sys.schemas S ON S.schema_id = O.schema_id
		WHERE   C.[text] LIKE @SearchStringWild
		ORDER BY  O.type_desc, O.Name

	END --ALL
	
ELSE IF @SearchObject IN( 'Proc','Function','View','Trigger','Procedure' )
	BEGIN
		SELECT  O.type_desc AS SearchObject,
				S.Name AS SchemaName,
				O.Name AS ObjectName,
				C.[text] AS ObjectText,
				SUBSTRING(C.[text], CHARINDEX(@SearchString, C.[Text]) - 25, 150) AS ObjectSubsetText,
				O.Create_date, O.modify_date
		FROM    sys.SYSCOMMENTS C
		JOIN	SYS.objects O ON O.object_id = C.id
		JOIN	sys.schemas S ON S.schema_id = O.schema_id
		WHERE   C.[text] LIKE @SearchStringWild
		AND		O.type_desc = @SearchObjectName
		ORDER BY  O.type_desc, O.Name
	END --Proc
	
ELSE IF  @SearchObjectName = 'Table' 
	BEGIN
		SELECT 'Table' AS SearchObject, *
		FROM INFORMATION_SCHEMA.TABLES
		WHERE TABLE_NAME Like @SearchStringWild
		ORDER BY TABLE_NAME

		--Synonym
		SELECT 'Synonym'AS SearchObject
			,name
			,base_object_name 
		FROM sys.synonyms 
		WHERE name Like @SearchStringWild
		ORDER BY name
	END --Table

ELSE IF  @SearchObjectName = 'Column' 
	BEGIN
		SELECT  'Column' AS SearchObject,
				C.TABLE_CATALOG, C.TABLE_SCHEMA, C.TABLE_NAME, T.TABLE_TYPE,
				C.COLUMN_NAME, C.ORDINAL_POSITION, C.COLUMN_DEFAULT, C.IS_NULLABLE,
				C.DATA_TYPE, C.CHARACTER_MAXIMUM_LENGTH, C.CHARACTER_OCTET_LENGTH, C.NUMERIC_PRECISION,
				C.NUMERIC_PRECISION_RADIX, C.NUMERIC_SCALE, C.DATETIME_PRECISION, C.CHARACTER_SET_CATALOG,
				C.CHARACTER_SET_SCHEMA, C.CHARACTER_SET_NAME, C.COLLATION_CATALOG, C.COLLATION_SCHEMA,
				C.COLLATION_NAME, C.DOMAIN_CATALOG, C.DOMAIN_SCHEMA,C.DOMAIN_NAME
		FROM    INFORMATION_SCHEMA.COLUMNS AS C
		INNER JOIN INFORMATION_SCHEMA.TABLES AS T ON T.TABLE_NAME = C.TABLE_NAME
		WHERE   C.COLUMN_NAME LIKE @SearchStringWild
		ORDER BY T.TABLE_NAME
	END --Table 

ELSE 
	SELECT 'Error: @SearchObject be one of the following values (All, Proc, Table, Column, Function, View, Trigger)'