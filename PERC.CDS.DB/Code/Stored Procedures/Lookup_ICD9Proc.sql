
-- =============================================
-- Author:		<Tigran Avoundjian>
-- Create date: <1/14/2015>
-- Description:	<Pivoted ICD-9 Procedure lookup crosswalk>
--	8/19		ST - removed inactive flag which was being dropped for CDW update, also used Dim.ICD9ProcedureDescriptionVersion for ICD9ProcedureDescription
--	12/14/2016	GS - migrated with changes from OMHO_PsychPharm
--	2019-02-14	Jason Bacani - Refactored to use [Maintenance].[PublishTable]
-- =============================================
CREATE PROCEDURE [Code].[Lookup_ICD9Proc]
AS
BEGIN

INSERT INTO  LookUp.ColumnDescriptions
	WITH (TABLOCK)
	SELECT DISTINCT
  Object_ID as TableID
  ,a.Table_Name as TableName
		--Name of column from the LookupStopCode table
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
		WHERE b.Name = 'ICD9Proc'
			AND a.Name NOT IN (
			--enter columns you are pulled from CDW dim table here:
				'ICD9ProcedureSID'
				,'Sta3n'
				,'ICD9ProcedureDescription'
				,'ICD9ProcedureShort'
				,'ICD9ProcedureCode'
				--,'InactiveFlag'  --ST 8/19 commented out per Amy
				)
			AND a.Name NOT IN (
				SELECT DISTINCT ColumnName
				FROM  LookUp.ColumnDescriptions
				) --order by COLUMN_NAME
		) AS a
    
    delete LookUp.ColumnDescriptions where TableName = 'ICD9Proc' and columnname not in (SELECT 
    a.name as column_name	
      FROM  sys.columns as a 
		inner join sys.tables as b on   a.object_id = b.object_id-- a.TABLE_NAME = b.TABLE_NAME
		WHERE b.Name = 'ICD9Proc')
	
	DECLARE @Columns VARCHAR(Max);

	SELECT @Columns = CASE 
			WHEN @Columns IS NULL
				THEN '0 as ' + T.ColumnName
			ELSE @Columns + ', 0 as ' + T.ColumnName
			END
	FROM  Lookup.ColumnDescriptions AS T
  where T.TableName = 'ICD9Proc';

	--SELECT @Columns

	--select @Columns
	DECLARE @Insert AS VARCHAR(4000);;

	DROP TABLE IF EXISTS ##LookUp_ICD9Proc_Stage
	SET @Insert = 
		'
	Select a.[ICD9ProcedureSID]
     ,a.[Sta3n]
	 ,b.[ICD9ProcedureDescription]
	 ,Left(b.[ICD9ProcedureDescription], 100) as [ICD9ProcedureShort]
     ,[ICD9ProcedureCode]
    -- ,InActiveFlag  --ST 8/19 Commented out per Amy
     , ' 
		+ @Columns + ' 
	INTO ##LookUp_ICD9Proc_Stage
	from [Dim].[ICD9Procedure] as a inner join 
	[Dim].[ICD9ProcedureDescriptionVersion] as b on a.ICD9ProcedureSID=b.ICD9ProcedureSID
	where b.currentversionflag like ''Y'''; --ST 8/19 added join on ICDPRocedureDescversion
--
	EXECUTE (@Insert);

	EXEC [Maintenance].[PublishTable] '[LookUp].[ICD9Proc]', '##LookUp_ICD9Proc_Stage'


	UPDATE LookUp.ICD9Proc
	SET Psych_Therapy_ICD9Proc = 1
	WHERE ICD9ProcedureCode IN (
		'94.31'
		,'94.33'
		,'94.37'
		,'94.38'
		,'94.44'
		,'94.49'
	);

	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Psychotherapy Procedures',
	Category = 'PsychosocialTreatments',
	ColumnDescription = 'ICD9 Procedure Codes for psychotherapy procedures'
	WHERE ColumnName = 'Psych_Therapy_ICD9Proc';

	--,RM_ActiveTherapies_ICD9Proc [smallint] null
	UPDATE LookUp.ICD9Proc
	SET RM_ActiveTherapies_ICD9Proc = 1
	WHERE ICD9ProcedureCode IN (
		'93.81'
	);

	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Active Therapies',
	Category = 'RehabilitationMedicine',
	ColumnDescription = 'ICD9 Procedure Codes for active therapy procedures'
	WHERE ColumnName = 'RM_ActiveTherapies_ICD9Proc';

	--,RM_OccupationalTherapy_ICD9Proc [smallint] null
	UPDATE LookUp.ICD9Proc
	SET RM_OccupationalTherapy_ICD9Proc = 1
	WHERE ICD9ProcedureCode IN (
		'93.83'
	);

	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Occupational Therapy',
	Category = 'RehabilitationMedicine',
	ColumnDescription = 'ICD9 Procedure Codes for occupational therapy procedures'
	WHERE ColumnName = 'RM_OccupationalTherapy_ICD9Proc';

	--,RM_OtherTherapy_ICD9Proc [smallint] null
	UPDATE LookUp.ICD9Proc
	SET RM_OtherTherapy_ICD9Proc = 1
	WHERE ICD9ProcedureCode IN (
		'93.89'
	);

	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Other Therapy',
	Category = 'RehabilitationMedicine',
	ColumnDescription = 'ICD9 Procedure Codes for other therapy procedures'
	WHERE ColumnName = 'RM_OtherTherapy_ICD9Proc';

	--CAM
	  UPDATE LookUp.ICD9Proc
	SET CAM_ICD9Proc = 1
	WHERE ICD9ProcedureCode IN (
		'93.35'
		,'93.84'
		,'94.32'
		,'94.39'
		,'99.92'
	);

	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Complementary and Alternative Medicine Procedures',
	Category = 'Complementary and Alternative Medicine Treatments from Opioid Metrics',
	ColumnDescription = 'ICD9 Procedure Codes for complementary and alternative medicine therapies'
	WHERE ColumnName = 'CAM_ICD9Proc';

;

-----------------------------------------------------------------
/************INTO QFR.outbox*******************/
-----------------------------------------------------------------
;
--IF Object_Id('[App].[OMHO_QFR_Outbox_LookUpICD9Proc]') IS NOT NULL
--	DROP TABLE [App].[OMHO_QFR_Outbox_LookUpICD9Proc]

--SELECT DISTINCT *
--INTO [App].[OMHO_QFR_Outbox_LookUpICD9Proc]
--FROM LookUp.ICD9Proc

--IF Object_Id('[App].[OMHO_QFR_Outbox_LookUpICD9ProcDescription]') IS NOT NULL
--	DROP TABLE [App].[OMHO_QFR_Outbox_LookUpICD9ProcDescription]

--SELECT DISTINCT *
--INTO [App].[OMHO_QFR_Outbox_LookUpICD9ProcDescription]
--FROM LookUp.ColumnDescriptions
;


END
GO
