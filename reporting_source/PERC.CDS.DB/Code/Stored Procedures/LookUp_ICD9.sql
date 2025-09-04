

/***-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <1/21/2015>
-- Description:	<Pivoted ICD lookup crosswalk> 
-- Modifications: ST 9/16 added where statement for ICDDescriptionVersion
-- SM added Tourette and Huntington
-- 9/17/15 SM readded 307.23 to dementia code per IW
-- 9/28/15 SM updated AUD to be the same as Master file definition
-- 9/28/15 SM corrected DEPRESS definition per IW/JT to be MDD plus some other depression dx (exclude personality disorder, 
				psychosis and adjustment disorders with depression)
-- 12.7.15 ST Added SUD_noAUD_noOUD_noCann_noHalluc_noStim_noCoc, CocaineUD_AmphUD, CannabisUD_HallucUD
-- SM 12/11/15 updated MHorMedInd_AD and MHorMedInd_Benzo to include all SUD or MH dx used in IRA ([MHSUDdx_poss])
-- 9/15/16 MCP Added E980.2 to SAE_sed
-- 2018-06-07	Jason Bacani - Removed hard coded database references
-- 2019-02-15	Jason Bacani - Refactored to use [Maintenance].[PublishTable]; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
-- 2019-03-14	RAS - Commented out code for OtherSUD and Panic, which are no longer being used (code to populate these columns 
					  did NOT exist in ICD10 lookup code).  I removed these columns from ICD9 and ICD10 table.
-- 2019-12-04   CB  added in Women Reach Vet (WRV) variables
-- 2020-04-01	RAS Correced Other_MH_STORM code to use "UPDATE" statement to update the field.
-- 2020-04-20	RAS	Formatting. Added staging table to update and then publish
-- 2023-07-13   CW  Changed "Renal Failure" to "Renal Impairment" per JT.
-- 2024-12-18	LM	Removed Psych_Poss definition
-- =============================================
*/ 
CREATE PROCEDURE [Code].[LookUp_ICD9]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.LookUp_ICD9', @Description = 'Execution of Code.LookUp_ICD9 SP'

/*** When ADDING A NEW VARIABLE, first add the column to the target table (LookUp.ICD9). ***/

/**************************************************************************************************/
/*** Add new rows to [LookUp].[ColumnDescriptions] if they exist in LookUp.ICD10 *************/
/**************************************************************************************************/

/*** adding variables from App.LookUpICD to [LookUp].[ColumnDescriptions]****/
	INSERT INTO [LookUp].[ColumnDescriptions]
	WITH (TABLOCK)
	SELECT DISTINCT
		 Object_ID as TableID
		,a.Table_Name as TableName
		--Name of column from the LookupICD9 table
		,Column_Name AS ColumnName
		,NULL AS Category
		,NULL AS PrintName
		,NULL AS ColumnDescription
		,Null as DefinitionOwner
	FROM (
		SELECT a.Object_ID
			  ,b.name as Table_Name
			  ,a.name as column_name	
        FROM  sys.columns as a 
		INNER JOIN sys.tables as b on a.object_id = b.object_id-- a.TABLE_NAME = b.TABLE_NAME
		WHERE b.Name = 'ICD9'
			AND a.Name NOT IN (
				'ICD9SID'
				,'Sta3n'
				,'ICD9Description'
				,'ICD9Code'
				)
			AND a.Name NOT IN ( --only new columns without definitions already
				SELECT DISTINCT ColumnName
				FROM [LookUp].[ColumnDescriptions] 
				WHERE TableName =  'ICD9'
				) --order by COLUMN_NAME
		) AS a
		    
    --remove any deleted columns
	DELETE [LookUp].[ColumnDescriptions]
	WHERE TableName = 'ICD9' 
		AND ColumnName NOT IN (
			SELECT a.name as ColumnName
			FROM  sys.columns as a 
			INNER JOIN sys.tables as b on  a.object_id = b.object_id
			WHERE b.Name = 'ICD9'
			)
		;	
	
/**************************************************************************************************/
/*** Pull complete data from Dim.ICD10 with fields from LookUp.ICD10***/
/**************************************************************************************************/

	DECLARE @Columns VARCHAR(Max);

	SELECT @Columns = 
		CASE 
			WHEN @Columns IS NULL
				THEN '0 as ' + T.ColumnName
			ELSE @Columns + ', 0 as ' + T.ColumnName
			END
	FROM [LookUp].[ColumnDescriptions] AS T
    WHERE T.TableName = 'ICD9';

	--select @Columns  --(if you want to see results of code above)
	
	DECLARE @Insert AS VARCHAR(max);

	DROP TABLE IF EXISTS ##Lookup_ICD9_Stage
	SET @Insert = '
	Select a.ICD9SID
		  ,a.Sta3n
		  ,b.ICD9Description
		  ,a.ICD9Code
		  ,' + @Columns + ' 
	INTO ##Lookup_ICD9_Stage
	FROM  [Dim].[ICD9] as a
	INNER JOIN [Dim].[ICD9DescriptionVersion] as b on a.ICD9SID=b.ICD9SID
	WHERE EndEffectiveDate > GetDate()
		AND CurrentVersionFlag LIKE ''Y''
		'
	EXEC (@Insert);

/**************************************************************************************************/
/***** Updating ICD9 variable flags and adding definitions. ************************/
/**************************************************************************************************/	

	/***Other_MH_STORM **************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Other_MH_STORM'
		,Category = 'STORM Predictor'
		,ColumnDescription = 'Other Mental Health per STORM paper'
		,DefinitionOwner = 'STORM Model Oliva et al 2017'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'Other_MH_STORM'

	-- updating field flag
	UPDATE ##LookUp_ICD9_Stage
	SET Other_MH_STORM = 1
	WHERE (ICD9Code BETWEEN '295' AND '298.99' 
			OR ICD9Code BETWEEN '300.0' AND  '300.49' 
			OR ICD9Code BETWEEN '300.6' AND  '301.99' 
			OR ICD9Code LIKE '307.1%'	
			OR ICD9Code LIKE '307.5%'	
			OR ICD9Code BETWEEN '308' AND  '309.99' 
			OR ICD9Code BETWEEN '311' AND  '312.99' 
			OR ICD9Code LIKE '314%'	    
			)--PsychDx_poss
		AND (ICD9Code NOT LIKE '296.2%' 
				AND ICD9Code NOT like '296.3%'
			)  -- MDDdx_poss
		AND (ICD9Code NOT LIKE '309.81')  --PTSDdx_poss
		AND (ICD9Code NOT BETWEEN '296.0' AND '296.19' 
				AND ICD9Code NOT BETWEEN '296.4' AND '296.89'
			)  -- AFFdx_poss

	/***************Suicide Attempt*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Suicide Attempt',
		Category = 'Mental Health',
		ColumnDescription = 'Suicide, includes sequela, initial and subsequent excludes ideation ',
		DefinitionOwner = 'ORM'  
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'SuicideAttempt'

	-- updating variable flag
		--Does not include suicide ideation (V62.84)
	UPDATE ##LookUp_ICD9_Stage
	SET SuicideAttempt = 1
	WHERE ICD9Code IN (
		 'E950.0','E950.01','E950.02'
		,'E950.1','E950.11','E950.12'
		,'E950.2','E950.21','E950.22'
		,'E950.3','E950.31','E950.32'
		,'E950.4','E950.41','E950.42'
		,'E950.5','E950.51','E950.52'
		,'E950.6','E950.61','E950.62'
		,'E950.7','E950.71','E950.72'
		,'E950.8','E950.81','E950.82'
		,'E950.9','E950.91','E950.92'
		,'E951.0','E951.01','E951.02'
		,'E951.1','E951.11','E951.12'
		,'E951.8','E951.81','E951.82'
		,'E952.0','E952.01','E952.02'
		,'E952.1','E952.11','E952.12'
		,'E952.8','E952.81','E952.82'
		,'E952.9','E952.91','E952.92'
		,'E953.0','E953.01','E953.02'
		,'E953.1','E953.11','E953.12'
		,'E953.8','E953.81','E953.82'
		,'E953.9'
		,'E954.','E954.1','E954.2'
		,'E955.0','E955.01','E955.02'
		,'E955.1','E955.11','E955.12'
		,'E955.2','E955.21','E955.22'
		,'E955.3','E955.31','E955.32'
		,'E955.4','E955.41','E955.42'
		,'E955.5','E955.51','E955.52'
		,'E955.6','E955.7','E955.9'
		,'E956.','E956.1','E956.2'
		,'E957.0','E957.01','E957.02'
		,'E957.1','E957.11','E957.12'
		,'E957.2','E957.21','E957.22'
		,'E957.9','E957.91','E957.92'
		,'E958.0','E958.01','E958.02'
		,'E958.1','E958.11','E958.12'
		,'E958.2''E958.21','E958.22'
		,'E958.3','E958.31','E958.32'
		,'E958.4','E958.41','E958.42'
		,'E958.5','E958.51','E958.52'
		,'E958.6','E958.61','E958.62'
		,'E958.7','E958.71','E958.72'
		,'E958.8','E958.81','E958.82'
		,'E958.9'
		,'E959.'
		,'E980.6','E980.8'
		,'E981.0','E981.1','E981.8'
		,'E982.0','E982.1','E982.8','E982.9'
		,'E983.0','E983.1','E983.8','E983.9'
		,'E984.'
		,'E988.0','E988.1','E988.2','E988.3','E988.4'
		,'E988.5','E988.6','E988.7','E988.8','E988.9'
		)

   /*** TBI**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'TBI'
		,Category = 'TBI'
		,ColumnDescription = 'TBI based on James paper'
		,DefinitionOwner = 'STORM Model'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'TBI_Dx'

	UPDATE ##LookUp_ICD9_Stage
	SET TBI_Dx= 1
	WHERE ICD9Code LIKE '851%'
		OR ICD9Code LIKE '852%'
		OR ICD9Code LIKE '853%'
		OR ICD9Code LIKE '854%'
		OR ICD9Code LIKE '855%'
		OR ICD9Code LIKE '856%'
		OR ICD9Code LIKE '857%'
		OR ICD9Code LIKE '858%'
		OR ICD9Code LIKE '859%' 

   /*** Long QT syndrome**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Long QT syndrome'
		,Category = 'Long QT syndrome'
		,ColumnDescription = 'Long QT syndrome'
		,DefinitionOwner = 'STORM Model'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'LongQTSyndrome_Dx'

	UPDATE ##LookUp_ICD9_Stage
	SET LongQTSyndrome_Dx= 1
	WHERE ICD9Code LIKE '426.82'
   
	/*** SUD_Active_Dx **************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Active SUD'
		,Category = 'Active SUD'
		,ColumnDescription = 'Active SUD'
		,DefinitionOwner = 'STORM Model'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'SUD_Active_Dx'

	UPDATE ##LookUp_ICD9_Stage
	SET  SUD_Active_Dx= 1
    WHERE (ICD9Code BETWEEN '291'AND '292.99'
			OR ICD9Code BETWEEN '303' AND '305.09'
			OR ICD9Code BETWEEN '305.2' AND '305.999'
		)
		AND ICD9Description NOT LIKE '%remission%'		

	/*** SUD_Remission_Dx **************/
	-- updating definition information
	 UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'SUD_Remission_Dx',
		Category = 'SUD_Remission_Dx',
		ColumnDescription = 'SUD_Remission_Dx',
		DefinitionOwner = 'STORM Model'
	WHERE TableName = 'ICD9' and  ColumnName = 'SUD_Remission_Dx'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET  SUD_Remission_Dx= 1
    WHERE (ICD9Code BETWEEN '291' AND '292.99'
			OR ICD9Code BETWEEN '303' AND '305.09'
			OR ICD9Code BETWEEN '305.2' AND '305.999'
		)
		AND ICD9Description LIKE '%remission%'

	/*** Huntington**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Huntington'
		,Category = 'Huntington'
		,ColumnDescription = 'Huntingtons Chorea'
		,DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9'
		AND ColumnName = 'Huntington'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET Huntington = 1
	WHERE ICD9Code LIKE '333.4'

   /*** Tourette**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Tourette',
		Category = 'Tourette',
		ColumnDescription = 'Tourettes Disorder',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'Tourette'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET Tourette = 1
	WHERE ICD9Code LIKE '307.23'

	/*** Alcohol Use Disorder**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Alcohol Use Disorder',
		Category = 'Alcohol Use Disorder',
		ColumnDescription = 'ALCdx_poss for ORM risk computation',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9'
		AND ColumnName = 'ALCdx_poss'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET ALCdx_poss = 1
	WHERE ICD9Code LIKE '291%' 
		OR ICD9Code LIKE '303%' 
		OR ICD9Code LIKE '305.0%'

	/*** Amphetamine Use Disorder**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Amphetamine Use Disorder',
		Category = 'Amphetamine Use Disorder',
		ColumnDescription = 'Amphetamine Use Disorder',
		DefinitionOwner = 'SM_vettedJT'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'AmphetamineUseDisorder'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET AmphetamineUseDisorder = 1
	WHERE ICD9Code IN (
		'304.40','304.400'
		,'304.41','304.410'
		,'304.42','304.420'
		,'304.43','304.430'
		,'305.70','305.700'
		,'305.71','305.710'
		,'305.72','305.720'
		,'305.73','305.730'
		)

	/***************AUD*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Alcohol Use Disorder',
		Category = 'Alcohol Use Disorder',
		ColumnDescription = 'Alcohol Use Disorder',
		DefinitionOwner = 'VISN21 + Academic Detailing'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'AUD'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET AUD = 1
	WHERE ICD9Code LIKE '291%' 
		OR ICD9Code LIKE '303%' 
		OR ICD9Code LIKE '305.0%' -- 9/28/15 SM updated to match IRA file definition (ALCdx_poss) but leaving as old name to avoid other code changes
		--Academic Details (end organ damage)
		OR ICD9Code IN ('357.5','425.5','535.3','535.3','535.31','571','571.1','571.2','571.3','760.71')


	/***************AUD_ORM*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Alcohol Use Disorder',
		Category = 'Alcohol Use Disorder',
		ColumnDescription = 'Alcohol Use Disorder',
		DefinitionOwner = 'Unknown'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'AUD_ORM'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET AUD_ORM = 1
	WHERE ICD9Code LIKE '291.%'
		OR ICD9Code LIKE '303%'
		OR ICD9Code LIKE '305.0%'

  /***************Benzo_AD_MHDx*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Benzo_AD_MHDx',
		Category = 'Benzo_AD_MHDx',
		ColumnDescription = 'Benzo_AD_MHDx',
		DefinitionOwner = 'OMHO_SMITREC'
	WHERE TableName = 'ICD9' 
		AND  ColumnName = 'Benzo_AD_MHDx'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET Benzo_AD_MHDx = 1
    WHERE ICD9Code IN (
			'291.1','291.2'
			,'292.12'
			,'292.2'
			,'292.81','292.82','292.83','292.84','292.85','292.89'
			,'292.9'
			,'300.11','300.12','300.13','300.14','300.15','300.16','300.19'
			,'300.22','300.23','300.29'
			,'300.3'
			,'300.7'
			,'300.81','300.82','300.89'
			,'300.9'
			,'301.12'
			,'301.21'
			,'301.4','301.6','301.7'
			,'301.81','301.82','301.84'
			,'303.93'
			,'305.03'
			,'305.6'
			,'307.1'
			,'307.51','307.52','307.53','307.54','307.59'
			,'308.1','308.2','308.3','308.4','308.9'
			,'309.3','309.4','309.82','309.83','309.89','309.9'
			,'312.31','312.32','312.33','312.34','312.35','312.39'
			,'312.4','312.8','312.9'
			,'314.01','314.1','314.2','314.8','314.9'
			)
		OR (ICD9Code LIKE '291.8%')
		OR (ICD9Code LIKE '295.5%')
		OR (ICD9Code LIKE '300.0%')
		OR (ICD9Code LIKE '301.5%')
		OR (ICD9Code LIKE '303.0%')
		OR (ICD9Code LIKE '303.9%')
		OR (ICD9Code LIKE '304.0%')
		OR (ICD9Code LIKE '304.1%')
		OR (ICD9Code LIKE '304.2%')
		OR (ICD9Code LIKE '304.3%')
		OR (ICD9Code LIKE '304.4%')
		OR (ICD9Code LIKE '304.5%')
		OR (ICD9Code LIKE '304.6%')
		OR (ICD9Code LIKE '304.7%')
		OR (ICD9Code LIKE '304.8%')
		OR (ICD9Code LIKE '304.9%')
		OR (ICD9Code LIKE '305.0%')
		OR (ICD9Code LIKE '305.2%')
		OR (ICD9Code LIKE '305.3%')
		OR (ICD9Code LIKE '305.4%')
		OR (ICD9Code LIKE '305.5%')
		OR (ICD9Code LIKE '305.6%')
		OR (ICD9Code LIKE '305.7%')
		OR (ICD9Code LIKE '305.8%')
		OR (ICD9Code LIKE '305.9%')
		OR (ICD9Code LIKE '307.5%')
		OR (ICD9Code LIKE '309.2%')
		OR (ICD9Code LIKE '312.0%')
		OR (ICD9Code LIKE '312.1%')
		OR (ICD9Code LIKE '312.2%')
		OR (ICD9Code LIKE '312.8%')

	/***************BIPOLAR*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'BIPOLAR',
		Category = 'BIPOLAR',
		ColumnDescription = 'BIPOLAR',
		DefinitionOwner = 'VISN21'
	WHERE TableName = 'ICD9' and  ColumnName = 'BIPOLAR';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET BIPOLAR = 1
	WHERE ICD9Code IN (
		'296.00','296.01','296.02','296.03','296.04','296.05','296.06'
		,'296.10','296.11','296.12','296.13','296.14','296.15','296.16'
		,'296.40','296.41','296.42','296.43','296.44','296.45','296.46'
		,'296.50','296.51','296.52','296.53','296.54','296.55','296.56'
		,'296.60','296.61','296.62','296.63','296.64','296.65','296.66'
		,'296.7'
		,'296.80','296.81','296.89'
		)

   /***************Cannabis*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Cannabis',
		Category = 'Cannabis',
		ColumnDescription = 'Cannabis',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'Cannabis'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET Cannabis = 1
	WHERE ICD9Code IN (
		'304.30','304.300','304.309'
		,'304.31','304.310','304.319'
		,'304.32','304.320','304.329'
		,'304.33','304.330','304.339'
		,'304.39'
		,'305.20','305.200','305.209'
		,'305.21','305.210','305.219'
		,'305.22','305.220','305.229'
		,'305.23','305.230','305.239'
		,'305.29'
		)

   /***************Cannabis & Hallucinogen ST 12/7/15*********************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Cannabis and Hallucinogen Use Disorder',
		Category = 'Cannabis and Hallucinogen Use Disorder',
		ColumnDescription = 'Cannabis and Hallucinogen Use Disorder',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'CannabisUD_HallucUD'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET CannabisUD_HallucUD = 1
	WHERE ICD9Code LIKE '304.3%' 
		OR ICD9Code LIKE '305.2%' 
		OR ICD9Code LIKE '304.5%'  
		OR ICD9Code LIKE '305.3%'

   /***************Cocaine Use Disorder*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Cocaine Use Disorder',
		Category = 'Cocaine Use Disorder',
		ColumnDescription = 'Cocaine Use Disorder',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' and  ColumnName = 'COCNdx';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET COCNdx = 1
	WHERE ICD9Code LIKE '304.2%'
		OR ICD9Code LIKE '305.6%'

 /***************Cocaine and Amphetamines (Stimulant Use Disorders) ST 12/7/15***********/
	-- updating definition information   
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Cocaine Use Disorder and Amphetamine Use Disorder',
		Category = 'Cocaine Use Disorder and Amphetamine Use Disorder',
		ColumnDescription = 'Cocaine Use Disorder and Amphetamine Use Disorder',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'CocaineUD_AmphUD'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET CocaineUD_AmphUD = 1
	WHERE ICD9Code LIKE '304.2%'  
		OR ICD9Code LIKE '305.6%'
		OR ICD9Code LIKE '304.4%'
		OR ICD9Code LIKE '305.7'

   /***************DEMENTIA*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'DEMENTIA',
		Category = 'DEMENTIA',
		ColumnDescription = 'GEC Services 10P4G maintains for official VHA reporting purposes (http://vaww.arc.med.va.gov/reports/dementia_toc.asp)',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'DEMENTIA'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET DEMENTIA = 1
	WHERE ICD9Code IN (
		'046.1','046.11','046.19','046.3','046.79'
		,'290.0','290.10','290.11','290.12','290.13','290.20','290.21','290.3','290.40','290.41','290.42','290.43'
		,'291.2'
		,'292.82'
		,'294.10','294.11','294.20','294.21','294.8'
		,'331.0','331.11','331.19','331.2','331.7','331.82','331.89','331.9'
		,'333.0','333.4'
		)

 /***************DEPRESSION*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'DEPRESSION',
		Category = 'DEPRESSION',
		ColumnDescription = 'DEPRESSION',
		DefinitionOwner = 'PERC'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'DEPRESS'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET DEPRESS = 1
	WHERE ICD9Code IN (
				'290.13'	--PRESENILE DEMENTIA WITH DEPRESSIVE FEATURES
				,'290.21'	--SENILE DEMENTIA WITH DEPRESSIVE FEATURES
				,'290.43'	--VASCULAR DEMENTIA, WITH DEPRESSED MOOD
				,'293.83'	--MOOD DISORDER IN CONDITIONS CLASSIFIED ELSEWHERE
				,'296.20','296.21','296.22','296.23','296.24','296.25'--HEDIS 2016 Major Depression
				,'296.26'	--MAJOR DEPRESSIVE AFFECTIVE DISORDER, SINGLE EPISODE, IN FULL REMISSION
				,'296.30','296.31','296.32','296.33','296.34','296.35'--HEDIS 2016 Major Depression
				,'296.36'	--MAJOR DEPRESSIVE AFFECTIVE DISORDER, RECURRENT EPISODE, IN FULL REMISSION
				,'296.82'	--ATYPICAL DEPRESSIVE DISORDER
				--,'298.0'  removed per IW 9/28/15 SM  --HEDIS 2016 Major Depression
				,'300.4'	--DYSTHYMIC DISORDER
				--'301.12' removed per IW 9/28/15 SM
				--,'309.0'  removed per IW 9/28/15 SM
				--,'309.28' Omission vetted by Jodie Trafton and edited by ST on 3/28/14
				--,'309.1'  removed per IW 9/28/15 SM
				,'311.'		--HEDIS 2016 Major Depression
				)

 /***************DEPRESSION for EBP templates reports*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'DEPRESSION',
		Category = 'DEPRESSION',
		ColumnDescription = 'DEPRESSION for EBP templates',
		DefinitionOwner = 'PERC'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'DEPRESS_EBP'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET DEPRESS_EBP = 1
	WHERE ICD9Code IN (
		'296.20','296.21','296.22','296.23','296.24','296.25'
		,'296.30','296.31','296.32','296.33','296.34','296.35'
		,'296.82'
		,'300.4'
		,'309.0'
		,'309.1'
		,'311.'
		)
		
 /***************EH_AIDS*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'AIDS',
		Category = 'AIDS',
		ColumnDescription = 'EH AIDS',
		DefinitionOwner = 'PERC'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_AIDS'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_AIDS = 1
	WHERE ICD9Code LIKE '042%'

/***************Alcohol Dependence*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Alcohol Dependence',
		Category = 'Alcohol Dependence',
		ColumnDescription = 'Alcohol Dependence',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_AlcDep'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_AlcDep = 1
    WHERE ICD9Code LIKE '291%'
		OR ICD9Code LIKE '303%'
		OR ICD9Code LIKE '305.0%'

	/***************Alcohol Abuse*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Alcohol Abuse',
		Category = 'Alcohol Abuse',
		ColumnDescription = 'Alcohol Abuse',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_ALCOHOL'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_ALCOHOL = 1
	WHERE ICD9Code LIKE '291.1%'
		OR ICD9Code LIKE '291.2%'
		OR ICD9Code LIKE '291.5%'
		OR ICD9Code LIKE '291.8%'
		OR ICD9Code LIKE '291.9%'
		OR ICD9Code LIKE 'V11.3%'
		OR ICD9Code LIKE '303.9%'
		OR ICD9Code LIKE '305.0%'
  
  /***************CARDIAC ARRHYTHMIA*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'CARDIAC ARRHYTHMIA',
		Category = 'CARDIAC ARRHYTHMIA',
		ColumnDescription = 'CARDIAC ARRHYTHMIA',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_ARRHYTH'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_ARRHYTH = 1
	WHERE ICD9Code LIKE '426.10%'
			OR ICD9Code LIKE '426.11%'
			OR ICD9Code LIKE '426.13%'
			OR ICD9Code LIKE '427.0%'
			OR ICD9Code LIKE '427.2%'
			OR ICD9Code LIKE '427.31%'
			OR ICD9Code LIKE '427.60%'
			OR ICD9Code LIKE '427.9%'
			OR ICD9Code LIKE '785.0%'
			OR ICD9Code LIKE 'V45.0%'
			OR ICD9Code LIKE 'V53.3%'
			OR ICD9Code BETWEEN '426.2' AND '426.53'
			OR ICD9Code BETWEEN '426.6' AND '426.89'
  
  /***************BLOOD LOSS ANEMIA*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'BLOOD LOSS ANEMIA',
		Category = 'BLOOD LOSS ANEMIA',
		ColumnDescription = 'BLOOD LOSS ANEMIA',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_BLANEMIA'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_BLANEMIA = 1
	WHERE ICD9Code LIKE '280.0%'

  /***************CHRONIC PULMONARY DISEASE*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'CHRONIC PULMONARY DISEASE',
		Category = 'CHRONIC PULMONARY DISEASE',
		ColumnDescription = 'CHRONIC PULMONARY DISEASE',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_CHRNPULM'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_CHRNPULM = 1
	WHERE ICD9Code LIKE '494%'
		OR ICD9Code LIKE '506.4%'
		OR ICD9Code BETWEEN '490' AND '492.8'
		OR ICD9Code BETWEEN '493.00' AND '493.91'
		OR ICD9Code BETWEEN '495.0' AND '505'
 
  /***************COAGULOPATHY*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'COAGULOPATHY',
		Category = 'COAGULOPATHY',
		ColumnDescription = 'COAGULOPATHY',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_COAG'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_COAG = 1
	WHERE ICD9Code LIKE '286%'
			OR ICD9Code LIKE '287.1%'
			OR ICD9Code LIKE '287.3%'
			OR ICD9Code LIKE '287.4%'
			OR ICD9Code LIKE '287.5%'
		
  /***************DIABETES - COMPLICATED*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'DIABETES - COMPLICATED',
		Category = 'DIABETES - COMPLICATED',
		ColumnDescription = 'DIABETES - COMPLICATED',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_COMDIAB'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_COMDIAB = 1
	WHERE ICD9Code BETWEEN '250.40' AND '250.73'
		OR ICD9Code BETWEEN '250.90' AND '250.93'

 /***************DEFICIENCY ANEMIAS*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'DEFICIENCY ANEMIAS',
		Category = 'DEFICIENCY ANEMIAS',
		ColumnDescription = 'DEFICIENCY ANEMIAS',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_DefANEMIA'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_DefANEMIA = 1
    WHERE ICD9Code LIKE '285.9%'
		OR ICD9Code BETWEEN '280.1' AND '281.9'  


 /***************DEPRESSION*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'DEPRESSION',
		Category = 'DEPRESSION',
		ColumnDescription = 'DEPRESSION',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_DEPRESS'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_DEPRESS = 1
	WHERE ICD9Code LIKE '311%'
		OR ICD9Code LIKE '309.0%'
		OR ICD9Code LIKE '309.1%'
		OR ICD9Code LIKE '301.12%'
		OR ICD9Code LIKE '300.4%'

 /***************DRUG ABUSE*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'DRUG ABUSE',
		Category = 'DRUG ABUSE',
		ColumnDescription = 'DRUG ABUSE',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_DRUG'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_DRUG = 1
	WHERE ICD9Code LIKE '292.0%'
			OR ICD9Code LIKE '304%'
			OR ICD9Code BETWEEN '292.82' AND '292.9'
			OR ICD9Code BETWEEN '305.2' AND '305.93'

 /***************FLUID AND ELECTROLYTE DISORDERS*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'FLUID AND ELECTROLYTE DISORDERS',
		Category = 'FLUID AND ELECTROLYTE DISORDERS',
		ColumnDescription = 'FLUID AND ELECTROLYTE DISORDERS',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9'
		AND ColumnName = 'EH_ELECTRLYTE';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_ELECTRLYTE = 1
    WHERE ICD9Code LIKE '276%'

 /***************CONG HEART FAILURE*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'CONG HEART FAILURE',
		Category = 'CONG HEART FAILURE',
		ColumnDescription = 'CONG HEART FAILURE',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9'
		AND ColumnName = 'EH_HEART'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_HEART = 1
 	WHERE ICD9Code LIKE '398.91%'
			OR ICD9Code LIKE '402.11%'
			OR ICD9Code LIKE '402.91%'
			OR ICD9Code LIKE '404.11%'
			OR ICD9Code LIKE '404.13%'
			OR ICD9Code LIKE '404.91%'
			OR ICD9Code LIKE '404.93%'
			OR ICD9Code LIKE '428%'


 /***************HYPERTENSION*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'HYPERTENSION',
		Category = 'HYPERTENSION',
		ColumnDescription = 'HYPERTENSION',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9'
		AND ColumnName = 'EH_HYPERTENS'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_HYPERTENS = 1
	WHERE ICD9Code LIKE '401.1%'
			OR ICD9Code LIKE '401.9%'
			OR ICD9Code LIKE '402.10%'
			OR ICD9Code LIKE '402.90%'
			OR ICD9Code LIKE '404.10%'
			OR ICD9Code LIKE '404.90%'
			OR ICD9Code LIKE '405.1%'
			OR ICD9Code LIKE '405.9%'

 /***************HYPOTHYROIDISM*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'HYPOTHYROIDISM',
		Category = 'HYPOTHYROIDISM',
		ColumnDescription = 'HYPOTHYROIDISM',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9'
		AND ColumnName = 'EH_HYPOTHY'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_HYPOTHY = 1
	WHERE ICD9Code BETWEEN '243' AND '244.2'
		OR ICD9Code BETWEEN '244.8' AND '244.9'
 
 /***********LIVER DISEASE*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'LIVER DISEASE',
		Category = 'LIVER DISEASE',
		ColumnDescription = 'LIVER DISEASE',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9'
		AND ColumnName = 'EH_LIVER'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_LIVER = 1
	WHERE ICD9Code LIKE '070.32%'
		OR ICD9Code LIKE '070.33%'
		OR ICD9Code LIKE '070.54%'
		OR ICD9Code LIKE '456.0%'
		OR ICD9Code LIKE '456.1%'
		OR ICD9Code LIKE '456.20%'
		OR ICD9Code LIKE '456.21%'
		OR ICD9Code LIKE '571.0%'
		OR ICD9Code LIKE '571.2%'
		OR ICD9Code LIKE '571.3%'
		OR ICD9Code LIKE '571.5%'
		OR ICD9Code LIKE '571.6%'
		OR ICD9Code LIKE '571.8%'
		OR ICD9Code LIKE '571.9%'
		OR ICD9Code LIKE '572.3%'
		OR ICD9Code LIKE '572.8%'
		OR ICD9Code LIKE 'V42.7%'
		OR ICD9Code BETWEEN '571.40' AND '571.49'

 /***********Lymphoma*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'LYMPHOMA',
		Category = 'LYMPHOMA',
		ColumnDescription = 'LYMPHOMA',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9'
		AND ColumnName = 'EH_Lymphoma'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_Lymphoma = 1
	WHERE ICD9Code LIKE '238.6%' 
		OR ICD9Code LIKE '273.3%' 
		OR ICD9Code BETWEEN '200%' AND '202.38%' 
		OR ICD9Code BETWEEN '202.50%' AND '203.01%'
		OR ICD9Code BETWEEN '203.8%' AND '203.81%' 
		OR ICD9Code LIKE 'V10.7%'		

  /***********METASTATIC CANCER*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'METASTATIC CANCER',
		Category = 'METASTATIC CANCER',
		ColumnDescription = 'METASTATIC CANCER',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9'
		AND ColumnName = 'EH_METCANCR'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_METCANCR = 1
	WHERE ICD9Code LIKE '196%'
		OR ICD9Code LIKE '197%'
		OR ICD9Code LIKE '198%'
		OR ICD9Code LIKE '199.0%'
		OR ICD9Code LIKE '199.1%'	
					
  /***********SOLID TUMOR WO METASTASIS*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'SOLID TUMOR WO METASTASIS',
		Category = 'SOLID TUMOR WO METASTASIS',
		ColumnDescription = 'SOLID TUMOR WO METASTASIS',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_NMETTUMR'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_NMETTUMR = 1
    WHERE ICD9Code LIKE '174%'
		OR ICD9Code LIKE '175%'
		OR ICD9Code LIKE 'V10%'
		OR ICD9Code BETWEEN '140.0%' AND '172.9%'
		OR ICD9Code BETWEEN '179' AND '195.8'

  /********************OBESITY*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'OBESITY',
		Category = 'OBESITY',
		ColumnDescription = 'OBESITY',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_OBESITY'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_OBESITY = 1
    WHERE ICD9Code LIKE '278.0%'	

  /********************Opioid Dependence (APM)*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Opioid Dependence',
		Category = 'Opioid Dependence',
		ColumnDescription = 'Opioid Dependence (APM)',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_OpiDep'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_OpiDep = 1
    WHERE ICD9Code LIKE '304.0%'
		OR ICD9Code LIKE '305.5%'
		OR ICD9Code LIKE '304.7%'


  /********************OTHER NEUROLOGICAL DISORDER*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'OTHER NEUROLOGICAL DISORDER',
		Category = 'OTHER NEUROLOGICAL DISORDER',
		ColumnDescription = 'OTHER NEUROLOGICAL DISORDER',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_OTHNEURO'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_OTHNEURO = 1
    WHERE ICD9Code LIKE '331.9%'
		OR ICD9Code LIKE '332.0%'
		OR ICD9Code LIKE '333.4%'
		OR ICD9Code LIKE '333.5%'
		OR ICD9Code LIKE '340%'
		OR ICD9Code LIKE '348.1%'
		OR ICD9Code LIKE '348.3%'
		OR ICD9Code LIKE '780.3%'
		OR ICD9Code LIKE '784.3%'
		OR ICD9Code BETWEEN '334.0' AND '335.99'
		OR ICD9Code BETWEEN '341.1' AND '341.99'
		OR ICD9Code BETWEEN '345.0' AND '345.11'
		OR ICD9Code BETWEEN '345.40' AND '345.51'
		OR ICD9Code BETWEEN '345.80' AND '345.91'

  /********************OTHER NEUROLOGICAL DISORDER*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'OTHER NEUROLOGICAL DISORDER',
		Category = 'OTHER NEUROLOGICAL DISORDER',
		ColumnDescription = 'OTHER NEUROLOGICAL DISORDER',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_OTHNEURO'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_OTHNEURO = 1
    WHERE ICD9Code LIKE '331.9%'
		OR ICD9Code LIKE '332.0%'
		OR ICD9Code LIKE '333.4%'
		OR ICD9Code LIKE '333.5%'
		OR ICD9Code LIKE '340%'
		OR ICD9Code LIKE '348.1%'
		OR ICD9Code LIKE '348.3%'
		OR ICD9Code LIKE '780.3%'
		OR ICD9Code LIKE '784.3%'
		OR ICD9Code BETWEEN '334.0' AND '335.99'
		OR ICD9Code BETWEEN '341.1' AND '341.99'
		OR ICD9Code BETWEEN '345.0' AND '345.11'
		OR ICD9Code BETWEEN '345.40' AND '345.51'
		OR ICD9Code BETWEEN '345.80' AND '345.91'	
				
/********************PARALYSIS*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'PARALYSIS',
		Category = 'PARALYSIS',
		ColumnDescription = 'PARALYSIS',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_PARALYSIS'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_PARALYSIS = 1
    	WHERE ICD9Code BETWEEN '342.0' AND '342.12'
			OR ICD9Code BETWEEN '342.9' AND '344.9'

/****************PEPTIC ULCER DISEASE-WO BLEEDING*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'PEPTIC ULCER DISEASE-WO BLEEDING',
		Category = 'PEPTIC ULCER DISEASE-WO BLEEDING',
		ColumnDescription = 'PEPTIC ULCER DISEASE-WO BLEEDING',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_PEPTICULC'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_PEPTICULC = 1
    WHERE ICD9Code LIKE '531.70%'
		OR ICD9Code LIKE '531.90%'
		OR ICD9Code LIKE '532.70%'
		OR ICD9Code LIKE '532.90%'
		OR ICD9Code LIKE '533.70%'
		OR ICD9Code LIKE '533.90%'
		OR ICD9Code LIKE '534.70%'
		OR ICD9Code LIKE '534.90%'
		OR ICD9Code LIKE 'V12.71%'		

/****************PERIPHERAL VASCULAR DISORDER*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'PERIPHERAL VASCULAR DISORDER',
		Category = 'PERIPHERAL VASCULAR DISORDER',
		ColumnDescription = 'PERIPHERAL VASCULAR DISORDER',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'EH_PERIVALV'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_PERIVALV = 1
	WHERE ICD9Code LIKE '441.2%'
		OR ICD9Code LIKE '441.4%'
		OR ICD9Code LIKE '441.7%'
		OR ICD9Code LIKE '441.9%'
		OR ICD9Code LIKE '447.1%'
		OR ICD9Code LIKE '557.1%'
		OR ICD9Code LIKE '557.9%'
		OR ICD9Code LIKE 'V43.4%'
		OR ICD9Code BETWEEN '440.0' AND '440.9'
		OR ICD9Code BETWEEN '443.1' AND '443.9'	
				
/****************PSYCHOSES*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'PSYCHOSES',
		Category = 'PSYCHOSES',
		ColumnDescription = 'PSYCHOSES',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' and  ColumnName = 'EH_PSYCHOSES';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_PSYCHOSES= 1
	WHERE ICD9Code LIKE '295%'
			OR ICD9Code LIKE '296%'
			OR ICD9Code LIKE '297%'
			OR ICD9Code LIKE '298%'
			OR ICD9Code LIKE '299.1%'	
			
/****************PULMONARY CIRCULATION DISORDER*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'PULMONARY CIRCULATION DISORDER',
		Category = 'PULMONARY CIRCULATION DISORDER',
		ColumnDescription = 'PULMONARY CIRCULATION DISORDER',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' and  ColumnName = 'EH_PULMCIRCS';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_PULMCIRC= 1
	WHERE ICD9Code LIKE '416%'
			OR ICD9Code LIKE '417.9%'
			
/****************RENAL FAILURE*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'RENAL IMPAIRMENT',
		Category = 'RENAL IMPAIRMENT',
		ColumnDescription = 'RENAL IMPAIRMENT',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' and  ColumnName = 'EH_RENAL';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_RENAL= 1
	WHERE ICD9Code LIKE '403.11%'
			OR ICD9Code LIKE '403.91%'
			OR ICD9Code LIKE '404.12%'
			OR ICD9Code LIKE '404.92%'
			OR ICD9Code LIKE '585%'
			OR ICD9Code LIKE '586%'
			OR ICD9Code LIKE 'V42.0%'
			OR ICD9Code LIKE 'V45.1%'
			OR ICD9Code LIKE 'V56.0%'
			OR ICD9Code LIKE 'V56.8%'		

/****************RHEUMATOID ARTHRITIS/COLLAGEN VASCULAR*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'RHEUMATOID ARTHRITIS/COLLAGEN VASCULAR',
		Category = 'RHEUMATOID ARTHRITIS/COLLAGEN VASCULAR',
		ColumnDescription = 'RHEUMATOID ARTHRITIS/COLLAGEN VASCULAR',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' and  ColumnName = 'EH_RHEUMART';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_RHEUMART= 1
  WHERE ICD9Code LIKE '701.0%'
			OR ICD9Code LIKE '710%'
			OR ICD9Code LIKE '714%'
			OR ICD9Code LIKE '720%'
			OR ICD9Code LIKE '725%'		

/****************Solid Tumor No metastasis EH*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Solid Tumor No metastasis EH',
		Category = 'Solid Tumor No metastasis EH',
		ColumnDescription = 'Solid Tumor No metastasis EH',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' and  ColumnName = 'EH_SolidTumorNoMet';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_SolidTumorNoMet= 1
	where ICD9Code like '174%' OR
			ICD9Code like '175%' OR
			 (ICD9Code BETWEEN '140%' and '172.9%') OR
			  (ICD9Code BETWEEN '179%' and '195.8%')	

/****************DIABETES - UNCOMPLICATED*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'DIABETES - UNCOMPLICATED',
		Category = 'DIABETES - UNCOMPLICATED',
		ColumnDescription = 'DIABETES - UNCOMPLICATED',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' and  ColumnName = 'EH_UNCDIAB';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_UNCDIAB = 1
	WHERE ICD9Code BETWEEN '250'
				AND '250.33'

/****************DIABETES - UNCOMPLICATED*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'DIABETES - UNCOMPLICATED',
		Category = 'DIABETES - UNCOMPLICATED',
		ColumnDescription = 'DIABETES - UNCOMPLICATED',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' and  ColumnName = 'EH_UNCDIAB';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_UNCDIAB = 1
	WHERE ICD9Code BETWEEN '250'
				AND '250.33'

/****************VALVULAR DISEASE*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'VALVULAR DISEASE',
		Category = 'VALVULAR DISEASE',
		ColumnDescription = 'VALVULAR DISEASE',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' and  ColumnName = 'EH_VALVDIS';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_VALVDIS = 1
		WHERE ICD9Code LIKE 'V42.2%'
			OR ICD9Code LIKE 'V43.3%'
			OR ICD9Code BETWEEN '093.20'
				AND '093.24'
			OR ICD9Code BETWEEN '394.0'
				AND '397.1'
			OR ICD9Code BETWEEN '424.0'
				AND '424.91'
			OR ICD9Code BETWEEN '746.3'
				AND '746.6'

/****************VALVULAR DISEASE*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'WEIGHT LOSS',
		Category = 'WEIGHT LOSS',
		ColumnDescription = 'WEIGHT LOSS',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' and  ColumnName = 'EH_WEIGHTLS';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET EH_WEIGHTLS = 1
		WHERE ICD9Code LIKE '260%'
			OR ICD9Code LIKE '261%'
			OR ICD9Code LIKE '262%'
			OR ICD9Code LIKE '263%'

/****************Homeless*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Homeless',
		Category = 'Homeless',
		ColumnDescription = 'Homeless',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' and  ColumnName = 'Homeless';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET Homeless = 1
	Where ICD9Code LIKE '%V60.0%'	
	
/****************Major Depressive Disorder*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Major Depressive Disorder',
		Category = 'Major Depressive Disorder',
		ColumnDescription = 'Major Depressive Disorder',
		DefinitionOwner = 'VISN21'
	WHERE TableName = 'ICD9' and  ColumnName = 'MDD';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET MDD = 1
	WHERE ICD9Code like '296.2%' or ICD9Code like '296.3%'	

/****************Medical indications for anti-depressants*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Medical indications for anti-depressants',
		Category = 'Medical indications for anti-depressants',
		ColumnDescription = 'Medical indications for anti-depressants',
		DefinitionOwner = 'OMHO'
	WHERE TableName = 'ICD9' and  ColumnName = 'MedIndAntiDepressant';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET MedIndAntiDepressant = 1
	WHERE (ICD9Code = '788.36')
			OR (ICD9Code = '053.12')
			OR (ICD9Code = '352.1')
			OR (ICD9Code = '780.51')
			OR (ICD9Code = '780.52')
			OR (ICD9Code LIKE '327.%')
			OR (ICD9Code LIKE '346.%')
			OR (ICD9Code = '307.81')
			OR (ICD9Code = '784.0')
			OR (ICD9Code LIKE '338.%')
			OR (ICD9Code = '780.96')
			OR (ICD9Code = '250.6')
			OR (
				ICD9Code BETWEEN '377.0'
					AND '337.19'
				)
			OR (ICD9Code LIKE '354.%')
			OR (ICD9Code = '350.2')
			OR (ICD9Code = '350.1')
			OR (
				ICD9Code BETWEEN '356'
					AND '357.99'
				)
			OR (ICD9Code LIKE '357%')
			OR (
				ICD9Code BETWEEN '140.0'
					AND '208.9'
				)
			OR (ICD9Code LIKE '377%')
			OR (ICD9Code LIKE '719.4%')
			OR --(vetted by IW 09/24/14) 
			(ICD9Code LIKE '729.2%')

/****************Medical Indications Benzodiazapines*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Medical Indications Benzodiazapines',
		Category = 'Medical Indications Benzodiazapines',
		ColumnDescription = 'Medical Indications Benzodiazapines',
		DefinitionOwner = 'OMHO'
	WHERE TableName = 'ICD9' and  ColumnName = 'MedIndBenzodiazepine';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET MedIndBenzodiazepine = 1
	WHERE (ICD9Code = '780.51')
			OR (ICD9Code = '780.52')
			OR (ICD9Code = '352.1')
			OR (ICD9Code = '728.85')
			OR (ICD9Code = '781.0')
			OR (ICD9Code LIKE '345.%')
		--	OR (ICD9Code LIKE '327.%')-- deleted per IW 9/11/15, adding specific 327s
			OR (ICD9Code LIKE '307.4%')
			OR ICD9Code in ('780.5', -- added per IW 9/11/15
				'780.55',
				'780.56',
				'780.59'
				) OR
				ICD9code in ('327',
				'327.01',
				'327.02',
				'327.09',
				'327.3',
				'327.31',
				'327.32',
				'327.33',
				'327.34',
				'327.35',
				'327.36',
				'327.37',
				'327.39',
				'327.42',
				'327.8')

/****************Any MH dx*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Any MH dx',
		Category = 'Any MH dx',
		ColumnDescription = 'Any MH dx as defined in Master file',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' and  ColumnName = 'MHSUDdx_poss';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET MHSUDdx_poss = 1
	WHERE    ICD9Code between '291' and '292.99'  or 
   ICD9Code between '295'   and  '298.99' or  /* includes major depression*/
   ICD9Code between '300.0' and  '300.49' or
   ICD9Code between '300.6' and  '301.99' or
   ICD9Code between '303' and '305.09' or   /*stricly less than 305.1*/
   ICD9Code between '305.2' and '305.99'  or /*305.99 is a bit safer than 305.9!*/
   ICD9Code LIKE 	'307.1%'	or
   ICD9Code LIKE 	'307.5%'	or
   ICD9Code between '308'   and  '309.99' or
   ICD9Code between '311'   and  '312.99' or
   ICD9Code LIKE 	'314%'	 
 
   
   
/****************Nicotine Diagnosis (for STORM model)*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Nicotine Diagnosis',
		Category = 'Nicotine Diagnosis',
		ColumnDescription = 'Nicotine Diagnosis',
		DefinitionOwner = 'ORM'
	WHERE TableName = 'ICD9' and  ColumnName = 'Nicdx_poss';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET Nicdx_poss = 1
	WHERE ICD9Code LIKE '305.1' 
		or ICD9Code LIKE '305.10' 
		or ICD9Code LIKE '305.11' 
		or ICD9Code LIKE '305.12'	  
		
		
/****************Opioid Overdose for OEND *************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Opioid Overdose',
		Category = 'Opioid Overdose',
		ColumnDescription = 'Opioid Overdose',
		DefinitionOwner = 'PERC'
	WHERE TableName = 'ICD9' and  ColumnName = 'OpioidOverdose';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET OpioidOverdose = 1
	WHERE ICD9Code LIKE '965.00'
			OR ICD9Code LIKE '965.01'
			OR ICD9Code LIKE '965.02'
			OR ICD9Code LIKE '965.09'
			OR ICD9Code LIKE 'E850.0%'
			OR ICD9Code LIKE 'E850.1%'
			OR ICD9Code LIKE 'E850.2%'
			OR ICD9Code LIKE 'E980.0%'
			OR ICD9Code LIKE 'E935.0%'
			OR ICD9Code LIKE 'E935.1%'
			OR ICD9Code LIKE 'E935.2%'	   
			
			
/****************Osteoporosis for ORM model computation *************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Osteoporosis',
		Category = 'Osteoporosis',
		ColumnDescription = 'Osteoporosis',
		DefinitionOwner = 'ORM'
	WHERE TableName = 'ICD9' and  ColumnName = 'Osteoporosis';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET Osteoporosis = 1
    WHERE ICD9Code LIKE '733.0%'  	
	
/****************other MH dx NO ptsd, dep or bipolar  for ORM *************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Other MH diagnosis',
		Category = 'Other MH diagnosis',
		ColumnDescription = 'other MH dx NO ptsd, dep or bipolar',
		DefinitionOwner = 'PERC'
	WHERE TableName = 'ICD9' and  ColumnName = 'OtherMH';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET OtherMH = 1
    WHERE  (ICD9Code between '295' and '298.99' and ICD9Code not in ('290.13'
    ,'290.21'
    ,'290.43'
    ,'293.83'
    ,'296.00'
    ,'296.01'
    ,'296.02'
    ,'296.03'
    ,'296.04'
    ,'296.05'
    ,'296.06'
    ,'296.10'
    ,'296.11'
    ,'296.12'
    ,'296.13'
    ,'296.14'
    ,'296.15'
    ,'296.16'
    ,'296.40'
    ,'296.41'
    ,'296.42'
    ,'296.43'
	,'296.44'
    ,'296.45'
    ,'296.46'
    ,'296.50'
    ,'296.51'
    ,'296.52'
    ,'296.53'
    ,'296.54'
    ,'296.55'
    ,'296.56'
    ,'296.60'
    ,'296.61'
    ,'296.62'
    ,'296.63'
    ,'296.64'
    ,'296.65'
    ,'296.66'
    ,'296.7'
    ,'296.80'
    ,'296.81'
    ,'296.89'
	,'296.20'
    ,'296.21'
    ,'296.22'
    ,'296.23'
    ,'296.24'
    ,'296.25'
    ,'296.26'
    ,'296.30'
    ,'296.31'
    ,'296.32'
    ,'296.33'
    ,'296.34'
    ,'296.35'
    ,'296.36'
    ,'296.82'
)) or
   (ICD9Code between '300.0' and  '300.49' and ICD9Code not in ('300.4'
    ,'309.1'
    ,'311.')) or
  ICD9Code between '300.6' and  '301.99'  or
   ICD9Code LIKE 	'307.1%'	or
   ICD9Code LIKE 	'307.5%'	or
   (ICD9Code between '308' and  '309.99' and ICD9Code not like '309.81') or
   ICD9Code between '311' and  '312.99' or
  ICD9Code LIKE 	'314%'								

/****************OTHER SUD no AUD no OUD no cannabis for ORM ************************
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Other SUD Diagnosis',
		Category = 'Other SUD Diagnosis',
		ColumnDescription = 'OTHER SUD no AUD no OUD no cannabis',
		DefinitionOwner = 'ORM'
	WHERE TableName = 'ICD9' and  ColumnName = 'OtherSUD';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET OtherSUD = 1
    WHERE ICD9Code In (
				'292.0',
'292.11',
'292.12',
'292.2',
'292.21',
'292.81',
'292.82',
'292.83',
'292.84',
'292.85',
'292.89',
'292.9',
'304.10',
'304.100',
'304.101',
'304.102',
'304.103',
'304.104',
'304.105',
'304.106',
'304.107',
'304.108',
'304.109',
'304.11',
'304.110',
'304.111',
'304.112',
'304.113',
'304.114',
'304.115',
'304.116',
'304.117',
'304.118',
'304.119',
'304.12',
'304.120',
'304.121',
'304.122',
'304.123',
'304.124',
'304.125',
'304.126',
'304.127',
'304.128',
'304.129',
'304.13',
'304.130',
'304.131',
'304.132',
'304.133',
'304.134',
'304.135',
'304.136',
'304.137',
'304.138',
'304.139',
'304.14',
'304.14',
'304.15',
'304.16',
'304.17',
'304.18',
'304.18',
'304.19',
'304.20',
'304.21',
'304.22',
'304.23',
'304.40',
'304.400',
'304.401',
'304.409',
'304.41',
'304.410',
'304.411',
'304.419',
'304.42',
'304.420',
'304.421',
'304.429',
'304.43',
'304.430',
'304.431',
'304.439',
'304.49',
'304.50',
'304.500',
'304.509',
'304.51',
'304.510',
'304.519',
'304.52',
'304.520',
'304.529',
'304.53',
'304.530',
'304.539',
'304.59',
'304.60',
'304.600',
'304.609',
'304.61',
'304.610',
'304.619',
'304.62',
'304.620',
'304.629',
'304.63',
'304.630',
'304.639',
'304.80',
'304.81',
'304.82',
'304.83',
'304.90',
'304.900',
'304.909',
'304.91',
'304.910',
'304.919',
'304.92',
'304.920',
'304.929',
'304.93',
'304.930',
'304.939',
'304.99',
'305.30',
'305.300',
'305.309',
'305.31',
'305.310',
'305.319',
'305.32',
'305.320',
'305.329',
'305.33',
'305.330',
'305.339',
'305.39',
'305.40',
'305.400',
'305.401',
'305.402',
'305.403',
'305.404',
'305.405',
'305.406',
'305.407',
'305.408',
'305.409',
'305.41',
'305.410',
'305.411',
'305.412',
'305.413',
'305.414',
'305.415',
'305.416',
'305.417',
'305.418',
'305.419',
'305.42',
'305.420',
'305.421',
'305.422',
'305.423',
'305.424',
'305.425',
'305.426',
'305.427',
'305.428',
'305.429',
'305.43',
'305.430',
'305.431',
'305.432',
'305.433',
'305.434',
'305.435',
'305.436',
'305.437',
'305.438',
'305.439',
'305.44',
'305.44',
'305.45',
'305.45',
'305.46',
'305.46',
'305.47',
'305.47',
'305.48',
'305.48',
'305.49',
'305.6',
'305.60',
'305.61',
'305.62',
'305.63',
'305.70',
'305.700',
'305.701',
'305.709',
'305.71',
'305.710',
'305.711',
'305.719',
'305.72',
'305.720',
'305.721',
'305.729',
'305.73',
'305.730',
'305.731',
'305.739',
'305.79',
'305.80',
'305.81',
'305.82',
'305.83',
'305.90',
'305.900',
'305.909',
'305.91',
'305.910',
'305.919',
'305.92',
'305.920',
'305.929',
'305.93',
'305.930',
'305.939',
'305.99'
)
*/

/****************Opiod Dependence Diagnosis for OAT Measure *************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Opioid Use Disorder',
		Category = 'Opioid Use Disorder',
		ColumnDescription = 'Opioid Use Disorder',
		DefinitionOwner = 'VISN21'
	WHERE TableName = 'ICD9' and  ColumnName = 'OUD';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET OUD = 1
    	WHERE ICD9Code LIKE '304.0%'
			OR ICD9Code LIKE '305.5%'
			OR ICD9Code LIKE '304.7%'  

/****************Panic Disorder *************************
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Panic Disorder',
		Category = 'Panic Disorder',
		ColumnDescription = 'Panic Disorder',
		DefinitionOwner = 'VISN21'
	WHERE TableName = 'ICD9' and  ColumnName = 'Panic';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET Panic = 1
    WHERE ICD9Code IN (
				'293.84'
				,'300.00'
				,'300.01'
				,'300.02'
				,'300.09'
				,'300.21'
				,'309.24'
				,'309.28'
				) 
*/

/****************Psychosis *************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Psychosis',
		Category = 'Psychosis',
		ColumnDescription = 'Psychosis',
		DefinitionOwner = 'VISN21'
	WHERE TableName = 'ICD9' and  ColumnName = 'Psych';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET Psych = 1
    WHERE ICD9Code IN (
				'290.11'
				,'290.12'
				,'290.20'
				,'290.3'
				,'290.41'
				,'290.42'
				,'290.8'
				,'290.9'
				,'292.11'
				,'293.0'
				,'293.1'
				,'293.81'
				,'293.82'
				,'293.83'
				,'294.9'
				,'296.04'
				,'296.14'
				,'296.34'
				,'296.40'
				,'296.41'
				,'296.42'
				,'296.44'
				,'296.54'
				,'296.64'
				,'296.90'
				,'296.99'
				,'297.0'
				,'297.1'
				,'297.2'
				,'297.3'
				,'297.8'
				,'297.9'
				,'298.0'
				,'298.1'
				,'298.2'
				,'298.3'
				,'298.4'
				,'298.8'
				,'298.9'
				,'300.6'
				,'301.0'
				,'301.20'
				,'301.22'
				,'301.3'
				,'301.83'
				,'301.89'
				,'301.9'
				,'780.1'
				)

/****************Any MH dx from IRA file for ORM risk computation *************************/
	-- updating definition information
	--UPDATE [LookUp].[ColumnDescriptions]
	--SET PrintName = 'Any MH diagnosis excluding SUD',
	--	Category = 'Any MH diagnosis',
	--	ColumnDescription = 'Any MH diagnosis excluding SUD',
	--	DefinitionOwner = 'IRA'
	--WHERE TableName = 'ICD9' and  ColumnName = 'Psych_poss';

	---- updating variable flag
	--UPDATE ##LookUp_ICD9_Stage
	--SET Psych_poss = 1
	--	WHERE  ICD9Code between '295' and '298.99' or
 --  ICD9Code between '300.0' and  '300.49' or
 --  ICD9Code between '300.6' and  '301.99'  or
 --  ICD9Code LIKE 	'307.1%'	or
 --  ICD9Code LIKE 	'307.5%'	or
 --  ICD9Code between '308' and  '309.99' or
 --  ICD9Code between '311' and  '312.99' or
 --  ICD9Code LIKE 	'314%' 

/****************Post Traumatic Stress Disorder *************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Post Traumatic Stress Disorder',
		Category = 'Post Traumatic Stress Disorder',
		ColumnDescription = 'Post Traumatic Stress Disorder',
		DefinitionOwner = 'IRA'
	WHERE TableName = 'ICD9' and  ColumnName = 'PTSD';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET PTSD = 1
	WHERE ICD9Code IN ('309.81')

/****************Serious Adverse Events - Acetaminophin*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Serious Adverse Events - Acetaminophen',
		Category = 'Serious Adverse Events - Acetaminophen',
		ColumnDescription = 'Serious Adverse Events - Acetaminophen',
		DefinitionOwner = 'OpioidMetrics'
	WHERE TableName = 'ICD9' and  ColumnName = 'SAE_Acet';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET SAE_Acet = 1
	WHERE ICD9Code IN ('965.4',
'E850.4',
'E935.4',
'967.0',
'967.8',
'968.0',
'969.1',
'969.2',
'969.3',
'969.4',
'969.5',
'E851.',
'E852.0',
'E852.1',
'E852.3',
'E852.4',
'E852.5',
'E852.8',
'E852.9',
'E853.0',
'E853.1',
'E853.2',
'E853.8',
'E853.9',
'E937.0',
'E937.8',
'E938.0',
'E939.1',
'E939.2',
'E939.4',
'E939.5',
'E980.1',
'E980.3'
	)

/****************Serious Adverse Events - Falls*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Serious Adverse Events - Falls',
		Category = 'Serious Adverse Events - Falls',
		ColumnDescription = 'Serious Adverse Events - Falls',
		DefinitionOwner = 'OpioidMetrics'
	WHERE TableName = 'ICD9' and  ColumnName = 'SAE_Falls';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET SAE_Falls = 1
	WHERE ICD9Code IN (
				'E888.'
				,'E880.0'
				,'E987.9'
				,'E888.9'
				,'E987.2'
				,'E882.'
				,'E883.9'
				,'E881.1'
				,'E885.1'
				,'E885.2'
				,'E888.0'
				,'E884.9'
				,'E884.2'
				,'E884.0'
				,'E987.0'
				,'E885.9'
				,'E884.3'
				,'E887.'
				,'E883.0'
				,'E885.4'
				,'E886.9'
				,'E885.'
				,'E883.2'
				,'E880.1'
				,'E880.9'
				,'E888.8'
				,'E885.3'
				,'E884.5'
				,'E886.0'
				,'E888.1'
				,'E884.1'
				,'E987.1'
				,'E884.6'
				,'E884.4'
				,'E929.3'
				,'E881.0'
				,'E885.0'
				,'E883.1'
				)

/****************Serious Adverse Events - Other Accidents*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Serious Adverse Events - Other Accidents',
		Category = 'Serious Adverse Events - Other Accidents',
		ColumnDescription = 'Serious Adverse Events - Other Accidents',
		DefinitionOwner = 'OpioidMetrics'
	WHERE TableName = 'ICD9' and  ColumnName = 'SAE_OtherAccident';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET SAE_OtherAccident = 1
	WHERE ICD9Code IN (
				'E920.4'
				,'E920.9'
				,'E922.5'
				,'E922.8'
				,'E985.6'
				,'E922.9'
				,'E919.5'
				,'E910.4'
				,'E985.7'
				,'E920.2'
				,'E919.0'
				,'E919.2'
				,'E922.3'
				,'E910.0'
				,'E920.3'
				,'E919.3'
				,'E920.5'
				,'E985.4'
				,'E922.0'
				,'E910.1'
				,'E920.8'
				,'E985.5'
				,'E985.3'
				,'E920.0'
				,'E910.2'
				,'E919.8'
				,'E922.1'
				,'E910.9'
				,'E985.2'
				,'E919.1'
				,'E922.4'
				,'E919.4'
				,'E985.1'
				,'E919.6'
				,'E910.3'
				,'E985.0'
				,'E920.1'
				,'E919.7'
				,'E986.'
				,'E919.9'
				,'E922.2'
				,'E910.8'
				)

/****************Serious Adverse Events - Other Drug*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Serious Adverse Events - Other Drug',
		Category = 'Serious Adverse Events - Other Drug',
		ColumnDescription = 'Serious Adverse Events - Other Drug',
		DefinitionOwner = 'OpioidMetrics'
	WHERE TableName = 'ICD9' and  ColumnName = 'SAE_OtherDrug';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET SAE_OtherDrug = 1
	WHERE ICD9Code IN (
				'E855.1'
				,'969.05'
				,'E855.0'
				,'E854.1'
				,'E935.6'
				,'E855.6'
				,'E939.7'
				,'E980.5'
				,'E935.3'
				,'969'
				,'E855.5'
				,'969.02'
				,'E850.3'
				,'E940.1'
				,'E980.4'
				,'E855.9'
				,'E939.0'
				,'965.1'
				,'E855.4'
				,'E854.0'
				,'969.6'
				,'965.69'
				,'970.1'
				,'E855.3'
				,'E939.6'
				,'969'
				,'969.09'
				,'969.01'
				,'965.6'
				,'969.72'
				,'969.03'
				,'E855.8'
				,'E855.2'
				,'965.61'
				,'E854.3'
				,'969.04'
				)

/****************Serious Adverse Events - Sedative*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Serious Adverse Events - Sedative',
		Category = 'Serious Adverse Events - Sedative',
		ColumnDescription = 'Serious Adverse Events - Sedative',
		DefinitionOwner = 'OpioidMetrics'
	WHERE TableName = 'ICD9' and  ColumnName = 'SAE_sed';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET SAE_sed = 1
	WHERE ICD9Code IN (
'967.0',
'967.8',
'968.0',
'969.1',
'969.2',
'969.3',
'969.4',
'969.5',
'E851.',
'E852.0',
'E852.1',
'E852.2',
'E852.3',
'E852.4',
'E852.5',
'E852.8',
'E852.9',
'E853.0',
'E853.1',
'E853.2',
'E853.8',
'E853.9',
'E937.0',
'E937.8',
'E938.0',
'E939.1',
'E939.2',
'E939.4',
'E939.5',
'E980.1',
'E980.2',
'E980.3'
	)

/****************Serious Adverse Events - Vehicle*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Serious Adverse Events - Vehicle',
		Category = 'Serious Adverse Events - Vehicle',
		ColumnDescription = 'Serious Adverse Events - Vehicle',
		DefinitionOwner = 'OpioidMetrics'
	WHERE TableName = 'ICD9' and  ColumnName = 'SAE_Vehicle';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET SAE_Vehicle = 1
	Where ICD9Code IN (
				'E836.9'
				,'E835.6'
				,'E842.6'
				,'E827.0'
				,'E833.7'
				,'E811.3'
				,'E820.3'
				,'E819.6'
				,'E825.4'
				,'E841.4'
				,'E830.2'
				,'E835.4'
				,'E815.4'
				,'E816.1'
				,'E818.6'
				,'E846.'
				,'E840.4'
				,'E827.8'
				,'E814.8'
				,'E929.0'
				,'E810.7'
				,'E817.2'
				,'E838.9'
				,'E823.5'
				,'E826.1'
				,'E833.3'
				,'E821.1'
				,'E816.6'
				,'E813.0'
				,'E844.7'
				,'E834.8'
				,'E817.8'
				,'E832.5'
				,'E843.8'
				,'E838.5'
				,'E833.1'
				,'E821.3'
				,'E811.0'
				,'E822.8'
				,'E824.5'
				,'E848.'
				,'E818.0'
				,'E805.3'
				,'E837.5'
				,'E806.8'
				,'E812.7'
				,'E831.2'
				,'E821.7'
				,'E813.6'
				,'E824.3'
				,'E844.5'
				,'E828.2'
				,'E814.3'
				,'E821.8'
				,'E838.6'
				,'E802.8'
				,'E836.1'
				,'E818.7'
				,'E836.6'
				,'E835.1'
				,'E828.9'
				,'E834.1'
				,'E802.2'
				,'E840.7'
				,'E817.5'
				,'E825.3'
				,'E841.5'
				,'E830.3'
				,'E825.9'
				,'E800.0'
				,'E829.4'
				,'E807.1'
				,'E840.1'
				,'E824.8'
				,'E818.1'
				,'E837.4'
				,'E810.4'
				,'E833.0'
				,'E838.2'
				,'E821.4'
				,'E817.9'
				,'E826.4'
				,'E812.3'
				,'E843.3'
				,'E811.5'
				,'E831.9'
				,'E832.0'
				,'E805.0'
				,'E830.7'
				,'E820.4'
				,'E843.5'
				,'E804.8'
				,'E820.6'
				,'E824.6'
				,'E836.4'
				,'E805.9'
				,'E820.1'
				,'E823.9'
				,'E834.0'
				,'E836.2'
				,'E800.9'
				,'E802.9'
				,'E814.2'
				,'E814.1'
				,'E833.9'
				,'E825.8'
				,'E836.7'
				,'E816.3'
				,'E828.8'
				,'E823.7'
				,'E826.9'
				,'E815.0'
				,'E842.9'
				,'E832.7'
				,'E817.4'
				,'E840.6'
				,'E800.1'
				,'E818.8'
				,'E830.0'
				,'E830.6'
				,'E824.9'
				,'E810.2'
				,'E825.2'
				,'E810.5'
				,'E807.0'
				,'E819.9'
				,'E838.1'
				,'E833.5'
				,'E811.4'
				,'E843.6'
				,'E804.3'
				,'E819.7'
				,'E806.0'
				,'E845.0'
				,'E844.3'
				,'E834.2'
				,'E813.8'
				,'E837.9'
				,'E821.9'
				,'E804.9'
				,'E812.9'
				,'E837.3'
				,'E818.9'
				,'E841.7'
				,'E828.4'
				,'E803.9'
				,'E801.9'
				,'E820.2'
				,'E834.3'
				,'E811.2'
				,'E833.8'
				,'E822.4'
				,'E829.8'
				,'E801.3'
				,'E827.3'
				,'E829.0'
				,'E801.1'
				,'E825.7'
				,'E814.7'
				,'E817.7'
				,'E816.4'
				,'E816.0'
				,'E823.4'
				,'E815.7'
				,'E823.2'
				,'E802.0'
				,'E840.3'
				,'E810.8'
				,'E817.1'
				,'E814.5'
				,'E830.1'
				,'E845.9'
				,'E826.2'
				,'E845.8'
				,'E825.1'
				,'E816.9'
				,'E819.4'
				,'E831.7'
				,'E832.2'
				,'E834.5'
				,'E813.1'
				,'E844.2'
				,'E838.4'
				,'E807.9'
				,'E833.2'
				,'E843.1'
				,'E804.0'
				,'E811.7'
				,'E805.2'
				,'E813.5'
				,'E813.7'
				,'E844.6'
				,'E844.8'
				,'E837.8'
				,'E837.2'
				,'E824.0'
				,'E806.9'
				,'E831.5'
				,'E842.7'
				,'E803.3'
				,'E814.4'
				,'E835.8'
				,'E836.0'
				,'E801.8'
				,'E803.8'
				,'E811.1'
				,'E820.5'
				,'E834.4'
				,'E829.9'
				,'E822.3'
				,'E810.0'
				,'E817.6'
				,'E816.7'
				,'E827.2'
				,'E833.4'
				,'E818.2'
				,'E815.8'
				,'E823.1'
				,'E807.2'
				,'E802.1'
				,'E825.0'
				,'E832.9'
				,'E841.6'
				,'E830.4'
				,'E840.0'
				,'E804.1'
				,'E819.3'
				,'E837.1'
				,'E816.8'
				,'E812.0'
				,'E807.8'
				,'E821.5'
				,'E838.3'
				,'E843.4'
				,'E831.8'
				,'E802.3'
				,'E806.2'
				,'E819.5'
				,'E824.7'
				,'E830.8'
				,'E805.1'
				,'E831.0'
				,'E803.2'
				,'E805.8'
				,'E820.9'
				,'E844.9'
				,'E813.2'
				,'E831.6'
				,'E836.3'
				,'E814.9'
				,'E820.0'
				,'E814.0'
				,'E835.5'
				,'E800.2'
				,'E818.3'
				,'E816.2'
				,'E841.1'
				,'E835.3'
				,'E815.5'
				,'E838.8'
				,'E810.6'
				,'E825.5'
				,'E810.3'
				,'E823.6'
				,'E811.9'
				,'E840.8'
				,'E819.2'
				,'E806.1'
				,'E815.2'
				,'E801.0'
				,'E832.4'
				,'E841.0'
				,'E834.7'
				,'E844.0'
				,'E807.3'
				,'E803.1'
				,'E822.7'
				,'E822.1'
				,'E837.0'
				,'E819.0'
				,'E812.4'
				,'E821.6'
				,'E843.9'
				,'E831.3'
				,'E826.0'
				,'E840.9'
				,'E813.9'
				,'E837.6'
				,'E822.5'
				,'E812.6'
				,'E813.4'
				,'E800.3'
				,'E836.5'
				,'E816.5'
				,'E814.6'
				,'E825.6'
				,'E841.2'
				,'E810.9'
				,'E815.6'
				,'E827.4'
				,'E835.2'
				,'E840.2'
				,'E838.7'
				,'E841.8'
				,'E835.0'
				,'E817.0'
				,'E818.4'
				,'E843.2'
				,'E812.2'
				,'E834.6'
				,'E820.7'
				,'E819.1'
				,'E826.3'
				,'E811.8'
				,'E832.1'
				,'E844.1'
				,'E843.0'
				,'E801.2'
				,'E811.6'
				,'E837.7'
				,'E822.6'
				,'E832.3'
				,'E824.1'
				,'E831.4'
				,'E812.5'
				,'E803.0'
				,'E842.8'
				,'E830.5'
				,'E836.8'
				,'E835.7'
				,'E841.9'
				,'E823.8'
				,'E822.0'
				,'E822.2'
				,'E828.0'
				,'E800.8'
				,'E840.5'
				,'E815.3'
				,'E815.1'
				,'E827.9'
				,'E817.3'
				,'E810.1'
				,'E818.5'
				,'E823.0'
				,'E832.8'
				,'E815.9'
				,'E841.3'
				,'E806.3'
				,'E804.2'
				,'E834.9'
				,'E823.3'
				,'E838.0'
				,'E833.6'
				,'E822.9'
				,'E821.2'
				,'E843.7'
				,'E826.8'
				,'E832.6'
				,'E812.1'
				,'E835.9'
				,'E819.8'
				,'E812.8'
				,'E831.1'
				,'E824.4'
				,'E821.0'
				,'E847.'
				,'E830.9'
				,'E813.3'
				,'E820.8'
				,'E824.2'
				,'E844.4'
				)

/****************Schizophrenia*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Schizophrenia',
		Category = 'Schizophrenia',
		ColumnDescription = 'Schizophrenia',
		DefinitionOwner = 'PERC'  --ST not sure if this is PERC?? 
	WHERE TableName = 'ICD9' and  ColumnName = 'Schiz';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET Schiz = 1
	WHERE ICD9Code LIKE '295%'
			AND ICD9Code NOT LIKE '295.5%' -- Vetted by Jodie Trafton and edited by ST on 3/28/14

/****************Sedate Issue *************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Sedate issue',
		Category = 'Sedate issue',
		ColumnDescription = 'Sedate issue',
		DefinitionOwner = 'OpioidMetrics'  
	WHERE TableName = 'ICD9' and  ColumnName = 'SedateIssue';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET SedateIssue = 1
	WHERE ICD9Code IN (
				'E855.1'
,'969.05'
,'E855.0'
,'E854.1'
,'E935.6'
,'E855.6'
,'E939.7'
,'E980.5'
,'E935.3'
,'969'
,'E855.5'
,'969.02'
,'E850.3'
,'E940.1'
,'E980.4'
,'E855.9'
,'E939.0'
,'965.1'
,'E855.4'
,'E854.0'
,'969.6'
,'965.69'
,'970.1'
,'E855.3'
,'E939.6'
,'969.09'
,'969.01'
,'965.6'
,'969.72'
,'969.03'
,'E855.8'
,'E855.2'
,'965.61'
,'E854.3'
,'969.04'
,'E888.'
,'E880.0'
,'E987.9'
,'E888.9'
,'E987.2'
,'E882.'
,'E883.9'
,'E881.1'
,'E885.1'
,'E885.2'
,'E888.0'
,'E884.9'
,'E884.2'
,'E884.0'
,'E987.0'
,'E885.9'
,'E884.3'
,'E887.'
,'E883.0'
,'E885.4'
,'E886.9'
,'E885.'
,'E883.2'
,'E880.1'
,'E880.9'
,'E888.8'
,'E885.3'
,'E884.5'
,'E886.0'
,'E888.1'
,'E884.1'
,'E987.1'
,'E884.6'
,'E884.4'
,'E929.3'
,'E881.0'
,'E885.0'
,'E883.1'
,'E920.4'
,'E920.9'
,'E922.5'
,'E922.8'
,'E985.6'
,'E922.9'
,'E919.5'
,'E910.4'
,'E985.7'
,'E920.2'
,'E919.0'
,'E919.2'
,'E922.3'
,'E910.0'
,'E920.3'
,'E919.3'
,'E920.5'
,'E985.4'
,'E922.0'
,'E910.1'
,'E920.8'
,'E985.5'
,'E985.3'
,'E920.0'
,'E910.2'
,'E919.8'
,'E922.1'
,'E910.9'
,'E985.2'
,'E919.1'
,'E922.4'
,'E919.4'
,'E985.1'
,'E919.6'
,'E910.3'
,'E985.0'
,'E920.1'
,'E919.7'
,'E986.'
,'E919.9'
,'E922.2'
,'E910.8'
,'E836.9'
,'E835.6'
,'E842.6'
,'E827.0'
,'E833.7'
,'E811.3'
,'E820.3'
,'E819.6'
,'E825.4'
,'E841.4'
,'E830.2'
,'E835.4'
,'E815.4'
,'E816.1'
,'E818.6'
,'E846.'
,'E840.4'
,'E827.8'
,'E814.8'
,'E929.0'
,'E810.7'
,'E817.2'
,'E838.9'
,'E823.5'
,'E826.1'
,'E833.3'
,'E821.1'
,'E816.6'
,'E813.0'
,'E844.7'
,'E834.8'
,'E817.8'
,'E832.5'
,'E843.8'
,'E838.5'
,'E833.1'
,'E821.3'
,'E811.0'
,'E822.8'
,'E824.5'
,'E848.'
,'E818.0'
,'E805.3'
,'E837.5'
,'E806.8'
,'E812.7'
,'E831.2'
,'E821.7'
,'E813.6'
,'E824.3'
,'E844.5'
,'E828.2'
,'E814.3'
,'E821.8'
,'E838.6'
,'E802.8'
,'E836.1'
,'E818.7'
,'E836.6'
,'E835.1'
,'E828.9'
,'E834.1'
,'E802.2'
,'E840.7'
,'E817.5'
,'E825.3'
,'E841.5'
,'E830.3'
,'E825.9'
,'E800.0'
,'E829.4'
,'E807.1'
,'E840.1'
,'E824.8'
,'E818.1'
,'E837.4'
,'E810.4'
,'E833.0'
,'E838.2'
,'E821.4'
,'E817.9'
,'E826.4'
,'E812.3'
,'E843.3'
,'E811.5'
,'E831.9'
,'E832.0'
,'E805.0'
,'E830.7'
,'E820.4'
,'E843.5'
,'E804.8'
,'E820.6'
,'E824.6'
,'E836.4'
,'E805.9'
,'E820.1'
,'E823.9'
,'E834.0'
,'E836.2'
,'E800.9'
,'E802.9'
,'E814.2'
,'E814.1'
,'E833.9'
,'E825.8'
,'E836.7'
,'E816.3'
,'E828.8'
,'E823.7'
,'E826.9'
,'E815.0'
,'E842.9'
,'E832.7'
,'E817.4'
,'E840.6'
,'E800.1'
,'E818.8'
,'E830.0'
,'E830.6'
,'E824.9'
,'E810.2'
,'E825.2'
,'E810.5'
,'E807.0'
,'E819.9'
,'E838.1'
,'E833.5'
,'E811.4'
,'E843.6'
,'E804.3'
,'E819.7'
,'E806.0'
,'E845.0'
,'E844.3'
,'E834.2'
,'E813.8'
,'E837.9'
,'E821.9'
,'E804.9'
,'E812.9'
,'E837.3'
,'E818.9'
,'E841.7'
,'E828.4'
,'E803.9'
,'E801.9'
,'E820.2'
,'E834.3'
,'E811.2'
,'E833.8'
,'E822.4'
,'E829.8'
,'E801.3'
,'E827.3'
,'E829.0'
,'E801.1'
,'E825.7'
,'E814.7'
,'E817.7'
,'E816.4'
,'E816.0'
,'E823.4'
,'E815.7'
,'E823.2'
,'E802.0'
,'E840.3'
,'E810.8'
,'E817.1'
,'E814.5'
,'E830.1'
,'E845.9'
,'E826.2'
,'E845.8'
,'E825.1'
,'E816.9'
,'E819.4'
,'E831.7'
,'E832.2'
,'E834.5'
,'E813.1'
,'E844.2'
,'E838.4'
,'E807.9'
,'E833.2'
,'E843.1'
,'E804.0'
,'E811.7'
,'E805.2'
,'E813.5'
,'E813.7'
,'E844.6'
,'E844.8'
,'E837.8'
,'E837.2'
,'E824.0'
,'E806.9'
,'E831.5'
,'E842.7'
,'E803.3'
,'E814.4'
,'E835.8'
,'E836.0'
,'E801.8'
,'E803.8'
,'E811.1'
,'E820.5'
,'E834.4'
,'E829.9'
,'E822.3'
,'E810.0'
,'E817.6'
,'E816.7'
,'E827.2'
,'E833.4'
,'E818.2'
,'E815.8'
,'E823.1'
,'E807.2'
,'E802.1'
,'E825.0'
,'E832.9'
,'E841.6'
,'E830.4'
,'E840.0'
,'E804.1'
,'E819.3'
,'E837.1'
,'E816.8'
,'E812.0'
,'E807.8'
,'E821.5'
,'E838.3'
,'E843.4'
,'E831.8'
,'E802.3'
,'E806.2'
,'E819.5'
,'E824.7'
,'E830.8'
,'E805.1'
,'E831.0'
,'E803.2'
,'E805.8'
,'E820.9'
,'E844.9'
,'E813.2'
,'E831.6'
,'E836.3'
,'E814.9'
,'E820.0'
,'E814.0'
,'E835.5'
,'E800.2'
,'E818.3'
,'E816.2'
,'E841.1'
,'E835.3'
,'E815.5'
,'E838.8'
,'E810.6'
,'E825.5'
,'E810.3'
,'E823.6'
,'E811.9'
,'E840.8'
,'E819.2'
,'E806.1'
,'E815.2'
,'E801.0'
,'E832.4'
,'E841.0'
,'E834.7'
,'E844.0'
,'E807.3'
,'E803.1'
,'E822.7'
,'E822.1'
,'E837.0'
,'E819.0'
,'E812.4'
,'E821.6'
,'E843.9'
,'E831.3'
,'E826.0'
,'E840.9'
,'E813.9'
,'E837.6'
,'E822.5'
,'E812.6'
,'E813.4'
,'E800.3'
,'E836.5'
,'E816.5'
,'E814.6'
,'E825.6'
,'E841.2'
,'E810.9'
,'E815.6'
,'E827.4'
,'E835.2'
,'E840.2'
,'E838.7'
,'E841.8'
,'E835.0'
,'E817.0'
,'E818.4'
,'E843.2'
,'E812.2'
,'E834.6'
,'E820.7'
,'E819.1'
,'E826.3'
,'E811.8'
,'E832.1'
,'E844.1'
,'E843.0'
,'E801.2'
,'E811.6'
,'E837.7'
,'E822.6'
,'E832.3'
,'E824.1'
,'E831.4'
,'E812.5'
,'E803.0'
,'E842.8'
,'E830.5'
,'E836.8'
,'E835.7'
,'E841.9'
,'E823.8'
,'E822.0'
,'E822.2'
,'E828.0'
,'E800.8'
,'E840.5'
,'E815.3'
,'E815.1'
,'E827.9'
,'E817.3'
,'E810.1'
,'E818.5'
,'E823.0'
,'E832.8'
,'E815.9'
,'E841.3'
,'E806.3'
,'E804.2'
,'E834.9'
,'E823.3'
,'E838.0'
,'E833.6'
,'E822.9'
,'E821.2'
,'E843.7'
,'E826.8'
,'E832.6'
,'E812.1'
,'E835.9'
,'E819.8'
,'E812.8'
,'E831.1'
,'E824.4'
,'E821.0'
,'E847.'
,'E830.9'
,'E813.3'
,'E820.8'
,'E824.2'
,'E844.4'
)

/****************Sedative Use Disorder*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Sedative Use Disorder',
		Category = 'Sedative Use Disorder',
		ColumnDescription = 'Sedative Use Disorder',
		DefinitionOwner = 'PERC'  --ST not sure if this is PERC?? 
	WHERE TableName = 'ICD9' and  ColumnName = 'SedativeUseDisorder';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET SedativeUseDisorder = 1
    WHERE ICD9Code like '304.1%'  or ICD9Code like '305.4%'


/****************Sleep Apnea*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Sleep Apnea',
		Category = 'Sleep Apnea',
		ColumnDescription = 'Sleep Apnea',
		DefinitionOwner = 'ORM'  
	WHERE TableName = 'ICD9' and  ColumnName = 'SleepApnea';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET SleepApnea = 1
    WHERE [ICD9Description] LIKE '%sleep apnea%'


/****************Serious Mental Illness*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Serious Mental Illness',
		Category = 'Serious Mental Illness',
		ColumnDescription = 'Serious Mental Illness',
		DefinitionOwner = 'ORM and same definition as  SMI_poss from Master File'  
	WHERE TableName = 'ICD9' and  ColumnName = 'SMI';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET SMI = 1
    WHERE (ICD9Code LIKE '295%' AND ICD9Code NOT LIKE '295.5%')
			OR ICD9Code BETWEEN '297' AND '298.99'
			OR ICD9Code BETWEEN '296.0' AND '296.19'
			OR ICD9Code BETWEEN '296.4' AND '296.89'


/****************SUD Dx without OUD and AUD for ORM*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'SUD diagnosis without AUD and OUD',
		Category = 'SUD diagnosis without AUD and OUD',
		ColumnDescription = 'SUD diagnosis without AUD and OUD',
		DefinitionOwner = 'ORM'  
	WHERE TableName = 'ICD9' and  ColumnName = 'SUD_NoOUD_NoAUD';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET SUD_NoOUD_NoAUD = 1
    WHERE ICD9Code In (
				'292.0',
'292.11',
'292.12',
'292.2',
'292.21',
'292.81',
'292.82',
'292.83',
'292.84',
'292.85',
'292.89',
'292.9',
'304.10',
'304.100',
'304.101',
'304.102',
'304.103',
'304.104',
'304.105',
'304.106',
'304.107',
'304.108',
'304.109',
'304.11',
'304.110',
'304.111',
'304.112',
'304.113',
'304.114',
'304.115',
'304.116',
'304.117',
'304.118',
'304.119',
'304.12',
'304.120',
'304.121',
'304.122',
'304.123',
'304.124',
'304.125',
'304.126',
'304.127',
'304.128',
'304.129',
'304.13',
'304.130',
'304.131',
'304.132',
'304.133',
'304.134',
'304.135',
'304.136',
'304.137',
'304.138',
'304.139',
'304.14',
'304.14',
'304.15',
'304.16',
'304.17',
'304.18',
'304.18',
'304.19',
'304.20',
'304.21',
'304.22',
'304.23',
'304.30',
'304.300',
'304.309',
'304.31',
'304.310',
'304.319',
'304.32',
'304.320',
'304.329',
'304.33',
'304.330',
'304.339',
'304.39',
'304.40',
'304.400',
'304.401',
'304.409',
'304.41',
'304.410',
'304.411',
'304.419',
'304.42',
'304.420',
'304.421',
'304.429',
'304.43',
'304.430',
'304.431',
'304.439',
'304.49',
'304.50',
'304.500',
'304.509',
'304.51',
'304.510',
'304.519',
'304.52',
'304.520',
'304.529',
'304.53',
'304.530',
'304.539',
'304.59',
'304.60',
'304.600',
'304.609',
'304.61',
'304.610',
'304.619',
'304.62',
'304.620',
'304.629',
'304.63',
'304.630',
'304.639',
'304.80',
'304.81',
'304.82',
'304.83',
'304.90',
'304.900',
'304.909',
'304.91',
'304.910',
'304.919',
'304.92',
'304.920',
'304.929',
'304.93',
'304.930',
'304.939',
'304.99',
'305.20',
'305.200',
'305.209',
'305.21',
'305.210',
'305.219',
'305.22',
'305.220',
'305.229',
'305.23',
'305.230',
'305.239',
'305.29',
'305.29',
'305.30',
'305.300',
'305.309',
'305.31',
'305.310',
'305.319',
'305.32',
'305.320',
'305.329',
'305.33',
'305.330',
'305.339',
'305.39',
'305.40',
'305.400',
'305.401',
'305.402',
'305.403',
'305.404',
'305.405',
'305.406',
'305.407',
'305.408',
'305.409',
'305.41',
'305.410',
'305.411',
'305.412',
'305.413',
'305.414',
'305.415',
'305.416',
'305.417',
'305.418',
'305.419',
'305.42',
'305.420',
'305.421',
'305.422',
'305.423',
'305.424',
'305.425',
'305.426',
'305.427',
'305.428',
'305.429',
'305.43',
'305.430',
'305.431',
'305.432',
'305.433',
'305.434',
'305.435',
'305.436',
'305.437',
'305.438',
'305.439',
'305.44',
'305.44',
'305.45',
'305.45',
'305.46',
'305.46',
'305.47',
'305.47',
'305.48',
'305.48',
'305.49',
'305.6',
'305.60',
'305.61',
'305.62',
'305.63',
'305.70',
'305.700',
'305.701',
'305.709',
'305.71',
'305.710',
'305.711',
'305.719',
'305.72',
'305.720',
'305.721',
'305.729',
'305.73',
'305.730',
'305.731',
'305.739',
'305.79',
'305.80',
'305.81',
'305.82',
'305.83',
'305.90',
'305.900',
'305.909',
'305.91',
'305.910',
'305.919',
'305.92',
'305.920',
'305.929',
'305.93',
'305.930',
'305.939',
'305.99'
)

/****************SUD no AUD no OUD no cannabis no hallucinogen no stimulant no Cocaine no Sed for ORM ST 12/7/15******************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Other SUD Diagnosis',
		Category = 'Other SUD Diagnosis',
		ColumnDescription = 'OTHER SUD no AUD no OUD no cannabis UD no hallucinogen UD no stimulant UD
		no cocaine UD, includes abuse and dependence of: OTHER SPECIFIED DRUG,PHENCYCLIDINE (PCP), 
		COMBINATIONS OF DRUG DEPENDENCE EXCLUDING OPIOID TYPE DRUG, UNSPECIFIED DRUG, 
		ANTIDEPRESSANT TYPE, OTHER, MIXED, OR UNSPECIFIED DRUG ABUSE,OTHER MIXED/UNSPEC DRUG ABUSE',
		DefinitionOwner = 'ORM'
	WHERE TableName = 'ICD9' and  ColumnName = 'OtherSUD_RiskModel';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET OtherSUD_RiskModel = 1
    WHERE ICD9Code In (
--'292.0',
--'292.11',
--'292.12',  
--'292.2',
--'292.21',
--'292.81',
--'292.82',
--'292.83',
--'292.84',
--'292.85',
--'292.89',
--'292.9',
--'304.10',
--'304.100',
--'304.101',
--'304.102',
--'304.103',
--'304.104',
--'304.105',
--'304.106',
--'304.107',
--'304.108',
--'304.109',
--'304.11',
--'304.110',
--'304.111',
--'304.112',
--'304.113',
--'304.114',
--'304.115',
--'304.116',
--'304.117',
--'304.118',
--'304.119',
--'304.12',
--'304.120',
--'304.121',
--'304.122',
--'304.123',
--'304.124',
--'304.125',
--'304.126',
--'304.127',
--'304.128',
--'304.129',
--'304.13',
--'304.130',
--'304.131',
--'304.132',
--'304.133',
--'304.134',
--'304.135',
--'304.136',
--'304.137',
--'304.138',
--'304.139',
--'304.14',
--'304.14',
--'304.15',
--'304.16',
--'304.17',
--'304.18',
--'304.18',
--'304.19',
'304.60',
'304.600',
'304.609',
'304.61',
'304.610',
'304.619',
'304.62',
'304.620',
'304.629',
'304.63',
'304.630',
'304.639',
'304.80',
'304.81',
'304.82',
'304.83',
'304.90',
'304.900',
'304.909',
'304.91',
'304.910',
'304.919',
'304.92',
'304.920',
'304.929',
'304.93',
'304.930',
'304.939',
'304.99',
--'305.40',
--'305.400',
--'305.401',
--'305.402',
--'305.403',
--'305.404',
--'305.405',
--'305.406',
--'305.407',
--'305.408',
--'305.409',
--'305.41',
--'305.410',
--'305.411',
--'305.412',
--'305.413',
--'305.414',
--'305.415',
--'305.416',
--'305.417',
--'305.418',
--'305.419',
--'305.42',
--'305.420',
--'305.421',
--'305.422',
--'305.423',
--'305.424',
--'305.425',
--'305.426',
--'305.427',
--'305.428',
--'305.429',
--'305.43',
--'305.430',
--'305.431',
--'305.432',
--'305.433',
--'305.434',
--'305.435',
--'305.436',
--'305.437',
--'305.438',
--'305.439',
--'305.44',
--'305.44',
--'305.45',
--'305.45',
--'305.46',
--'305.46',
--'305.47',
--'305.47',
--'305.48',
--'305.48',
--'305.49',
'305.80',
'305.81',
'305.82',
'305.83',
'305.90',
'305.900',
'305.909',
'305.91',
'305.910',
'305.919',
'305.92',
'305.920',
'305.929',
'305.93',
'305.930',
'305.939',
'305.99'
)

/***************SUD Diagnosis*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'SUD Diagnosis',
		Category = 'SUD Diagnosis',
		ColumnDescription = 'SUD Diagnosis',
		DefinitionOwner = 'IRA'  
	WHERE TableName = 'ICD9' and  ColumnName = 'SUDdx_poss';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET SUDdx_poss = 1
    WHERE ICD9Code BETWEEN '291'
				AND '292.99'
			OR ICD9Code BETWEEN '303'
				AND '305.09'
			OR ICD9Code BETWEEN '305.2'
				AND '305.999'


/***************Suicide*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Suicide',
		Category = 'Suicide',
		ColumnDescription = 'Suicide',
		DefinitionOwner = 'OpioidMetrics'  
	WHERE TableName = 'ICD9' and  ColumnName = 'Suicide';

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET Suicide = 1
  WHERE ICD9Code IN (
'E988.3',
'E951.11',
'E951.01',
'E951.82',
'E958.82',
'E957.91',
'E951.8',
'E952.12',
'E950.72',
'E950.2',
'E950.62',
'E950.31',
'E980.8',
'E950.21',
'E958.32',
'E957.1',
'E988.9',
'E958.3',
'E959.',
'E958.7',
'E982.0',
'E955.52',
'E950.71',
'E950.82',
'E958.52',
'E952.81',
'E951.1',
'E950.1',
'E957.92',
'E958.61',
'E953.11',
'E958.81',
'E982.1',
'E952.9',
'E950.9',
'E954.1',
'E953.9',
'E955.22',
'E954.',
'E950.02',
'E988.4',
'E958.0',
'E981.8',
'E955.5',
'E957.9',
'E953.12',
'E951.0',
'E956.1',
'E981.0',
'E955.1',
'E958.42',
'E950.4',
'E983.9',
'E982.8',
'E983.0',
'E958.22',
'E950.92',
'E958.02',
'E958.1',
'E951.81',
'E988.7',
'E953.01',
'E953.1',
'E951.12',
'E983.1',
'E957.01',
'E957.22',
'E955.0',
'E955.01',
'E984.',
'E950.51',
'E950.22',
'E982.9',
'E953.82',
'E952.11',
'E988.0',
'E952.0',
'E958.8',
'E950.12',
'E956.',
'E957.2',
'E988.2',
'E955.32',
'E955.7',
'E955.51',
'E957.02',
'E958.6',
'E952.82',
'V62.84',
'E950.6',
'E955.02',
'E953.81',
'E955.41',
'E950.8',
'E958.11',
'E958.9',
'E953.8',
'E955.6',
'E950.3',
'E955.2',
'E956.2',
'E952.92',
'E955.3',
'E958.31',
'E952.01',
'E955.42',
'E958.41',
'E950.5',
'E958.4',
'E988.8',
'E957.0',
'E950.81',
'E958.01',
'E950.91',
'E950.52',
'E955.9',
'E957.21',
'E958.51',
'E950.0',
'E958.62',
'E952.91',
'E950.42',
'E958.72',
'E952.02',
'E955.11',
'E980.6',
'E952.8',
'E957.12',
'E988.1',
'E950.01',
'E955.21',
'E954.2',
'E958.5',
'E953.0',
'E950.11',
'E952.1',
'E988.5',
'E951.02',
'E955.31',
'E981.1',
'E958.71',
'E950.41',
'E955.4',
'E950.61',
'E955.12',
'E950.7',
'E958.12',
'E950.32',
'E983.8',
'E958.21',
'E953.02',
'E988.6',
'E957.11',
'E958.2'
)

	/*** Any suicide attempt**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Any suicide attempt',
		Category = 'Attempt',
		ColumnDescription = 'definition taken from PWC code [ETL].[RUN_ICD9Factors] in VACI_IRDS - keeping same variable name' ,             
		DefinitionOwner = 'PWC'
	WHERE TableName = 'ICD9' 
		AND  ColumnName = 'REACH_attempt'
     
	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
    SET REACH_attempt=1
    WHERE  ICD9Code LIKE 'E95%' 

	/*** Arthritis **************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Arthritis',
		Category = 'Arthritis',
		ColumnDescription = 'definition taken from PWC code [ETL].[RUN_ICD9Factors] in VACI_IRDS - keeping same variable name' ,             
		DefinitionOwner = 'PWC'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'REACH_arth'
     
	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET REACH_arth =1
	WHERE (ICD9Code >= '710.0' AND ICD9Code < '720.0') 
		OR (ICD9Code >= '725.' AND ICD9Code < '740.0') 

	/*** Bipolar **************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Bipolar I',
		Category = 'Bipolar I',
		ColumnDescription = 'definition taken from PWC code [ETL].[RUN_ICD9Factors] in VACI_IRDS - keeping same variable name',              
		DefinitionOwner = 'PWC'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'REACH_bipoli'
     
	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
    SET  REACH_bipoli=1
    WHERE (ICD9Code LIKE '296.0%') 
		OR (ICD9Code LIKE '296.1%') 
		OR (ICD9Code LIKE '296.4%') 
		OR (ICD9Code LIKE '296.5%') 
		OR (ICD9Code LIKE '296.6%') 
		OR (ICD9Code LIKE '296.7%') 

	/*** 'cancer of the head/neck region'**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'cancer of the head/neck region',
		Category = 'head cancer',
		ColumnDescription = 'definition taken from PWC code [ETL].[RUN_ICD9Factors] in VACI_IRDS - keeping same variable name',              
		DefinitionOwner = 'PWC'
	WHERE TableName = 'ICD9' and  ColumnName = 'REACH_ca_head'
     
	 -- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
    SET REACH_ca_head=1
    WHERE  (ICD9Code LIKE '141%') 
		OR (ICD9Code LIKE '143%') 
		OR (ICD9Code LIKE '145%') 
		OR (ICD9Code LIKE '146%') 
		OR (ICD9Code LIKE '147%') 
		OR (ICD9Code LIKE '148%') 
		OR (ICD9Code LIKE '160%') 
		OR (ICD9Code LIKE '161%') 
		OR (ICD9Code LIKE '170%') 
		OR (ICD9Code LIKE '192%') 
		OR (ICD9Code LIKE '140.3%') 
		OR (ICD9Code LIKE '140.4%') 
		OR (ICD9Code LIKE '140.6%') 
		OR (ICD9Code LIKE '140.9%') 
		OR (ICD9Code LIKE '141.1%') 
		OR (ICD9Code LIKE '141.2%') 
		OR (ICD9Code LIKE '141.3%') 
		OR (ICD9Code LIKE '141.9%') 
		OR (ICD9Code LIKE '143.1%') 
		OR (ICD9Code LIKE '143.9%') 
		OR (ICD9Code LIKE '144.9%') 
		OR (ICD9Code LIKE '145.2%') 
		OR (ICD9Code LIKE '145.3%') 
		OR (ICD9Code LIKE '145.4%') 
		OR (ICD9Code LIKE '145.6%') 
		OR (ICD9Code LIKE '146.2%') 
		OR (ICD9Code LIKE '146.3%') 
		OR (ICD9Code LIKE '146.4%') 
		OR (ICD9Code LIKE '146.6%') 
		OR (ICD9Code LIKE '146.7%') 
		OR (ICD9Code LIKE '146.9%') 
		OR (ICD9Code LIKE '147.1%') 
		OR (ICD9Code LIKE '147.2%') 
		OR (ICD9Code LIKE '147.9%') 
		OR (ICD9Code LIKE '148.1%') 
		OR (ICD9Code LIKE '148.3%') 
		OR (ICD9Code LIKE '148.9%') 
		OR (ICD9Code LIKE '150.9%') 
		OR (ICD9Code LIKE '160.1%') 
		OR (ICD9Code LIKE '160.2%') 
		OR (ICD9Code LIKE '160.3%') 
		OR (ICD9Code LIKE '160.4%') 
		OR (ICD9Code LIKE '160.5%') 
		OR (ICD9Code LIKE '160.9%') 
		OR (ICD9Code LIKE '161.1%') 
		OR (ICD9Code LIKE '161.2%') 
		OR (ICD9Code LIKE '161.3%') 
		OR (ICD9Code LIKE '170.1%') 
		OR (ICD9Code LIKE '190.1%') 

	/*** 'Chronic Pain'**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Chronic Pain',
		Category = 'Chronic Pain',
		ColumnDescription = 'definition taken from PWC code [ETL].[RUN_ICD9Factors] in VACI_IRDS - keeping same variable name',              
		DefinitionOwner = 'PWC'
	WHERE TableName = 'ICD9' 
		AND  ColumnName = 'REACH_chronic';
     
  -- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
    SET REACH_chronic=1
    WHERE  (ICD9Code LIKE '338.0%') 
		OR (ICD9Code LIKE '338.2%') 
		OR (ICD9Code LIKE '338.4%')   

	/*** Depression**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Depression',
		Category = 'Depression',
		ColumnDescription = 'definition taken from PWC code [ETL].[RUN_ICD9Factors] in VACI_IRDS - keeping same variable name',              
		DefinitionOwner = 'PWC'
	WHERE TableName = 'ICD9' 
		AND  ColumnName = 'REACH_dep'
     
	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
    SET REACH_dep=1
    WHERE  (ICD9Code LIKE '293.83%') 
		OR (ICD9Code LIKE '296.2%') 
		OR (ICD9Code LIKE '296.3%') 
		OR (ICD9Code LIKE '296.90%') 
		OR (ICD9Code LIKE '296.99%') 
		OR (ICD9Code LIKE '298.0%') 
		OR (ICD9Code LIKE '300.4%') 
		OR (ICD9Code LIKE '301.12%') 
		OR (ICD9Code LIKE '309.0%') 
		OR (ICD9Code LIKE '309.1%') 
		OR (ICD9Code LIKE '311%') 

	/*** Diabetes**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Diabetes Melitus',
		Category = 'Diabetes Melitus',
		ColumnDescription = 'definition taken from PWC code [ETL].[RUN_ICD9Factors] in VACI_IRDS - keeping same variable name',              
		DefinitionOwner = 'PWC'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'REACH_dm'
     
	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
    SET REACH_dm=1
    WHERE  (ICD9Code LIKE '250%') 
		OR (ICD9Code LIKE '357.2%') 
		OR (ICD9Code LIKE '362.0%') 
		OR (ICD9Code LIKE '366.41%') 

	/*** Lupus and similar**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Systemic Lupus Erythematosus and other connective tissue disorders'
		,Category = 'Systemic Lupus Erythematosus'
		,ColumnDescription = 'definition taken from PWC code [ETL].[RUN_ICD9Factors] in VACI_IRDS - keeping same variable name'
		,DefinitionOwner = 'PWC'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'REACH_sle'
     
	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET REACH_sle=1
	WHERE ICD9Code LIKE '710%' 

	/*** Substance use disorder**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Substance use disorder',
		Category = 'substance use disorder',
		ColumnDescription = 'definition taken from PWC code [ETL].[RUN_ICD9Factors] in VACI_IRDS - keeping same variable name',              
		DefinitionOwner = 'PWC'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'REACH_sud'
     
	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET REACH_sud=1
	WHERE (ICD9Code LIKE '291%') 
		OR (ICD9Code LIKE '292%')
		OR (ICD9Code LIKE '303.0%') 
		OR (ICD9Code LIKE '303.9%') 
		OR (ICD9Code LIKE '304.2%') 
		OR (ICD9Code LIKE '304.0%') 
		OR (ICD9Code LIKE '304.7%') 
		OR (ICD9Code LIKE '304.3%') 
		OR (ICD9Code LIKE '304.1%') 
		OR (ICD9Code LIKE '304.4%') 
		OR (ICD9Code LIKE '304.5%') 
		OR (ICD9Code LIKE '304.6%') 
		OR (ICD9Code LIKE '304.8%') 
		OR (ICD9Code LIKE '304.9%') 
		OR (ICD9Code LIKE '305.0%') 
		OR (ICD9Code LIKE '305.6%') 
		OR (ICD9Code LIKE '305.5%') 
		OR (ICD9Code LIKE '305.2%') 
		OR (ICD9Code LIKE '305.3%') 
		OR (ICD9Code LIKE '305.4%') 
		OR (ICD9Code LIKE '305.7%') 
		OR (ICD9Code LIKE '305.8%') 
		OR (ICD9Code LIKE '305.9%') 

   /***************Reach Other Anxiety Disorder*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Other Anxiety Disorder',
		Category = 'Other Anxiety Disorder',
		ColumnDescription = 'definition taken from SMITREC data dictionary for Perceptive Reach keeping same variable name',              
		DefinitionOwner = 'PWC'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'Reach_othanxdis'

	-- updating variable flag
		-- taken from data dictionary Claire is maintaining 10/18/16
	UPDATE ##LookUp_ICD9_Stage
	SET Reach_othanxdis = 1
	WHERE ICD9Code IN (
		'300.00','300.01','300.02' 
		,'300.09' 
		,'300.10' 
		,'300.20','300.21','300.22','300.23' 
		,'300.29'
		)

   /***************Reach Other Anxiety Disorder*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Personality Disorder',
	Category = 'Personality Disorder',
	ColumnDescription = 'definition taken from SMITREC data dictionary for Perceptive Reach keeping same variable name',              
	DefinitionOwner = 'SMITREC'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'Reach_persond'

	-- updating variable flag
		-- taken from data dictionary Claire is maintaining 10/18/16
	UPDATE ##LookUp_ICD9_Stage
	SET Reach_persond = 1
	WHERE ICD9Code IN (
		'301.0' 
		,'301.20' 
		,'301.22' 
		,'301.4'
		,'301.50' 
		,'301.6' 
		,'301.7' 
		,'301.81','301.82','301.83' 
		,'301.9'
		)

	/*** Chronic Respiratory Diseases**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Chronic Respiratory Diseases',
		Category = 'Chronic Respiratory Diseases',
		ColumnDescription = 'Chronic Respiratory Diseases - includes COPD and Sleep Apnea ',              
		DefinitionOwner = 'AD/PERC'
	WHERE TableName = 'ICD9' 
		AND  ColumnName = 'ChronicResp_Dx'
     
	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET ChronicResp_Dx = 1
	WHERE ICD9Code LIKE '491.2%'
		OR ICD9Description LIKE '%sleep apnea%'

	/***Menopausal Disorder**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Menopausal disorder',
		Category = 'Reproductive health',
		ColumnDescription = 'Menopausal disorder, definition from WHEI',             
		DefinitionOwner = 'WHEI'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'WRV_MenopausalDisorder'
 
	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET  WRV_MenopausalDisorder=1
	WHERE ICD9code in (
		'256.2','256.3'
		,'256.31','256.39'
		,'256.8','256.9'
		,'624.1'
		,'627.0','627.1','627.2','627.3','627.4'
		,'627.8','627.9'
		,'V07.4'
		,'V49.81'
		)

	/***Menstrual Disorder**************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Menstrual disorder'
		,Category = 'Reproductive health'
		,ColumnDescription = 'Menstrual disorder, definition from WHEI'
		,DefinitionOwner = 'WHEI'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'WRV_MenstrualDisorder'
 
	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET  WRV_MenstrualDisorder=1
	WHERE ICD9code IN (
		'625.2','625.3','625.4'
		,'626.0','626.1','626.2','626.3','626.4','626.5','626.6'
		,'626.8','626.9')

	/***NonViable Pregnancy**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Non-viable pregnancy',
        Category = 'Reproductive health',
        ColumnDescription = 'Non-viable pregnancy (miscarriage, ectopic), definition from WHEI',             
		DefinitionOwner = 'WHEI'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'WRV_NonViablePregnancy'
 
	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
    SET  WRV_NonViablePregnancy=1
	WHERE ICD9code IN (
		'632.'

		,'633.0','633.00','633.01'
		,'633.1','633.10','633.11'
		,'633.2','633.20','633.21'
		,'633.8','633.80','633.81'
		,'633.9','633.90','633.91'

		,'634.00','634.01','634.02'
		,'634.10','634.11','634.12'
		,'634.20','634.21','634.22'
		,'634.30','634.31','634.32'
		,'634.40','634.41','634.42'
		,'634.50','634.51','634.52'
		,'634.60','634.61','634.62'
		,'634.70','634.71','634.72'
		,'634.80','634.81','634.82'
		,'634.90','634.91','634.92'

		,'639.0','639.1','639.2','639.3','639.4','639.5','639.6'
		,'639.8','639.9'
		)

	/***Pregnancy**************/
 	-- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Pregnancy',
        Category = 'Reproductive health',
        ColumnDescription = 'Viable pregnancy',             
		DefinitionOwner = 'WHEI'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'WRV_Pregnancy'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET  WRV_Pregnancy=1
	WHERE ICD9code IN ( 
		'622.5'
		,'630.'
		,'631.','631.0','631.8'

		,'640.00','640.01','640.03'
		,'640.80','640.81','640.83'
		,'640.90','640.91','640.93'
		
		,'641.00','641.01','641.03'
		,'641.10','641.11','641.13'
		,'641.20','641.21','641.23'
		,'641.30','641.31','641.33'
		,'641.80','641.81','641.83'
		,'641.90','641.91','641.93'
		
		,'642.00','642.01','642.02','642.03','642.04'
		,'642.10','642.11','642.12','642.13','642.14'
		,'642.20','642.21','642.22','642.23','642.24'
		,'642.30','642.31','642.32','642.33','642.34'
		,'642.40','642.41','642.42','642.43','642.44'
		,'642.50','642.51','642.52','642.53','642.54'
		,'642.60','642.61','642.62','642.63','642.64'
		,'642.70','642.71','642.72','642.73','642.74'
		,'642.90','642.91','642.92','642.93','642.94'

		,'643.00','643.01','643.03'
		,'643.10','643.11','643.13'
		,'643.20','643.21','643.23'
		,'643.80','643.81','643.83'
		,'643.90','643.91','643.93'
		
		,'644.00','644.03'
		,'644.10','644.13'
		,'644.20','644.21'
		
		,'645.00','645.01','645.03'
		,'645.10','645.11','645.13'
		,'645.20','645.21','645.23'
		
		,'646.00','646.01','646.03'
		,'646.10','646.11','646.12','646.13','646.14'
		,'646.20','646.21','646.22','646.23','646.24'
		,'646.30','646.31','646.33'
		,'646.40','646.41','646.42','646.43','646.44'
		,'646.50','646.51','646.52','646.53','646.54'
		,'646.60','646.61','646.62','646.63','646.64'
		,'646.80','646.81','646.82','646.83','646.84'
		,'646.70','646.71','646.73'
		,'646.90','646.91','646.93'
		
		,'647.00','647.01','647.02','647.03','647.04'
		,'647.10','647.11','647.12','647.13','647.14'
		,'647.20','647.21','647.22','647.23','647.24'
		,'647.30','647.31','647.32','647.33','647.34'
		,'647.40','647.41','647.42','647.43','647.44'
		,'647.50','647.51','647.52','647.53','647.54'
		,'647.60','647.61','647.62','647.63','647.64'
		,'647.80','647.81','647.82','647.83','647.84'
		,'647.90','647.91','647.92','647.93','647.94'

		,'648.00','648.01','648.02','648.03','648.04'		
		,'648.10','648.11','648.12','648.13','648.14'
		,'648.20','648.21','648.22','648.23','648.24'
		,'648.30','648.31','648.32','648.33','648.34'
		,'648.40','648.41','648.42','648.43','648.44'
		,'648.50','648.51','648.52','648.53','648.54'
		,'648.60','648.61','648.62','648.63','648.64'
		,'648.70','648.71','648.72','648.73','648.74'
		,'648.80','648.81','648.82','648.83','648.84'
		,'648.90','648.91','648.92','648.93','648.94'
		
		,'649.00','649.01','649.02','649.03','649.04'
		,'649.10','649.11','649.12','649.13','649.14'
		,'649.20','649.21','649.22','649.23','649.24'
		,'649.30','649.31','649.32','649.33','649.34'
		,'649.40','649.41','649.42','649.43','649.44'
		,'649.50','649.51','649.53'
		,'649.60','649.61','649.62','649.63','649.64'
		,'649.70','649.71','649.73'
		,'649.81','649.82'
		
		,'650.'
		,'651.00','651.01','651.03'
		,'651.10','651.11','651.13'
		,'651.20','651.21','651.23'
		,'651.30','651.31','651.33'
		,'651.40','651.41','651.43'
		,'651.50','651.51','651.53'
		,'651.60','651.61','651.63'
		,'651.70','651.71','651.73'
		,'651.80','651.81','651.83'
		,'651.90','651.91','651.93'

		,'652.00','652.01','652.03'
		,'652.10','652.11','652.13'
		,'652.20','652.21','652.23'
		,'652.30','652.31','652.33'
		,'652.40','652.41','652.43'
		,'652.50','652.51','652.53'
		,'652.60','652.61','652.63'
		,'652.70','652.71','652.73'
		,'652.80','652.81','652.83'
		,'652.90','652.91','652.93'
		
		,'653.00','653.01','653.03'
		,'653.10','653.11','653.13'
		,'653.20','653.21','653.23'
		,'653.30','653.31','653.33'
		,'653.40','653.41','653.43'
		,'653.50','653.51','653.53'
		,'653.60','653.61','653.63'
		,'653.70','653.71','653.73'
		,'653.80','653.81','653.83'
		,'653.90','653.91','653.93'
		
		,'654.00','654.01','654.02','654.03','654.04'
		,'654.10','654.11','654.12','654.13','654.14'
		,'654.20','654.21','654.23'
		,'654.30','654.31','654.32','654.33','654.34'
		,'654.40','654.41','654.42','654.43','654.44'
		,'654.50','654.51','654.52','654.53','654.54'
		,'654.60','654.61','654.62','654.63','654.64'
		,'654.70','654.71','654.72','654.73','654.74'
		,'654.80','654.81','654.82','654.83','654.84'
		,'654.90','654.91','654.92','654.93','654.94'
		
		,'655.00','655.01','655.03'
		,'655.10','655.11','655.13'
		,'655.20','655.21','655.23'
		,'655.30','655.31','655.33'
		,'655.40','655.41','655.43'
		,'655.50','655.51','655.53'
		,'655.60','655.61','655.63'
		,'655.70','655.71','655.73'
		,'655.80','655.81','655.83'
		,'655.90','655.91','655.93'
		
		,'656.00','656.01','656.03'
		,'656.10','656.11','656.13'
		,'656.20','656.21','656.23'
		,'656.30','656.31','656.33'
		,'656.40','656.41','656.43'
		,'656.50','656.51','656.53'
		,'656.60','656.61','656.63'
		,'656.70','656.71','656.73'	
		,'656.80','656.81','656.83'
		,'656.90','656.91','656.93'
		
		,'657.00','657.01','657.03'
		
		,'658.00','658.01','658.03'
		,'658.10','658.11','658.13'
		,'658.20','658.21','658.23'
		,'658.30','658.31','658.33'
		,'658.40','658.41','658.43'
		,'658.80','658.81','658.83'
		,'658.90','658.91','658.93'
		
		,'659.00','659.01','659.03'
		,'659.10','659.11','659.13'
		,'659.20','659.21','659.23'
		,'659.30','659.31','659.33'
		,'659.40','659.41','659.43'
		,'659.50','659.51','659.53'
		,'659.60','659.61','659.63'
		,'659.70','659.71','659.73'
		,'659.80','659.81','659.83'
		,'659.90','659.91','659.93'
		
		,'660.00','660.01','660.03'
		,'660.10','660.11','660.13'
		,'660.20','660.21','660.23'
		,'660.30','660.31','660.33'
		,'660.40','660.41','660.43'
		,'660.50','660.51','660.53'
		,'660.60','660.61','660.63'
		,'660.70','660.71','660.73'
		,'660.80','660.81','660.83'
		,'660.90','660.91','660.93'
		
		,'661.00','661.01','661.03'
		,'661.10','661.11','661.13'
		,'661.20','661.21','661.23'
		,'661.30','661.31','661.33'
		,'661.40','661.41','661.43'
		,'661.90','661.91','661.93'
		
		,'662.00','662.01','662.03'
		,'662.10','662.11','662.13'
		,'662.20','662.21','662.23'
		,'662.30','662.31','662.33'
		
		,'663.00','663.01','663.03'
		,'663.10','663.11','663.13'
		,'663.20','663.21','663.23'
		,'663.30','663.31','663.33'
		,'663.40','663.41','663.43'
		,'663.50','663.51','663.53'
		,'663.60','663.61','663.63'
		,'663.80','663.81','663.83'
		,'663.90','663.91','663.93'
		
		,'664.00','664.01','664.04'
		,'664.10','664.11','664.14'
		,'664.20','664.21','664.24'
		,'664.30','664.31','664.34'
		,'664.40','664.41','664.44'
		,'664.50','664.51','664.54'
		,'664.60','664.61','664.64'
		,'664.80','664.81','664.84'
		,'664.90','664.91','664.94'
		
		,'665.00','665.01','665.03'
		,'665.10','665.11','665.12','665.14'
		,'665.20','665.22','665.24'
		,'665.30','665.31','665.34'
		,'665.40','665.41','665.44'
		,'665.50','665.51','665.54'
		,'665.60','665.61','665.64'
		,'665.70','665.71','665.72','665.74'
		,'665.80','665.81','665.82','665.83','665.84'
		,'665.90','665.91','665.92','665.93','665.94'
		
		,'666.00','666.02','666.04'
		,'666.10','666.12','666.14'
		,'666.20','666.22','666.24'
		,'666.30','666.32','666.34'
		
		,'667.00','667.02','667.04'
		,'667.10','667.12','667.14'
		
		,'668.00','668.01','668.02','668.03','668.04'
		,'668.20','668.21','668.22','668.23','668.24'
		,'668.80','668.81','668.82','668.83','668.84'
		,'668.90','668.91','668.92','668.93','668.94'
		
		,'669.00','669.01','669.02'
		,'668.10','668.11','668.12','668.13','668.14'

		,'669.03','669.04'
		,'669.10','669.11','669.12','669.13','669.14'
		,'669.20','669.21','669.22','669.23','669.24'
		,'669.30','669.32','669.34'
		,'669.40','669.41','669.42','669.43','669.44'
		,'669.50','669.51'
		,'669.60','669.61'
		,'669.70','669.71'
		,'669.80','669.81','669.82','669.83','669.84'
		,'669.90','669.91','669.92','669.93','669.94'
		
		,'670.00','670.02','670.04'
		,'670.10','670.12','670.14'
		,'670.20','670.22','670.24'
		,'670.30','670.32','670.34'
		,'670.80','670.82','670.84'
		
		,'671.00','671.01','671.02','671.03','671.04'
		,'671.10','671.11','671.12','671.13','671.14'
		,'671.20','671.21','671.22','671.23','671.24'
		,'671.30','671.31','671.33'
		,'671.40','671.42','671.44'
		,'671.50','671.51','671.52','671.53','671.54'
		,'671.80','671.81','671.82','671.83','671.84'
		,'671.90','671.91','671.92','671.93','671.94'
		
		,'672.00','672.02','672.04'
		
		,'673.00','673.01','673.02','673.03','673.04'
		,'673.10','673.11','673.12','673.13','673.14'
		,'673.20','673.21','673.22','673.23','673.24'
		,'673.30','673.31','673.32','673.33','673.34'
		,'673.80','673.81','673.82','673.83','673.84'
		
		,'674.00','674.01','674.02','674.03','674.04'
		,'674.10','674.12','674.14'
		,'674.20','674.22','674.24'
		,'674.30','674.32','674.34'
		,'674.40','674.42','674.44'
		,'674.50','674.51','674.52','674.53','674.54'
		,'674.80','674.82','674.84'
		,'674.90','674.92','674.94'
		
		,'675.00','675.01','675.02','675.03','675.04'
		,'675.10','675.11','675.12','675.13','675.14'
		,'675.20','675.21','675.22','675.23','675.24'
		,'675.80','675.81','675.82','675.83','675.84'
		,'675.90','675.91','675.92','675.93','675.94'
		
		,'676.00','676.01','676.02','676.03','676.04'
		,'676.10','676.11','676.12','676.13','676.14'
		,'676.20','676.21','676.22','676.23','676.24'
		,'676.30','676.31','676.32','676.33','676.34'
		,'676.40','676.41','676.42','676.43','676.44'
		,'676.50','676.51','676.52','676.53','676.54'
		,'676.60','676.61','676.62','676.63','676.64'
		,'676.80','676.81','676.82','676.83','676.84'
		,'676.90','676.91','676.92','676.93','676.94'
		
		,'677.'
		
		,'678.00','678.01','678.03'
		,'678.10', '678.11','678.13'
		
		,'679.00','679.01','679.02','679.03','679.04'
		,'679.10','679.11','679.12','679.13','679.14'
		
		,'792.3'

		,'779.84'
		
		,'V22.0','V22.1','V22.2'

		,'V23.0','V23.1','V23.2','V23.3','V23.4'
		,'V23.41','V23.42','V23.49'
		,'V23.5','V23.7','V23.8'
		,'V23.81','V23.82','V23.83','V23.84','V23.85','V23.86','V23.87','V23.89'
		,'V23.9'

		,'V24.0','V24.1','V24.2'
		
		,'V27.0','V27.1','V27.2','V27.3','V27.4','V27.5','V27.6','V27.7','V27.9'

		,'V72.42'

		,'V89.01','V89.02','V89.03','V89.04','V89.05','V89.09'
				
		,'V91.00','V91.01','V91.02','V91.03','V91.09'
		,'V91.10','V91.11','V91.12','V91.19'
		,'V91.20','V91.21','V91.22','V91.29'
		,'V91.90','V91.91','V91.92','V91.99'
		)

	/***EatingDisorder**************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Eating disorder'
		,Category = 'Reproductive health'
		,ColumnDescription = 'Eating disorder'
		,DefinitionOwner = 'WHEI'
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'WRV_EatingDisorder'

	-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET  WRV_EatingDisorder=1
	WHERE ICD9code IN (
		'307.1'
		,'307.50'
		,'307.51'
		,'307.53'
		,'307.54'
		,'307.59'
		)

-------------------------------------------------------------------------------------------
/**** Categories dependent on above definitions ***************/
-------------------------------------------------------------------------------------------		
/***KEEP these codes at the bottom because they reference updates made above ***************/

	/***************MHorMedInd_AD*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'MH or medical indication for Antidepressant',
		Category = 'MHorMedInd_AD',
		ColumnDescription = 'MH or medical indication for AD',
		DefinitionOwner = 'OMHO' --AR 1/8/16 Changed to OMHO VISN21 has never owned the definition of this measure
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'MHorMedInd_AD';

		-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET MHorMedInd_AD = 1
	WHERE MHSUDdx_poss=1 
		OR MedIndAntiDepressant=1 -- SM 12/11/15 updated to include all SUD or MH dx used in IRA

  /***************MHorMedInd_Benzo*************************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'MH or medical indication for benzodiazepines',
		Category = 'MHorMedInd_Benzo',
		ColumnDescription = 'MH or medical indication for benzodiazepines',
		DefinitionOwner = 'OMHO' --AR 1/8/16 Changed to OMHO VISN21 has never owned the definition of this measure
	WHERE TableName = 'ICD9' 
		AND ColumnName = 'MHorMedInd_Benzo'

		-- updating variable flag
	UPDATE ##LookUp_ICD9_Stage
	SET MHorMedInd_Benzo = 1
	WHERE MHSUDdx_poss=1 
		OR MedIndBenzodiazepine=1 -- SM 12/11/15 updated to include all SUD or MH dx used in IRA

-------------------------------------------------------------------------------------------
/****Publish &  Unpivot for vertical publish***************/
-------------------------------------------------------------------------------------------		
EXEC [Maintenance].[PublishTable] 'LookUp.ICD9','##LookUp_ICD9_Stage'

DROP TABLE ##LookUp_ICD9_Stage;

DROP TABLE IF EXISTS #Columns;
SELECT COLUMN_NAME 
INTO #Columns
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE  TABLE_SCHEMA='LookUp' 
	AND TABLE_NAME = 'ICD9'
	AND COLUMN_NAME NOT IN ('sta3n','ICD9Description','ICD9SID','ICD9Code')
  
DECLARE @ColumnNames varchar(max) =
(SELECT STRING_AGG(COLUMN_NAME,',')
FROM #Columns)
--PRINT @ColumnNames

DROP TABLE IF EXISTS #unpivot;
CREATE TABLE #unpivot (
	ICD9Code varchar(25)
	,ICD9SID int
	,ICD9Description varchar(250)
	,DxCategory varchar(100)
	)
DECLARE @sql varchar(max) = 
'INSERT INTO #unpivot (ICD9Code,ICD9SID,ICD9Description,DxCategory)
 SELECT ICD9Code,ICD9SID,ICD9Description,DxCategory
 FROM
  (SELECT a.*
   FROM [LookUp].[ICD9] as a
	) AS p
  unpivot
    (Flag
    FOR DxCategory
    IN ('+@ColumnNames+'
    )) as a
WHERE
  Flag > 0'
  EXEC (@sql)

EXEC [Maintenance].[PublishTable] 'LookUp.ICD9_VerticalSID','#unpivot' 

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END
GO
