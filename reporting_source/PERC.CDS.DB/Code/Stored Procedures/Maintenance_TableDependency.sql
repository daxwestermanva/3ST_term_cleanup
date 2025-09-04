-- =============================================
-- Author:		<Amy Furman >
-- Create date: <5/4/17>
-- Description:	Find the tables used and created by each stored proc
-- ======================a=======================
CREATE PROCEDURE [Code].[Maintenance_TableDependency]
	-- Add the parameters for the stored procedure here

AS
BEGIN

/*
*********************************************************************************************
Begin
Find all the tables that exists in all the databases we care about
*********************************************************************************************
*/
DECLARE @db varchar(50)=(SELECT DISTINCT Table_Catalog FROM INFORMATION_SCHEMA.TABLES)

DROP TABLE IF EXISTS #AllTables;
SELECT TABLE_SCHEMA
      ,TABLE_NAME
	  ,TABLE_CATALOG
	  ,TABLE_CATALOG + '.' + TABLE_SCHEMA + '.' + TABLE_NAME as TableName 
	  ,Table_Name as  TABLE_NAME_SHORT
      --Account for all possible permutations of DataBase.Schema.TableName with brackets (might be able to replace with reg ex)
	  ,  Table_Catalog + '_._' + TABLE_SCHEMA + '_._' + TABLE_NAME  as TableNameBracketALL
	  ,  Table_Catalog + '_.' + TABLE_SCHEMA + '.' + TABLE_NAME   as TableNameBracketDB
	  ,  Table_Catalog + '._' + TABLE_SCHEMA + '_.' + TABLE_NAME  as TableNameBracketSchema
	  ,  Table_Catalog + '.' + TABLE_SCHEMA + '._' + TABLE_NAME  as TableNameBracketTable
	  ,  Table_Catalog + '._' + TABLE_SCHEMA + '_._' + TABLE_NAME  as TableNameBracketSchemaTable
	  ,  Table_Catalog + '_.' + TABLE_SCHEMA + '._' + TABLE_NAME  as TableNameBracketDBTable
	  ,  Table_Catalog + '_._' + TABLE_SCHEMA + '_.' + TABLE_NAME  as TableNameBracketDBSchema
      ,                          TABLE_SCHEMA + '_.' + TABLE_NAME as TableNameNoDBBracketSchema
	  ,                          TABLE_SCHEMA + '._' + TABLE_NAME as TableNameNoDBBracketTable
      ,                          TABLE_SCHEMA + '_._' + TABLE_NAME as TableNameNoDBBracketSchemaTable
      ,                          TABLE_SCHEMA + '.' + TABLE_NAME as TableNameNoDB
	  ,create_date
	  ,max(modify_date) over (partition by TABLE_NAME) as modify_date
      ,ObjectType
INTO #AllTables
FROM (
  	 SELECT DISTINCT a.[name] as Table_Name
	       ,b.name as Table_Schema
		   ,Table_Catalog=@db
		   ,create_date
		   ,isnull(last_user_update,modify_date) as modify_date
		   ,'Table' as ObjectType  
	FROM sys.tables as a WITH (NOLOCK)
	LEFT OUTER JOIN sys.schemas as b WITH (NOLOCK) 
		ON a.schema_id = b.schema_id
	LEFT OUTER JOIN sys.dm_db_index_usage_stats i WITH (NOLOCK) 
		ON a.object_id = i.object_id

	UNION ALL

	SELECT DISTINCT a.[name] as Table_Name
	      ,b.name as Table_Schema
		  ,Table_Catalog=@db
		  ,create_date
		  ,isnull(last_user_update,modify_date) as modify_date
		  ,'Synonym' as ObjectType     
	FROM sys.synonyms as a WITH (NOLOCK)
	LEFT OUTER JOIN sys.schemas as b WITH (NOLOCK) 
		ON a.schema_id = b.schema_id
	LEFT OUTER JOIN sys.dm_db_index_usage_stats i WITH (NOLOCK) 
		ON a.object_id = i.object_id

	UNION ALL

	SELECT DISTINCT a.[name] as Table_Name
	      ,b.name as Table_Schema
		  ,Table_Catalog=@db
		  ,create_date
		  ,isnull(last_user_update,modify_date) as modify_date
		  ,'View' as ObjectType     
	FROM sys.views as a WITH (NOLOCK)
	LEFT OUTER JOIN sys.schemas as b WITH (NOLOCK)	
		ON a.schema_id = b.schema_id
	LEFT OUTER JOIN sys.dm_db_index_usage_stats i WITH (NOLOCK) 
		ON a.object_id = i.object_id
    ) as a ;
--select * from #AllTables

/*
*********************************************************************************************
Begin
Finds the "INTO" command in all the codes and pulls all the data for that line, only keeps the tables with a . in them (ie not temp tables)
*********************************************************************************************
*/

DROP TABLE IF EXISTS #ProcTables;
with T as (
SELECT cast(0 as int) as row
      ,charindex('into ', img) pos
	  ,img 
	  ,name
	  ,DatabaseName
FROM (
    SELECT DISTINCT @db as DatabaseName, o.name ,s.Name as SchemaName
	      ,definition as img--substring(definition,CHARINDEX('into ',definition)+5,60) as TableStep1
	FROM sys.sql_modules m WITH (NOLOCK)
	LEFT OUTER JOIN sys.objects o WITH (NOLOCK) ON m.object_id=o.object_id
    LEFT OUTER JOIN sys.schemas s WITH (NOLOCK)	
		ON o.schema_id= s.schema_ID
    WHERE s.Name in ('App','Code')
    ) as a 

UNION ALL

    SELECT cast(pos as int) + 1
	      ,charindex('into ', img, pos + 1)
		  ,img
		  ,name
		  ,DatabaseName
    FROM T	
    WHERE pos > 0
)

SELECT DISTINCT DatabaseName
      ,name
	  ,RTrim(LTrim(TableCreatedByProc)) as TableCreatedByProc
INTO #ProcTables
FROM (
    SELECT * 
	      ,substring(TableStep1,1,CHARINDEX(CHAR(13)+CHAR(10),TableStep1)) as TableCreatedByProc
	FROM (
        SELECT DatabaseName,img, pos ,t.name,substring(img,pos+5,60) as TableStep1
        FROM T
		WHERE pos > 0  
		) as a 
	) as b 
WHERE TableCreatedByProc like '%.%' and TableCreatedByProc not like '%*/'
OPTION(maxrecursion 500)
;
/*
*********************************************************************************************
Begin
Strips out the author and the descriptions for each procedure, this only works if you use the standard report template (see the top of this proc)
*********************************************************************************************
*/
DROP TABLE IF EXISTS #ProcedureNameAuthor
SELECT DatabaseName
      ,name
	  ,SchemaName
	  ,substring(DecriptionStep1,1,CHARINDEX(CHAR(13)+CHAR(10),DecriptionStep1)) as ProcDescription
	  ,substring(AuthorStep1,1,CHARINDEX(CHAR(13)+CHAR(10),AuthorStep1)) as ProcAuthor
INTO #ProcedureNameAuthor
FROM (
	SELECT DISTINCT @db as DatabaseName
	      ,o.name
		  ,s.name as SchemaName
		  ,definition
		  ,substring(definition,CHARINDEX('Description:',definition)+13,300) as DecriptionStep1
	      ,substring(definition,CHARINDEX('Author:',definition)+7,300) as AuthorStep1
	FROM sys.sql_modules m WITH (NOLOCK)
	LEFT OUTER JOIN sys.objects o WITH (NOLOCK) ON m.object_id=o.object_id
    LEFT OUTER JOIN  sys.schemas s WITH (NOLOCK) 
		ON o.schema_id= s.schema_ID
    WHERE s.Name in ('App','Code')   
	) as a ;

/*
*********************************************************************************************
Begin
Combines all the data for each proc, Author, Description, and tables created
*********************************************************************************************
*/

DROP TABLE IF EXISTS #ProdDetails
SELECT a.name
      ,CASE WHEN a.name LIKE 'uspinc%' THEN 'Incramental Load' else ProcDescription end ProcDescription
      ,CASE WHEN a.name LIKE 'uspinc%' THEN 'Kevin Dostie' else ProcAuthor end ProcAuthor,TableCreatedByProc
INTO #ProdDetails
FROM (
    SELECT @db as DatabaseName
	      ,o.name
		  ,s.[name] as SchemaName
	FROM sys.sql_modules m WITH (NOLOCK)
	LEFT OUTER JOIN sys.objects o WITH (NOLOCK) 
		ON m.object_id=o.object_id
    LEFT OUTER JOIN sys.schemas s WITH (NOLOCK) 
		ON o.schema_id= s.schema_ID
    WHERE s.Name in ('App','Code')  
    ) as a 
LEFT OUTER JOIN #ProcedureNameAuthor as b 
    on b.name = a.name 
	and b.DatabaseName = a.DatabaseName
LEFT OUTER JOIN #ProcTables as c 
    on a.name = c.name 
	and c.DatabaseName = a.DatabaseName

/*
******************************************************************************************************************************************************************************************
String match all the possible tables names with the stored proc definition to find all the tables referenced 
*/
	DROP TABLE IF EXISTS #Definition
    SELECT @db as DatabaseName, o.name,definition,s.[name] as SchemaName
	INTO #definition
	FROM sys.sql_modules m WITH (NOLOCK)
	LEFT OUTER JOIN sys.objects o WITH (NOLOCK) ON m.object_id=o.object_id
    LEFT OUTER JOIN sys.schemas s WITH (NOLOCK) on o.schema_id= s.schema_ID
    WHERE s.Name in ('App','Code')

DROP TABLE IF EXISTS #TablesReferenced
SELECT m.DatabaseName
	  ,m.SchemaName 
	  ,m.name
	  ,c.TABLE_CATALOG
	  ,c.TableName
	  ,c.Table_Name_Short 
	  ,m.Definition
	  ,c.TableNameBracketAll
	  ,c.TableNameBracketDB
	  ,c.TableNameBracketDBSchema
	  ,c.TableNameBracketDBTable
	  ,c.TableNameBracketSchema
	  ,c.TableNameBracketSchemaTable
	  ,c.TableNameBracketTable
      ,c.TableNameNoDBBracketSchema
      ,c.TableNameNoDBBracketTable 
      ,c.TableNameNoDBBracketSchemaTable
      ,c.TableNameNoDB
      ,c.ObjectType
	  ,c.create_date
	  ,c.modify_date
	  ,c.Table_Schema
INTO #TablesReferenced 
FROM #AllTables as c 
INNER JOIN #definition as m 
	on m.Definition LIKE CONCAT('%',c.TableNameNoDBBracketSchemaTable,'%')
	or m.Definition LIKE CONCAT('%',c.TableNameNoDB,'%')
	or m.Definition LIKE CONCAT('%',c.TableNameNoDBBracketSchema,'%')
	or m.Definition LIKE CONCAT('%',c.TableNameNoDBBracketTable,'%')

  /*
*********************************************************************************************
Begin - Final table 
Get details of the referenced tables and create a flag to determine of the table is referenced or created by the proc
*********************************************************************************************
*/
	DROP TABLE IF EXISTS #StageTableDependency
    SELECT DISTINCT  DatabaseName
		,SchemaName
		,Name
		,ProcDescription
		,ProcAuthor
		,TABLE_CATALOG
		,TableName
		,ObjectType
		,create_date
		,modify_date
        ,Table_schema
		,Max(CreateFlag) over(partition by name,TableName) as CreateFlag 
		,Table_Name_Short
  INTO #StageTableDependency
  FROM (
      SELECT  DatabaseName,b.Name,SchemaName,ProcDescription,ProcAuthor,a.TABLE_CATALOG,ObjectType,a.TableName,isnull(a.create_date,c.create_date) as Create_Date,isnull(a.modify_date,c.modify_date) as Modify_Date
	        ,a.Table_schema,tablecreatedbyproc, Table_Name_Short
	        ,case when (tablecreatedbyproc) like '%' + Tablename+'%' then 1 
	              when tablecreatedbyproc like '%' + TableNameBracketAll+ '%' then 1 
	              when tablecreatedbyproc like '%' + TableNameBracketDB+ '%' then 1 
	              when tablecreatedbyproc like '%' + TableNameBracketDBSchema+ '%' then 1 
	              when tablecreatedbyproc like '%' + TableNameBracketDBTable+ '%' then 1 
	              when tablecreatedbyproc like '%' + TableNameBracketSchema+ '%' then 1 
	              when tablecreatedbyproc like '%' + TableNameBracketSchemaTable+ '%' then 1 
	              when tablecreatedbyproc like '%' + TableNameBracketTable+ '%' then 1 
                  when tablecreatedbyproc like  '%' +TableNameNoDBBracketSchema + '%' then 1 
	              when tablecreatedbyproc like  '%' +TableNameNoDBBracketTable + '%' then 1 
                  when tablecreatedbyproc like  '%' +TableNameNoDBBracketSchemaTable + '%' then 1 
                  when tablecreatedbyproc like  '%' +TableNameNoDB + '%' then 1 
	              else 0 End CreateFlag
	FROM #TablesReferenced as a 
	FULL OUTER JOIN #ProdDetails as b on a.name = b.name 
	LEFT OUTER JOIN (
	    SELECT replace(Table_Name,right(Table_Name,5),'') as Table_Name
		      ,Table_Schema,Create_Date,Modify_Date 
		FROM #alltables 
		WHERE table_name like '%v00_'
		) as c on @db+ c.Table_Schema +'.' +  c.table_name =  a.tablename
    ) as a 
WHERE name is not null and tablename is not null 

EXEC [Maintenance].[PublishTable] '[Maintenance].[TableDependency]','#StageTableDependency'

END
GO
