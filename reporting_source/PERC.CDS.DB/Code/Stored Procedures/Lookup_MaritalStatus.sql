

-- =============================================
-- Author:		<Susana Martins>
-- Create date: <10/26/2016>
-- Description:	<Pivoted Marital Status Lookup crosswalk>
-- Updates:
--	2019-02-14	Jason Bacani - Refactored to use [Maintenance].[PublishTable]
--	2020-10-30	LM - Integrating marital status from Cerner
-- =============================================

CREATE PROCEDURE [Code].[Lookup_MaritalStatus]
AS
BEGIN

/*
drop table LookUp.MaritalStatus 
GO

CREATE TABLE LookUp.MaritalStatus  (
	MaritalStatusSID [bigint] not null
	,Sta3n smallint not null 
	,[MaritalStatus] varchar(100)  null 
	,Reach_Widow_MaritalStatus [smallint] null
	,Reach_Divorced_MaritalStatus [smallint] null
	,Reach_Married_MaritalStatus [smallint] null
	) --ON [DefFG]
	;

	GO

CREATE UNIQUE CLUSTERED INDEX [pk_CrosswalkMaritalStatus__MaritalStatusSID] ON  LookUp.MaritalStatus  (MaritalStatussid ASC)
	WITH (DATA_COMPRESSION = PAGE) --ON [DefFG]
	;
;

	*/

	/*** adding variables from App.LookUpICD to App.LookUpICDDescription****/
	INSERT INTO  LookUp.ColumnDescriptions
	WITH (TABLOCK)
	SELECT DISTINCT
  Object_ID as TableID
  ,a.Table_Name as TableName
		--Name of column from the LookupMaritalStatus table
		,Column_Name AS ColumnName,
		NULL AS Category,
		NULL AS PrintName,
		NULL AS ColumnDescription,
		Null as DefinitionOwner
	FROM (
		SELECT a.Object_ID
    ,b.name as Table_Name
    ,a.name as column_name	
      FROM  sys.columns as a 
		inner join   sys.tables as b on   a.object_id = b.object_id-- a.TABLE_NAME = b.TABLE_NAME
		inner join sys.schemas as c on b.schema_id=c.schema_id
		WHERE b.Name = 'MaritalStatus' and c.name ='LookUp'
			AND a.Name NOT IN (
				'MaritalStatusSID',
				'Sta3n',
				'MaritalStatus'
				)
			AND a.Name NOT IN (
				SELECT DISTINCT ColumnName
				FROM LookUp.ColumnDescriptions
				) --order by COLUMN_NAME
		) AS a
    
    delete  LookUp.ColumnDescriptions where TableName = 'MaritalStatus' and ColumnName not in (SELECT 
    a.name as column_name	
      FROM  sys.columns as a 
		inner join   sys.tables as b on   a.object_id = b.object_id-- a.TABLE_NAME = b.TABLE_NAME
		inner join sys.schemas as c on b.schema_id=c.schema_id
		WHERE b.Name = 'MaritalStatus' and c.name ='LookUp')
		--	order by case when COLUMN_NAME in ('sta3n', 'patientsid') then 'AA' + COLUMN_NAME else COLUMN_NAME end 
		;

	/*** B. Pulls complete dim.ICD into App.LookUpICD (this will enable us to check for new data entered into 
	dim.ICD and alert us - not implemented yet) and populates variables created above with zeros in App.LookUpICD ****/
	DECLARE @Columns VARCHAR(Max);

	SELECT @Columns = CASE 
			WHEN @Columns IS NULL
				THEN '0 as ' + T.ColumnName
			ELSE @Columns + ', 0 as ' + T.ColumnName
			END
	FROM Lookup.ColumnDescriptions AS T
  where T.TableName = 'MaritalStatus';

	--select @Columns
	DECLARE @Insert AS VARCHAR(4000);;

	DROP TABLE IF EXISTS ##LookUp_MaritalStatus_Stage 
	SET @Insert = 
		'
		SELECT distinct [MaritalStatusSID]
			,[Sta3n]
			,[MaritalStatus]
			,' 
		+ @Columns + ' 
		INTO ##LookUp_MaritalStatus_Stage
		FROM [Dim].[MaritalStatus]
		UNION
		SELECT distinct [CodeValueSID]
			,[Sta3n]=200
			,[Display]
			,' 
		+ @Columns + ' 
		FROM [NDimMill].[CodeValue]
		WHERE CodeValueSetID=''38''
		AND ActiveIndicator=1'
		;

	EXEC (@Insert);

	EXEC [Maintenance].[PublishTable] '[LookUp].[MaritalStatus]', '##LookUp_MaritalStatus_Stage'

	  /************* Married MaritalStatus********/

	UPDATE LookUp.MaritalStatus
	SET Reach_Married_MaritalStatus = 1
	WHERE MaritalStatus in ('MARRIED', 'COMMON-LAW') 

	UPDATE LookUp.ColumnDescriptions
	SET [PrintName] = 'Married MaritalStatus',
	[Category] = 'Married',
	[ColumnDescription] = 'Married marital status as defined by Perceptive Reach (SMITREC)',
	[DefinitionOwner]= 'SMITREC Perceptive Reach'
	WHERE [ColumnName] = 'Reach_Married_MaritalStatus'

	  /************* divorced or separated MaritalStatus********/

	UPDATE LookUp.MaritalStatus
	SET Reach_Divorced_MaritalStatus = 1
	WHERE MaritalStatus in ('DIVORCED', 'SEPARATED', 'Legally Separated', 'Annulled','Interlocutory Decree') 

	UPDATE LookUp.ColumnDescriptions
	SET [PrintName] = 'Divorced or separated MaritalStatus',
	[Category] = 'MaritalStatus',
	[ColumnDescription] = 'Divorced or separated MaritalStatus as defined by Perceptive Reach (SMITREC)',
	[DefinitionOwner]= 'SMITREC Perceptive Reach'
	WHERE [ColumnName] = 'Reach_Divorced_MaritalStatus'


		  /************* widow MaritalStatus********/

	UPDATE LookUp.MaritalStatus
	SET Reach_Widow_MaritalStatus = 1
	WHERE MaritalStatus in ('WIDOW/WIDOWER', 'WIDOWED') 

	UPDATE LookUp.ColumnDescriptions
	SET [PrintName] = 'Widow MaritalStatus',
	[Category] = 'MaritalStatus',
	[ColumnDescription] = 'Widow MaritalStatus as defined by Perceptive Reach (SMITREC)',
	[DefinitionOwner]= 'SMITREC Perceptive Reach'
	WHERE [ColumnName] = 'Reach_Widow_MaritalStatus'


END
GO
