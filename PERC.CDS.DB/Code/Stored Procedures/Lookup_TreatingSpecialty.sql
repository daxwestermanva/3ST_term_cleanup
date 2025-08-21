


-- =============================================
-- Author:		<Susana Martins>
-- Create date: <10/28/16>
-- Description:	<Pivoted Treating Specialty Lookup crosswalk>
-- NEPEC provided this spreadsheet \\vhacdwmul03.vha.med.va.gov\Projects\OMHO_PsychPharm\PDSI\TreatmentSpecialtyCodesListBedSectionsFY2011FY2016_PDSIrev.xls
-- Updates:
--	2019-02-15	Jason Bacani - Refactored to use [Maintenance].[PublishTable]; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
--	2020-03-25	RAS	Reviewed history of residential/dom/rrtp definitions.  Updated RRTP to align with definitions being used in PDE and STORM.
				----I believe Residential_TreatingSpecialty and Domiciliary_Treating specialty should be deprecated in favor of RRTP_TreatingSpecialty,
				----but PDSI is using these separately, so need to determine if this is actual display requirement
--	2020-03-25	RAS	Added discontinued codes to MentalHealth_TreatingSpecialty in case needed for history and to align with STORM/PDE definitions.
				----Changes still align with NEPEC spreadsheet listed above, but includes discontinued codes as well.
-- 2020-03-27	RAS	Adding notes for STORM Inpatient Mental Health: Per Oliva et al. 2016: Bed Sections: 33, 70,72-74, 76, 79,89,91-94,25-27,37,39,84-86,88,89,109, 110, 111 
-- 2020-06-18	RAS	Added PTFCode to table, changed SpecialtyIEN datatype back to varchar to match source. Updated queries to use PTFCode instead of SpecialtyIEN.
-- 2020-10-19	PS  Branched from main code, creating a _VM version
-- 2021-05-20  JJR_SA - Added tag for identifying code to Share in ShareMill
-- 2021-06-03  JJR_SA - Updated tagging for use in sharing code for ShareMill;adjusted position of ending tag
-- 2021-09-24  SG  - Added Cerner specific catch all PTF codes  ( 'GR' ,'GS'  ,'GM'  ,'GB','ON') to the categories
-- 2024-06-14	RAS	Removed SpecialtyIEN because CDW is removing from source and we can use PTFCode (which is better for future anyway).

-- =============================================
CREATE PROCEDURE [Code].[Lookup_TreatingSpecialty]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.Lookup_TreatingSpecialty', @Description = 'Execution of Code.Lookup_TreatingSpecialty SP'

/*** When ADDING A NEW VARIABLE, first add the column to the target table ***/

---------------------------------------------------------------------------------------------------
/*** Add new rows to [LookUp].[ColumnDescriptions] if they exist in the target table ***/
---------------------------------------------------------------------------------------------------	
	INSERT INTO [LookUp].[ColumnDescriptions]
	WITH (TABLOCK)
	SELECT DISTINCT
		Object_ID as TableID
		,a.Table_Name as TableName
		--Name of column from the LookupTreatingSpecialty table
		,Column_Name AS ColumnName
		,NULL AS Category
		,NULL AS PrintName
		,NULL AS ColumnDescription
		,Null as DefinitionOwner
	FROM (
		SELECT c.Object_ID
			  ,t.name as Table_Name
			  ,c.name as column_name	
		FROM  sys.columns as c 
		INNER JOIN sys.tables as t on c.object_id = t.object_id-- a.TABLE_NAME = b.TABLE_NAME
		INNER JOIN sys.schemas as s on t.schema_id=s.schema_id
		WHERE t.Name = 'TreatingSpecialty' 
			AND s.Name ='LookUp'
			AND c.Name NOT IN (
				'TreatingSpecialtySID'
				,'Sta3n'
				,'TreatingSpecialtyName'
				,'Specialty'
				,'PTFCode'
				)
			AND c.Name NOT IN (
				SELECT DISTINCT ColumnName
				FROM [LookUp].[ColumnDescriptions]
				WHERE TableName = 'TreatingSpecialty'
				) --order by COLUMN_NAME
		) AS a

    --remove any deleted columns
	DELETE [LookUp].[ColumnDescriptions]
    WHERE TableName = 'TreatingSpecialty' 
		AND ColumnName NOT IN (
			SELECT c.name as column_name	
			FROM  sys.columns as c
			INNER JOIN sys.tables as t on t.object_id = c.object_id
			INNER JOIN sys.schemas as s on t.schema_id=s.schema_id
			WHERE t.Name = 'TreatingSpecialty' 
				AND s.Name ='LookUp'
			)

---------------------------------------------------------------------------------------------------
/***Pull all data from source CDW Dim table(s) into staging table***/
---------------------------------------------------------------------------------------------------
	DECLARE @Columns VARCHAR(Max);

	SELECT @Columns = CASE 
			WHEN @Columns IS NULL
				THEN '0 as ' + T.ColumnName
			ELSE @Columns + ', 0 as ' + T.ColumnName
			END
	FROM [LookUp].[ColumnDescriptions] AS T
	WHERE T.TableName = 'TreatingSpecialty';

	--select @Columns
	DECLARE @Insert AS VARCHAR(4000);;

	DROP TABLE IF EXISTS ##LookUp_TreatingSpecialty_Stage
	SET @Insert = '
		SELECT DISTINCT 
			TreatingSpecialtySID
			,TreatingSpecialtyName
			,PTFCode
			,Specialty
			,Sta3n
			,'+ @Columns + ' 
		INTO ##LookUp_TreatingSpecialty_Stage
		FROM ('

		/*##SHAREMILL BEGIN##*/
		SET @Insert =  @Insert + N'
			SELECT DISTINCT 
				t.TreatingSpecialtySID
				,t.TreatingSpecialtyName
				,s.PTFCode
				,t.Specialty
				,t.Sta3n			
			FROM [Dim].[TreatingSpecialty] t
			LEFT JOIN [Dim].[Specialty] s on s.SpecialtySID=t.SpecialtySID
		UNION ALL
			SELECT DISTINCT 
				t.CodeValueSID AS TreatingSpecialtySID
				,t.Specialty AS TreatingSpecialtyName
				,t.PTFCode
				,t.Specialty
				,t.Sta3n
			FROM [Cerner].[DimSpecialty] t
			LEFT JOIN Dim.Specialty s on t.PTFCode = s.PTFCode'/*##SHAREMILL END##*/
			SET @Insert =  @Insert + N')M'

	EXECUTE (@Insert);

	

-------------------------------------------------------------------
--ACUTE - SHORT TERM STAYS
-------------------------------------------------------------------
/********* MED/SURG INPATIENT  ******/
	UPDATE ##LookUp_TreatingSpecialty_Stage
	SET MedSurgInpatient_TreatingSpecialty = 1
	WHERE PTFCode in ('1F','1G','1H','1J','1N'
							  ,'2','3','4','5','6','8','9'
							  ,'10','11','12','13','14','15','16','17','18','19'
							  ,'20','21','22','23','24'
							  ,'30','32'
							  ,'40','41','48','49'
							  ,'50','51','52','53','54','55','56','57','58','59'
							  ,'60','61','63','65'
							  ,'78'
							  ,'82','83'
							  ,'97' )
		  --Cerner specific catch all PTF codes
          OR PTFCode in (  'GR'   -- Other Rehabilitation Med
                          ,'GS'  -- Other General Surgery
                          ,'GM'  -- Other General Medicine	
			            )
      
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Med/Surg',
		Category = 'Non-MentalHealth',
		[ColumnDescription] = 'Inpatients staying in medicine or surgery beds',
		[DefinitionOwner]= 'NEPEC'
	WHERE [ColumnName] = 'MedSurgInpatient_TreatingSpecialty'
	;

/********* MENTAL HEALTH INPATIENT - NOT RESIDENTIAL  ******/
  	UPDATE ##LookUp_TreatingSpecialty_Stage
	SET MentalHealth_TreatingSpecialty = 1
	WHERE PTFCode in (
				'33'  --GEM PSYCHIATRIC BEDS		
				,'72' --ALCOHOL DEPENDENCE TRMT UNIT	
				,'73' --DRUG DEPENDENCE TRMT UNIT	
				,'74' --SUBSTANCE ABUSE TRMT UNIT	
				,'79' --SIPU (SPEC INPT PTSD UNIT)	
				,'89' --STAR I, II & III	
				,'91' --EVAL/BRF TRMT PTSD UNIT(EBTPU)	
				,'92' --GEN INTERMEDIATE PSYCH	
				,'93' --HIGH INTENSITY GEN PSYCH INPAT	
				,'94' --PSYCHIATRIC OBSERVATION	
				)
			OR PTFCode IN ( --Old codes, included for history
				'70' --ACUTE PSYCHIATRY (<45 DAYS)
				--'71' --LONG TERM PSYCHIATRY(>45 DAYS) 
				--20200325 RAS - 71 is included in PDE definition, but excluded here because no use in past 5 years and conceptually it is confusing here and NOT part of STORM definition.
				,'76' --PSYCHIATRIC MENTALLY INFIRM	OLD
				,'84' --SUBSTANCE ABUSE INTERMED CARE
				--,'90' --SUBST ABUSE STAR I, II & III --included in PDE definition, but NOT STORM definition. No recent usage, so exluded to align definition to STORM.
		       	)
             --Cerner specific catch all PTF codes
             OR PTFCode in ('GB' --   Other Behavioral Health	
			                )

    UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Mental Health',
		Category = 'Mental Health',
		[ColumnDescription] = 'Inpatients staying in a MH inpatient bed, includes mental health and substance use',
		[DefinitionOwner]= 'NEPEC'
	WHERE [ColumnName] = 'MentalHealth_TreatingSpecialty'
	;
-------------------------------------------------------------------	
--RESIDENTIAL AND LONG TERM STAYS
-------------------------------------------------------------------
-------------------------------------------------------------------
	UPDATE ##LookUp_TreatingSpecialty_Stage
	SET RRTP_TreatingSpecialty = 1
	WHERE PTFCode in (
				'37'  --Dom CHV
				,'85' --Dom Gen
				,'86' --Dom SA
				,'88' --Dom PTSD
			    ,'39' --GENERAL CWT/TR
				,'1K' --PSYCH RESID REHAB PROG (SpecialtyIEN 109)
				,'1L' --PTSD RESID REHAB PROG (SpecialtyIEN 110)
				,'1M'--SUBSTANCE ABUSE RESID PROG (SpecialtyIEN 111)
				) 
        OR PTFCode in  --these are outdated Psych and SA RRTPs, but need them for historical data;
			('25' -- PRRTP
			,'26' -- PTSD RRTP
			,'27' -- SA RRTP
			,'29' -- SA CWT	--not in STORM, but no recent usage
			,'38' -- PTSD CWT --not in STORM, but no recent usage
			,'77' -- PRRTP	--not in STORM, but no recent usage
			)
    UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Mental Health Residential',
		Category = 'Mental Health',
		[ColumnDescription] = 'MH Residential rehab treatment programs and Doms, includes SUD',
		[DefinitionOwner]= 'PERC'
	WHERE [ColumnName] = 'RRTP_TreatingSpecialty'
	;

	/*20200325 RAS Re: RRTP_TreatingSpecialty
	PDE will need to use RRTP definition AND Homeless (28,39)
	PDE also has 75 Halfway House, but there is no recent usage of this code (past 5 years)
	*/


/********* DOMICILIARY ******/
  UPDATE ##LookUp_TreatingSpecialty_Stage
	SET Domiciliary_TreatingSpecialty = 1
	WHERE PTFCode in ('37','85','86','88')
  
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Domiciliary',
		Category = 'Residential',
		[ColumnDescription] = 'Patient residing in a Domiciliary - Gen, CHV, PTSD, and SUD',
		[DefinitionOwner]= 'Ilse'
	WHERE [ColumnName] = 'Domiciliary_TreatingSpecialty'
	;

/********* HOMELESS ******/
	UPDATE ##LookUp_TreatingSpecialty_Stage
	SET Homeless_TreatingSpecialty = 1
	WHERE PTFCode in ('37','28')
  
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Homeless',
		Category = 'Homeless',
		[ColumnDescription] = 'Homeless - Domicilliary, transitional residential programs',
		[DefinitionOwner]= 'Homeless office - Michal Wilson June/2017'
	WHERE [ColumnName] = 'Homeless_TreatingSpecialty'
;

/********* NURSING HOME  ******/
  	UPDATE ##LookUp_TreatingSpecialty_Stage
	SET NursingHome_TreatingSpecialty = 1
	WHERE Specialty like '%NH%'
	      or PTFCode in ('ON'  -- Other Nursing Home Care 
		                )
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'CLC',
		Category = 'Nursing Home',
		[ColumnDescription] = 'Inpatients staying in nursing home care, including short stay, hospice, and respite.',
		[DefinitionOwner]= 'PDSI' --also NEPEC
	WHERE [ColumnName] = 'NursingHome_TreatingSpecialty'
	;

/********* RESIDENTIAL TREATMENT defined by Tobacco project ******/
	--This can be phased out in favor of RRTP_TreatingSpecialty
	--Originally this was defined by Liz Gifford's tobacco project/official MH RRTPs per Jen Burden
	----however, code was changed and now doms are excluded.  PDSI only code using this with Doms listed separately.
	UPDATE ##LookUp_TreatingSpecialty_Stage
	SET Residential_TreatingSpecialty = 1
	WHERE PTFCode IN ('25','27','37','39'--,'85','86','88' Moved into Dom Category
						   ,'1K','1L','1M')

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Residential',
	Category = 'Residential',
	[ColumnDescription] = 'Residential rehab treatment programs - Do not use this definition for new projects. RRTP_TreatingSpecialty is preferred. ',
	[DefinitionOwner]= 'PDSI'
	WHERE [ColumnName] = 'Residential_TreatingSpecialty'
	;
-------------------------------------------------------------------
--REACH
-------------------------------------------------------------------
--------------- Reach_MHDischarge_TreatingSpecialty --------------- 
	/*For anymhdisprior12mos
		  anymhdisprior1mos
		  anymhdisprior24mos
		  anymhdisprior6mos
	*/
	UPDATE ##LookUp_TreatingSpecialty_Stage
	SET Reach_MHDischarge_TreatingSpecialty = 1
	WHERE PTFCode IN  ('33','79','89','91','92','93','94')
	      --Cerner specific catch all PTF codese 
          OR PTFCode in ('GB' --   Other Behavioral Health	
			            )
	
	UPDATE [LookUp].[ColumnDescriptions]
	SET [PrintName] = 'MH discharge',
	[Category] = 'MH discharge',
	[ColumnDescription] = 'MH discharge as defined by Perceptive Reach (SMITREC), Treating specialty = PTFCode',
	[DefinitionOwner]= 'SMITREC Perceptive Reach'
	WHERE [ColumnName] = 'Reach_MHDischarge_TreatingSpecialty'
	;
--------------- Reach_AnyMH_TreatingSpecialty --------------- 
	/*For anymhtx12
		  anymhtx24
	*/
	UPDATE ##LookUp_TreatingSpecialty_Stage
	SET Reach_AnyMH_TreatingSpecialty = 1
	WHERE PTFCode IN ('25','26','27','28','29'
						  ,'33','37','38','39'
						  ,'70','71','72','73','74','75','76','77','79'
						  ,'84','85','86','87','88','89'
						  ,'90','91','92','93','94')
		 --Cerner specific catch all PTF codes
           OR PTFCode in ('GB' --   Other Behavioral Health	
			                )
	;
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'MH discharge',
	Category = 'MH discharge',
	[ColumnDescription] = 'MH discharge as defined by Perceptive Reach (SMITREC), Treating specialty = PTFCode',
	[DefinitionOwner]= 'SMITREC Perceptive Reach'
	WHERE [ColumnName] = 'Reach_AnyMH_TreatingSpecialty'
	;
-------------------------------------------------------------------
-------------------------------------------------------------------

EXEC [Maintenance].[PublishTable] '[LookUp].[TreatingSpecialty]', '##LookUp_TreatingSpecialty_Stage'
	DROP TABLE IF EXISTS ##LookUp_TreatingSpecialty_Stage

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END
;