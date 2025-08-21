/***-- =============================================
-- Author:		<Susana Martins>
-- Create date: <9/10/2015>
-- Description:	Code to populate LookUp.ICD10
-- Modifications:
	--	2015-09-16	SM added where statement for ICDDescriptionVersion; adding Tourette and Huntington
	--  2015-12-07	ST	Added SUD_noAUD_noOUD_noCann_noHalluc_noStim_noCoc, CocaineUD_AmphUD, CannabisUD_HallucUD
	--	2016-01-01	MP	revised definitions to match Aaron/Eleanor's vetted code
	--	2016-02-11	SM	updated medind AD and benzo based on IW's email sent 2/11/16
	--	2016-04-14	SM	updated mhsud_poss - it was out of sync with Master file - 3 new variables added...
	--	2019-02-14	JB	Refactored to use [Maintenance].[PublishTable]
	--  2019-03-14	RAS	Corrected code for tourette's to 'F95.2' instead of 'F952'
	--	2019-03-14	RAS	Removed OtherSUD column from ICD9 and ICD10 tables - the code has been commented out since the earliest version in source control, so the column has not been populating with any data.  
	--  2019-09-19	SG	updated the ColumnDescription for the Reach variables.
	--  2019-11-29	CB	added in Women Reach Vet (WRV) variables
	--  2020-01-23	RAS	Formatting changes.  Changed update statements to update staging table instead of permanent table and moved PublishTable to end.
	--	2020-03-23	RAS	Corrected EH_PULMCIRC definition (previously was same as EH_VALVDIS).
	--  2020-03-27	SM Added correct Other_MH_STORM for computing STORM risk score
	--	2020-03-27  SM - Updated SuicideAttempt to remove heat exhaustion from the definition
	--	2020-06-05	SM - updated SAE_Otherdrug per JT request (definition was not aligned with original decision)
	--	2021-04-21  LM - Updated Suicide to remove heat exhaustion from the definition
	--  2021-05-14  JJR_SA - Added tag for identifying code to Share in ShareMill
	--	2021-05-19	LM	Added TBI and chronic respiratory disease to CRISTAL ProjectType
	--	2021-05-28	RAS	Corrected PDE_SuicideRelated to match eTM. Incorrectly entered previously as same as PDE_ExternalCauses.
	--	2021-06-03  JJR_SA - Updated tagging for use in sharing code for ShareMill;adjusted position of ending tag
	--	2021-11-05	RAS	Updated final section to save project type display information into separate table so that 
						LookUp.ICD10_VerticalSID_VM has granularity ICD10SID + DxCategory 
	--	2022-04-27	LM	Added missing homelessness codes
	--  2022-08-02	MP	Added ADD/ADHD, Narcolepsy, and Binge eating disorder
	--  2022-12-21  TG  Changed the AIDS category to HIV because of user complaints about stigmatization. 
	--  2023-07-13  CW  Changed "Renal Failure" to "Renal Impairment" per JT.
	--  2023-11-23  AR  Pulling variables from alex where there is no difference in rules 
	--  2024-1-9	AR  Pulling variables from alex where the only difference is a training decimal
	--  2024-4-15	CW  Updating diagnosis group for ORM - Suicide
	--  2024-12-18	LM	Removed Psych_Poss definition
	--	2024-12-30	LM	Transition SAE_Vehicle and SAE_OtherAccident to use ALEX definitions
	--	2025-04-08	LM	Rename to remove _VM
    --  2025-04-22  TG  Excluding Cannabis from Other Substance Use Disorder category.
  --2025-05-29 AER   Pulling MoodDisorderOther, PsychoticDisorderOther from risk monthly
-- =============================================
*/
CREATE PROCEDURE [Code].[LookUp_ICD10]
AS
BEGIN

/*** When ADDING A NEW VARIABLE, first add the column to the target table (LookUp.ICD10). ***/

EXEC [Log].[ExecutionBegin] 'EXEC Code.LookUp_ICD10','Execution of Code.LookUp_ICD10 SP'

/**************************************************************************************************/
/*** Add new rows to [LookUp].[ColumnDescriptions] if they exist in LookUp.ICD10 *************/
/**************************************************************************************************/

DECLARE @TableName VARCHAR(50) = 'ICD10'

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
				'ICD10SID'
				,'Sta3n'
				,'ICD10Description'
				,'ICD10Code'
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

--pull ICD10values from ALEX for items that we ready to convert to ALEX definitions 
drop table if exists ##ReadyToConvert
select distinct CDS_Lookup, a.SetTerm, case when len(Value)=3 then value + '.' else value end Value
into ##ReadyToConvert
from   LookUp.cds_alex as a left outer join [XLA].[Lib_SetValues_CDS] as c on a.SetTerm = c.SetTerm and c.Vocabulary = 'icd10CM'
where  a.CDS_Lookup in (
N'EH_BLANEMIA', N'BingeEating', N'DEPRESS_EBP', N'WRV_MenstrualDisorder', N'Narcolepsy', N'SAE_Acet', N'SleepApnea', N'Tourette'
,N'ADD_ADHD', N'CocaineUD_AmphUD', N'AmphetamineUseDisorder', N'EH_ARRHYTH', N'ALCdx_poss', N'AUD', N'BIPOLAR', N'CannabisUD_HallucUD'
, N'Cannabis', N'ChronicResp_Dx', N'COCNdx', N'EH_ELECTRLYTE', N'Nicdx_poss', N'Osteoporosis', N'EH_OpiDep', N'SAE_Falls', N'Schiz'
, N'SedativeUseDisorder', N'SMI',N'Huntington','DEMENTIA','DEPRESS','Homeless','PTSD','SUDdx_poss' ,'MDD' ,'AUD_ORM','OUD'
,'OpioidOverdose','MHSUDdx_poss','EH_LIVER','SAE_Vehicle','SAE_OtherAccident' 
,'EH_AIDS','EH_HYPERTENS','EH_PEPTICULC','TBI_Dx','Psych',

--added for RV2 from alex 
'Amputation','AnxietyGeneralized','EatingDisorderUnspecified','IntentionalSelfHarmIdeation','OtherSpecifiedEatingDisorders','PainAbdominal','PainOther','PainSystemicDisorder','Parkinsons','PsychosocialProblemsNOS','ViablePregnancy') 	AND CDS_Lookup  IN (
			SELECT a.name as ColumnName
			FROM  sys.columns as a 
			INNER JOIN sys.tables as b on  a.object_id = b.object_id
			WHERE b.Name = @TableName
			)

--reitred ALEX items which are used in RV2
insert into ##ReadyToConvert
select distinct CDS_Lookup, a.SetTerm, case when len(Value)=3 then value + '.' else value end Value
from   LookUp.cds_alex as a left outer join [XLA].[Lib_SetValues_RiskMonthly] as c on a.SetTerm = c.SetTerm and c.Vocabulary = 'icd10CM'
where  a.CDS_Lookup in ('MoodDisorderOther','PsychoticDisorderOther') 	AND CDS_Lookup  IN (
			SELECT a.name as ColumnName
			FROM  sys.columns as a 
			INNER JOIN sys.tables as b on  a.object_id = b.object_id
			WHERE b.Name = @TableName
			)



	--SELECT * FROM  ##ReadyToConvert  WHERE CDS_Lookup = 'homeless'

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
    WHERE T.TableName = @TableName;

	--select @Columns  --(if you want to see results of code above)
	
	DECLARE @Insert AS VARCHAR(max);

	DROP TABLE IF EXISTS ##LookUp_ICD10_Stage
	SET @Insert = N'
	SELECT ICD10SID
		  ,Sta3n
		  ,ICD10Code
		  ,ICD10Description
		  ,' + @Columns + ' 
	INTO ##LookUp_ICD10_Stage
	FROM ('

	/*##SHAREMILL BEGIN##*/
	SET @Insert =  @Insert + N'
	SELECT DISTINCT
			NomenclatureSID as ICD10SID
			,CAST(200 AS SMALLINT) AS Sta3n
			,(CASE 
			WHEN SourceIdentifier NOT LIKE ''%.%'' THEN CONCAT(SourceIdentifier,''.'')
			ELSE SourceIdentifier
			END) AS ICD10Code
			,SourceString as ICD10Description
		FROM [Cerner].[DimNomenclature]
		WHERE SourceVocabulary IN (''ICD-10-CM'')
		AND PrincipleType = ''Disease or Syndrome''
		AND ContributorSystem = ''Centers for Medicare & Medicaid Services''
	UNION ALL
		SELECT DISTINCT a.ICD10SID, a.Sta3n, a.ICD10Code, b.ICD10Description
		FROM  [Dim].[ICD10] as a
		INNER JOIN [Dim].[ICD10DescriptionVersion] as b on a.ICD10SID=b.ICD10SID
		WHERE EndEffectiveDate > GetDate()
			AND CurrentVersionFlag LIKE ''Y''
			AND 1=1'/*##SHAREMILL END##*/
	SET @Insert =  @Insert + N' /*ST added 9/16/05*/	) m'
	
	EXEC (@Insert);

	
while (select count(distinct cds_lookup) from ##ReadyToConvert) > 0
begin
declare @column varchar(100)
set @column = (select top 1 cds_lookup from ##ReadyToConvert order by cds_lookup )

declare @Update varchar(max)

set @update = '

update ##LookUp_ICD10_Stage
set ' + @Column + '= 1 
where ICD10Code in (select value from ##ReadyToConvert where CDS_Lookup = ''' + @Column + ''')

delete from ##ReadyToConvert where CDS_Lookup = ''' + @Column + '''

'
exec (@update)
end 

/**************************************************************************************************/
/***** Updating ICD10 variable flags and adding definitions. ************************/
/**************************************************************************************************/	


/****** Other_MH_STORM*****/
	 -- updating definition information
	 UPDATE [LookUp].[ColumnDescriptions]
     SET PrintName = 'Other Mental Health per STORM paper',
          Category = 'Mental Health',
          ColumnDescription = 'Other Mental Health per STORM paper, Oliva et al 2017',
		 DefinitionOwner= 'PERC'
     WHERE TableName = @TableName AND ColumnName = 'Other_MH_STORM'

	--Per JT, definition in ICD10 is IRA Psych_Poss excluding PTSD, BIPOLAR and MDD

--In IRA:
--PsychDX_poss= CASE WHEN 
-- (OtherMH + SMI_POSS + MDDdx_poss + PERSNdx_poss + ODEPRdx_poss + ANXgen_poss + ANXunsp_poss + OPSYdx_poss+ PTSDdx_poss+ OMOODdx_poss)>0 
-- THEN 1 ELSE 0 END
     
	 -- updating field flag
	 UPDATE ##LookUp_ICD10_Stage
     SET Other_MH_STORM = 1
     WHERE 
--   SMI_POSS
	 LEFT(ICD10Code,5) in ('F06.0','F06.2') or --OPSYdx_poss
	 LEFT(ICD10Code,3) in 
(
	'F20', -- SCHIZdx_poss
	'F22',--OPSYdx_poss
	'F23',--OPSYdx_poss
	'F24',--OPSYdx_poss
	'F25',-- SCHIZdx_poss
	'F28',--OPSYdx_poss
	'F29',--OPSYdx_poss
--		 'F30', -- AFFdx_poss BIPOLAR EXCLUDED PER STORM DEFINITION
--		 'F31',-- AFFdx_poss BIPOLAR EXCLUDED PER STORM DEFINITION
	'F53'--OPSYdx_poss
)  OR 

--MDD
--LEFT(ICD10Code,3) in ('F32','F33') and   EXCLUDED PER STORM DEFINITION
--LEFT(ICD10Code,5) not in ('F32.8','F33.8')  EXCLUDED PER STORM DEFINITION

-- PTSDdx_poss
--LEFT(ICD10Code,5) in ('F43.1')  EXCLUDED PER STORM DEFINITION

--PERSNdx_poss
(
	LEFT(ICD10Code,3) in ('F60', 'F69','F21') or 
    LEFT(ICD10Code,5) in ('F68.8')
) OR

 --ODEPRdx_poss
(
   LEFT(ICD10Code,5) in ('F34.1','F32.8','F33.8') or
   LEFT(ICD10Code,6) in ('F06.31','F06.32')
) OR

--ANXgen_poss
(
	LEFT(ICD10Code,5) in ('F41.1')
) OR

--AnxUnsp_poss 
(
	LEFT(ICD10Code,6) in ('F45.20','F45.21','F45.29') or
	LEFT(ICD10Code,5) in ('F06.4','F41.0', 'F41.3','F41.8','F41.9') OR 
	LEFT(ICD10Code,3) in ('F40', 'F42')
) OR

--OPSYdx_poss
(
	LEFT(ICD10Code,5) in ('F06.0','F06.2') or
	LEFT(ICD10Code,3) in ('F22', 'F23', 'F24','F28','F29','F53')
) OR

--OMOODdx_poss
(
      (
	  LEFT(ICD10Code,3) in ('F34', 'F39') and LEFT(ICD10Code,5) not in ('F34.1')
	  )  OR
      LEFT(ICD10Code,6) in ('F06.30','F06.33','F06.34')
) OR

---SMI
(
	LEFT(ICD10Code,5) in ('F06.0','F06.2') OR --OPSYdx_poss
	LEFT(ICD10Code,3) in 
	('F20', -- SCHIZdx_poss
	'F22',--OPSYdx_poss
	'F23',--OPSYdx_poss
	'F24',--OPSYdx_poss
	'F25',-- SCHIZdx_poss
	'F28',--OPSYdx_poss
	'F29',--OPSYdx_poss
	--	 'F30', -- AFFdx_poss BIPOLAR  EXCLUDED PER STORM DEFINITION
	--	 'F31',-- AFFdx_poss BIPOLAR  EXCLUDED PER STORM DEFINITION
	'F53')--OPSYdx_poss
) OR 

--OtherMH	 
(
LEFT(ICD10Code,3) in ( 'F44', 'F50', 'F63', 'F90', 'F91') or
LEFT(ICD10Code,5) in (
         'R45.7',
         'F43.0',
         'F43.8',
         'F43.9',
         'F44.0',
         'F44.1',
         'F44.2',
         'F44.4',
         'F44.5',
         'F44.6',
         'F44.7',
         'F44.8',
         'F44.9',
         'F45.0',
         'F45.1',
         'F45.8',
         'F45.9',
         'F48.1',
         'F50.0',
         'F50.2',
         'F50.8',
         'F50.9',
         'F63.0',
         'F63.1',
         'F63.2',
         'F63.3',
         'F63.8',
         'F63.9',
         'F68.1',
         'F90.0',
         'F90.1',
         'F90.2',
         'F90.8',
         'F90.9',
         'F91.0',
         'F91.1',
         'F91.2',
         'F91.3',
         'F91.8',
         'F91.9',
         'F43.2',
         'F43.8',
         'F43.9') OR

      LEFT(ICD10Code,6) in (
         'F44.81',
         'F44.89',
         'F45.22',
         'F50.00',
         'F50.01',
         'F50.02',
         'F63.81',
         'F63.89',
         'F43.20',
         'F43.24',
         'F43.29',
         'F43.25',
         'F45.22')
)


 
/****** SUD_Active_Dx (Active SUD)   ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Substance Use Disorder',
        Category = 'Substance Use Disorder',
        ColumnDescription = 'Active SUD',
		DefinitionOwner= 'PERC'
    WHERE TableName = @TableName AND ColumnName = 'SUD_Active_Dx'
       
	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage
    SET SUD_Active_Dx = 1 
	WHERE ICD10Code in ('F11.120','F11.121','F10.982','F11.19','F11.122','F11.14','F10.988',
		'F11.150','F11.282','F11.220','F10.99','F11.151','F11.920','F11.24','F11.10','F11.129','F11.159','F11.921','F11.281','F11.181','F11.23','F11.250','F11.929','F11.288','F11.29','F11.20',
		'F11.221','F11.922','F11.951','F11.222','F11.959','F11.950','F11.93','F11.229','F12.120','F11.99','F11.988','F11.251','F12.129','F11.259','F12.121','F12.122','F12.20','F12.220','F12.221',
		'F12.151','F11.90','F11.94','F12.150','F12.222','F12.19','F12.229','F11.981','F12.159','F12.259','F12.288','F11.982','F12.251','F12.29','F12.920','F12.10','F12.180','F12.921','F12.951','F12.280','F12.188',
		'F12.922','F12.988','F12.959','F13.120','F13.14','F12.90','F12.250','F13.159','F13.19','F12.929','F12.950','F13.180','F13.250','F12.980','F13.121','F13.220','F12.99','F13.282','F13.259','F13.151',
		'F13.10','F13.288','F13.26','F13.29','F13.129','F13.181','F13.920','F13.930','F13.150','F13.182','F13.939','F13.931','F13.221','F13.188','F13.229','F13.932','F13.988','F13.20','F13.230','F13.951',
		'F13.99','F13.980','F14.120','F14.10','F14.150','F13.231','F13.232','F14.121','F14.151','F13.24','F13.239','F14.14','F14.159','F13.251','F13.27','F14.221','F14.180','F13.280','F14.280','F13.90','F13.281',
		'F14.20','F14.222','F14.288','F13.950','F13.921','F14.23','F14.251','F14.922','F13.981','F13.929','F14.259','F14.950','F13.982','F13.94','F14.281','F14.959','F14.122','F13.959','F14.129','F13.96',
		'F14.29','F15.150','F14.181','F13.97','F14.182','F14.229','F14.90','F14.24','F14.929','F14.94','F14.951','F15.23','F14.188','F14.250','F14.980','F14.981','F14.19','F14.982','F14.220','F14.921',
		'F15.259','F14.988','F14.282','F15.120','F15.282','F14.920','F14.99','F15.950','F15.129','F15.121','F15.10','F15.122','F15.959','F15.14','F15.159','F15.188','F15.981','F15.151','F15.181','F15.180',
		'F15.99','F15.220','F15.19','F15.182','F16.121','F15.221','F15.229','F15.20','F16.14','F15.222','F15.250','F15.24','F16.159','F15.288','F15.251','F15.29','F16.180','F15.90','F15.280','F15.920','F16.188','F15.929',
		'F15.281','F15.921','F16.20','F16.221','F15.980','F15.922','F15.93','F16.229','F16.122','F15.951','F16.129','F16.283','F15.94','F16.120','F16.19','F16.920','F15.982','F16.183','F16.921',
		'F16.24','F16.220','F15.988','F16.959','F16.251','F16.250','F16.10','F16.150','F16.980','F16.259','F16.288','F16.151','F16.988','F16.94','F16.929','F16.280','F18.10','F18.120','F16.29',
		'F18.129','F16.90','F18.121','F16.951','F18.150','F16.950','F18.180','F16.983','F18.151','F18.14','F18.19','F16.99','F18.159','F18.250','F18.27','F18.188','F18.17','F18.251','F18.280',
		'F18.221','F18.288','F18.90','F18.20','F18.220','F18.920','F18.921','F18.24','F18.229','F18.94','F18.950','F18.259','F18.951','F18.959','F18.980','F18.97','F18.988','F19.122','F19.222',
		'F19.129','F19.120','F18.29','F19.229','F19.150','F19.121','F18.929','F19.24','F19.181','F19.14','F18.99','F19.282','F19.20','F19.159','F19.10','F19.90','F19.232','F19.180','F19.151',
		'F19.930','F19.239','F19.188','F19.16','F19.959','F19.251','F19.96','F19.17','F19.19','F19.27','F19.97','F19.182','F19.220','F19.920','F19.980','F19.221','F19.231','F19.922','F19.250',
		'F19.259','F19.230','F19.280','F19.26','F19.29','F19.929','F19.931','F19.281','F19.951','F19.99','F19.932','F19.939','F19.288','F19.981','F19.921','F19.982','F19.988','F19.94','F19.950') 
		--[SUDdx_poss]=1 and ICD10Description not like '%remission%'
  
  
/****** AUD_ORM     ******************/
/** AUD for STORM- same as AUD in future can delete this... **********/                  
	-- updating definition information
   UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Alcohol Use Disorder (restricted definition)',
        Category = 'Substance Use Disorder',
        ColumnDescription = 'Alcohol Use Disorder',
		DefinitionOwner= 'STORM Risk Model'
    WHERE TableName = @TableName AND ColumnName = 'AUD_ORM';
 
 	-- updating field flag
    UPDATE ##LookUp_ICD10_Stage
    SET AUD_ORM = 1
    WHERE LEFT(ICD10Code,3) = 'F10'
 
/****** Benzo_AD_MHDx     ******************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Any MH diagnosis',
        Category = 'Mental Health',
        ColumnDescription = 'Any MH diagnosis',
		DefinitionOwner= 'OMHO Master File'
    WHERE TableName = @TableName AND ColumnName = 'Benzo_AD_MHDx';
         
  	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage
    SET Benzo_AD_MHDx = 1 
    WHERE  LEFT(ICD10Code,6) in ('F45.20','F45.21','F45.29') or LEFT(ICD10Code,5) in ('F06.4', 'F41.0', 'F41.3','F41.8','F41.9') or   LEFT(ICD10Code,3) in  ('F40', 'F42') --ANXunsp_poss MP updated 1/11/16 
 		OR LEFT(ICD10Code,5) in ('F41.1') --ANXgen_poss
		OR LEFT(ICD10Code,5) in ('F34.1','F32.8','F33.8') or LEFT(ICD10Code,6) in ('F06.31','F06.32') -- other depression ODEPRdx_poss (1/11/16 MP revised)
		OR LEFT(ICD10Code,3) in ('F60', 'F69','F21') or LEFT(ICD10Code,5) in ('F68.8')  --PERSNdx_poss (1/11/16 MP revised to Aaron's def)
		OR (LEFT(ICD10Code,3) in ('F32','F33') and LEFT(ICD10Code,5) not in ('F32.8','F33.8'))  --MDDdx_poss (1/11/16 MP revised to Aaron's vetted def)
		OR LEFT(ICD10Code,5) in ('F06.0','F06.2') or LEFT(ICD10Code,3) in ('F20','F22', 'F23', 'F24','F25','F28','F29','F30', 'F31','F53')  --SMI_POSS (1/11/16 MP revised to Aaron's vetted def)
		OR LEFT(ICD10Code,3) in ('F44','F50','F63','F90','F91') 
		OR LEFT(ICD10Code,5) in ('R45.7','F43.0','F43.8','F43.9','F44.0','F44.1','F44.2','F44.4','F44.5','F44.6','F44.7','F44.8','F44.9','F45.0','F45.1','F45.8'
			,'F45.9','F48.1','F50.0','F50.2','F50.8','F50.9','F63.0','F63.1','F63.2','F63.3','F63.8','F63.9','F68.1','F90.0','F90.1','F90.2','F90.8','F90.9'
			,'F91.0','F91.1','F91.2','F91.3','F91.8','F91.9','F43.2','F43.8','F43.9') 
		OR LEFT(ICD10Code,6) in ('F44.81','F44.89','F45.22','F50.00','F50.01','F50.02','F63.81','F63.89','F43.20','F43.24','F43.29','F43.25','F45.22')--OtherMH (1/11/16 MP revised to Aaron's vetted def)
 
   
/****** DEMENTIA     ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Dementia', 
        Category = 'Mental Health', 
        ColumnDescription = 'Dementia', 
		DefinitionOwner= 'VHA Dementia Diagnostic Coding Consensus Workgroup ' 
    WHERE TableName = @TableName AND ColumnName = 'Dementia'

 	-- updating field flag
     UPDATE ##LookUp_ICD10_Stage
     SET Dementia = 1
     WHERE ICD10Code in ('A81.00','A81.01','A81.09'
		,'A81.2','A81.82','A81.89','A81.9'
		,'F01.50','F01.51'
		,'F02.80','F02.81'
		,'F03.90','F03.91'
		,'F10.27','F10.97'
		,'F13.27','F13.97'
		,'F18.17','F18.27','F18.97'
		,'F19.17','F19.27','F19.97'
		,'G23.1'
		,'G30.0','G30.1','G30.8','G30.9'
		,'G31.01','G31.09','G31.83'
		,'G90.3') 
 
/****** DEPRESS     ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions] 
    SET PrintName = 'Depression - MDD and other depression',
        Category = 'Mental Health',
        ColumnDescription = 'Depression: MDD and other depression',
		DefinitionOwner= 'OMHO Master File'
    WHERE TableName = @TableName AND ColumnName = 'DEPRESS'

 	-- updating field flag
    UPDATE ##LookUp_ICD10_Stage
    SET DEPRESS = 1
    WHERE (LEFT(ICD10Code,3) in ('F32','F33') and LEFT(ICD10Code,5) not in ('F32.8','F33.8')) --MDDdx_poss (1/11/16 MP revised to Aaron's vetted def)
		-- equivalentent to HEDIS 2016 plus F33.40 MAJOR DEPRESSIVE DISORDER, RECURRENT, IN REMISSION, UNSPECIFIED 
		----and F33.42	MAJOR DEPRESSIVE DISORDER, RECURRENT, IN FULL REMISSION
		OR LEFT(ICD10Code,5) in ('F34.1','F32.8','F33.8') or LEFT(ICD10Code,6) in ('F06.31','F06.32') -- other depression OPEPRdx_poss (1/11/16 MP revised)
 
	-- Not in HEDIS 2016 defintiion:
		--F06.31	MOOD DISORDER DUE TO KNOWN PHYSIOLOGICAL CONDITION WITH DEPRESSIVE FEATURES 
		--F06.32	MOOD DISORDER DUE TO KNOWN PHYSIOLOGICAL CONDITION WITH MAJOR DEPRESSIVE-LIKE EPISODE
		--F32.8	OTHER DEPRESSIVE EPISODES
		--F33.8	OTHER RECURRENT DEPRESSIVE DISORDERS
		--F34.1	DYSTHYMIC DISORDER
  
 
/****** EH_CHRNPULM - EH chronic pulmonary disease ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Chronic Pulmonary Dis',
        Category = 'Medical',
        ColumnDescription = 'Elixhauser chronic pulmonary disease based on Quan H 2005',
 		DefinitionOwner= 'Elixhauser'
    WHERE TableName = @TableName AND ColumnName = 'EH_CHRNPULM'

	-- updating field flag
    UPDATE ##LookUp_ICD10_Stage
    SET EH_CHRNPULM = 1
    WHERE LEFT(ICD10Code,5) in ('I27.8','I27.9','J68.4','J70.1','J70.3') 
 		OR LEFT(ICD10Code,3) in ('J40','J41','J42','J43','J44','J45','J46','J47','J60','J61','J62','J63','J64','J65','J66','J67')
 
/****** EH_COAG - EH Coagulopathy ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Coagulopathy',
        Category = 'Medical',
        ColumnDescription = 'Elixhauser Coagulopathy based on Quan H 2005',
 		DefinitionOwner= 'Elixhauser'
    WHERE TableName = @TableName AND ColumnName = 'EH_COAG'
	   
	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage
    SET EH_COAG = 1
    WHERE LEFT(ICD10Code,5) in ('D69.1','D69.3','D69.4','D69.5','D69.6')
 	or LEFT(ICD10Code,3) in ('D65','D66','D67','D68') 
 	   
/****** EH_COMDIAB - EH complicated diabetes ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Diabetes, Complicated',
        Category = 'Medical',
        ColumnDescription = 'Elixhauser complicated diabetes based on Quan H 2005',
 		DefinitionOwner= 'Elixhauser'
    WHERE TableName = @TableName AND ColumnName = 'EH_COMDIAB'
	   
	-- updating field flag
    UPDATE ##LookUp_ICD10_Stage
    SET EH_COMDIAB = 1
    WHERE  LEFT(ICD10Code,5) in (
		'E10.2','E10.3','E10.4','E10.5','E10.6','E10.7','E10.8','E11.2','E11.3','E11.4','E11.5', 'E11.6',
		'E11.7','E11.8','E12.2','E12.3','E12.4','E12.5','E12.6','E12.7','E12.8','E13.2', 'E13.3','E13.4',
		'E13.5','E13.6','E13.7','E13.8','E14.2','E14.3','E14.4','E14.5','E14.6','E14.7','E14.8'
		)
 
 /****** EH_DefANEMIA - EH deficiency anemia ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Anemia due to iron deficiency',
        Category = 'Medical',
        ColumnDescription = 'Elixhauser deficiency anemia based on Quan H 2005',
 		DefinitionOwner= 'Elixhauser'
    WHERE TableName = @TableName AND ColumnName = 'EH_DefANEMIA';

	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage
    SET EH_DefANEMIA = 1
    WHERE  LEFT(ICD10Code,5) in ('D50.8','D50.9')
 	or LEFT(ICD10Code,3) in ('D51','D52','D53') 
 

/****** EH_HEART - EH congestive heart disease ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Congestive Heart Failure',
        Category = 'Medical',
        ColumnDescription = 'Elixhauser congestive heart failure based on Quan H 2005',
		DefinitionOwner= 'Elixhauser'
	WHERE TableName = @TableName AND ColumnName = 'EH_HEART'
	
	-- updating field flag
    UPDATE ##LookUp_ICD10_Stage
	SET EH_HEART = 1
    WHERE  LEFT(ICD10Code,5) IN ('I09.9','I11.0','I13.0','I13.2','I25.5','I42.0','I42.5','I42.6', 'I42.7','I42.8','I42.9','P29.0') 
		OR LEFT(ICD10Code,3) IN ('I43','I50')
 
 
/****** EH_HYPOTHY - EH hypothyroidism ******************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Hypothyroidism',
		Category = 'Medical', 
		ColumnDescription = 'Elixhauser hypothyroidism based on Quan H 2005', 
		DefinitionOwner= 'Elixhauser' 
	WHERE TableName = @TableName AND ColumnName = 'EH_HYPOTHY'

  	-- updating field flag
    UPDATE ##LookUp_ICD10_Stage 
    SET EH_HYPOTHY = 1
    WHERE  LEFT(ICD10Code,5) IN ('E89.0')
		OR LEFT(ICD10Code,3) IN ('E00','E01','E02','E03')
 
 
 
/****** EH_Lymphoma     ******************/
    -- updating definition information 
    UPDATE [LookUp].[ColumnDescriptions] 
    SET PrintName = 'Lymphoma', 
        Category = 'Medical', 
        ColumnDescription = 'Elixhauser lymphoma based on Quan H 2005', 
		DefinitionOwner= 'Elixhauser' 
    WHERE TableName = @TableName AND ColumnName = 'EH_LYMPHOMA'
	
	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage
    SET EH_LYMPHOMA = 1
    WHERE LEFT(ICD10Code,5) in ('C90.0','C90.2') 
		OR LEFT(ICD10Code,3) in ('C81','C82','C83','C84','C85','C88','C96')

/****** EH_METCANCR  2 -  EH metastatic cancer  ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Cancer - Metastatic',
        Category = 'Medical',
        ColumnDescription = 'Elixhauser metastatic cancer based on Quan H 2005',
		DefinitionOwner= 'Elixhauser'
    WHERE TableName = @TableName AND ColumnName = 'EH_METCANCR'	  
	
	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage
    SET EH_METCANCR = 1 
    WHERE LEFT(ICD10Code,3) in ('C77','C78','C79','C80')

/****** EH_NMETTUMR - EH solid tumor without metastasis ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Cancer - solid tumor without metastasis',
        Category = 'Medical',
        ColumnDescription = 'Elixhauser solid tumor without metastasis based on Quan H 2005',
		DefinitionOwner= 'Elixhauser'
    WHERE TableName = @TableName AND ColumnName = 'EH_NMETTUMR'
 
	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage
    SET EH_NMETTUMR = 1
    WHERE LEFT(ICD10Code,3) in ('C00','C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','C11','C12','C13','C14','C15','C16','C17',
                                'C18','C19','C20','C21','C22','C23','C24','C25','C26','C30', 'C31','C32','C33','C34','C37','C38','C39','C40',
                                'C41','C43','C45','C46','C47','C48','C49','C50','C51','C52','C53','C54','C55','C56','C57','C58','C60','C61',
                                'C62','C63','C64','C65','C66','C67','C68','C69','C70','C71','C72','C73','C74','C75','C76','C97')
 
/****** EH_OBESITY     ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Obesity',
        Category = 'Medical',
        ColumnDescription = 'Elixhauser Obesity based on Quan H 2005',
		DefinitionOwner= 'Elixhauser'
    WHERE TableName = @TableName AND ColumnName = 'EH_OBESITY'

	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage
    SET EH_OBESITY = 1
    WHERE LEFT(ICD10Code,3) = 'E66' 
  
/****** EH_OTHNEURO - EH other neurological disorders ******************/
     -- updating definition information
     UPDATE [LookUp].[ColumnDescriptions]
     SET PrintName = 'Neurological disorders - Other',
          Category = 'Medical',
          ColumnDescription = 'Elixhauser other neurological disorders based on Quan H 2005',
		 DefinitionOwner= 'Elixhauser'
     WHERE TableName = @TableName AND ColumnName = 'EH_OTHNEURO';
 
	-- updating field flag
     UPDATE ##LookUp_ICD10_Stage
     SET EH_OTHNEURO = 1
     WHERE LEFT(ICD10Code,5) in ('G25.4','G25.5','G31.2','G31.8','G31.9','G93.1','G93.4','R47.0')
        OR LEFT(ICD10Code,3) in ('G10','G11','G12','G13','G20','G21','G22','G32','G35','G36','G37','G40','G41','R56')
 
/****** EH_PARALYSIS     ******************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Paralysis', 
		Category = 'Medical', 
		ColumnDescription = 'Elixhauser paralysis based on Quan H 2005', 
		DefinitionOwner= 'Elixhauser' 
	WHERE TableName = @TableName AND ColumnName = 'EH_PARALYSIS'

	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage 
	SET EH_PARALYSIS = 1 
	WHERE LEFT(ICD10Code,5) in ('G04.1','G11.4','G80.1','G80.2','G83.0','G83.1','G83.2','G83.3','G83.4','G83.9') 
		OR LEFT(ICD10Code,3) in ('G81','G82') 
 
/****** EH_PERIVALV - EH peripheral vascular disorders ******************/	 
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Peripheral Vascular Disease', 
	Category = 'Medical', 
	ColumnDescription = 'Elixhauser peripheral vascular disorders based on Quan H 2005', 
	DefinitionOwner= 'Elixhauser' 
	WHERE TableName = @TableName AND ColumnName = 'EH_PERIVALV'
 
	-- updating field flag 
	UPDATE ##LookUp_ICD10_Stage 
	SET EH_PERIVALV = 1 
	WHERE LEFT(ICD10Code,5) in ('I73.1','I73.8','I73.9','I77.1','I79.0','I79.2','K55.1','K55.8','K55.9','Z95.8','Z95.9')  
		OR LEFT(ICD10Code,3) in ('I70','I71')

/****** EH_PULMCIRC     ******************/
/** EH pulmonary circulation disorders **********/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Pulmonary Circulation Disorders',
		Category = 'Medical',
		ColumnDescription = 'Elixhauser pulmonary circulation disorders based on Quan H 2005',
		DefinitionOwner= 'Elixhauser'
	WHERE TableName = @TableName AND ColumnName = 'EH_PULMCIRC'
 
	-- updating field flag 
	UPDATE ##LookUp_ICD10_Stage 
	SET EH_PULMCIRC = 1 
	WHERE LEFT(ICD10Code,3) in ('I26','I27')
		OR LEFT(ICD10Code,5) in  ('I28.0','I28.8','I28.9')

/****** EH_RENAL - EH renal failure ******************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Renal Impairment',
		Category = 'Medical',
		ColumnDescription = 'Elixhauser renal impairment based on Quan H 2005',
		DefinitionOwner= 'Elixhauser'
	WHERE TableName = @TableName AND ColumnName = 'EH_RENAL'

	-- updating field flag 
	UPDATE ##LookUp_ICD10_Stage 
	SET EH_RENAL = 1 
	WHERE LEFT(ICD10Code,5) in ('I12.0','I13.1','N25.0','Z49.0','Z49.1','Z49.2','Z94.0','Z99.2')
		OR LEFT(ICD10Code,3) in ('N18','N19')

/****** EH_RHEUMART - EH RHEUMATOID ARTHRITIS/COLLAGEN VASCULAR ******************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Rheumatoid Arthritis/Collagen Vascular Disease',
		Category = 'Medical',
		ColumnDescription = 'Elixhauser RHEUMATOID ARTHRITIS/COLLAGEN VASCULAR based on Quan H 2005',
		DefinitionOwner= 'Elixhauser'
	WHERE TableName = @TableName AND ColumnName = 'EH_RHEUMART'

	-- updating field flag 
	UPDATE ##LookUp_ICD10_Stage 
	SET EH_RHEUMART = 1
	WHERE  LEFT(ICD10Code,5) in ('L94.0','L94.1','L94.3','M12.0','M12.3','M31.0','M31.1','M31.2','M31.3','M46.1','M46.8','M46.9')
		OR LEFT(ICD10Code,3) in ('M05','M06','M08','M30','M32','M33','M34','M35','M45')
 
/****** EH_SolidTumorNoMet     ******************/
    -- updating definition information 
    UPDATE [LookUp].[ColumnDescriptions] 
    SET PrintName = 'Solid Tumor no metastasis ',
        Category = 'Medical',
        ColumnDescription = 'EH_SolidTumorNoMet',
		DefinitionOwner= 'Elixhauser solid tumor no metastasis based on Quan H 2005'
    WHERE TableName = @TableName AND ColumnName = 'EH_SolidTumorNoMet';
 
    -- updating field flag
	UPDATE ##LookUp_ICD10_Stage 
    SET EH_SolidTumorNoMet = 1 
    WHERE LEFT(ICD10Code,3) in (
		'C00','C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','C11','C12','C13',
		'C14','C15','C16','C17','C18','C19','C20','C21','C22','C23','C24','C25','C26','C30',
		'C31','C32','C33','C34','C37','C38','C39','C40','C41','C43','C45','C46','C47','C48',
		'C49','C50','C51','C52','C53','C54','C55','C56','C57','C58','C60','C61','C62','C63',
		'C64','C65','C66','C67','C68','C69','C70','C71','C72','C73','C74','C75','C76','C97'
		)
 
/****** EH_UNCDIAB - EH uncomplicated diabetes ******************/
	-- updating definition information 
    UPDATE [LookUp].[ColumnDescriptions] 
    SET PrintName = 'Diabetes, Uncomplicated',
       Category = 'Medical',
        ColumnDescription = 'Elixhauser uncomplicated diabetes based on Quan H 2005',
		DefinitionOwner= 'Elixhauser'
    WHERE TableName = @TableName AND ColumnName = 'EH_UNCDIAB';
	
	-- updating field flag
    UPDATE ##LookUp_ICD10_Stage 
    SET EH_UNCDIAB = 1 
    WHERE  LEFT(ICD10Code,5) in (
		 'E10.0','E10.1','E10.9'
		,'E11.0','E11.1','E11.9'
		,'E12.0','E12.1','E12.9'
		,'E13.0','E13.1','E13.9'
		,'E14.0','E14.1','E14.9'
		) 
 
/****** EH_VALVDIS - EH valvular disease ******************/ 
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Valvular disease',
		Category = 'Medical',
		ColumnDescription = 'Elixhauser valvular disease based on Quan H 2005',
		DefinitionOwner= 'Elixhauser'
	WHERE TableName = @TableName AND ColumnName = 'EH_VALVDIS'
	
	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage 
    SET EH_VALVDIS = 1 
    WHERE LEFT(ICD10Code,5) in ('A52.0','I09.1','I09.8','Q23.0','Q23.1','Q23.2','Q23.3','Z95.2','Z95.3','Z95.4')
	or LEFT(ICD10Code,3) in ('I05','I06','I07','I08','I34','I35','I36','I37', 'I38','I39')
 
/****** EH_WEIGHTLS - EH weight loss ******************/
    -- updating definition information 
    UPDATE [LookUp].[ColumnDescriptions] 
    SET PrintName = 'Weight loss',
        Category = 'Medical',
        ColumnDescription = 'Elixhauser weight loss based on Quan H 2005',
		DefinitionOwner= 'Elixhauser'
    WHERE TableName = @TableName AND ColumnName = 'EH_WEIGHTLS';

	-- updating field flag
    UPDATE ##LookUp_ICD10_Stage 
    SET EH_WEIGHTLS = 1 
    WHERE LEFT(ICD10Code,5) in ('R63.4') 
		OR LEFT(ICD10Code,3) in ('E40','E41','E42','E43','E44','E45','E46','R64');
 
/****** Homeless ******************/
    -- updating definition information 
    UPDATE [LookUp].[ColumnDescriptions] 
    SET PrintName = 'Homeless',
        Category = 'Social',
        ColumnDescription = 'ICD10 code for homeless per Master file',
		DefinitionOwner= 'OMHO Master File'
    WHERE TableName = @TableName AND ColumnName = 'Homeless';
	
	-- updating field flag
    UPDATE ##LookUp_ICD10_Stage 
    SET Homeless = 1 
    WHERE ICD10Code IN ('Z59.0','Z59.00','Z59.01','Z59.02')
	;
  
 
/****** MDD - Major Depressive Disorder ******************/
--1/11/16 MP revised to Aaron's vetted def
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Depression - Major Depressive Disorder',
		Category = 'Mental Health',
		ColumnDescription = 'Major Depressive Disorder',
		DefinitionOwner= 'OMHO Master File'
	WHERE TableName = @TableName AND ColumnName = 'MDD';
	 	 
	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage 
	SET MDD = 1 
	WHERE (LEFT(ICD10Code,3) in ('F32','F33') 
		AND LEFT(ICD10Code,5) not in ('F32.8','F33.8')
		) 
 
/****** MedIndAntiDepressant - Medical Indications AD ******************/
--SM  2/11/16  updated based on IW's email sent 2/11/16            
    -- updating definition information 
    UPDATE [LookUp].[ColumnDescriptions] 
    SET PrintName = 'Medical indications for antidepressant',
        Category = 'Medical Indication',
        ColumnDescription = 'Medical indications for antidepressant',
		DefinitionOwner= 'NEPEC- IW'
    WHERE TableName = @TableName AND ColumnName = 'MedIndAntiDepressant';
 
	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage 
    SET MedIndAntiDepressant= 1 
    WHERE ICD10Code between 'C00%' and 'D49%'		-- malignant neoplasms
		OR ICD10Code between 'G56.1%' and 'G56.99%'	-- nerve related pain OK 2/10
		OR ICD10Code between 'G62%' and 'G62.22%' 	-- polyneuropathy
		OR ICD10Code like 'D03%' 					-- melanoma in situ
		OR ICD10Code like 'D45%'					-- Polycythemia vera
		OR ICD10Code like 'F51.0%'					-- insomnias
		OR ICD10Code like'G43%'						-- migraines
		OR ICD10Code like 'G47.0%'					-- insomnia
		OR ICD10Code like 'G47.2%'					-- CIRCADIAN RHYTHM SLEEP DISORDERs
		OR ICD10Code like 'G50%'					-- TRIGEMINAL NEURALGIA
		OR ICD10Code like  'G62.81'					-- CRITICAL ILLNESS POLYNEUROPATHY
		OR(ICD10Code like 'G89%' and ICD10Code <> 'G89.3' ) -- acute and chronic pain
		OR ICD10Code like 'H46%'					-- optic nerve related pain OK 2/10
		OR ICD10Code like 'H47.0%'					-- eye related pain OK 2/10
		OR ICD10Code like 'M25.5%'					-- pain OK 2/10
		OR ICD10Code like 'M54.1%'					-- radiculopathy Ok 2/10
		OR ICD10Code like 'M79.64%'					-- hand pain OK 2/10
		OR ICD10Code between 'E10.4%' and 'E10.43%' --type 1 dm neuropathy 
		OR ICD10Code between 'E11.4%' and 'E11.43%' -- type 2 dm neuropathy 
		OR ICD10Code between 'E13.4%' and 'E13.43%' --other specified dm neuropathy
		OR ICD10Code in ('B02.22'--Postherpetic trigeminal neuralgia
			,'E08.40'--DIABETES MELLITUS DUE TO UNDERLYING CONDITION WITH DIABETIC NEUROPATHY, UNSPECIFIED
			,'E08.41'--DIABETES MELLITUS DUE TO UNDERLYING CONDITION WITH DIABETIC MONONEUROPATHY
			,'E08.42'--  DIABETES MELLITUS DUE TO UNDERLYING CONDITION WITH DIABETIC POLYNEUROPATHY   	
			,'E08.43' --DIABETES MELLITUS DUE TO UNDERLYING CONDITION WITH DIABETIC AUTONOMIC (POLY)NEUROPATHY
			,'E09.40' --DRUG OR CHEMICAL INDUCED DIABETES MELLITUS WITH NEUROLOGICAL COMPLICATIONS WITH DIABETIC NEUROPATHY, UNSPECIFIED
			,'E09.41'--DRUG OR CHEMICAL INDUCED DIABETES MELLITUS WITH NEUROLOGICAL COMPLICATIONS WITH DIABETIC MONONEUROPATHY
			,'E09.42'--DRUG OR CHEMICAL INDUCED DIABETES MELLITUS WITH NEUROLOGICAL COMPLICATIONS WITH DIABETIC POLYNEUROPATHY 
			,'E09.43' --DRUG OR CHEMICAL INDUCED DIABETES MELLITUS WITH NEUROLOGICAL COMPLICATIONS WITH DIABETIC AUTONOMIC (POLY)NEUROPATHY
			,'F51.12' --INSUFFICIENT SLEEP SYNDROME
			,'F51.3' --SLEEPWALKING [SOMNAMBULISM]
			,'F51.8' --OTHER SLEEP DISORDERS NOT DUE TO A SUBSTANCE OR KNOWN PHYSIOLOGICAL CONDITION
			,'F51.9' --SLEEP DISORDER NOT DUE TO A SUBSTANCE OR KNOWN PHYSIOLOGICAL CONDITION, UNSPECIFIED
			,'G44.1' -- VASCULAR HEADACHE, NOT ELSEWHERE CLASSIFIED
			,'G44.209' --TENSION-TYPE HEADACHE, UNSPECIFIED, NOT INTRACTABLE
			,'G44.201' --TENSION-TYPE HEADACHE, UNSPECIFIED, INTRACTABLE
			,'G47.52%' --REM SLEEP BEHAVIOR DISORDER
			,'G47.8' --OTHER SLEEP DISORDERS
			,'G47.9' --SLEEP DISORDER, UNSPECIFIED
			,'G47.00' --INSOMNIA, UNSPECIFIED
			,'G47.30' --SLEEP APNEA, UNSPECIFIED
			,'G58.7' --MONONEURITIS MULTIPLEX
			,'G60.0' --HEREDITARY MOTOR AND SENSORY NEUROPATHY
			,'G60.1' --REFSUM'S DISEASE
			,'G60.3' --IDIOPATHIC PROGRESSIVE NEUROPATHY
			,'G60.8' --OTHER HEREDITARY AND IDIOPATHIC NEUROPATHIES
			,'G60.9' --HEREDITARY AND IDIOPATHIC NEUROPATHY, UNSPECIFIED
			,'G61.0' --GUILLAIN-BARRE SYNDROME
			,'G61.81' --CHRONIC INFLAMMATORY DEMYELINATING POLYNEURITIS
			,'G61.89' --OTHER INFLAMMATORY POLYNEUROPATHIES
			,'G61.9' --INFLAMMATORY POLYNEUROPATHY, UNSPECIFIED
			,'G63.' --POLYNEUROPATHY IN DISEASES CLASSIFIED ELSEWHERE
			,'M79.2' --NEURALGIA AND NEURITIS, UNSPECIFIED
			,'N39.44' --NOCTURNAL ENURESIS
			,'R51.' --HEADACHE
			,'R52.' --PAIN, UNSPECIFIED
		)
 
/****** MedIndBenzodiazepine     ******************/ 
--SM  2/11/16  updated based on IW's email sent 2/11/16
    -- updating definition information 
    UPDATE [LookUp].[ColumnDescriptions] 
    SET PrintName = 'Medical Indications for Benzodiazepine',
        Category = 'Medical Indications',
        ColumnDescription = 'Medical Indications for Benzodiazepine',
		DefinitionOwner= 'NEPEC'
    WHERE TableName = @TableName AND ColumnName = 'MedIndBenzodiazepine';

	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage 
    SET MedIndBenzodiazepine = 1 
    WHERE  ICD10Code like 'F51.0%'  -- insomnias
		OR ICD10Code between 'G40.1%' and 'G40.99%'  -- epilepsy OK 2/10
		OR ICD10Code like 'G47.0%' -- insomnia
		OR ICD10Code like 'G47.2%'  -- CIRCADIAN RHYTHM SLEEP DISORDERs
		OR ICD10Code like 'M62.4%'  -- contracture with all sites Ok 2/10
		OR ICD10Code like 'M62.83%'  -- muscle spasm OK 2/10
		OR ICD10Code in (
		     'F51.12' --INSUFFICIENT SLEEP SYNDROME
			,'F51.3' --SLEEPWALKING [SOMNAMBULISM]
			,'F51.8' --OTHER SLEEP DISORDERS NOT DUE TO A SUBSTANCE OR KNOWN PHYSIOLOGICAL CONDITION
			,'F51.9' --SLEEP DISORDER NOT DUE TO A SUBSTANCE OR KNOWN PHYSIOLOGICAL CONDITION, UNSPECIFIED
			,'G47.30' --SLEEP APNEA, UNSPECIFIED	
			,'G47.52%' --REM SLEEP BEHAVIOR DISORDER 
			,'G47.8' --OTHER SLEEP DISORDERS
			,'G47.9' --SLEEP DISORDER, UNSPECIFIED	 
			,'G52.1' -- DISORDERS OF GLOSSOPHARYNGEAL NERVE
			,'M62.40' --CONTRACTURE OF MUSCLE, UNSPECIFIED SITE
			,'R25.2' --CRAMP AND SPASM
			,'R25.9' --UNSPECIFIED ABNORMAL INVOLUNTARY MOVEMENTS
		)

/****** OpioidOverdose  same as SAE_Opioid   ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions] 
    SET PrintName = 'Opioid Overdose or Adverse Events',
        Category = 'Substance Use Disorder',
        ColumnDescription = 'Opioid Overdose', -- remover or adverse events since this variable is specific to opioid overdose
		DefinitionOwner= 'ORM'
    WHERE TableName = @TableName AND ColumnName = 'OpioidOverdose';

	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage
	SET OpioidOverdose= 1
	WHERE  ICD10Code between 'T40.0X1' and 'T40.0X6' 
		OR ICD10Code between 'T40.1X1' and 'T40.1X5'  
		OR ICD10Code between 'T40.2X1' and 'T40.2X6'  
		OR ICD10Code between 'T40.3X1' and 'T40.3X6'  
		OR ICD10Code between 'T40.4X1' and 'T40.4X6'  
		OR ICD10Code between 'T40.601' and 'T40.606'  
		OR ICD10Code between 'T40.691' and 'T40.696'

 
/****** OtherMH     ******************/
--OtherMH (1/11/16 MP revised to vetted def); 2017-10-30 RAS removed duplicates
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Other MH Disorders',
		Category = 'Mental Health',
		ColumnDescription = 'Other mental health',
		DefinitionOwner= 'OMHO Master File'
	WHERE TableName = @TableName AND ColumnName = 'OtherMH'

	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage
	SET OtherMH = 1
	WHERE LEFT(ICD10Code,3) in ('F44','F50','F63','F90','F91')
		OR LEFT(ICD10Code,5) in ('R45.7'
				,'F43.0','F43.2','F43.8','F43.9'
				,'F45.0','F45.1','F45.8','F45.9'
				,'F48.1'
				,'F68.1'
			)  
		OR LEFT(ICD10Code,6) = 'F45.22'

/****** OUD     ******************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Opioid',
		Category = 'Substance Use Disorder',
		ColumnDescription = 'Opioid Use Disorder',
		DefinitionOwner= 'OMHO Master File'
	WHERE TableName = @TableName AND ColumnName = 'OUD' 
 
	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage 
	SET OUD = 1 
	WHERE LEFT(ICD10Code,3) in ('F11') 
		AND ICD10Code not like 'F11.9%'

/****** Psych - Other Psychosis ******************/
--1/11/16 MP revised to OPSYdx_poss def in Master File 
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Other Psychosis',
		Category = 'Mental Health',
		ColumnDescription = 'Other Psychosis',
		DefinitionOwner= 'OMHO Master File'
	WHERE TableName = @TableName AND ColumnName = 'Psych'

	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage
	SET Psych = 1 
	WHERE LEFT(ICD10Code,5) in ('F06.0','F06.2') 
		OR LEFT(ICD10Code,3) in ('F22', 'F23', 'F24','F28','F29','F53') 
 
/****** Psych_poss     ******************/
-- PsychDX_poss=Case When (OtherMH + SMI_POSS +MDDdx_poss + PERSNdx_poss + ODEPRdx_poss + ANXgen_poss + ANXunsp_poss)>0 (defintion in Master file)
    -- updating definition information 
 --   UPDATE [LookUp].[ColumnDescriptions] 
 --   SET PrintName = 'Other MH Disorder', 
 --       Category = 'Mental Health', 
 --       ColumnDescription = 'Any MH diagnosis excluding SUD', 
	--	DefinitionOwner= 'OMHO Master File' 
 --   WHERE TableName = @TableName AND ColumnName = 'Psych_poss'
 
	---- updating field flag
	--UPDATE ##LookUp_ICD10_Stage 
	--SET Psych_poss = 1 
	--WHERE  LEFT(ICD10Code,6) in ('F45.20','F45.21','F45.29') or LEFT(ICD10Code,5) in ('F06.4','F41.0', 'F41.3','F41.8','F41.9') or LEFT(ICD10Code,3) in  ('F40','F42') --ANXunsp_poss updated 1/11/16 MP  
	--	OR LEFT(ICD10Code,5) in ('F41.1') --ANXgen_poss 
	--	OR LEFT(ICD10Code,5) in ('F34.1','F32.8','F33.8') or LEFT(ICD10Code,6) in ('F06.31','F06.32') --ODEPRdx_poss (1/11/16 MP revised) 
	--	OR LEFT(ICD10Code,3) in ('F60', 'F69','F21') or LEFT(ICD10Code,5) in ('F68.8')  --PERSNdx_poss (1/11/16 MP revised to Aaron's def) 
	--	OR (
	--		LEFT(ICD10Code,3) in ('F32','F33') AND LEFT(ICD10Code,5) not in ('F32.8','F33.8')
	--		)  --MDDdx_poss (1/11/16 MP revised to Aaron's vetted def) 
	--	OR LEFT(ICD10Code,5) in ('F06.0','F06.2') or LEFT(ICD10Code,3) in ('F20','F22', 'F23', 'F24','F25','F28','F29','F30', 'F31','F53')  --SMI_POSS (1/11/16 MP revised to Aaron's vetted def) 
	--	OR LEFT(ICD10Code,3) in ('F44','F50','F63','F90','F91')  
	--	OR LEFT(ICD10Code,5) in ('R45.7','F43.0','F43.8','F43.9','F44.0','F44.1','F44.2','F44.4','F44.5','F44.6','F44.7','F44.8','F44.9','F45.0','F45.1','F45.8'
	--		,'F45.9','F48.1','F50.0','F50.2','F50.8','F50.9','F63.0','F63.1','F63.2','F63.3','F63.8','F63.9','F68.1','F90.0','F90.1','F90.2','F90.8','F90.9'
	--		,'F91.0','F91.1','F91.2','F91.3','F91.8','F91.9','F43.2','F43.8','F43.9') 	  
	--	OR LEFT(ICD10Code,3) in  ('F34')
	--	OR LEFT(ICD10Code,6) in ('F44.81','F44.89','F45.22','F50.00','F50.01','F50.02','F63.81','F63.89','F43.20','F43.24','F43.29','F43.25','F45.22') --OtherMH (1/11/16 MP revised to vetted def)
 
/****** PTSD     ******************/
     -- updating definition information 
     UPDATE [LookUp].[ColumnDescriptions] 
     SET PrintName = 'PTSD',
         Category = 'Mental Health',
         ColumnDescription = 'PTSD',
		 DefinitionOwner= 'OMHO Master File'
     WHERE TableName = @TableName AND ColumnName = 'PTSD'

     -- updating field flag
	 UPDATE ##LookUp_ICD10_Stage 
     SET PTSD = 1 
     WHERE LEFT(ICD10Code,5) in ('F43.1') 
  

/****** SAE_OtherDrug     ******************/         
    -- updating definition information 
    UPDATE [LookUp].[ColumnDescriptions] 
    SET PrintName = 'Related to drugs',
        Category = 'Adverse Event',
        ColumnDescription = 'Serious adverse event related to other drugs',
		DefinitionOwner= 'ORM'
    WHERE TableName = @TableName AND ColumnName = 'SAE_OtherDrug'
	 
    -- updating field flag
	UPDATE ##LookUp_ICD10_Stage 
    SET SAE_OtherDrug= 1 
    WHERE ICD10Code between 'T50.7X1' and 'T50.7X6' 
		OR ICD10Code between 'T40.7X1' and 'T40.7X6' 
		OR ICD10Code between 'T40.8X1' and 'T40.8X5' 
		or ICD10Code between 'T44.901' and 'T44.905' 
		OR ICD10Code between 'T44.991' and 'T44.996' 
		OR ICD10Code between 'T50.7X1' and 'T50.7X6'
		OR ICD10code BETWEEN 'T39.011%'  AND 'T39.015S'  --updated 6/5 per JT request
		OR ICD10code BETWEEN 'T39.091%'  AND 'T39.095S'  --updated 6/5 per JT request 
		OR ICD10code BETWEEN 'T39.4X1%'  AND 'T39.4X5S'  --updated 6/5 per JT request
		OR ICD10code BETWEEN 'T40.5X1%'  AND 'T40.5X5S'  --updated 6/5 per JT request
		OR ICD10code BETWEEN 'T40.901%'  AND  'T40.905S'  --updated 6/5 per JT request 
		OR ICD10code BETWEEN 'T40.991%'  AND  'T40.995S'  --updated 6/5 per JT request 
		OR ICD10code BETWEEN 'T43.011%'  AND 'T43.015S'  --updated 6/5 per JT request
		OR ICD10code BETWEEN 'T43.021%'  AND 'T43.025S'  --updated 6/5 per JT request 
		OR ICD10code BETWEEN 'T43.1X1%'  AND 'T43.1X5S'  --updated 6/5 per JT request
		OR ICD10code BETWEEN 'T43.201%'  AND  'T43.205S'   --updated 6/5 per JT request 
		OR ICD10code BETWEEN 'T43.211%'  AND 'T43.215S'  --updated 6/5 per JT request 
		OR ICD10code BETWEEN 'T43.221%'  AND 'T43.225S'  --updated 6/5 per JT request 
		OR ICD10code BETWEEN  'T43.291%'  AND 'T43.295S'  --updated 6/5 per JT request 
		OR ICD10code BETWEEN  'T43.601%'  AND 'T43.605S'  --updated 6/5 per JT request 
		OR ICD10code BETWEEN  'T43.621%'  AND 'T43.625S'  --updated 6/5 per JT request
		OR ICD10code BETWEEN  'T43.691%'  AND 'T43.695S'  --updated 6/5 per JT request
		OR ICD10code like 'T44.905%'    --updated 6/5 per JT request
  
/****** SAE_sed     ******************/          
    -- updating definition information 
    UPDATE [LookUp].[ColumnDescriptions] 
    SET PrintName = 'Related to sedatives',
        Category = 'Adverse Event',
        ColumnDescription = 'Serious adverse event with sedatives',
		DefinitionOwner= 'ORM'
    WHERE TableName = @TableName AND ColumnName = 'SAE_sed'   
	 
	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage 
    SET SAE_sed = 1 
    WHERE ICD10Code between 'T41.0X' and 'T41.0X6'  
		OR ICD10Code between 'T41.1X' and 'T41.1X6' 
		OR ICD10Code between 'T41.20' and 'T41.206'  
		OR ICD10Code between 'T41.29' and 'T41.296'  
		OR ICD10Code between 'T41.3X' and 'T41.3X6'  
		OR ICD10Code between 'T41.4' and 'T41.46' 
		OR ICD10Code between 'T42.3X1' and 'T42.3X6' 
		OR ICD10Code between 'T42.6X1' and 'T42.6X6' 
		OR ICD10Code between 'T42.8X1' and 'T42.8X6' 
		OR ICD10Code between 'T43.3X1' and 'T43.3X6' 
		OR ICD10Code between 'T43.4X1' and 'T43.4X6'  
		OR ICD10Code between 'T43.501' and 'T43.506' 
		OR ICD10Code between 'T43.591' and 'T43.596' 
		OR ICD10Code between 'T42.4X1' and 'T42.4X6'  
		OR ICD10Code between 'T43.591' and 'T43.596' 
		OR ICD10Code between 'T41.5' and 'T41.56'

  
/****** SedateIssue     ******************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Related to sedatives',
		Category = 'Adverse Event',
		ColumnDescription = 'SedateIssue combines falls, vehicle and other accidents',
		DefinitionOwner= 'ORM'
	WHERE TableName = @TableName AND ColumnName = 'SedateIssue';
 
	-- updating field flag
	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage 
	SET SedateIssue = 1 
	WHERE SAE_Falls=1 OR SAE_Vehicle=1 OR SAE_OtherAccident=1
 
     
     
/****** SUD_NoOUD_NoAUD     ******************/
--other SUD (MISSING) - added inhalant and hallucinogen UDs as other SUD
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Other SUD',
		Category = 'Substance Use Disorder',
		ColumnDescription = 'Substance Use Disorder other any OUD or AUD',
		DefinitionOwner= 'OMHO Master File'
	WHERE TableName = @TableName AND ColumnName = 'SUD_NoOUD_NoAUD'
	
	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage  
	SET SUD_NoOUD_NoAUD = 1 
	WHERE  LEFT(ICD10Code,3) in  ('F14')  --COCNdx_poss
		--OR LEFT(ICD10Code,3) in  ('F12')  --CANNdx_poss --Not sure why this was added in the first place
		OR LEFT(ICD10Code,3) in  ('F15') -- other stimulant
		OR LEFT(ICD10Code,3) in  ('F13')  --Barbdx_poss 
		OR LEFT(ICD10Code,3) in  ('F16')  -- hallucinogen UD
		OR LEFT(ICD10Code,3) in  ('F18') -- inhalant UD

/****** SUDdx_poss     ******************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Substance Use Disorder',
		Category = 'Substance Use Disorder - Duplicate',
		ColumnDescription = 'SUD Diagnosis',
		DefinitionOwner= 'OMHO Master File'
	WHERE TableName = @TableName AND ColumnName = 'SUDdx_poss';
	
	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage 
	SET SUDdx_poss = 1 
	WHERE  LEFT(ICD10Code,3) in ('F10', 'F11','F12', 'F13', 'F14','F15','F16', 'F18','F19') -- (1/11/16 MP revised to Aaron's vetted def)
	
	--F10 AUD, F11 OUD
 
/****************SUD no AUD no OUD no cannabis no hallucinogen no stimulant no Cocaine no Sed for ORM ST 12/7/15************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Other SUD Diagnosis',
		Category = 'Substance Use Disorder',
		ColumnDescription = 'OTHER SUD no AUD no OUD no cannabis no hallucinogen no stimulant no cocaine',
		DefinitionOwner= 'OMHO Master File'
	WHERE TableName = @TableName AND ColumnName = 'OtherSUD_RiskModel'; 
	
	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage  
	SET OtherSUD_RiskModel = 1 
	WHERE  LEFT(ICD10Code,3) in ('F18')

/****** Suicide  Attempt   ******************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Suicide Attempt',
		Category = 'Mental Health',
		ColumnDescription = 'Suicide, includes sequela, initial and subsequent ',
		DefinitionOwner= 'ORM'
	WHERE TableName = @TableName AND ColumnName = 'SuicideAttempt';
 
	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage  
	SET SuicideAttempt = 1 
	WHERE 
	(
		ICD10Code between 'X71' and 'X84'
		or ICD10Code like 'T14.91%' 
		--	or ICD10Code like'R45.851%' -- suicide ideation
		or ((ICD10Code between 'T36.0X2' and 'T65.9') and ICD10Code like 'T__.__2%')
		or ((ICD10Code between 'T36.92X' and 'T72') and ICD10Code like 'T__._2X%')
		or ((ICD10Code between 'T71.112' and 'T72') and ICD10Code like 'T__.__2%') 
		)
		AND ICD10code not like 'T67%' -- SM removing heat exhaustion

/****** Suicide     ******************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Suicide or Overdose Related Event',
		Category = 'Mental Health',
		ColumnDescription = 'Suicide, includes suicide ideation, sequela, initial and subsequent; or overdose, includes accidental', 
		DefinitionOwner= 'ORM'
	WHERE ColumnName = 'Suicide'

	-- updating field flag
	UPDATE ##LookUp_ICD10_Stage  
	SET Suicide = 1 
	WHERE 
	(
		ICD10Code between 'X71' and 'X84'
		or ICD10Code like 'T14.91%' 
		or ICD10Code like'R45.851%'
		or ((ICD10Code between 'T36.0X2' and 'T65.9') and ICD10Code like 'T__.__2%')
		or ((ICD10Code between 'T36.92X' and 'T72') and ICD10Code like 'T__._2X%')
		or ((ICD10Code between 'T71.112' and 'T72') and ICD10Code like 'T__.__2%')  
		)
	AND ICD10code not like 'T67%' -- LM removing heat exhaustion



	
/*** PDE Overdose and Poison **************/ 
	-- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Overdose and Poison',
		Category = 'MHIS',
		ColumnDescription = 'Definition from MHIS for post discharge engagement data. Overdoses and poisonings involving intentional self-harm.',             
		DefinitionOwner = 'David/Paty'
	WHERE TableName = @TableName AND ColumnName = 'PDE_OverdoseAndPoison'
  
	-- updating variable flag
	UPDATE ##LookUp_ICD10_Stage
    SET  PDE_OverdoseAndPoison=1
    WHERE ICD10Code IN ( --T36.0 to T65.9 when coded as an initial treatment encounter for intentional self-harm
		'T36.0X2A', 'T36.1X2A', 'T36.2X2A', 'T36.3X2A', 'T36.4X2A', 'T36.5X2A', 'T36.6X2A', 'T36.7X2A', 'T36.8X2A', 'T36.9X2A', 
		'T37.0X2A', 'T37.1X2A', 'T37.2X2A', 'T37.3X2A', 'T37.4X2A', 'T37.5X2A', 'T37.8X2A', 'T37.9X2A', 
		'T38.0X2A', 'T38.1X2A', 'T38.2X2A', 'T38.3X2A', 'T38.4X2A', 'T38.5X2A', 'T38.6X2A', 'T38.7X2A', 'T38.8X2A', 'T38.9X2A', 
		'T39.0X2A', 'T39.0X2A', 'T39.1X2A', 'T39.2X2A', 'T39.3X2A', 'T39.4X2A', 'T39.8X2A', 'T39.9X2A', 
		'T40.0X2A', 'T40.1X2A', 'T40.2X2A', 'T40.3X2A', 'T40.4X2A', 'T40.5X2A', 'T40.6X2A', 'T40.7X2A', 'T40.8X2A', 'T40.9X2A', 
		'T41.0X2A', 'T41.1X2A', 'T41.2X2A', 'T41.3X2A', 'T41.4X2A', 'T41.5X2A', 
		'T42.0X2A', 'T42.1X2A', 'T42.2X2A', 'T42.3X2A', 'T42.4X2A', 'T42.5X2A', 'T42.6X2A', 'T42.7X2A', 'T42.8X2A', 
		'T43.0X2A', 'T43.1X2A', 'T43.2X2A', 'T43.2X2A', 'T43.2X2A', 'T43.3X2A', 'T43.4X2A', 'T43.5X2A', 'T43.6X2A', 'T43.8X2A', 'T43.9X2A', 
		'T44.0X2A', 'T44.1X2A', 'T44.2X2A', 'T44.3X2A', 'T44.4X2A', 'T44.5X2A', 'T44.6X2A', 'T44.7X2A', 'T44.8X2A', 'T44.9X2A', 
		'T45.0X2A', 'T45.1X2A', 'T45.2X2A', 'T45.3X2A', 'T45.4X2A', 'T45.5X2A', 'T45.6X2A', 'T45.7X2A', 'T45.8X2A', 'T45.9X2A', 
		'T46.0X2A', 'T46.1X2A', 'T46.2X2A', 'T46.3X2A', 'T46.4X2A', 'T46.5X2A', 'T46.6X2A', 'T46.7X2A', 'T46.8X2A', 'T46.9X2A', 
		'T47.0X2A', 'T47.1X2A', 'T47.2X2A', 'T47.3X2A', 'T47.4X2A', 'T47.5X2A', 'T47.6X2A', 'T47.7X2A', 'T47.8X2A', 'T47.9X2A', 
		'T48.0X2A', 'T48.1X2A', 'T48.2X2A', 'T48.3X2A', 'T48.4X2A', 'T48.5X2A', 'T48.6X2A', 'T48.9X2A',
		'T49.0X2A', 'T49.1X2A', 'T49.2X2A', 'T49.3X2A', 'T49.4X2A', 'T49.5X2A', 'T49.6X2A', 'T49.7X2A', 'T49.8X2A', 'T49.9X2A', 
		'T50.0X2A', 'T50.1X2A', 'T50.2X2A', 'T50.3X2A', 'T50.4X2A', 'T50.5X2A', 'T50.6X2A', 'T50.7X2A', 'T50.8X2A', 'T50.9X2A', 
		'T51.0X2A', 'T51.1X2A', 'T51.2X2A', 'T51.3X2A', 'T51.8X2A', 'T51.9X2A', 
		'T52.0X2A', 'T52.1X2A', 'T52.2X2A', 'T52.3X2A', 'T52.4X2A', 'T52.8X2A', 'T52.9X2A', 
		'T53.0X2A', 'T53.1X2A', 'T53.2X2A', 'T53.3X2A', 'T53.4X2A', 'T53.5X2A', 'T53.6X2A', 'T53.7X2A', 'T53.9X2A', 
		'T54.0X2A', 'T54.1X2A', 'T54.2X2A', 'T54.3X2A', 'T54.9X2A', 
		'T55.0X2A', 'T55.1X2A', 
		'T56.0X2A', 'T56.1X2A', 'T56.2X2A', 'T56.3X2A', 'T56.4X2A', 'T56.5X2A', 'T56.6X2A', 'T56.7X2A', 'T56.8X2A', 'T56.9X2A', 
		'T57.0X2A', 'T57.1X2A', 'T57.2X2A', 'T57.3X2A', 'T57.8X2A', 'T57.9X2A', 
		'T58.0X2A', 'T58.1X2A', 'T58.2X2A', 'T58.8X2A', 'T58.9X2A', 
		'T59.0X2A', 'T59.1X2A', 'T59.2X2A', 'T59.3X2A', 'T59.4X2A', 'T59.5X2A', 'T59.6X2A', 'T59.7X2A', 'T59.8X2A', 'T59.8X2A', 'T59.9X2A', 
		'T60.0X2A', 'T60.1X2A', 'T60.2X2A', 'T60.3X2A', 'T60.4X2A', 'T60.8X2A', 'T60.9X2A', 
		'T61.0X2A', 'T61.1X2A', 'T61.7X2A', 'T61.8X2A', 'T61.9X2A', 
		'T62.0X2A', 'T62.1X2A', 'T62.2X2A', 'T62.8X2A', 'T62.9X2A', 
		'T63.0X2A', 'T63.1X2A', 'T63.2X2A', 'T63.3X2A', 'T63.4X2A', 'T63.5X2A', 'T63.6X2A', 'T63.7X2A', 'T63.8X2A', 'T63.9X2A', 
		'T64.0X2A', 'T64.8X2A', 
		'T65.0X2A', 'T65.1X2A', 'T65.2X2A', 'T65.3X2A', 'T65.4X2A', 'T65.5X2A', 'T65.6X2A', 'T65.8X2A', 'T65.9X2A'
		)   	

/*** PDE External Causes **************/
 
  -- updating definition information
       UPDATE [LookUp].[ColumnDescriptions]
        SET PrintName = 'External Causes of Self Harm',
			Category = 'MHIS',
			ColumnDescription = 'Definition from MHIS for post discharge engagement data. External causes of injury when involving intentional self-harm.',             
			DefinitionOwner = 'David/Paty'
		WHERE TableName = @TableName AND ColumnName = 'PDE_ExternalCauses';
 
  -- updating variable flag
	  UPDATE ##LookUp_ICD10_Stage
       SET  PDE_ExternalCauses=1
       WHERE ICD10Code in(
	   	   'T71.112A','T71.122A','T71.132A','T71.152A','T71.162A','T71.192A','X71.0XXA','X71.1XXA','X71.2XXA','X71.3XXA','X71.8XXA','X71.9XXA'
		  ,'X72.XXXA','X73.0XXA','X73.1XXA','X73.2XXA','X73.8XXA','X73.9XXA'
		  ,'X74.01XA','X74.02XA','X74.09XA','X74.8XXA','X74.9XXA','X75.XXXA'
		  ,'X76.XXXA','X77.0XXA','X77.1XXA','X77.2XXA','X77.3XXA','X77.8XXA','X77.9XXA'
		  ,'X78.0XXA','X78.1XXA','X78.2XXA','X78.8XXA','X78.9XXA','X78.0XXA','X78.1XXA','X78.2XXA','X78.8XXA','X78.9XXA','X79.XXXA'
		  ,'X80.XXXA','X81.0XXA','X81.1XXA','X81.8XXA'
		  ,'X82.0XXA','X82.1XXA','X82.2XXA','X82.8XXA','X82.0XXA','X82.1XXA','X82.2XXA','X82.8XXA'
		  ,'X83.0XXA','X83.1XXA','X83.2XXA','X83.8XXA'
		) ;  

/*** PDE Suicide Related **************/

  -- updating definition information
       UPDATE [LookUp].[ColumnDescriptions]
        SET PrintName = 'Suicide related symptoms or behaviors',
			Category = 'MHIS',
			ColumnDescription = 'Definition from MHIS for post discharge engagement data',             
			DefinitionOwner = 'David/Paty'
		WHERE TableName = @TableName AND ColumnName = 'PDE_SuicideRelated';
 
  -- updating variable flag
	  UPDATE ##LookUp_ICD10_Stage
       SET  PDE_SuicideRelated=1
       WHERE ICD10Code IN ('T14.91', 'R45.851')

/*** Suicide attempts**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Any suicide attempt', 
		Category = 'Mental Health', 
		ColumnDescription = 'Any suicide attempt, definition taken from PWC code [VACI_IRDS].[ETL].[ICD10Codes] - keeping same variable name excludes suicide ideation and sequela',
		DefinitionOwner = 'PWC' 
	WHERE TableName = @TableName AND ColumnName = 'Reach_attempt'

	-- updating variable flag 
	UPDATE ##LookUp_ICD10_Stage 
	SET  Reach_attempt=1 
	WHERE (ICD10Description like '%SUICIDE ATTEMPT%' OR ICD10Description LIKE '%INTENTIONAL SELF-HARM%') 
		AND ICD10Description not like '%SEQUELA%'
 
/*** Arthritis**************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Arthritis', 
		Category = 'Medical', 
		ColumnDescription = 'Arthritis, definition taken from PWC code [VACI_IRDS].[ETL].[ICD10Codes] - keeping same variable name',
		DefinitionOwner = 'PWC' 
	WHERE TableName = @TableName AND ColumnName = 'Reach_arth'
 
  -- updating variable flag 
	UPDATE ##LookUp_ICD10_Stage 
	SET  Reach_arth=1 
	WHERE (ICD10Code in ('M99.80','M99.81','M99.82','M99.83','M99.84','M99.85','M99.86','M99.87','M99.88','M99.89') OR
		(ICD10Code='R25.2') OR
		(ICD10Code='R29.898') OR
		(ICD10Code='M85.2') OR
		(ICD10Code='M35.7') OR
		(ICD10Code='S42.009P') OR
		(ICD10Code='S42.209P') OR
		(ICD10Code='S42.90XP') OR
		(ICD10Code='S52.90XP') OR
		(ICD10Code='S52.90XQ') OR
		(ICD10Code='S52.90XR') OR
		(ICD10Code='S62.90XP') OR
		(ICD10Code='S72.90XP') OR
		(ICD10Code='S72.90XQ') OR
		(ICD10Code='S72.90XR') OR
		(ICD10Code='S82.009P') OR
		(ICD10Code='S82.009Q') OR
		(ICD10Code='S82.009R') OR
 		(ICD10Code='S82.90XP') OR
 		(ICD10Code='S82.90XQ') OR
 		(ICD10Code='S82.90XR') OR
 		(ICD10Code='S92.819P') OR
 		(ICD10Code='S92.909P') OR
 		(ICD10Code='S92.919P') OR
 		(ICD10Code='S99.209P') OR (ICD10Code='S99.219P') OR (ICD10Code='S99.229P') OR (ICD10Code='S99.239P') OR (ICD10Code='S99.249P') OR (ICD10Code='S99.299P') OR
 		(ICD10Code='D48.1') OR
 		(ICD10Code LIKE 'M00%') OR (ICD10Code LIKE 'M02%') OR (ICD10Code LIKE 'M05%') OR
 		(ICD10Code LIKE 'M11%') OR (ICD10Code LIKE 'M12%') OR (ICD10Code LIKE 'M15%') OR 
		(ICD10Code LIKE 'M20%') OR (ICD10Code LIKE 'M21%') OR (ICD10Code LIKE 'M24%') OR (ICD10Code LIKE 'M25 %') OR
 		(ICD10Code LIKE 'M40%') OR (ICD10Code LIKE 'M41%') OR (ICD10Code LIKE 'M43%') OR 
		(ICD10Code LIKE 'M60%') OR (ICD10Code LIKE 'M61%') OR (ICD10Code LIKE 'M62%') OR (ICD10Code LIKE 'M66%') OR (ICD10Code LIKE 'M67%') OR
 		(ICD10Code LIKE 'M70%') OR (ICD10Code LIKE 'M71%') OR 
 		(ICD10Code LIKE 'M72%') OR
 		(ICD10Code LIKE 'M79%') OR
 		(ICD10Code LIKE 'M81%') OR
 		(ICD10Code LIKE 'M84%') OR
 		(ICD10Code LIKE 'M86%') OR
 		(ICD10Code LIKE 'M87%') OR
 		(ICD10Code LIKE 'M89%') OR
 		(ICD10Code LIKE 'M90%') OR
 		(ICD10Code LIKE 'M91%') OR
 		(ICD10Code LIKE 'M92%') OR
 		(ICD10Code LIKE 'M93%') OR
 		(ICD10Code LIKE 'M94%') OR
 		(ICD10Code LIKE 'M95%') OR
 		(ICD10Code LIKE 'M85.4%') OR
 		(ICD10Code LIKE 'M85.5%') OR
 		(ICD10Code LIKE 'M86.5%') OR
 		(ICD10Code LIKE 'M85.3%')
		)
 
/*** Bipolar I**************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Bipolar I',
		Category = 'Mental Health',
		ColumnDescription = 'Bipolar I, definition taken from PWC code [VACI_IRDS].[ETL].[ICD10Codes] - keeping same variable name',										  
		DefinitionOwner = 'PWC'
	WHERE TableName = @TableName AND ColumnName = 'Reach_bipolI'
 
	-- updating variable flag 
	UPDATE ##LookUp_ICD10_Stage 
	SET  Reach_bipolI=1 
	WHERE (ICD10Code LIKE 'F30.%' OR ICD10Code LIKE 'F31.%') 
		AND ICD10Code NOT LIKE 'F31.8%'  
		AND ICD10Code NOT LIKE 'F31.9%' 
 
/*** Head and Neck Cancer**************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'cancer of the head/neck region', 
		Category = 'Medical', 
		ColumnDescription = 'Cancer of the head/neck region, definition taken from PWC code [VACI_IRDS].[ETL].[ICD10Codes] - keeping same variable name',
		DefinitionOwner = 'PWC' 
	WHERE TableName = @TableName AND ColumnName = 'Reach_ca_head'
 
	-- updating variable flag 
	UPDATE ##LookUp_ICD10_Stage 
	SET  Reach_ca_head=1 
	WHERE  ICD10Code LIKE 'C0%' 
		OR ICD10Code LIKE 'C10%' 
		OR ICD10Code LIKE 'C11%' 
		OR ICD10Code LIKE 'C12%' 
		OR ICD10Code LIKE 'C13%' 
		OR ICD10Code LIKE 'C14%' 
		OR ICD10Code LIKE 'C15%' 
		OR ICD10Code LIKE 'C30%' 
		OR ICD10Code LIKE 'C31%' 
		OR ICD10Code LIKE 'C32%' 
		OR ICD10Code LIKE 'C41%' /*this is incorrect but we are leaving it in the match the ICD9 codes*/ 
		OR ICD10Code LIKE 'C69.6%' 
		OR ICD10Code LIKE 'C69.8%' 
		OR ICD10Code LIKE 'C69.9%' 
		OR ICD10Code LIKE 'C72%' 
		OR ICD10Code LIKE 'C76.0'
 
 /*** Chronic Pain**************/ 
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Chronic Pain', 
		Category = 'Medical', 
		ColumnDescription = 'Chronic Pain, definition taken from PWC code [VACI_IRDS].[ETL].[ICD10Codes] - keeping same variable name',
		DefinitionOwner = 'PWC'
	WHERE TableName = @TableName AND ColumnName = 'Reach_chronic'      
 
	-- updating variable flag 
	UPDATE ##LookUp_ICD10_Stage 
	SET  Reach_chronic=1 
	WHERE ICD10Code = 'G89.0' 
		OR ICD10Code like 'G89.2%' 
		OR ICD10Code = 'G89.4'
		--OR ICD10Code = 'G89.3' --12.27.16 deleted this based on Claire Hanemann's observation that this was not included in ICD9 original model
 
/*** Depression**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Depression - MDD and other depression', 
		Category = 'Mental Health - Duplicate', 
		ColumnDescription = 'Depression, definition taken from PWC code [VACI_IRDS].[ETL].[ICD10Codes] - keeping same variable name',
		DefinitionOwner = 'PWC' 
	WHERE TableName = @TableName AND ColumnName = 'Reach_dep'
 
	-- updating variable flag
    UPDATE ##LookUp_ICD10_Stage 
    SET  Reach_dep=1 
    WHERE  ICD10Code LIKE 'F06.31' 
		OR ICD10Code LIKE 'F06.32' 
		OR ICD10Code LIKE 'F32.%' 
		OR ICD10Code LIKE 'F33.%' 
		OR ICD10Code LIKE 'F34.1'
 
/*** Diabetes**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Diabetes',
		Category = 'Medical',
		ColumnDescription = 'Diabetes, definition taken from PWC code [VACI_IRDS].[ETL].[ICD10Codes] - keeping same variable name', 
		DefinitionOwner = 'PWC' 
	WHERE TableName = @TableName AND ColumnName = 'Reach_dm'
  
	-- updating variable flag
    UPDATE ##LookUp_ICD10_Stage 
    SET  Reach_dm=1 
    WHERE ICD10Code like 'E10.%'  
		OR ICD10Code like 'E11.%'  
		OR ICD10Code like 'E13.%'
 
	--ask Susana about EH defn - why it doesnt include some codes
 
 /*** Systemic Lupus**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Systemic lupus', 
		Category = 'Medical', 
		ColumnDescription = 'Systemic lupus, definition taken from PWC code [VACI_IRDS].[ETL].[ICD10Codes] - keeping same variable name' , 
		DefinitionOwner = 'PWC'
	WHERE TableName = @TableName AND ColumnName = 'Reach_sle'
			    
	-- updating variable flag 
	UPDATE ##LookUp_ICD10_Stage 
	SET Reach_sle=1 
	WHERE ICD10Code like 'M32.%' 
		OR ICD10Code like 'M33.%' 
		OR ICD10Code like 'M34.%' 
		OR ICD10Code like 'M35.%'  
	--do we want to include M33-M35?

 
/*** Substance Use Disorder**************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Substance use disorder', 
        Category = 'Substance Use Disorder - Duplicate', 
        ColumnDescription = 'Substance Use Disorder, definition taken from PWC code [VACI_IRDS].[ETL].[ICD10Codes] - keeping same variable name',
 		DefinitionOwner = 'PWC' 
	WHERE TableName = @TableName AND ColumnName = 'Reach_sud'

	-- updating variable flag 
    UPDATE ##LookUp_ICD10_Stage 
    SET  Reach_sud=1 
    WHERE  ICD10Code LIKE 'F10.%'  
		OR ICD10Code LIKE 'F11.%' 
		OR ICD10Code LIKE 'F12.%' 
		OR ICD10Code LIKE 'F13.%' 
		OR ICD10Code LIKE 'F14.%' 
		OR ICD10Code LIKE 'F15.%' 
		OR ICD10Code LIKE 'F16.%' 
		OR ICD10Code LIKE 'F18.%' 
		OR ICD10Code LIKE 'F19.%'
 
/*** Other Anxiety Disorder**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Anxiety Disorder', 
        Category = 'Mental Health', 
        ColumnDescription = ' Other Anxiety Disorder definition taken from PWC code [VACI_IRDS].[ETL].[ICD10Codes] - keeping same variable name', 
		DefinitionOwner = 'PWC' 
	WHERE TableName = @TableName AND ColumnName = 'REACH_othanxdis'
 
	-- updating variable flag 
    UPDATE ##LookUp_ICD10_Stage 
    SET  REACH_othanxdis=1 
    WHERE  ICD10Code LIKE 'F40.%' 
		OR ICD10Code LIKE 'F41.%' 
		OR ICD10Code = 'F44.9'
 
 /*** Personaltiy Disorder**************/
    -- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Personality disorder', 
		Category = 'Mental Health', 
		ColumnDescription = 'Personality disorder, definition taken from PWC code [VACI_IRDS].[ETL].[ICD10Codes] - keeping same variable name', 
		DefinitionOwner = 'PWC' 
    WHERE TableName = @TableName AND ColumnName = 'Reach_persond'

	-- updating variable flag 
    UPDATE ##LookUp_ICD10_Stage 
    SET  Reach_persond=1 
    WHERE  ICD10Code LIKE 'F21.%'  
		OR ICD10Code LIKE 'F60.%'
		OR ICD10Code LIKE 'F68.8%' 
		OR ICD10Code LIKE 'F69.%'
    


 
--------------------------------------------------------------------------------------------------------------
/***KEEP these codes at the bottom because they reference updates made above ***************/
--------------------------------------------------------------------------------------------------------------
 
/***************MHorMedInd_AD*************************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'MH or medical indication for Antidepressant', 
		Category = 'Drug Indication', 
		ColumnDescription = 'MH or medical indication for Antidepressant', 
		DefinitionOwner = 'OMHO' --AR 1/8/16 Changed to OMHO VISN21 has never owned the definition of this measure 
	WHERE TableName = @TableName AND ColumnName = 'MHorMedInd_AD';
 
	-- updating variable flag  
	UPDATE ##LookUp_ICD10_Stage 
	SET MHorMedInd_AD = 1 
	WHERE MHSUDdx_poss=1 --12/18/15 SM updated from mutiple categories to MHSUDdx_poss 
		OR [MedIndAntiDepressant]=1 
 
/***************MHorMedInd_Benzo*************************/
--Reach variable created by Claire

-- updating definition information 
UPDATE [LookUp].[ColumnDescriptions] 
SET PrintName = 'MH or medical indication for benzodiazepines', 
	Category = 'Drug Indication', 
	ColumnDescription = 'MH or medical indication for benzodiazepines', 
	DefinitionOwner = 'OMHO' --AR 1/8/16 Changed to OMHO VISN21 has never owned the definition of this measure 
WHERE TableName = @TableName AND ColumnName = 'MHorMedInd_Benzo'
 
-- updating variable flag 
UPDATE ##LookUp_ICD10_Stage 
SET MHorMedInd_Benzo = 1 
WHERE MHSUDdx_poss=1 --12/18/15 SM updated from mutiple categories to MHSUDdx_poss
	OR MedIndBenzodiazepine=1  
 
-------------------------------------------------------------------------------------------
/****Publish &  Unpivot for vertical publish***************/
-------------------------------------------------------------------------------------------		
EXEC [Maintenance].[PublishTable] 'LookUp.ICD10','##LookUp_ICD10_Stage'

--DECLARE @TableName VARCHAR(50) = 'ICD10'

DROP TABLE IF EXISTS #Columns;
SELECT COLUMN_NAME 
INTO #Columns
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE  TABLE_SCHEMA='LookUp' 
	AND TABLE_NAME = @TableName
	AND COLUMN_NAME NOT IN ('ICD10Description','ICD10Code','ICD10SID','Sta3n')
  
DECLARE @ColumnNames varchar(max) = (
	SELECT STRING_AGG(COLUMN_NAME,',')
	FROM #Columns
	)
	--	PRINT @ColumnNames

DROP TABLE IF EXISTS #unpivot;
CREATE TABLE #unpivot (
	ICD10SID bigint
	,ICD10Code varchar(25)
	,ICD10Description varchar(250)
	,DxCategory varchar(100)
	)
DECLARE @sql varchar(max) = 
'INSERT INTO #unpivot (ICD10SID,ICD10Code,ICD10Description,DxCategory)
 SELECT ICD10SID,ICD10Code,ICD10Description,DxCategory
 FROM
  (SELECT a.*
   FROM [LookUp].[ICD10] as a
	) AS p
  unpivot
    (Flag
    FOR DxCategory
    IN ('+@ColumnNames+'
    )) as a
WHERE
  Flag > 0'
  EXEC (@sql)

EXEC [Maintenance].[PublishTable] 'LookUp.ICD10_VerticalSID','#unpivot' 
DROP TABLE ##LookUp_ICD10_Stage
DROP TABLE #unpivot

	-- TABLE FOR REPORT DISPLAY CRITERIA
	CREATE TABLE #Stage_ICD10Display (
		ProjectType VARCHAR(25)
		,DxCategory VARCHAR(50)
		)
	INSERT INTO #Stage_ICD10Display
	SELECT DISTINCT
		'CRISTAL'
		,DxCategory
	FROM [LookUp].[ICD10_VerticalSID]
	WHERE DxCategory IN (
		'AmphetamineUseDisorder','AUD','BIPOLAR','Cannabis','COCNdx','DEMENTIA','DEPRESS','EH_AIDS'
		,'EH_ARRHYTH','EH_BLANEMIA','EH_CHRNPULM','EH_COAG','EH_DefANEMIA','EH_ELECTRLYTE','EH_HEART','EH_HYPERTENS','EH_HYPOTHY','EH_LIVER'
		,'EH_Lymphoma','EH_METCANCR','EH_NMETTUMR','EH_OBESITY','EH_OTHNEURO','EH_PARALYSIS','EH_PEPTICULC','EH_PERIVALV'
		,'EH_PSYCHOSES','EH_PULMCIRC','EH_RENAL','EH_RHEUMART','EH_SolidTumorNoMet','EH_VALVDIS','EH_WEIGHTLS','Homeless','Huntington'
		,'OpioidOverdose','Osteoporosis','OUD','Panic','Psych','PTSD','Reach_arth','Reach_attempt','Reach_bipolI','Reach_ca_head','SleepApnea'
		,'Reach_chronic','Reach_dm','Reach_PersonD','Reach_sle','SAE_Acet','SAE_Falls','SAE_sed','SAE_Vehicle','Schiz','SedateIssue'
		,'SedativeUseDisorder','SMI','Suicide','Tourette','REACH_othanxdis','SUD_Active_Dx','OtherMH','TBI_Dx','ChronicResp_Dx'
		,'WRV_EatingDisorder','WRV_MenopausalDisorder','WRV_MenstrualDisorder','WRV_NonViablePregnancy','WRV_Pregnancy'
		) 
	INSERT INTO #Stage_ICD10Display
	SELECT DISTINCT
		'STORM'
		,DxCategory
	FROM [LookUp].[ICD10_VerticalSID]
	WHERE DxCategory IN (
		'EH_AIDS','EH_CHRNPULM','EH_COMDIAG','EH_ELECTRLYTE','EH_HYPERTENS','EH_LIVER','EH_NMETTUMR','EH_OTHNEURO','EH_PARALYSIS'
		,'EH_PEPTICULC','EH_PERIVALV','EH_RENAL','EH_HEART','EH_ARRHYTH','EH_VALVDIS','EH_PULMCIRC','EH_HYPOTHY','EH_RHEUMART','EH_COAG'
		,'EH_WEIGHTLS','EH_DEFANEMIA','SEDATEISSUE','AUD_ORM','OUD','SUDDX_POSS','OPIOIDOVERDOSE','SAE_FALLS','SAE_OTHERACCIDENT'
		,'SAE_OTHERDRUG','SAE_VEHICLE','SAE_ACET','SAE_SED','SUICIDE','OTHER_MH_STORM','SUD_NOOUD_NOAUD','OSTEOPOROSIS','SLEEPAPNEA'
		,'NICDX_POSS','BIPOLAR','PTSD','MDD','COCNDX','OTHERSUD_RISKMODEL','SEDATIVEUSEDISORDER','CANNABISUD_HALLUCUD','CocaineUD_AmphUD'
		,'EH_UNCDIAB','EH_COMDIAB','EH_LYMPHOMA','EH_METCANCR','EH_OBESITY','EH_BLANEMIA') 

 ------------------------updating lookup definitions where there is a match until we can get complete metadata from xla2.0 
   

/****** EH_BLANEMIA - EH Blood Loss Anemia ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Anemia due to blood loss',
        Category = 'Medical',
        ColumnDescription = 'Elixhauser blood loss anemia based on Quan H 2005',
 		DefinitionOwner= 'Elixhauser'
    WHERE TableName = @TableName AND ColumnName = 'EH_BLANEMIA'



/**************Binge Eating**************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Binge Eating Disorder', 
            Category = 'Mental Health', 
            ColumnDescription = 'Binge Eating Disorder',   
			DefinitionOwner = 'PDSI, Academic Detailing'
            WHERE TableName = @TableName AND ColumnName = 'BingeEating'
 

/**************Narcolepsy**************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Narcolepsy', 
            Category = 'Medical', 
            ColumnDescription = 'Narcolepsy',   
			DefinitionOwner = 'PDSI, Academic Detailing'
            WHERE TableName = @TableName AND ColumnName = 'Narcolepsy'
 
/****** SAE_Acet     ******************/
 -- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Related to acetaminophen',
		Category = 'Adverse Event',
		ColumnDescription = 'Serious adverse event involving acetaminophen',
		DefinitionOwner= 'OMHO Master File'
	WHERE TableName = @TableName AND ColumnName = 'SAE_Acet'


/****** SleepApnea     ******************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Sleep Apnea',
		Category = 'Medical',
		ColumnDescription = 'sleep apnea',
		DefinitionOwner= 'ORM'
	WHERE TableName = @TableName AND ColumnName = 'SleepApnea'
	
  

/****** Tourette     ******************/
    -- updating definition information 
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Tourette',
        Category = 'Medical',
        ColumnDescription = 'Tourette',
		DefinitionOwner= 'PDSI'
    WHERE TableName = @TableName AND ColumnName = 'Tourette';

/**************ADD/ADHD**************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'ADD/ADHD', 
            Category = 'Mental Health', 
            ColumnDescription = 'ADD/ADHD',   
			DefinitionOwner = 'PDSI, Academic Detailing'
            WHERE TableName = @TableName AND ColumnName = 'ADD_ADHD'
 
 
/***************Cocaine and Amphetamines (Stimulant Use Disorders) ST 12/7/15***********/                
     -- updating definition information
     UPDATE [LookUp].[ColumnDescriptions]
     SET PrintName = 'Stimulant Use Disorder',
          Category = 'Substance Use Disorder',
          ColumnDescription = 'Cocaine, Amphetamine or Other Stimulant Use Disorder',
		 DefinitionOwner= 'OMHO Master File'
     WHERE TableName = @TableName AND ColumnName = 'CocaineUD_AmphUD'
	  

 
/****** AmphetamineUseDisorder     ******************/
    -- updating definition information
     UPDATE [LookUp].[ColumnDescriptions]
     SET PrintName = 'Non Cocaine Stimulant Use Disorder',
          Category = 'Substance Use Disorder',
          ColumnDescription = 'Other Stimulant use disorder, most often amphetamine use disorder',
		 DefinitionOwner= 'PERC'
     WHERE TableName = @TableName AND ColumnName = 'AmphetamineUseDisorder'
	  
    
/****** EH_ARRHYTH - EH cardiac arrythmia ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Cardiac Arrhythmia',
        Category = 'Medical',
        ColumnDescription = 'Elixhauser cardiac arrhythmia based on Quan H 2005',
 		DefinitionOwner= 'Elixhauser'
    WHERE TableName = @TableName AND ColumnName = 'EH_ARRHYTH'

   
/****** ALCdx_poss     ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Alcohol',
        Category = 'Substance Use Disorder',
        ColumnDescription = 'Alcohol Use Disorder requires confirmation with SUD stop codes',
		DefinitionOwner= 'OMHO Master File'
    WHERE TableName = @TableName AND ColumnName = 'ALCdx_poss';
 
    
/****** AUD     ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Alcohol Use Disorder (comprehensive definition)',
        Category = 'Substance Use Disorder',
        ColumnDescription = 'Alcohol Use Disorder',
		DefinitionOwner= 'OMHO Master File + Academic Detailing'
    WHERE TableName = @TableName AND ColumnName = 'AUD'

    
/** Bipolar **********/                  
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Bipolar',
        Category = 'Mental Health',
        ColumnDescription = 'Bipolar',
		DefinitionOwner= 'OMHO Master File'
    WHERE TableName = @TableName AND ColumnName = 'Bipolar'

    
/***************Cannabis & Hallucinogen ST 12/7/15*********************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Cannabis/Hallucinogen',
        Category = 'Substance Use Disorder',
        ColumnDescription = 'Cannabis or Hallucinogen Use Disorder',
		DefinitionOwner= 'OMHO Master File'
    WHERE TableName = @TableName AND ColumnName = 'CannabisUD_HallucUD';
 
 
/****** Cannabis     ******************/
     -- updating definition information
     UPDATE [LookUp].[ColumnDescriptions]
     SET PrintName = 'Cannabis',
          Category = 'Substance Use Disorder',
          ColumnDescription = 'Cannabis Use Disorder',
		 DefinitionOwner= 'OMHO Master File'
     WHERE TableName = @TableName AND ColumnName = 'Cannabis'
  
/****** Chronic Respiratory Diseases*****/
	 -- updating definition information
	 UPDATE [LookUp].[ColumnDescriptions]
     SET PrintName = 'Chronic Respiratory Diseases',
          Category = 'Chronic Respiratory Diseases',
          ColumnDescription = 'Chronic Respiratory Diseases - includes COPD and sleep apnea',
		 DefinitionOwner= 'AD/PERC'
     WHERE TableName = @TableName AND ColumnName = 'ChronicResp_Dx'
     
 
/****** COCNdx     ******************/ 
	/** Cocaine UD **********/                  
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Cocaine',
        Category = 'Substance Use Disorder',
        ColumnDescription = 'Cocaine Use Disorder',
		DefinitionOwner= 'OMHO Master File'
    WHERE TableName = @TableName AND ColumnName = 'COCNdx'
 
 
/****** EH_ELECTRLYTE - EH Fluid_Electrolyte_Disorders ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Fluid Electrolyte Disorders',
        Category = 'Medical',
        ColumnDescription = 'Elixhauser Fluid_Electrolyte_Disorders based on Quan H 2005',
		DefinitionOwner= 'Elixhauser'
    WHERE TableName = @TableName AND ColumnName = 'EH_ELECTRLYTE'
 
 
/****** Nicdx_poss - Nicotine UD ******************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Nicotine',
		Category = 'Substance Use Disorder',
		ColumnDescription = 'Nicotine Use Disorder in the presence of an SUD stop code',
		DefinitionOwner= 'OMHO Master File'
	WHERE TableName = @TableName AND ColumnName = 'Nicdx_poss'

 
/****** Osteoporosis     ******************/         
	--updating definition information
    UPDATE [LookUp].[ColumnDescriptions] 
    SET PrintName = 'Osteoporosis',
        Category = 'Medical',
        ColumnDescription = 'Osteoporosis',
		DefinitionOwner= 'ORM'
    WHERE TableName = @TableName AND ColumnName = 'Osteoporosis'

 

 
/****** SAE_Falls     ******************/       
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Related to falls',
		Category = 'Adverse Event',
		ColumnDescription = 'Serious adverse events related to falls',
		DefinitionOwner= 'ORM'
	WHERE TableName = @TableName AND ColumnName = 'SAE_Falls'

/****** SAE_OtherAccident     ******************/
    -- updating definition information 
    UPDATE [LookUp].[ColumnDescriptions] 
    SET PrintName = 'Related to accidents',
        Category = 'Adverse Event',
        ColumnDescription = 'Serious adverse events related to other accidents',
		DefinitionOwner= 'ORM'
    WHERE TableName = @TableName AND ColumnName = 'SAE_OtherAccident'

/****** SAE_Vehicle     ******************/        
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Related to vehicular accidents',
		Category = 'Adverse Event',
		ColumnDescription = 'Serious adverse event with vehicles',
		DefinitionOwner= 'ORM'
	WHERE TableName = @TableName AND ColumnName = 'SAE_Vehicle';

/****** Schiz     ******************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Schizophrenia',
		Category = 'Mental Health',
		ColumnDescription = 'Schizophrenia',
		DefinitionOwner= 'OMHO Master File'
	WHERE TableName = @TableName AND ColumnName = 'Schiz'
 
 
/****** SedativeUseDisorder     ******************/
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Sedative',
		Category = 'Substance Use Disorder',
		ColumnDescription = 'Sedative Use Disorder',
		DefinitionOwner= 'OMHO Master File'
	WHERE TableName = @TableName AND ColumnName = 'SedativeUseDisorder'
 
 
/****** SMI     ******************/
--1/11/16 MP revised code to Aaron's vetted def
	-- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Serious Mental Illness',
		Category = 'Mental Health',
		ColumnDescription = 'Serious Mental Illness',
		DefinitionOwner= 'OMHO Master File'
	WHERE TableName = @TableName AND ColumnName = 'SMI';

 
/****** Huntington     ******************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Huntington',
		Category = 'Medical',
		ColumnDescription = 'Huntington’s Disease',
		DefinitionOwner= 'PDSI'
	WHERE TableName = @TableName AND ColumnName = 'Huntington';

 
 
/****** EH_AIDS ******************/
    -- updating definition information
    UPDATE [LookUp].[ColumnDescriptions] 
    SET PrintName = 'HIV',
        Category = 'Medical',
        ColumnDescription = 'Elixhauser AIDS based on Quan H 2005',
		DefinitionOwner= 'Elixhauser'
    WHERE TableName = @TableName AND ColumnName = 'EH_AIDS'


/****** EH_LIVER - EH Liver Disease ******************/
	-- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Liver Disease',
        Category = 'Medical',
        ColumnDescription = 'Elixhauser liver disease based on Quan H 2005',
		DefinitionOwner= 'Elixhauser' 
    WHERE TableName = @TableName AND ColumnName = 'EH_LIVER'  
	  
  
  
/****** EH_HYPERTENS - EH hypertension ******************/
	-- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Hypertension',
        Category = 'Medical',
        ColumnDescription = 'Elixhauser hypertension based on Quan H 2005',
		DefinitionOwner= 'Elixhauser'
    WHERE TableName = @TableName AND ColumnName = 'EH_HYPERTENS'

 
/****** EH_PEPTICULC - EH peptic ulcer disease ******************/	 
	 -- updating definition information 
	UPDATE [LookUp].[ColumnDescriptions] 
	SET PrintName = 'Peptic Ulcer Disease', 
		Category = 'Medical',
		ColumnDescription = 'Elixhauser peptic ulcer disease based on Quan H 2005', 
		DefinitionOwner= 'Elixhauser' 
	WHERE TableName = @TableName AND ColumnName = 'EH_PEPTICULC'




/****** TBI*****/
     -- updating definition information
     UPDATE [LookUp].[ColumnDescriptions]
     SET PrintName = 'Traumatic Brain Injury',
          Category = 'Medical',
          ColumnDescription = 'Traumatic Brain Injury',
		 DefinitionOwner= 'NEPEC (source is Rehab Office) '
     WHERE TableName = @TableName AND ColumnName = 'TBI_Dx'


/****** MHSUDdx_poss     ******************/
-- updating definition information 
    UPDATE [LookUp].[ColumnDescriptions] 
    SET PrintName = 'MHSUDdx_poss',
        Category = 'Mental Health',
        ColumnDescription = 'Any MH or SUD diagnosis',
		DefinitionOwner= 'OMHO Master File'
    WHERE TableName = @TableName AND ColumnName = 'MHSUDdx_poss';
  
  
--Update print names in ColumnDescriptions for items from ALEX
UPDATE [LookUp].[ColumnDescriptions]
     SET PrintName = a.ALEX2_PrintName
        ,Category = c.Category
        ,ColumnDescription = a.ALEX2_Detail
		, DefinitionOwner=c.DefinitionOwner
FROM Library.XLA_XLA2_Metadata a WITH (NOLOCK)
INNER JOIN Lookup.CDS_ALEX l WITH (NOLOCK) ON a.ObjectTerm=l.SetTerm
INNER JOIN Lookup.ColumnDescriptions c ON c.ColumnName=l.CDS_Lookup
WHERE a.Vocabulary='Dx' AND c.TableName='ICD10'
AND (a.ALEX2_PrintName<>c.PrintName OR c.PrintName IS NULL)

UPDATE [LookUp].[ColumnDescriptions]
     SET PrintName = a.ALEX2_PrintName
        ,Category = c.Category
        ,ColumnDescription = a.ALEX2_Detail
		, DefinitionOwner=c.DefinitionOwner
FROM Library.XLA_XLA2_Metadata a WITH (NOLOCK)
INNER JOIN Lookup.ColumnDescriptions c ON c.ColumnName=a.ObjectTerm
WHERE a.Vocabulary='Dx' AND c.TableName='ICD10'
AND (a.ALEX2_PrintName<>c.PrintName OR c.PrintName IS NULL)
	
EXEC [Maintenance].[PublishTable] 'LookUp.ICD10_Display','#Stage_ICD10Display'

EXEC [Log].[ExecutionEnd]

END