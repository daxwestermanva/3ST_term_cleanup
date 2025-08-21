

-- =============================================
-- Author:		<Paik, Meenah>
-- Create date: <02/18/2016>
-- Description:	<Lookup Table for ICD-10 Procedure Codes>
-- Modifications:
	-- 2020-08-04 - RAS	Branched from LookUp_ICD10Proc to create version for VistA and Cerner data
	-- 2021-05-14  JJR_SA - Added tag for identifying code to Share in ShareMill
	-- 2021-06-03  JJR_SA - Updated tagging for use in sharing code for ShareMill;adjusted position of ending tag
-- =============================================
CREATE   PROCEDURE [Code].[LookUp_ICD10Proc]
AS
BEGIN

/*** When ADDING A NEW VARIABLE, first add the column to the target table (LookUp.ICD10). ***/

EXEC [Log].[ExecutionBegin] 'EXEC Code.LookUp_ICD10Proc','Execution of Code.LookUp_ICD10Proc SP'

/**************************************************************************************************/
/*** Add new rows to [LookUp].[ColumnDescriptions] if they exist in LookUp.ICD10 *************/
/**************************************************************************************************/

DECLARE @TableName VARCHAR(50) = 'ICD10Proc'

/*** adding variables from App.LookUpICD10 to [LookUp].[ColumnDescriptions]****/
	INSERT INTO [LookUp].[ColumnDescriptions]
	WITH (TABLOCK)
	SELECT DISTINCT
		 Object_ID as TableID
		,a.TableName
		--Name of column from the LookupICD10 table
		,ColumnName
		,NULL AS Category
		,NULL AS PrintName
		,NULL AS ColumnDescription
		,Null as DefinitionOwner
	FROM (
		SELECT a.Object_ID
			  ,b.name as TableName
			  ,a.name as ColumnName	
        FROM  sys.columns as a 
		INNER JOIN sys.tables as b on a.object_id = b.object_id
		WHERE b.Name = @TableName
			AND a.Name NOT IN (
				 'ICD10ProcedureSID'
				,'Sta3n'
				,'ICD10ProcedureCode'
				,'ICD10ProcedureDescription'
				,'ICD10ProcedureShort'
				)
			AND a.Name NOT IN ( --only new columns without definitions already
				SELECT DISTINCT ColumnName
				FROM [LookUp].[ColumnDescriptions] 
				WHERE TableName =  @TableName
				)
		) AS a
    
    --remove any deleted columns
	DELETE [LookUp].[ColumnDescriptions]
	WHERE TableName = @TableName 
		AND ColumnName NOT IN (
			SELECT a.name as ColumnName
			FROM  sys.columns as a 
			INNER JOIN sys.tables as b on  a.object_id = b.object_id
			WHERE b.Name = @TableName
			)
		;

	--SELECT * FROM  [LookUp].[ColumnDescriptions] WHERE TableName=@TableName ORDER BY ColumnName

/**************************************************************************************************/
/*** Pull complete data from dim tables and combine with fields for LookUp table***/
/**************************************************************************************************/

--DECLARE @TableName VARCHAR(50) = 'ICD10Proc'

	DECLARE @Columns VARCHAR(Max);

	SELECT @Columns = 
		CASE 
			WHEN @Columns IS NULL
				THEN '0 as ' + T.ColumnName
			ELSE @Columns + ', 0 as ' + T.ColumnName
			END
	FROM [LookUp].[ColumnDescriptions] AS T
    WHERE T.TableName = @TableName;

	--select @Columns  --(if you want to see results of code above)
	
	DECLARE @Insert AS VARCHAR(max);

	DROP TABLE IF EXISTS ##LookUp_ICD10Proc_Stage
	SET @Insert = 		'
		SELECT ICD10ProcedureSID
			  ,Sta3n
			  ,ICD10ProcedureDescription
			  ,ICD10ProcedureShort
			  ,ICD10ProcedureCode
			  ,' + @Columns + ' 
		INTO ##LookUp_ICD10Proc_Stage
		FROM ('

		/*##SHAREMILL BEGIN##*/
		SET @Insert =  @Insert + N'
			SELECT DISTINCT NomenclatureSID as ICD10ProcedureSID
				,Sta3n = CAST(200 AS SMALLINT)
				,SourceString as ICD10ProcedureDescription
				,LEFT(SourceString, 100) as ICD10ProcedureShort
				,SourceIdentifier as ICD10ProcedureCode
			FROM [Cerner].[DimNomenclature] WITH (NOLOCK)
			WHERE SourceVocabulary IN (''ICD-10-PCS'')
			AND PrincipleType =''Procedure''
			AND ContributorSystem = ''Centers for Medicare & Medicaid Services''
		UNION ALL 
			SELECT DISTINCT p.ICD10ProcedureSID
				,p.Sta3n
				,d.ICD10ProcedureDescription
				,LEFT(d.ICD10ProcedureDescription, 100) as ICD10ProcedureShort
				,p.ICD10ProcedureCode
			FROM [Dim].[ICD10Procedure] as p WITH (NOLOCK)
			INNER JOIN [Dim].[ICD10ProcedureDescriptionVersion] as d WITH (NOLOCK) on d.ICD10ProcedureSID=p.ICD10ProcedureSID
			WHERE d.CurrentVersionFlag LIKE ''Y'''/*##SHAREMILL END##*/
		SET @Insert =  @Insert + N') a'
		EXEC (@Insert);

	

/**************************************************************************************************/
/***** Updating variable flags and adding definitions. ************************/
/**************************************************************************************************/	

--DECLARE @TableName VARCHAR(50) = 'ICD10Proc'

	UPDATE ##LookUp_ICD10Proc_Stage
	SET Psych_Therapy_ICD10Proc = 1
	WHERE ICD10ProcedureCode IN (
		'GZ54ZZZ'
		,'8EOZXYZ'
		,'GZ51ZZZ'
		,'GZ58ZZZ'
		,'GZ50ZZZ'
		,'GZ52ZZZ'
		,'GZ53ZZZ'
		,'GZ55ZZZ'
		,'GZ56ZZZ'
		,'GZHZZZZ'
		,'GZ63ZZZ'
		,'GZ59ZZZ'
		,'HZ52ZZZ'
		)

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Psychotherapy Procedures',
		Category = 'PsychosocialTreatments',
		ColumnDescription = 'ICD10 Procedure Codes for psychotherapy procedures'
	WHERE ColumnName = 'Psych_Therapy_ICD10Proc'
		AND TableName=@TableName

	--,RM_ActiveTherapies_ICD10Proc [smallint] null
	UPDATE ##LookUp_ICD10Proc_Stage
	SET RM_ActiveTherapies_ICD10Proc = 1
	WHERE ICD10ProcedureCode = 'F07M6ZZ'

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Active Therapies',
		Category = 'RehabilitationMedicine',
		ColumnDescription = 'ICD10 Procedure Codes for active therapy procedures'
	WHERE ColumnName = 'RM_ActiveTherapies_ICD10Proc'
		AND TableName=@TableName

	--,RM_OccupationalTherapy_ICD10Proc [smallint] null
	UPDATE ##LookUp_ICD10Proc_Stage
	SET RM_OccupationalTherapy_ICD10Proc = 1
	WHERE ICD10ProcedureCode LIKE 'F02Z%' 
		OR ICD10ProcedureCode LIKE 'F08Z%'

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Occupational Therapy',
		Category = 'RehabilitationMedicine',
		ColumnDescription = 'ICD10 Procedure Codes for occupational therapy procedures'
	WHERE ColumnName = 'RM_OccupationalTherapy_ICD10Proc'
		AND TableName=@TableName

	--,RM_OtherTherapy_ICD10Proc [smallint] null
	UPDATE ##LookUp_ICD10Proc_Stage
	SET RM_ChiropracticCare_ICD10Proc = 1
	WHERE ICD10ProcedureCode LIKE '9WB%'
	

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Chiropractic Care',
	Category = 'RehabilitationMedicine',
	ColumnDescription = 'ICD10 Procedure Codes for chiropractic care procedures'
	WHERE ColumnName = 'RM_ChiropracticCare_ICD10Proc'
		AND TableName=@TableName

	--CIH
	UPDATE ##LookUp_ICD10Proc_Stage
	SET CIH_ICD10Proc = 1
	WHERE ICD10ProcedureCode IN (
		'GZFZZZ'
		,'GZC9ZZZ'
		,'8E0H30Z'
		,'8E0H300'
		,'8E0KX1Z'
		,'8E0ZXY4'
		,'8E0ZXY5'
		)

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Complementary and Integrative Health Procedures',
		Category = 'Complementary and Integrative Health Treatments from Opioid Metrics',
		ColumnDescription = 'ICD10 Procedure Codes for Complementary and Integrative Health therapies'
	WHERE ColumnName = 'CIH_ICD10Proc'
		AND TableName=@TableName

	--,MedMgt_ICD10Proc [smallint] null
	UPDATE ##LookUp_ICD10Proc_Stage
	SET MedMgt_ICD10Proc = 1
	WHERE ICD10ProcedureCode = 'GZ3ZZZZ'
	;

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Medication Management',
		Category = 'MedicationManagement',
		ColumnDescription = 'ICD10 Procedure Codes for Medication Management Procedures'
	WHERE ColumnName = 'MedMgt_ICD10Proc'
		AND TableName=@TableName

	--,SAE_Detox_ICD10Proc [smallint] null
	UPDATE ##LookUp_ICD10Proc_Stage
	SET SAE_Detox_ICD10Proc = 1
	WHERE ICD10ProcedureCode = 'HZ2ZZZZ'

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'SAE Detox Procedures',
		Category = 'SAE Detoxification Services',
		ColumnDescription = 'ICD10 Procedure Codes for SAE Detox Procedures'
	WHERE ColumnName = 'SAE_Detox_ICD10Proc'
		AND TableName=@TableName

EXEC [Maintenance].[PublishTable] 'LookUp.ICD10Proc','##LookUp_ICD10Proc_Stage'

EXEC [Log].[ExecutionEnd]


--select distinct ICD10ProcedureCode into #c from lookup.ICD10Proc where sta3n='200'
--select distinct ICD10ProcedureCode into #v from lookup.ICD10Proc where sta3n<>'200'


--top 10 * from LookUp.ICD10Proc where ICD10ProcedureCode ='0HBQXZX'

END
;