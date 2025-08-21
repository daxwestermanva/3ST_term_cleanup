
/***-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <2/26/2015>
-- ColumnDescription:	<Pivoted NationalDrug lookup crosswalk> 
-- Modification:
	2015-05-13	ST	updated reference to drugnamewithout dose to pull from dim.drugnamewithoutdose instead of dim.national drug
	2015-07-31	ST	added sedatives z drug
	2015-09-04	SM	added Ach categories
	2015-09-17	SM	adding new category AP_Geri which excludes promethazine and prochorperazine if used <=60 days
	2015-09-25	SM	added zolpidem
	2018-08-07	SM	updated PainAdjTCA_Rx definition, removed tiagabine (it is only an anticonvulsant) per JT
	2020-03-17	CB	automated the fill of missing StrengthNumeric for OpioidForPain_Rx category combination medications (required to compute MEDD), 
					--also fixed StrengthNumeric to be equivalent to dim table definition of decimal(19,4) null (creating errors since may strength's had decimals)
	2020-10-14  CMH added VUID to LookUp.NationalDrug
	2020-10-29	PS	branched and renamed to _VM version
	2020-11-10	CB	updated OpioidForPain_Rx for Cerner 
	2020-11-27	RAS	Set NDC to NULL for VistA data and added group by and MAX for fields from Millenium. I want to test downstream code without 
					duplicate NationalDrugSIDs, but a permanent solution to this problem will require additional research and discussion.
	2020-12-30  CB	Added additional column so we can compare StrengthNumeric and CalculatedStrengthNumeric
	2021-04-15	RAS	Added LookUp.NationalDrug_Vertical and added unpivoting code at end of this SP.
	2021-05-14  JJR_SA - Added tag for identifying code to Share in ShareMill
	2021-06-03  JJR_SA - Updated tagging for use in sharing code for ShareMill;adjusted position of ending tag
	2022-02-14	SM - Removing Millennium Drug reference since we will use dim.NationaDrug.VUID as primary key for join with FactPharmacyOutpatientDispensed
						- getting unique CSFederalSchedule by VUID (lots of nulls in Dim.NationalDrug)
	2022-05-03	RAS	Added section to flag specific VUID records to use for Cerner overlay.  Inactivated records in Dim.NationalDrug accounted for 
					the majority of the differences with VUIDs resulting in multiple distinct records.  Still need to figure out Sta3n-specific definitions.
	2022-05-04	RAS	Removed VUIDFlag addition and added publishing of LookUp.Drug_VUID
	2022-08-03	SM	Added Clobazam to benzodiazepine category	
	2022-08-03	MP	Added naloxone INJ formulation (Zimhi) to Naloxone kit category
	2023-04-12	RAS	Removed METHADONE HCL 10MG/ML SOLN,ORAL SYRINGE 1ML from OpioidForPain - this was added to CDWWork Dim table end of Nov 2022
					and per Michael Harvey, it does not appear to be a formulation that would be used for pain treatment.
	2023-09-07	MCP	Removed NALTREXONE 4.5MG from AlcoholPharmacotherapy_Rx and AlcoholPharmacotherapy_notop_Rx, which is not being 
					used for AUD treatment
	2023-10-12	RAS	Corrected ordering in creation of VUID table to correctly prioritize OpioidForPain by adding "DESC"
	2024-04-24	LM	Changed InactivationDate to InactivationDateTime due to change in CDWWork table
	2024-09-19  AER Removing station based OTP logic
	2025-05-06  AER Pointing to ALEX for like for like items 
	2025-08-20	MCP	Updated PDSI relevant drugs to only include drugs used in denominator or for actionable 
-- =============================================
*/ 
CREATE PROCEDURE [Code].[LookUp_NationalDrug]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.LookUp_NationalDrug', @Description = 'Execution of Code.LookUp_NationalDrug SP'

/*** When ADDING A NEW VARIABLE, first add the column to the target table ***/

---------------------------------------------------------------------------------------------------
/*** Add new rows to [LookUp].[ColumnDescriptions] if they exist in the target table ***/
---------------------------------------------------------------------------------------------------
	INSERT INTO [LookUp].[ColumnDescriptions]
	SELECT DISTINCT
		Object_ID as TableID
		,a.Table_Name as TableName
		--Name of column from the LookupStopCode table
		,Column_Name AS ColumnName
		,NULL AS Category
		,NULL AS PrintName
		,NULL AS ColumnDescription
		,NULL AS DefinitionOwner
	FROM (
		SELECT a.Object_ID
			  ,b.name as Table_Name
			  ,a.name as column_name	
		FROM  sys.columns as a 
		INNER JOIN sys.tables as b on a.object_id = b.object_id-- a.TABLE_NAME = b.TABLE_NAME
		WHERE b.Name = 'NationalDrug'
			AND a.Name NOT IN (
				'NationalDrugSID'
				,'VUID'
				,'NDC'
				,'CMOP'
				,'Sta3n'
				,'DrugNameWithDose'
				,'DrugNameWithoutDose'
				,'DrugNameWithoutDoseSID'
				,'CSFederalSchedule'
				,'PrimaryDrugClassCode'
				,'StrengthNumeric'
				,'CalculatedStrengthNumeric'
				,'DosageForm'
				,'InactivationDateTime'
				)
			AND a.Name NOT IN (
				SELECT DISTINCT ColumnName
				FROM [LookUp].[ColumnDescriptions]
				WHERE TableName = 'NationalDrug'
				) --order by COLUMN_NAME
		) AS a
    
    --remove any deleted columns
	DELETE [LookUp].[ColumnDescriptions]
	WHERE TableName = 'NationalDrug' 
		AND ColumnName NOT IN (
			SELECT a.name as ColumnName
			FROM  sys.columns as a 
			INNER JOIN sys.tables as b on  a.object_id = b.object_id
			WHERE b.Name = 'NationalDrug'
			)
		;
    
    
    
    drop table if exists ##ReadyToConvertRx
select distinct CDS_Lookup, a.SetTerm, case when len(Value)=3 then value + '.' else value end Value
into ##ReadyToConvertRx
from   LookUp.cds_alex as a left outer join [XLA].[Lib_SetValues_CDS] as c on a.SetTerm = c.SetTerm and c.Vocabulary = 'VUID'
where  a.CDS_Lookup in (
'AChALL_Rx','AchAntiHist_Rx','Alprazolam_Rx','Benzodiazepine_Rx','Clonazepam_Rx','Lorazepam_Rx','Methadone_Rx','Mirtazapine_Rx','NaltrexoneINJ_Rx','Olanzapine_Rx'
,'PainAdjAnticonvulsant_Rx','PainAdjTCA_Rx','Prazosin_Rx','Prochlorperazine_Rx','Sedative_zdrug_Rx','Promethazine_Rx','SedativeOpioid_Rx','SSRI_Rx'
,'SSRI_SNRI_Rx','TobaccoPharmacotherapy_Rx','Tramadol_Rx','Zolpidem_Rx'
) 	AND CDS_Lookup  IN (
			SELECT a.name as ColumnName
			FROM  sys.columns as a 
			INNER JOIN sys.tables as b on  a.object_id = b.object_id
			WHERE b.Name = 'NationalDrug'
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
	WHERE T.TableName = 'NationalDrug';

	--SELECT @Columns  --(if you want to see results of code above)
	
	DECLARE @Insert AS VARCHAR(4000);

	DROP TABLE IF EXISTS ##LookUp_NationalDrug_Stage;

	SET @Insert = '
	SELECT m.*,
	' + @Columns + ' 
    INTO ##LookUp_NationalDrug_Stage 
    FROM ('
	SET @Insert =  @Insert + N'
	SELECT DISTINCT a.NationalDrugSID
		  ,a.VUID
		  ,NDC = NULL 
		  ,a.VAProductIdentifier as CMOP
		  ,a.Sta3n
		  ,a.DrugNameWithDose
		  ,b.DrugNameWithoutDose
		  ,a.DrugNameWithoutDoseSID
		  ,e.CSFederalSchedule
		  ,c.DrugClassCode as PrimaryDrugClassCode
		  ,a.StrengthNumeric
		  ,CAST(NULL as decimal(19, 4)) as CalculatedStrengthNumeric
		  ,d.DosageForm
		  ,a.InactivationDateTime
	FROM [Dim].[NationalDrug] as a
	INNER JOIN [Dim].[DrugNameWithoutDose] as b on a.DrugNameWithoutDoseSID=b.DrugNameWithoutDoseSID
	INNER JOIN [Dim].[DrugClass] as c on a.PrimaryDrugClassSID=c.DrugClassSID
	INNER JOIN [Dim].[DosageForm] as d on a.DosageFormSID=d.DosageFormSID
	INNER JOIN  (	
		SELECT CSFederalSchedule
			,VUID  --- CSFederalSchedule is not fully populated at the NationalDrugSID level
		FROM [Dim].[NationalDrug] 
		WHERE CSFederalSchedule IS NOT NULL
		GROUP BY VUID,CSFederalSchedule
		) e on a.VUID=e.VUID
	--LEFT JOIN [Dim].[LocalDrug] as e on a.NationalDrugSID = e.NationalDrugSID
	WHERE a.NationalDrugSID <> -1'
	SET @Insert =  @Insert + N') m';
	EXEC (@Insert)
	
  	
while (select count(distinct cds_lookup) from ##ReadyToConvertRx) > 0
begin
declare @column varchar(100)
set @column = (select top 1 cds_lookup from ##ReadyToConvertRx order by cds_lookup )

declare @Update varchar(max)

set @update = '

update ##LookUp_NationalDrug_Stage 
set ' + @Column + '= 1 
where VUID in (select value from ##ReadyToConvertRx where CDS_Lookup = ''' + @Column + ''')

delete from ##ReadyToConvertRx where CDS_Lookup = ''' + @Column + '''

'
exec (@update)
end 
  
  
  
  
  
  
---------------------------------------------------------------------------------------------------
/*****	Step 4: Updating variable flags and adding definitions. 
		If you are adding a new variable add it after last exisiting update statement *****/
---------------------------------------------------------------------------------------------------
;

/***************SSRI_Rx **************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'SSRI',
		Category = 'PERC',
		ColumnDescription = 'SSRI defined by PERC'
	WHERE ColumnName = 'SSRI_Rx'
	;


/***************Olanzapine_Rx**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Olanzapine',
		Category = 'PDSI',
		ColumnDescription = 'Olanzapine'
	WHERE ColumnName = 'Olanzapine_Rx';


/***************Zolpidem_Rx **************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Zolpidem',
		Category = 'PDSI',
		ColumnDescription = 'Zolpidem'
	WHERE ColumnName = 'Zolpidem_Rx'
	;

/***************Anticholinergic ALL **************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Anticholinergic drugs',
		Category = 'PDSI',
		ColumnDescription = 'Anticholinergic drugs per BEERs 2015 Categoryification'
	WHERE ColumnName = 'AChALL_Rx'
	;

/***************Anticholinergic Antihistamine**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Anticholinergic Antihistamine',
		Category = 'PDSI',
		ColumnDescription = 'Antihistamines with an strong anticholinergic effect'
	WHERE ColumnName = 'AchAntiHist_Rx'
	;


/***************Anticholinergic antidepressant**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Anticholinergic Antidepressant',
		Category = 'PDSI',
		ColumnDescription = 'Antihdepressants with an strong anticholinergic effect'
	WHERE ColumnName = 'AChAD_Rx'
	;
	-- updating variable flag
	UPDATE ##LookUp_NationalDrug_Stage
	SET AChAD_Rx = 1 
	FROM ##LookUp_NationalDrug_Stage
	where  drugnamewithoutdose in ('paroxetine', 'nortriptyline', 'imipramine','desipramine') 
		or drugnamewithoutdose like'%amitriptyline%' -- SM added desipramine per IW
		or (DrugNameWithoutDose like '%Doxepin%' and DrugNameWithDose not like '%6%' 
			and  DrugNameWithDose not like '%3%'and DrugNameWithDose not like '%cream%')  --SM added 9/11 exclude 3 and 6mg formulations
		--ST 9/14 changed and to or
		-- 11/13 SM updated from 'in' criteria to 'like' criteria to get all combo drugs...
	;

/***************Alcohol Pharmacotherapy**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Alcohol Pharmacotherapy',
		Category = 'PDSI',
		ColumnDescription = 'Medications to treat Alcohol Use Disorder'
	WHERE ColumnName = 'AlcoholPharmacotherapy_Rx'
	;
	-- updating variable flag
	UPDATE ##LookUp_NationalDrug_Stage
	SET AlcoholPharmacotherapy_Rx = 1
	where drugnamewithoutdose in ('naltrexone','disulfiram','Acamprosate','topiramate')--, 'gabapentin', 'baclofen') Removed by Jodie (5/2014) confirmed by Alex and Dan (7/2014)
	and drugnamewithdose not like '%naltrexone%4.5%'
	;
	
	
	/***************Alcohol Pharmacotherapy without topiramate**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Alcohol Pharmacotherapy no top',
		Category = 'PDSI',
		ColumnDescription = 'Medications to treat Alcohol Use Disorder not including topiramate'
	WHERE ColumnName = 'AlcoholPharmacotherapy_notop_Rx'
	;
	-- updating variable flag
	UPDATE ##LookUp_NationalDrug_Stage
	SET AlcoholPharmacotherapy_notop_Rx = 1
	where drugnamewithoutdose in ('naltrexone','disulfiram','Acamprosate')--,'topiramate')--, 'gabapentin', 'baclofen') Removed by Jodie (5/2014) confirmed by Alex and Dan (7/2014)
	and drugnamewithdose not like '%naltrexone%4.5%'
	;


/***************MoodStabilizers*************/
	-- updating definition information
    UPDATE [LookUp].[ColumnDescriptions]
    SET PrintName = 'Mood Stabilizer excluding Clonazepam',
		Category = 'PDSI',
        ColumnDescription = 'Mood Stadilizer medication category for the GE3 measure excludes clonazepam due to overlap with Anxiolytics_Rx'
    WHERE ColumnName = 'MoodStabilizer_GE3_Rx'
    ;
    -- updating variable flag         
    UPDATE ##LookUp_NationalDrug_Stage
    SET MoodStabilizer_GE3_Rx = 1
    WHERE DrugNameWithoutDose in ('carbamazepine', 'divalproex','Felbamate', 'gabapentin', 'lamotrigine'
		,'oxcarbazepine', 'topiramate', 'valproic acid')
		or DrugNameWithoutDose like '%lithium%'
	   ;
	   
/*************** Anticonvulsants for treating pain**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Anticonvulsants for treating pain',
		Category = 'ORM',
		ColumnDescription = 'Anticonvulsants for adjunct pain therapy per VA guideline'
	WHERE ColumnName = 'PainAdjAnticonvulsant_Rx'
	;


/***************Antidepressant**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Antidepressant',
		Category = 'PDSI',
		ColumnDescription = 'Medications to treat depression'
	WHERE ColumnName = 'Antidepressant_Rx'
	;
	-- updating variable flag
	UPDATE ##LookUp_NationalDrug_Stage
	SET Antidepressant_Rx = 1
	WHERE  PrimaryDrugClassCode IN ('CN601', 'CN602','CN609')
		or DrugNameWithoutDose like '%AMITRIPTYLINE%'
		or DrugNameWithoutDose like '%FLUOXETINE%'
		--or drugnamewithoutdose like '%Atomoxetine%' -- This WAS Added by SMITREC bc it was in some measures but not others it was decided to REMOVE this as an AD for ALL MEASURES 12/16/14
	;

/***************SSRI SNRI**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'SSRI or SNRI',
		Category = 'CDS',
		ColumnDescription = 'First line medications to treat depression'
	WHERE ColumnName = 'SSRI_SNRI_Rx'
	;
  

/***************Pain Meds with sedating effects**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Pain medications with sedative effects',
		Category = 'ORM',
		ColumnDescription = 'Pain medications with sedative effects'
	WHERE ColumnName = 'SedatingPainORM_Rx';
	;
	-- updating variable flag
	UPDATE ##LookUp_NationalDrug_Stage
	SET SedatingPainORM_Rx = 1
	WHERE  DrugNameWithoutDose in ('AMITRIPTYLINE', 'DOXEPIN', 'IMIPRAMINE','TIAGABINE', 
	'PROTRIPTYLINE', 'TRIMIPRAMINE', 'MIRTAZAPINE', 'DESIPRAMINE', 'MAPROTILINE', 
	'NORTRIPTYLINE', 'CLOMIPRAMINE', 'VENLAFAXINE', 'MILNACIPRAN','DULOXETINE', 
	'carbamazepine', 'LEVETIRACETAM', 'ZONISAMIDE','TIAGABINE', 'gabapentin', 
	'PREGABALIN', 'oxcarbazepine', 'topiramate', 'valproic acid')
	;

/***************Tramadol**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Pain medications with sedative effects',
		Category = 'ORM',
		ColumnDescription = 'Pain medications with sedative effects'
	WHERE ColumnName = 'Tramadol_Rx';
	;

/***************Antipsychotic  Geri**************/
--removing promethazie and Chlorperazine if prescribed for <=60 days in outpatient setting
--do not include for outpatient measures if prescribed as inpatient
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Antipsychotic for Geri',
		Category = 'PDSI',
		ColumnDescription = 'Medications to treat psychosis (excluded promethazine and chlorperazine)'
	WHERE ColumnName = 'Antipsychotic_Geri_Rx';
	;
	-- updating variable flag
	UPDATE ##LookUp_NationalDrug_Stage
	SET Antipsychotic_Geri_Rx = 1
	where (PrimaryDrugClassCode like 'CN70%'
		or DrugNameWithoutDose like '%PERPHENAZINE%'
		or Drugnamewithoutdose like 'olanzapine%'
		--Added by SMITREC
		or Drugnamewithoutdose like '%Droperidol%'
		or Drugnamewithoutdose like '%Pimozide%'
		--or Drugnamewithoutdose like '%Prochlorperazine%' --SM removed per IW 9/17/15
		--or Drugnamewithoutdose like '%Promethazine%' --SM removed per IW 9/17/15
		or drugnamewithoutdose like '%PALIPERIDONE%' or 
		drugnamewithoutdose like '%MESORIDAZINE BESYLATE%' or --updated where clause to pick up combo formulations 8/6/16 SM
		drugnamewithoutdose like '%ASENAPINE%' or
		drugnamewithoutdose like '%CHLORPROTHIXENE%' or
		drugnamewithoutdose like '%LURASIDONE%' or
		drugnamewithoutdose like '%AMITRIPTYLINE/PERPHENAZINE%' or
		drugnamewithoutdose like '%BREXPIPRAZOLE%' or
		drugnamewithoutdose like '%CLOZAPINE (UDL)%' or
		drugnamewithoutdose like '%TRIFLUOPERAZINE%' or
		drugnamewithoutdose like '%PIMAVANSERIN%' or
		drugnamewithoutdose like '%CLOZAPINE (ACTAVIS)%' or
		drugnamewithoutdose like '%MOLINDONE%' or
		drugnamewithoutdose like '%HALOPERIDOL%' or
		drugnamewithoutdose like '%ILOPERIDONE%' or
		drugnamewithoutdose like '%LOXAPINE%' or
		drugnamewithoutdose like '%OLANZAPINE%' or
		drugnamewithoutdose like '%TRIFLUPROMAZINE%' or
		drugnamewithoutdose like '%DROPERIDOL%' or
		drugnamewithoutdose like '%CLOZAPINE (CLOZARIL)%' or
		drugnamewithoutdose like '%PERPHENAZINE%' or
		drugnamewithoutdose like '%RISPERIDONE%' or
		drugnamewithoutdose like '%FLUPHENAZINE%' or
		drugnamewithoutdose like '%ACETOPHENAZINE MALEATE%' or
		drugnamewithoutdose like '%ARIPIPRAZOLE%' or
		drugnamewithoutdose like '%CLOZAPINE (CARACO)%' or
		drugnamewithoutdose like '%CLOZAPINE%' or
		drugnamewithoutdose like '%PIMOZIDE%' or
		drugnamewithoutdose like '%THIORIDAZINE%' or
		drugnamewithoutdose like '%CARIPRAZINE%' or
		drugnamewithoutdose like '%THIOTHIXENE%' or
		drugnamewithoutdose like '%CLOZAPINE (TEVA)%' or
		drugnamewithoutdose like '%CHLORPROMAZINE%' or
		drugnamewithoutdose like '%CLOZAPINE (VERSACLOZ)%' or
		drugnamewithoutdose like '%DROPERIDOL/FENTANYL%' or
		drugnamewithoutdose like '%CLOZAPINE (MYLAN)%' or
		drugnamewithoutdose like '%CLOZAPINE (FAZACLO)%' or
		drugnamewithoutdose like '%ZIPRASIDONE%' or
		drugnamewithoutdose like '%QUETIAPINE%' or
		drugnamewithoutdose like '%CLOZAPINE (IVAX)%' 
		)
		--REmoved by SMITREC
		and (drugnamewithoutdose not like '%Methotrimeprazine%'
		and drugnamewithoutdose not like '%Piperacetazine%'
		and drugnamewithoutdose not like 'Promazine%'
		)
	;

/***************Prochlorperazine**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Prochlorperazine',
		Category = 'PDSI',
		ColumnDescription = 'Prochlorperazine - antipsychotic if used for >60days'
	WHERE ColumnName = 'Prochlorperazine_Rx';
	;

	
/***************Promethazine**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Promethazine',
		Category = 'PDSI',
		ColumnDescription = 'Promethazine - antipsychotic if used for >60days'
	WHERE ColumnName = 'Promethazine_Rx';
	;


/***************Antipsychotic**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Antipsychotic',
		Category = 'PDSI',
		ColumnDescription = 'Medications to treat psychosis'
	WHERE ColumnName = 'Antipsychotic_Rx';
	;
	-- updating variable flag
	UPDATE ##LookUp_NationalDrug_Stage
	SET Antipsychotic_Rx = 1
	where (PrimaryDrugClassCode like 'CN70%'
		or drugnamewithoutdose like '%ACETOPHENAZINE MALEATE%' --updated where clause to pick up combo formulations 8/6/16 SM
		or drugnamewithoutdose like '%ARIPIPRAZOLE%'
		or drugnamewithoutdose like '%ASENAPINE%' 
		or drugnamewithoutdose like '%BREXPIPRAZOLE%' 
		or drugnamewithoutdose like '%CARIPRAZINE%' 
		or drugnamewithoutdose like '%CHLORPROMAZINE%'
		or drugnamewithoutdose like '%CHLORPROTHIXENE%'
		or drugnamewithoutdose like '%CLOZAPINE%'
		or drugnamewithoutdose like '%DROPERIDOL%'
		or drugnamewithoutdose like '%DROPERIDOL/FENTANYL%'
		or drugnamewithoutdose like '%FLUPHENAZINE%'
		or drugnamewithoutdose like '%HALOPERIDOL%' 
		or drugnamewithoutdose like '%ILOPERIDONE%' 
		or drugnamewithoutdose like '%LOXAPINE%' 
		or drugnamewithoutdose like '%LURASIDONE%'
		or drugnamewithoutdose like '%MESORIDAZINE BESYLATE%'
		or drugnamewithoutdose like '%MOLINDONE%'
		or drugnamewithoutdose like '%OLANZAPINE%'
		or drugnamewithoutdose like '%PALIPERIDONE%'
		or drugnamewithoutdose like '%PERPHENAZINE%'
		or drugnamewithoutdose like '%PIMAVANSERIN%'
		or drugnamewithoutdose like '%PIMOZIDE%'
		or drugnamewithoutdose like '%PROCHLORPERAZINE%'
		or drugnamewithoutdose like '%PROMETHAZINE%'
		or drugnamewithoutdose like '%QUETIAPINE%'
		or drugnamewithoutdose like '%RISPERIDONE%'
		or drugnamewithoutdose like '%THIORIDAZINE%'
		or drugnamewithoutdose like '%THIOTHIXENE%'
		or drugnamewithoutdose like '%TRIFLUOPERAZINE%'
		or drugnamewithoutdose like '%TRIFLUPROMAZINE%'
		or drugnamewithoutdose like '%ZIPRASIDONE%'
		)
	-- Removed by SMITREC
		and (drugnamewithoutdose not like '%Methotrimeprazine%'
			and drugnamewithoutdose not like '%Piperacetazine%'
			and drugnamewithoutdose not like 'Promazine%'
			);

/***************Antipsychotics - Second Generation**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Second Generation Antipsychotics',
		Category = 'PDSI',
		ColumnDescription = 'Second Generation Antipsychotics'
	WHERE ColumnName = 'AntipsychoticSecondGen_Rx';
	;
	-- updating variable flag
	UPDATE ##LookUp_NationalDrug_Stage
	SET AntipsychoticSecondGen_Rx = 1
	WHERE (PrimaryDrugClassCode like 'CN709' 
		or drugnamewithoutdose like '%ARIPIPRAZOLE%'  --updated where clause to pick up combo formulations 8/6/16 SM
		or drugnamewithoutdose like '%ASENAPINE%' 
		or drugnamewithoutdose like '%BREXPIPRAZOLE%' 
		or drugnamewithoutdose like '%CARIPRAZINE%' 
		or drugnamewithoutdose like '%CLOZAPINE%' 
		or drugnamewithoutdose like '%ILOPERIDONE%' 
		or drugnamewithoutdose like '%LURASIDONE%' 
		or drugnamewithoutdose like '%OLANZAPINE%' 
		or drugnamewithoutdose like '%PALIPERIDONE%' 
		or drugnamewithoutdose like '%PIMAVANSERIN%' 
		or drugnamewithoutdose like '%QUETIAPINE%' 
		or drugnamewithoutdose like '%RISPERIDONE%' 
		or drugnamewithoutdose like '%ZIPRASIDONE%' )

/*These are in the wrong Category is in the wrong Category code*/ 
and drugnamewithoutdose not like 'Hal%' and drugnamewithoutdose not like '%Loxapine%' and drugnamewithoutdose not like '%Molindone%'
	;

/***************Stimulants**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Stimulants',
		Category = 'PERC',
		ColumnDescription = 'Stimulants All'
	WHERE ColumnName = 'Stimulant_Rx';
	;
	-- updating variable flag
	UPDATE ##LookUp_NationalDrug_Stage
	SET Stimulant_Rx = 1
	WHERE DrugNameWithoutDose like '%amphetamine%' or DrugNameWithoutDose like '%Methylphenidate%'
	 or DrugNameWithoutDose like '%modafinil%' ;
	 ;

/***************Stimulants for ADHD**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Stimulants for ADHD',
		Category = 'PERC',
		ColumnDescription = 'Stimulants approved for treatment of attention deficient (and hyperactivity) disorder'
	WHERE ColumnName = 'StimulantADHD_Rx';
	;
	-- updating variable flag
	UPDATE ##LookUp_NationalDrug_Stage
	SET StimulantADHD_Rx = 1
	WHERE PrimaryDrugClassCode like 'CN801' OR (PrimaryDrugClassCode like 'CN802' AND DrugNameWithoutDose not like 'MAZINDOL') ;
	-- broadened to use drug class code to mirror Academic Detailing definition
	;
	
/***************Tricyclic antidepressants (TCAs) for treating pain**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Tricyclic antidepressants (TCAs) for treating pain',
		Category = 'ORM',
		ColumnDescription = 'Tricyclic antidepressants (TCAs) for adjunct pain therapy per VA guideline'
	WHERE ColumnName = 'PainAdjTCA_Rx';
	;

/***************Serotonin-Norepinephrine Reuptake Inhibitors (SNRI) for treating pain**************/
	--updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Serotonin-Norepinephrine Reuptake Inhibitors (SNRI) for treating pain',
		Category = 'ORM',
		ColumnDescription = 'Serotonin-Norepinephrine Reuptake Inhibitors (SNRI) for adjunct pain therapy per VA guideline'
	WHERE ColumnName = 'PainAdjSNRI_Rx'
	;
	-- updating variable flag
	UPDATE ##LookUp_NationalDrug_Stage
	SET PainAdjSNRI_Rx = 1
	where DrugNameWithoutDose in ('VENLAFAXINE', 'MILNACIPRAN','DULOXETINE')
	--,'BUPROPION' Removed 3/5/15 per Jodie
	;

/***************Anxiolytics**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Anxiolytics',
		Category = 'PDSI',
		ColumnDescription = 'This is a category created by the orginal PDSI group and contains both Sedatives (for sleep) and anxiolytics (for anxiety)'
	WHERE ColumnName = 'Anxiolytics_Rx'
	;
	-- updating variable flag		
	UPDATE ##LookUp_NationalDrug_Stage
	SET Anxiolytics_Rx = 1
	WHERE  (PrimaryDrugClassCode like 'CN302' 
		or DrugNameWithoutDose in ('Alprazolam','Estazolam','Lorazepam','Oxazepam','Temazepam','Triazolam','Clorazepate'
			,'Ch+lordiazepoxide','Clonazepam','Diazepam','Flurazepam','Quazepam','Zolpidem','Buspirone','Chloral hydrate'
			,'Zaleplon','Eszopiclone')
		or DrugNameWithoutDose like '%Zolpidem%' -- adding individual drugs to capture combo drugs
		or drugnamewithoutdose like '%DIAZEPAM%' 
		or drugnamewithoutdose  like '%LORAZEPAM%' 
		or drugnamewithoutdose  like '%TRIAZOLAM%' 
		or drugnamewithoutdose  like '%HALAZEPAM%' 
		or drugnamewithoutdose  like '%CLORAZEPATE%' 
		or drugnamewithoutdose  like '%CLONAZEPAM%' 
		or drugnamewithoutdose  like '%TEMAZEPAM%' 
		or drugnamewithoutdose  like '%ESTAZOLAM%' 
		or drugnamewithoutdose  like '%ALPRAZOLAM%' 
		or drugnamewithoutdose  like '%ZOLPIDEM%' 
		or drugnamewithoutdose  like '%QUAZEPAM%' 
		or drugnamewithoutdose  like '%ZALEPLON%' 
		or drugnamewithoutdose  like '%ESZOPICLONE%' 
		or drugnamewithoutdose  like '%BUSPIRONE%' 
		or drugnamewithoutdose  like '%OXAZEPAM%' 
		or drugnamewithoutdose  like '%FLURAZEPAM%' 
		or drugnamewithoutdose  like '%CHLORAL HYDRATE%' 
		or drugnamewithoutdose  like '%PRAZEPAM%' 
		or drugnamewithoutdose  like '%CHLORDIAZEPOXIDE%')
		and drugnamewithoutdose <> 'MIDAZOLAM' --Removed by Ilse Wiechers 4/2014 
	;

/***************Benzodiazepines*************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Benzodiazepines',
		Category = 'PDSI',
		ColumnDescription = 'Benzodiazepines'
	WHERE ColumnName = 'Benzodiazepine_Rx'
	;
/***************Sedatives (Z drugs)*************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Sedatives Z Drugs',
		Category = 'PDSI',
		ColumnDescription = 'Sedatives including zolpidem, zaleplon, eszopiclone'
	WHERE ColumnName = 'Sedative_zdrug_Rx'



/***************Mood Stabilizers*************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Mood Stabilizer',
		Category = 'PDSI',
		ColumnDescription = 'Medications used for treating bipolar disorder complete list including clonazepam'
	WHERE ColumnName = 'MoodStabilizer_Rx'
	;
	-- updating variable flag		
	UPDATE ##LookUp_NationalDrug_Stage
	SET MoodStabilizer_Rx = 1
	WHERE   DrugNameWithoutDose in ('carbamazepine', 'clonazepam', 'divalproex','Felbamate', 'gabapentin', 'lamotrigine'
     , 'oxcarbazepine', 'topiramate', 'valproic acid')
	 or DrugNameWithoutDose like '%lithium%'
	;

/***************MoodStabilizers - No Clonazepam*************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Mood Stabilizer excluding Clonazepam',
		Category = 'PDSI',
		ColumnDescription = 'Mood Stadilizer medication category for the GE3 measure excludes clonazepam due to overlap with Anxiolytics_Rx'
	WHERE ColumnName = 'MoodStabilizer_GE3_Rx'
	;

	-- updating variable flag		
	UPDATE ##LookUp_NationalDrug_Stage
	SET MoodStabilizer_Rx = 1
	WHERE   DrugNameWithoutDose in ('carbamazepine', 'clonazepam', 'divalproex','Felbamate', 'gabapentin', 'lamotrigine'
     , 'oxcarbazepine', 'topiramate', 'valproic acid')
	 or DrugNameWithoutDose like '%lithium%'
	;

	/***************Methadone for non va meds**************/
	-- updating definition information
		UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Methadone',
		Category = 'STORM',
		ColumnDescription = 'Methadone for use in non VA med selection for OAT'
	WHERE ColumnName = 'Methadone_Rx'
	;

/***************Opioid Agonist**************/
	-- updating definition information
UPDATE [LookUp].[ColumnDescriptions]
SET PrintName = 'Opioid Agonist',
Category = 'PDSI',
ColumnDescription = 'Medications used to treat opioid dependence'
WHERE ColumnName = 'OpioidAgonist_Rx'
;
-- updating variable flag
-- OpioidAgonist_Rx defintions based on Methadone formulation reporting by OTP clinics
UPDATE ##LookUp_NationalDrug_Stage
set OpioidAgonist_Rx = case
	when  drugnamewithdose = 'METHADONE CONCENTRATED 10MG/ML SOLN,ORAL' then 1
	when	drugnamewithdose = 'METHADONE HCL 10MG/5ML SOLN,ORAL' then 1
  when  drugnamewithdose = 'METHADONE HCL 1MG/ML SOLN,ORAL' then 1
 --MAYBE 	when	drugnamewithdose = 'METHADONE%SOLN%ORAL' then 1 
	when  Drugnamewithdose like '%bupre%nalox%bucc%' then 1	
	when  drugnamewithdose like '%buprenorphine%' and dosageform like '%INJ,SOLN,SA%' then 1
	when	(DrugNameWithoutDose like '%Buprenorphine%' AND NOT drugnamewithdose LIKE '%mcg%film%' ) --these formulations are opioid for pain (case when it is bupe film with nalaxone are caught above)
			and drugnamewithdose not like '%patch%' 
			and drugnamewithdose not like '%hcl%inj%' --this may be redundant with line below or perhaps there are other hcl inj it should be excluding?
			and drugnamewithdose not like '%buprenorphine%ampul%' 
			then 1 --per JT, no one would give a syringe of bupe as an opioid agonist. This has been revisited due to Sublocade issue.
ELSE 0
end



;


/***************Injectible Naltrexone**************/
	-- updating definition information
		UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Injectible Naltrexone',
		Category = 'PDSI',
		ColumnDescription = 'Medications used to treat opioid dependence'
	WHERE ColumnName = 'NaltrexoneINJ_Rx'
	;
	

			/***************Opioid analgesics includes tramadol**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'OpioidsForPain',
		Category = 'ORM',
		ColumnDescription = 'Opioid analgesics includes tramadol'
	WHERE ColumnName = 'OpioidForPain_Rx'
	;		
	-- updating variable flag					
	UPDATE ##LookUp_NationalDrug_Stage
	SET OpioidForPain_Rx = case
	when  drugnamewithdose = 'METHADONE CONCENTRATED 10MG/ML SOLN,ORAL' then 0
	when	drugnamewithdose = 'METHADONE HCL 10MG/5ML SOLN,ORAL' then 0
 --MAYBE 	when	drugnamewithdose = 'METHADONE%SOLN%ORAL' then 1 
	when  Drugnamewithdose like '%bupre%nalox%bucc%' then 0	
	when  drugnamewithdose like '%buprenorphine%' and dosageform like '%INJ,SOLN,SA%' then 0
	when	(DrugNameWithoutDose like '%Buprenorphine%' AND NOT drugnamewithdose LIKE '%mcg%film%' ) --these formulations are opioid for pain (case when it is bupe film with nalaxone are caught above)
			and drugnamewithdose not like '%patch%' 
			and drugnamewithdose not like '%hcl%inj%' --this may be redundant with line below or perhaps there are other hcl inj it should be excluding?
			and drugnamewithdose not like '%buprenorphine%ampul%' 
			then 0 --per JT, no one would give a syringe of bupe as an opioid agonist. This has been revisited due to Sublocade issue.
	when (PrimaryDrugClassCode = 'CN101' or DrugNameWithoutDose like '%tramadol%')
			AND DrugNameWithDose NOT LIKE '%BUPRENOR%NALOX%' -- for OAT JT
			AND DrugNameWithDose  NOT like '%bupre%sublingual%' -- for OAT JT
			AND DrugNameWithDose NOT LIKE '%ipecac%'--exclude opium formulations with ipecac JT
			AND DrugNameWithDose  not like '%bupre%kit%' -- excluded from opioid pain by IW/JT
			AND DrugNameWithDose NOT LIKE '%DOVERIN%' 
			AND DrugNameWithDose NOT LIKE '%buprenor%ER%syringe%'
			AND DosageForm NOT LIKE '%INJ,SOLN,SA%' 
			AND DosageForm != 'SOLUTION-IV' --CB added for Cerner
			THEN 1
ELSE 0
  end
  
  UPDATE ##LookUp_NationalDrug_Stage
	SET OpioidForPain_Rx = 0
  where OpioidAgonist_Rx = 1 
  
		

	/*******************************************************************
	 Updating StrengthNumeric for OpioidForPain_Rx where it is NULL 
	******************************************************************/
	--Process for Vista records
	
	--First, we find the index in the DrugNameWithDose string after which we can start looking for a dosage amount.
	--We can't assume that the opioid in a combination drug is listed first, therefore we search for the opioid by name.
	DROP TABLE IF EXISTS #OpioidName_Vista_Vista
	SELECT DISTINCT 
		NationalDrugSID
		,DrugNameWithDose
		,StrengthNumeric 
		,CASE 
			WHEN PATINDEX('%Buprenorphine%', DrugNameWithDose) > 0 THEN PATINDEX('%Buprenorphine%', DrugNameWithDose) 
			WHEN PATINDEX('%Butorphanol%', DrugNameWithDose) > 0 THEN PATINDEX('%Butorphanol%', DrugNameWithDose) 
			WHEN PATINDEX('%Dihydrocodeine%', DrugNameWithDose) > 0 THEN PATINDEX('%Dihydrocodeine%', DrugNameWithDose) --Put Dihydrocodeine BEFORE codeine in CASE statement
			WHEN PATINDEX('%Codeine%', DrugNameWithDose) > 0 THEN PATINDEX('%Codeine%', DrugNameWithDose) 
			WHEN PATINDEX('%Fentanyl%', DrugNameWithDose) > 0 THEN PATINDEX('%Fentanyl%', DrugNameWithDose) 
			WHEN PATINDEX('%Hydrocodone%', DrugNameWithDose) > 0 THEN PATINDEX('%Hydrocodone%', DrugNameWithDose)
			WHEN PATINDEX('%Hydromorphone%', DrugNameWithDose) > 0 THEN PATINDEX('%Hydromorphone%', DrugNameWithDose) 
			WHEN PATINDEX('%Levorphanol%', DrugNameWithDose) > 0 THEN PATINDEX('%Levorphanol%', DrugNameWithDose) 
			WHEN PATINDEX('%Meperidine%', DrugNameWithDose) > 0 THEN PATINDEX('%Meperidine%', DrugNameWithDose) 
			WHEN PATINDEX('%Methadone%', DrugNameWithDose) > 0 THEN PATINDEX('%Methadone%', DrugNameWithDose) 
			WHEN PATINDEX('%Morphine%', DrugNameWithDose) > 0 THEN PATINDEX('%Morphine%', DrugNameWithDose) 
			WHEN PATINDEX('%Opium%', DrugNameWithDose) > 0 THEN PATINDEX('%Opium%', DrugNameWithDose) 
			WHEN PATINDEX('%Oxycodone%', DrugNameWithDose) > 0 THEN PATINDEX('%Oxycodone%', DrugNameWithDose) 
			WHEN PATINDEX('%Oxymorphone%', DrugNameWithDose) > 0 THEN PATINDEX('%Oxymorphone%', DrugNameWithDose) 
			WHEN PATINDEX('%Pentazocine%', DrugNameWithDose) > 0 THEN PATINDEX('%Pentazocine%', DrugNameWithDose)
			WHEN PATINDEX('%Propoxyphene%', DrugNameWithDose) > 0 THEN PATINDEX('%Propoxyphene%', DrugNameWithDose)
			WHEN PATINDEX('%Tapentadol%', DrugNameWithDose) > 0 THEN PATINDEX('%Tapentadol%', DrugNameWithDose)
			WHEN PATINDEX('%Tramadol%', DrugNameWithDose) > 0 THEN PATINDEX('%Tramadol%', DrugNameWithDose)
		ELSE LEN(DrugNameWithDose)
		END OpioidNameEndingIndex	
	INTO #OpioidName_Vista
	FROM ##LookUp_NationalDrug_Stage
	WHERE OpioidForPain_Rx = 1	
		AND StrengthNumeric IS NULL
		AND Sta3n <> 200
	

	--Next, we find the starting and ending indices of the dosage amount. 
	----Note, these indices are relative to the substring starting with the opioid name. The starting index is found by looking for the first number we see appearing in the substring. 
	----The ending index is found by looking for the start of the pattern 'MG' or 'MCG'. We know that we want all numbers up to that point.
	DROP TABLE IF EXISTS #DosageIndices_Vista
	SELECT NationalDrugSID
		,DrugNameWithDose
		,StrengthNumeric
		,PATINDEX('% [0-9]%', SUBSTRING(DrugNameWithDose,OpioidNameEndingIndex,LEN(DrugNameWithDose))) as DosageStartingIndex
		,CASE
			WHEN PATINDEX('%MG%',SUBSTRING(DrugNameWithDose,OpioidNameEndingIndex,LEN(DrugNameWithDose))) > 0 THEN PATINDEX('%MG%',SUBSTRING(DrugNameWithDose,OpioidNameEndingIndex,LEN(DrugNameWithDose)))
			WHEN PATINDEX('%MCG%',SUBSTRING(DrugNameWithDose,OpioidNameEndingIndex,LEN(DrugNameWithDose)))> 0 THEN PATINDEX('%MCG%',SUBSTRING(DrugNameWithDose,OpioidNameEndingIndex,LEN(DrugNameWithDose)))
			ELSE NULL 
			END as DosageEndingIndex 
		,OpioidNameEndingIndex
	INTO #DosageIndices_Vista
	FROM #OpioidName_Vista
	
	--Finally, we calculate the strengthNumeric. After testing that our indices are valid, we take the substring of numbers from
	--DrugNameWithDose. This requires starting at the dosageStartingIndex + opioidNameEndingIndex, so that we are looking at the 
	--apporopriate place in the entire string, and we want a length of dosageEndingIndex - 1) - dosageStartingIndex.
	DROP TABLE IF EXISTS #CalculateStrengthNumeric_Vista
	SELECT NationalDrugSID
		,DrugNameWithDose
		,CASE WHEN DosageEndingIndex-DosageStartingIndex > 0 THEN
			--this substring picks out the drug strength based on the indices we found below
			CAST(SUBSTRING(DrugNameWithDose, DosageStartingIndex + OpioidNameEndingIndex, (DosageEndingIndex - 1) - DosageStartingIndex) AS decimal(19,4))
			ELSE NULL 
			END as Strength
	INTO #CalculateStrengthNumeric_Vista
	FROM #DosageIndices_Vista

	--Now we are ready to UPDATE##LookUp_NationalDrug_Stage's strengthNumeric column with our calculatedStrengthNumeric.
	UPDATE ##LookUp_NationalDrug_Stage
	SET CalculatedStrengthNumeric = Strength
	FROM ##LookUp_NationalDrug_Stage as nd
	INNER JOIN #CalculateStrengthNumeric_Vista as a ON a.NationalDrugSID = nd.NationalDrugSID
		AND nd.Sta3n<>200


	/*
	select distinct sta3n, drugnamewithdose,strengthnumeric,calculatedstrengthnumeric 
	from ##LookUp_NationalDrug_Stage where opioidforpain_rx=1 and (strengthnumeric IS NULL OR strengthnumeric <> calculatedstrengthnumeric)
	*/

	DROP TABLE #OpioidName_Vista,#DosageIndices_Vista,#CalculateStrengthNumeric_Vista


/***************Opioid medications,  includes tramadol **************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Opioid',
		Category = 'ORM',
		ColumnDescription = 'Opioid medications, includes tramadol'
	WHERE ColumnName = 'Opioid_Rx'
	;		
	-- updating variable flag					
	UPDATE ##LookUp_NationalDrug_Stage
	SET Opioid_Rx = 1
	WHERE   PrimaryDrugClassCode = 'CN101' or DrugNameWithoutDose like '%tramadol%'
	;

/***************Opioid Antagonist Kit - i.e. Naloxone Kits**************/
	-- updating definition information
	--UPDATE [LookUp].[ColumnDescriptions]
	--SET PrintName = 'Opioid Antagonist Kit',
	--	Category = 'ORM',
	--	ColumnDescription = 'Naloxone its to prevent opioid overdose'
	--WHERE ColumnName = 'OpioidAntagonistKit_Rx'
	--;		
	---- updating variable flag					
	--UPDATE ##LookUp_NationalDrug_Stage
	--SET OpioidAntagonistKit_Rx = 1
	--WHERE (drugnamewithdose like '%Nalox%kit%' 
	--    or drugnamewithdose like '%NALOX%AUTO%' 
 --       or drugnamewithdose like '%EVZIO%'
 --       or drugnamewithdose like '%NALOX%SPRAY%'
 --       or drugnamewithdose like '%NARC%SPRAY%')
	--and drugnamewithdose not like '%DEMO%'
	--;


/***************Naloxone Kit**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Naloxone Kit',
		Category = 'ORM',
		ColumnDescription = 'Naloxone is used to treat opioid overdose'
	WHERE ColumnName = 'NaloxoneKit_Rx'
	;		
	-- updating variable flag					
	UPDATE ##LookUp_NationalDrug_Stage
	SET NaloxoneKit_Rx = 1
	WHERE (drugnamewithdose like '%Nalox%kit%' 
	    or drugnamewithdose like '%NALOX%AUTO%' 
        or drugnamewithdose like '%EVZIO%'
        or drugnamewithdose like '%NALOX%SPRAY%'
        or drugnamewithdose like '%NARC%SPRAY%'
		or drugnamewithdose like '%NALOX%5MG/0.5ML%INJ%')
	and drugnamewithdose not like '%DEMO%'
	;

	
/***************Sedative**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Sedatives',
		Category = 'ORM',
		ColumnDescription = 'Sedatives All, non injectable'
	WHERE ColumnName = 'SedativeOpioid_Rx'
	;		

/***************Bowel**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Bowel Treatments',
		Category = 'ORM',
		ColumnDescription = 'Medications to treat the constipation side effects of opioids'
	WHERE ColumnName = 'Bowel_Rx'
	;		
	-- updating variable flag					
	UPDATE ##LookUp_NationalDrug_Stage
	SET Bowel_Rx = 1
	WHERE  PrimaryDrugClassCode = 'GA201' 
		or PrimaryDrugClassCode = 'GA202'
		or PrimaryDrugClassCode = 'GA203'
		or PrimaryDrugClassCode = 'GA204'
		or PrimaryDrugClassCode = 'GA205'
		or PrimaryDrugClassCode = 'GA209'
		or PrimaryDrugClassCode = 'RS300'
	;
	
/*************** Prazosin**************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Prazosin',
		Category = 'PDSI',
		ColumnDescription = 'Prazosin - used to treat PTSD'
	WHERE ColumnName = 'Prazosin_Rx'
	;		

	
/*************** Tobacco/Nicotine **************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Tobacco Pharmacotherapy',
		Category = 'PDSI',
		ColumnDescription = 'Medications for smoking cessation and nicotine dependence including NRT, varenicline, and bupropion'
	WHERE ColumnName = 'TobaccoPharmacotherapy_Rx';
	;

-----------------------------------------------------------------------------------------------------
/*
************Categories below this point need to remain at the bottom of the code 
they reference the columns defined above to make parent cateogries************
*/

/***************Psychotropic*************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Psychotropic',
		Category = 'PDSI',
		ColumnDescription = 'Any medications in the Antipsychotic, Antidepressant,Mood Stabilizer or Anxiolytic categories'
	WHERE ColumnName = 'Psychotropic_Rx'
	;
	-- updating variable flag		
	UPDATE ##LookUp_NationalDrug_Stage
	SET Psychotropic_Rx = 1
	WHERE   Antipsychotic_Rx = 1 or Antidepressant_Rx = 1 or MoodStabilizer_Rx = 1 or Anxiolytics_Rx =1 
	;

/***************PDSIRelevantDrug*************/
	-- updating definition information
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'PDSI Relevant Drug',
		Category = 'PDSI',
		ColumnDescription = 'Any medications in the Referenced in PDSI categories'
	WHERE ColumnName = 'PDSIRelevant_Rx'
	;
	-- updating variable flag		
	UPDATE ##LookUp_NationalDrug_Stage
	SET PDSIRelevant_Rx = 1
	WHERE Antipsychotic_Rx = 1 or Benzodiazepine_Rx=1 or OpioidForPain_Rx=1 or Sedative_zdrug_Rx=1 or StimulantADHD_Rx=1
	;

;

/***************Reach Antidepressant**************/
	-- updating definition information
	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Antidepressant',
		Category = 'Preceptive Reach - Reach Vet',
		ColumnDescription = 'Medications to treat depression based on SMITREC Perceptive Reach Model'
	WHERE ColumnName = 'Reach_Antidepressant_Rx';
	;
	-- updating variable flag
	UPDATE ##LookUp_NationalDrug_Stage
	SET Reach_Antidepressant_Rx = 1
	WHERE (PrimaryDrugClassCode IN ('CN601', 'CN602','CN609')
		or DrugNameWithoutDose like '%AMITRIPTYLINE%'
		or DrugNameWithoutDose like '%FLUOXETINE%'
		or DrugNameWithoutDose like '%ATOMOXETINE%')
		and DrugNameWithoutDose not like 'LEVOMILNACIPRAN'
		and DrugNameWithoutDose not like 'MILNACIPRAN'
		and DrugNameWithoutDose not like 'VORTIOXETINE'
	;
	
/***************Reach Alprazolam**************/
	-- updating definition information
	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Alprazolam',
		Category = 'Preceptive Reach - Reach Vet',
		ColumnDescription = 'Alprazolam based on SMITREC Perceptive Reach Model'
	WHERE ColumnName = 'Alprazolam_Rx';	
	;


/***************Reach Clonazepam**************/
	-- updating definition information
	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Clonazepam',
		Category = 'Preceptive Reach - Reach Vet',
		ColumnDescription = 'Clonazepam based on SMITREC Perceptive Reach Model'
	WHERE ColumnName = 'Clonazepam_Rx';
	;


/***************Reach Lorazepam**************/
	-- updating definition information
	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Lorazepam',
		Category = 'Preceptive Reach - Reach Vet',
		ColumnDescription = 'Lorazepam based on SMITREC Perceptive Reach Model'
	WHERE ColumnName = 'Lorazepam_Rx';
	;
	-- updating variable flag
	UPDATE ##LookUp_NationalDrug_Stage
	SET Lorazepam_Rx = 1
	WHERE  DrugNameWithoutDose like '%Lorazepam%'
	;

/***************Reach Mirtazapine**************/
	-- updating definition information
	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Mirtazapine',
		Category = 'Preceptive Reach - Reach Vet',
		ColumnDescription = 'Mirtazapine based on SMITREC Perceptive Reach Model'
	WHERE ColumnName = 'Mirtazapine_Rx';
	;


/***************Reach Antipsychotic**************/
	-- updating definition information
	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Antipsychotic',
		Category = 'Preceptive Reach - Reach Vet',
		ColumnDescription = 'Medications to treat psychosis defined by SMITREC for Perceptive Reach'
	WHERE ColumnName = 'Reach_Antipsychotic_Rx';
	;
	-- updating variable flag
	UPDATE ##LookUp_NationalDrug_Stage
	SET Reach_Antipsychotic_Rx = 1
	where (PrimaryDrugClassCode like 'CN70%'
		or drugnamewithoutdose like '%ACETOPHENAZINE MALEATE%' --updated where clause to pick up combo formulations 8/6/16 SM
		or drugnamewithoutdose like '%ARIPIPRAZOLE%' 
		or drugnamewithoutdose like '%ASENAPINE%' 
		or drugnamewithoutdose like '%CHLORPROMAZINE%' 
		or drugnamewithoutdose like '%CHLORPROTHIXENE%' 
		or drugnamewithoutdose like '%CLOZAPINE%' 
		or drugnamewithoutdose like '%DROPERIDOL%' 
		or drugnamewithoutdose like '%DROPERIDOL/FENTANYL%' 
		or drugnamewithoutdose like '%FLUPHENAZINE%' 
		or drugnamewithoutdose like '%HALOPERIDOL%' 
		or drugnamewithoutdose like '%ILOPERIDONE%' 
		or drugnamewithoutdose like '%LOXAPINE%' 
		or drugnamewithoutdose like '%LURASIDONE%' 
		or drugnamewithoutdose like '%MESORIDAZINE BESYLATE%' 
		or drugnamewithoutdose like '%MOLINDONE%' 
		or drugnamewithoutdose like '%OLANZAPINE%' 
		or drugnamewithoutdose like '%PALIPERIDONE%' 
		or drugnamewithoutdose like '%PERPHENAZINE%' 
		or drugnamewithoutdose like '%PIMOZIDE%' 
		or drugnamewithoutdose like '%PROCHLORPERAZINE%' 
		or drugnamewithoutdose like '%PROMETHAZINE%' 
		or drugnamewithoutdose like '%QUETIAPINE%'
		or drugnamewithoutdose like '%RISPERIDONE%' 
		or drugnamewithoutdose like '%THIORIDAZINE%' 
		or drugnamewithoutdose like '%THIOTHIXENE%' 
		or drugnamewithoutdose like '%TRIFLUOPERAZINE%' 
		or drugnamewithoutdose like '%TRIFLUPROMAZINE%' 
		or drugnamewithoutdose like '%ZIPRASIDONE%'
		)
		and (drugnamewithoutdose not like '%Methotrimeprazine%'
			and drugnamewithoutdose not like '%Piperacetazine%'
			and drugnamewithoutdose not like 'Promazine%'
			and drugnamewithoutdose not like '%BREXPIPRAZOLE%'-- not in SMITREC Perceptive Reach
			and drugnamewithoutdose not like '%CARIPRAZINE%'-- not in SMITREC Perceptive Reach
			and drugnamewithoutdose not like '%PIMAVANSERIN%'-- not in SMITREC Perceptive Reach
			)
;

/***************Reach Statins**************/
	-- updating definition information
	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Statins',
		Category = 'Preceptive Reach - Reach Vet',
		ColumnDescription = 'Medications to treat hyperlipidemia defined by SMITREC Perceptive Reach'
	WHERE ColumnName = 'Reach_Statin_Rx';
	;
	-- updating variable flag
	UPDATE ##LookUp_NationalDrug_Stage
	SET Reach_Statin_Rx = 1
	where  drugnamewithoutdose like '%ATORVASTATIN%' 
		or drugnamewithoutdose like '%FLUVASTATIN%'
		or drugnamewithoutdose like '%LOVASTATIN%' 
		or drugnamewithoutdose like '%PITAVASTATIN%'
		or drugnamewithoutdose like '%PRAVASTATIN%' 
		or drugnamewithoutdose like '%ROSUVASTATIN%' 
		or drugnamewithoutdose like '%SIMVASTATIN%' 
		;
		
/***************Reach Sedative_Anxiolytics**************/
	-- updating definition information
	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Anxiolytics',
		Category = 'Preceptive Reach - Reach Vet',
		ColumnDescription = 'This is a category created by SMITREC for Perceptive Reach Model that contains both Sedatives (for sleep) and anxiolytics (for anxiety)'
	WHERE ColumnName = 'Reach_SedativeAnxiolytic_Rx'
	;
	-- updating variable flag		
	UPDATE ##LookUp_NationalDrug_Stage
	SET Reach_SedativeAnxiolytic_Rx = 1
	WHERE  (PrimaryDrugClassCode like 'CN302' 
		or DrugNameWithoutDose in ('Alprazolam','Estazolam','Lorazepam','Oxazepam','Temazepam','Triazolam'
			,'Clorazepate','Chlordiazepoxide','Clonazepam','Diazepam','Flurazepam','Quazepam'
			,'Zolpidem','Buspirone','Chloral hydrate','Zaleplon','Eszopiclone')
		or DrugNameWithoutDose like '%Zolpidem%' -- adding individual drugs to capture combo drugs
		or drugnamewithoutdose like '%LORAZEPAM%' 
		or DrugNameWithoutDose like '%TRIAZOLAM%' 
		or DrugNameWithoutDose like '%CLORAZEPATE%' 
		or DrugNameWithoutDose like '%TEMAZEPAM%' 
		or DrugNameWithoutDose like '%ESTAZOLAM%' 
		or DrugNameWithoutDose like '%ALPRAZOLAM%' 
		or DrugNameWithoutDose like '%ZOLPIDEM%' 
		or DrugNameWithoutDose like '%QUAZEPAM%' 
		or DrugNameWithoutDose like '%ZALEPLON%' 
		or DrugNameWithoutDose like '%ESZOPICLONE%' 
		or DrugNameWithoutDose like '%BUSPIRONE%' 
		or DrugNameWithoutDose like '%OXAZEPAM%' 
		or DrugNameWithoutDose like '%FLURAZEPAM%' 
		or DrugNameWithoutDose like '%CHLORAL HYDRATE%' 
		or DrugNameWithoutDose like '%CHLORDIAZEPOXIDE%'
		)
		and drugnamewithoutdose <> 'MIDAZOLAM'  
		and drugnamewithoutdose not like  '%halazepam%'
		and drugnamewithoutdose not like  '%prazepam%'
	;
	
/***************Reach Opioid**************/
	-- updating definition information
	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Opioid',
		Category = 'Perceptive reach - Reach Vet',
		ColumnDescription = 'Opioid analgesics includes tramadol as defined by SMITREC for Perceptive Reach Model'
	WHERE ColumnName = 'Reach_Opioid_Rx'
	;		
	-- updating variable flag					
	UPDATE ##LookUp_NationalDrug_Stage
	SET Reach_Opioid_Rx = 1
	WHERE (PrimaryDrugClassCode = 'CN101' or DrugNameWithoutDose like '%tramadol%')
		and  drugnamewithoutdose not like  '%ALFENTANIL%'
		and  drugnamewithoutdose not like  '%ALPHAPRODINE%'
		and  drugnamewithoutdose not like  '%OPIUM%'
		and  drugnamewithoutdose not like  '%LEVORPHANOL%'
		and  drugnamewithoutdose not like  '%OXYMORPHONE%'
		and  drugnamewithoutdose not like  '%REMIFENTANIL%'
		and  drugnamewithoutdose not like  '%SUFENTANIL%'
		and  drugnamewithoutdose not like  '%TAPENTADOL%'
		and  drugnamewithoutdose not like  '%DEZOCINE%'
	;
/***************CNS_Depress_Rx**************/
--RAS added from Marcos Lau's original SPPRITE Code
	-- updating definition information
	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'CNS for Depression',
		Category = 'CNS',
		ColumnDescription = 'CNS Depression'
	WHERE ColumnName = 'CNS_Depress_Rx'
	;		

	-- updating variable flag					
	UPDATE ##LookUp_NationalDrug_Stage
	SET CNS_Depress_Rx = 1
	WHERE PrimaryDrugClassCode in ('CN101','CN300', 'CN301','CN302', 'CN309', 'MS200') or
		   (DrugNameWithoutDose = 'clonazepam' or DrugNameWithoutDose = 'diazepam' 
		OR DrugNameWithoutDose like '%chlordiazepoxide%' OR DrugNameWithoutDose like '%phenobarb%'
		or DrugNameWithoutDose = 'clobazam') 
		AND DrugNameWithoutDose not in ('buspirone', 'ORPHENADRINE CITRATE', 'ORPHENADRINE HYDROCHLORIDE','TIZANIDINE')
		or DrugNameWithoutDose in ('cyclobenzaprine','dronabinol')
	;
/***************CNS_ActiveMed_Rx**************/
--RAS added from Marcos Lau's original SPPRITE Code
	-- updating definition information
	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'CNS Medications',
		Category = 'CNS',
		ColumnDescription = 'CNS Any'
	WHERE ColumnName = 'CNS_ActiveMed_Rx'
	;		

	-- updating variable flag					
	UPDATE ##LookUp_NationalDrug_Stage
	SET CNS_ActiveMed_Rx = 1
	WHERE PrimaryDrugClassCode in ('CN709','CN801','CN802') or
	  DrugNameWithoutDose in (
'ACETAMINOPHEN/BUTALBITAL/CAFFEINE/CODEINE','ACETAMINOPHEN/CODEINE','ACETAMINOPHEN/HYDROCODONE','ACETAMINOPHEN/OXYCODONE',
'ACETAMINOPHEN/PENTAZOCINE','ALFENTANIL','ASPIRIN/BUTALBITAL/CAFFEINE/CODEINE','ASPIRIN/CAFFEINE/DIHYDROCODEINE',
'ASPIRIN/OXYCODONE','BUPRENORPHINE','BUPRENORPHINE/NALOXONE','BUTORPHANOL','CODEINE','FENTANYL',
'HYDROCODONE/IBUPROFEN','HYDROMORPHONE','LEVORPHANOL','MEPERIDINE','METHADONE','MORPHINE',
'NALBUPHINE','NALOXONE/PENTAZOCINE','OXYCODONE','OXYMORPHONE','PENTAZOCINE','REMIFENTANIL','SUFENTANIL','TAPENTADOL',
'NALOXONE','NALTREXONE','ACETAMINOPHEN/ASPIRIN/CAFFEINE','ACETAMINOPHEN/BUTALBITAL/CAFFEINE',
'ASPIRIN/BUTALBITAL/CAFFEINE','CLONIDINE','TRAMADOL','TRAMADOL/ACETAMINOPHEN',
'ZICONOTIDE','ACETAMINOPHEN/DICHLORALPHENAZONE/ISOMETHEPTENE','ALMOTRIPTAN','CAFFEINE/ERGOTAMINE',
'DIHYDROERGOTAMINE','ELETRIPTAN','FROVATRIPTAN','NARATRIPTAN','RIZATRIPTAN','SUMATRIPTAN','ZOLMITRIPTAN','RAMELTEON',
'AMOBARBITAL','PENTOBARBITAL','PHENOBARBITAL','SECOBARBITAL','ALPRAZOLAM','CHLORDIAZEPOXIDE',
'CLORAZEPATE','DIAZEPAM','ESTAZOLAM','FLURAZEPAM','LORAZEPAM','MIDAZOLAM','OXAZEPAM','TEMAZEPAM',
'TRIAZOLAM','BUSPIRONE','CHLORAL HYDRATE','DEXMEDETOMIDINE','ESZOPICLONE','MEPROBAMATE',
'ZALEPLON','ZOLPIDEM','CARBAMAZEPINE','CLONAZEPAM','DIAZEPAM','DIVALPROEX',
'ETHOSUXIMIDE','FELBAMATE','FOSPHENYTOIN','GABAPENTIN','LACOSAMIDE','LAMOTRIGINE','LEVETIRACETAM','METHSUXIMIDE',
'OXCARBAZEPINE','PERAMPANEL','PHENYTOIN','PRIMIDONE','TIAGABINE','TOPIRAMATE','VALPROATE SODIUM','VALPROIC ACID',
'ZONISAMIDE','APOMORPHINE','CARBIDOPA/ENTACAPONE/LEVODOPA','CARBIDOPA/LEVODOPA','ENTACAPONE','PRAMIPEXOLE',
'RASAGILINE','ROPINIROLE','ROTIGOTINE','SELEGILINE','TOLCAPONE','MECLIZINE','SCOPOLAMINE','AMITRIPTYLINE',
'AMOXAPINE','CLOMIPRAMINE','DESIPRAMINE','DOXEPIN','IMIPRAMINE','NORTRIPTYLINE','PROTRIPTYLINE','TRIMIPRAMINE',
'ISOCARBOXAZID','PHENELZINE SULFATE','SELEGILINE','TRANYLCYPROMINE','BUPROPION','CITALOPRAM',
'DESVENLAFAXINE','DULOXETINE','ESCITALOPRAM','FLUOXETINE','FLUVOXAMINE','MAPROTILINE',
'MILNACIPRAN','MIRTAZAPINE','NEFAZODONE','PAROXETINE','SERTRALINE','TRAZODONE','VENLAFAXINE','VILAZODONE','CHLORPROMAZINE',
'FLUPHENAZINE','PERPHENAZINE','THIORIDAZINE','THIOTHIXENE','TRIFLUOPERAZINE','ARIPIPRAZOLE',
'CLOZAPINE (CLOZARIL)','CLOZAPINE (FAZACLO)','CLOZAPINE (MYLAN)','HALOPERIDOL','LOXAPINE','LURASIDONE',
'OLANZAPINE','PALIPERIDONE','QUETIAPINE','RISPERIDONE','ZIPRASIDONE','LITHIUM','AMPHETAMINE RESIN COMPLEX',
'AMPHETAMINE/DEXTROAMPHETAMINE','DEXTROAMPHETAMINE','LISDEXAMFETAMINE','METHYLPHENIDATE',
'ARMODAFINIL','CAFFEINE/SODIUM BENZOATE','MODAFINIL','ACETAMINOPHEN/DIPHENHYDRAMINE',
'ALCOHOL','AMITRIPTYLINE/CHLORDIAZEPOXIDE','AMITRIPTYLINE/PERPHENAZINE','ATOMOXETINE',
'DEXTROMETHORPHAN/QUINIDINE','DONEPEZIL','ERGOLOID MESYLATES','FLUOXETINE/OLANZAPINE','GALANTAMINE',
'MEMANTINE','PIMOZIDE','PREGABALIN','RILUZOLE','RIVASTIGMINE','SODIUM OXYBATE')
--added some other CNS-active meds based on feedback from stimulant dashboard beta testing -- ck 2/9/2018
or DrugNameWithoutDose in (
--Added anticholinergics from PDSI as CNS-active meds -- ck 2/12/2018
'cyclobenzaprine','melatonin','ramelteon','prazosin','dronabinol'
,'ACETAMINOPHEN/ALUMINUM ACETATE/CHLORPHENIRAMINE/PHENYLPROPANOLAM','ACETAMINOPHEN/ATROPINE/ETHAVERINE/SALICYLAMIDE','ACETAMINOPHEN/BROMPHENIRAMINE'
,'ACETAMINOPHEN/BROMPHENIRAMINE/PSEUDOEPHEDRINE','ACETAMINOPHEN/CAFFEINE/CHLORPHENIRAMINE/HYDROCODONE/PHENYLEPHRIN'
,'ACETAMINOPHEN/CAFFEINE/CHLORPHENIRAMINE/PHENYLEPHRINE/PYRILAMINE','ACETAMINOPHEN/CAFFEINE/CHLORPHENIRAMINE/PHENYLPROPANOLAMINE'
,'ACETAMINOPHEN/CHLORPHENIRAMINE','ACETAMINOPHEN/CHLORPHENIRAMINE/CODEINE/PHENYLEPHRINE'
,'ACETAMINOPHEN/CHLORPHENIRAMINE/DEXTROMETHORPHAN','ACETAMINOPHEN/CHLORPHENIRAMINE/DEXTROMETHORPHAN/PHENYLEPHRINE'
,'ACETAMINOPHEN/CHLORPHENIRAMINE/DEXTROMETHORPHAN/PHENYLPROPANOLAM','ACETAMINOPHEN/CHLORPHENIRAMINE/DEXTROMETHORPHAN/PSEUDOEPHEDRINE'
,'ACETAMINOPHEN/CHLORPHENIRAMINE/PHENYLEPHRINE','ACETAMINOPHEN/CHLORPHENIRAMINE/PHENYLEPHRINE/PYRILAMINE'
,'ACETAMINOPHEN/CHLORPHENIRAMINE/PHENYLEPHRINE/SALICYLAMIDE','ACETAMINOPHEN/CHLORPHENIRAMINE/PHENYLPROPANOLAMINE','ACETAMINOPHEN/CHLORPHENIRAMINE/PHENYLPROPANOLAMINE/PHENYLTOLOXAM'
,'ACETAMINOPHEN/CHLORPHENIRAMINE/PHENYLPROPANOLAMINE/SALICYLAMIDE','ACETAMINOPHEN/CHLORPHENIRAMINE/PSEUDOEPHEDRINE'
,'ACETAMINOPHEN/DEXBROMPHENIRAMINE','ACETAMINOPHEN/DEXBROMPHENIRAMINE/PSEUDOEPHEDRINE'
,'ACETAMINOPHEN/DEXTROMETHORPHAN/DIPHENHYDRAMINE','ACETAMINOPHEN/DEXTROMETHORPHAN/DIPHENHYDRAMINE/PSEUDOEPHEDRINE'
,'ACETAMINOPHEN/DEXTROMETHORPHAN/DOXYLAMINE','ACETAMINOPHEN/DEXTROMETHORPHAN/DOXYLAMINE/EPHEDRINE'
,'ACETAMINOPHEN/DEXTROMETHORPHAN/DOXYLAMINE/PHENYLEPHRINE','ACETAMINOPHEN/DEXTROMETHORPHAN/DOXYLAMINE/PSEUDOEPHEDRINE'
,'ACETAMINOPHEN/DIPHENHYDRAMINE','ACETAMINOPHEN/DIPHENHYDRAMINE/PHENYLEPHRINE'
,'ACETAMINOPHEN/DIPHENHYDRAMINE/PSEUDOEPHEDRINE','ACETAMINOPHEN/PSEUDOEPHEDRINE/TRIPROLIDINE'
,'AL OH/DIPHENHYDRAMINE/LIDOCAINE/MAGNESIUM/SIMETHICONE','ALLANTOIN/DIPHENHYDRAMINE'
,'AMINOPHYLLINE/AMMONIUM CHLORIDE/DIPHENHYDRAMINE','AMITRIPTYLINE'
,'AMITRIPTYLINE/CHLORDIAZEPOXIDE','AMITRIPTYLINE/PERPHENAZINE'
,'AMMONIUM CHLORIDE/CHLORPHENIRAMINE/CODEINE/PHENYLEPHRINE','AMMONIUM CHLORIDE/CHLORPHENIRAMINE/CODEINE/PHENYLEPHRINE/POTASSI'
,'AMMONIUM CHLORIDE/CHLORPHENIRAMINE/DEXTROMETHORPHAN/PHENYLEPHRIN','AMMONIUM CHLORIDE/DIPHENHYDRAMINE'
,'AMMONIUM CHLORIDE/DIPHENHYDRAMINE/MENTHOL/SODIUM CITRATE','AMMONIUM/ANTIMONY/CHLORPHENIRAMINE/CODEINE/POTASSIUM GUAIACOLSUL'
,'AMMONIUM/ANTIMONY/CHLORPHENIRAMINE/POTASSIUM GUAIACOLSULFONATE','AMMONIUM/BROMODIPHENHYDRAMINE/CODEINE/DIPHENHYDRAMINE/POTASSIUM'
,'AMMONIUM/BROMODIPHENHYDRAMINE/CODEINE/MENTHOL/POTASSIUM','AMOXAPINE'
,'AMYLASE/ATROPINE/CELLULASE/HYOSCYAMINE/LIPASE/PHENOBARBITAL/PROT','AMYLASE/ATROPINE/LIPASE/PROTEASE'
,'AMYLASE/CELLULASE/HOMATROPINE/PHENOBARBITAL/PROTEASE','AMYLASE/CELLULASE/HYOSCYAMINE/LIPASE/PHENYLTOLOXAMINE/PROTEASE'
,'AMYLASE/DEHYDROCHOLIC/DESOXYCHOLIC/HOMATROPINE/PHENOBARBITAL/PRO','ASCORBIC ACID/CHLORPHENIRAMINE/PHENYLPROPANOLAMINE/PYRILAMINE'
,'ASPIRIN/ATROPINE/CAFFEINE/CAMPHOR/IPECAC/OPIUM/PHENACETIN','ASPIRIN/CAFFEINE/CHLORPHENIRAMINE'
,'ASPIRIN/CAFFEINE/DIHYDROCODEINE/PROMETHAZINE','ASPIRIN/CAFFEINE/ORPHENADRINE'
,'ASPIRIN/CHLORPHENIRAMINE/DEXTROMETHORPHAN/PHENYLEPHRINE','ASPIRIN/CHLORPHENIRAMINE/PHENYLEPHRINE'
,'ASPIRIN/CHLORPHENIRAMINE/PHENYLPROPANOLAMINE/SODIUM ACETYLSALICY','ASPIRIN/PROMETHAZINE/PSEUDOEPHEDRINE'
,'ATROPINE','ATROPINE/BENZOIC ACID/HYOSCYAMINE/METHENAMINE/PHENYL SALICYLATE'
,'ATROPINE/BENZOIC/GELSEMIUM/HYOSCYAMINE/METHENAMINE/METHYLENE/PHE','ATROPINE/BENZOIC/HYOSCYAMINE/METHENAMINE/METHYLENE/PHENYL'
,'ATROPINE/BROMPHENIRAMINE/PHENYLTOLOXAMINE/PSEUDOEPHEDRINE','ATROPINE/BUTABARBITAL/HYOSCYAMINE/OX BILE/PEPSIN/SCOPOLAMINE'
,'ATROPINE/CHLORPHENIRAMINE','ATROPINE/CHLORPHENIRAMINE/EPHEDRINE'
,'ATROPINE/CHLORPHENIRAMINE/HYOSCYAMINE/PHENYLEPHRINE/SCOPOLAMINE','ATROPINE/CHLORPHENIRAMINE/PHENYLEPHRINE/PHENYLTOLOXAMINE'
,'ATROPINE/CHLORPHENIRAMINE/PHENYLPROPANOLAMINE','ATROPINE/DIFENOXIN'
,'ATROPINE/DIPHENOXYLATE','ATROPINE/EDROPHONIUM'
,'ATROPINE/HYOSCYAMINE/KAOLIN/PECTIN/SCOPOLAMINE','ATROPINE/HYOSCYAMINE/PHENAZOPYRIDINE/SCOPOLAMINE'
,'ATROPINE/HYOSCYAMINE/PHENOBARBITAL','ATROPINE/HYOSCYAMINE/PHENOBARBITAL/SCOPOLAMINE'
,'ATROPINE/HYOSCYAMINE/SCOPOLAMINE/SIMETHICONE','ATROPINE/KAOLIN/PHENOBARBITAL'
,'ATROPINE/MEPERIDINE','ATROPINE/MORPHINE'
,'ATROPINE/NEOSTIGMINE','ATROPINE/PHENOBARBITAL'
,'ATROPINE/PHENOBARBITAL/SCOPOLAMINE','ATROPINE/PRALIDOXIME'
,'ATROPINE/PREDNISOLONE','BARBITAL/HYOSCYAMINE/HYOSCYAMUS/PASSION/SCOPOLAMINE/VALERIAN'
,'BELLADONNA/CHLORPHENIRAMINE/EPHEDRINE/PHENOBARBITAL','BELLADONNA/CHLORPHENIRAMINE/PHENIRAMINE/PHENYLPROPANOLAMINE'
,'BELLADONNA/CHLORPHENIRAMINE/PHENYLEPHRINE/PHENYLPROPANOLAMINE','BELLADONNA/CHLORPHENIRAMINE/PHENYLEPHRINE/PYRILAMINE'
,'BENZOCAINE/CALAMINE/DIPHENHYDRAMINE/MENTHOL','BENZTROPINE','BROMODIPHENHYDRAMINE/CODEINE'
,'BROMPHENIRAMINE','BROMPHENIRAMINE MALEATE','BROMPHENIRAMINE/CODEINE/GUAIFENESIN/MENTHOL/PHENYLEPHRINE/PHENYL','BROMPHENIRAMINE/CODEINE/GUAIFENESIN/PHENYLEPHRINE/PHENYLPROPANOL'
,'BROMPHENIRAMINE/CODEINE/PHENYLEPHRINE','BROMPHENIRAMINE/CODEINE/PHENYLPROPANOLAMINE'
,'BROMPHENIRAMINE/DEXTROMETHORPHAN/PHENYLEPHRINE','BROMPHENIRAMINE/DEXTROMETHORPHAN/PHENYLPROPANOLAMINE'
,'BROMPHENIRAMINE/DEXTROMETHORPHAN/PSEUDOEPHEDRINE','BROMPHENIRAMINE/GUAIFENESIN/MENTHOL/PHENYLEPHRINE/PHENYLPROPANOL'
,'BROMPHENIRAMINE/GUAIFENESIN/PHENYLEPHRINE/PHENYLPROPANOLAMINE','BROMPHENIRAMINE/GUAIFENESIN/PSEUDOEPHEDRINE'
,'BROMPHENIRAMINE/PHENYLEPHRINE','BROMPHENIRAMINE/PHENYLEPHRINE/PHENYLPROPANOLAMINE'
,'BROMPHENIRAMINE/PHENYLEPHRINE/PHENYLTOLOXAMINE','BROMPHENIRAMINE/PHENYLPROPANOLAMINE'
,'BROMPHENIRAMINE/PSEUDOEPHEDRINE','BUTABARBITAL/HYOSCYAMINE/PHENAZOPYRIDINE'
,'CALAMINE/CAMPHOR/DIPHENHYDRAMINE','CALAMINE/DIPHENHYDRAMINE'
,'CARAMIPHEN/CHLORPHENIRAMINE/ISOPROPAMIDE/PHENYLPROPANOLAMINE','CARBETAPENTANE/CHLORPHENIRAMINE'
,'CARBETAPENTANE/CHLORPHENIRAMINE/CITRIC/CODEINE/GUAIFENESIN/SODIU','CARBETAPENTANE/CHLORPHENIRAMINE/EPHEDRINE/PHENYLEPHRINE'
,'CARBINOXAMINE','CARBINOXAMINE/DEXTROMETHORPHAN/PSEUDOEPHEDRINE','CARBINOXAMINE/GAUIFENESIN/PSEUDOEPHEDRINE'
,'CARBINOXAMINE/METHSCOPOLAMINE/PSEUDOEPHEDRINE','CARBINOXAMINE/PSEUDOEPHEDRINE','CHLORDIAZEPOXIDE/CLIDINIUM'
,'CHLORDIAZEPOXIDE/METHSCOPOLAMINE','CHLORPHENIRAMINE','CHLORPHENIRAMINE/CHLOPHEDIANOL/PSEUDOEPHEDRINE'
,'CHLORPHENIRAMINE/CITRIC ACID/GUAIFENESIN/PHENYLPROPANOLAMINE/SOD','CHLORPHENIRAMINE/CODEINE'
,'CHLORPHENIRAMINE/CODEINE/GLYCEROL,IODINATED','CHLORPHENIRAMINE/CODEINE/PHENYLEPHRINE'
,'CHLORPHENIRAMINE/CODEINE/PHENYLEPHRINE/PHENYLPROPANOLAMINE','CHLORPHENIRAMINE/CODEINE/PHENYLEPHRINE/POTASSIUM IODIDE'
,'CHLORPHENIRAMINE/CODEINE/PHENYLPROPANOLAMINE','CHLORPHENIRAMINE/CODEINE/PSEUDOEPHEDRINE'
,'CHLORPHENIRAMINE/DEXTROMETHORPHAN','CHLORPHENIRAMINE/DEXTROMETHORPHAN/GLYCEROL,IODINATED'
,'CHLORPHENIRAMINE/DEXTROMETHORPHAN/GUAIFENESIN/PHENYLEPHRINE','CHLORPHENIRAMINE/DEXTROMETHORPHAN/GUAIFENESIN/PHENYLEPHRINE/SODI'
,'CHLORPHENIRAMINE/DEXTROMETHORPHAN/PHENYLEPHRINE','CHLORPHENIRAMINE/DEXTROMETHORPHAN/PHENYLEPHRINE/PHENYLPROPANOLAM'
,'CHLORPHENIRAMINE/DEXTROMETHORPHAN/PHENYLPROPANOLAMINE','CHLORPHENIRAMINE/DEXTROMETHORPHAN/PSEUDOEPHEDRINE'
,'CHLORPHENIRAMINE/DIHYDROCODEINE/PHENYLEPHRINE/PHENYLPROPANOLAMIN','CHLORPHENIRAMINE/EPHEDRINE'
,'CHLORPHENIRAMINE/EPHEDRINE/GUAIFENESIN/HYDRIODIC ACID','CHLORPHENIRAMINE/EPHEDRINE/GUAIFENESIN/PHENOBARBITAL/THEOPHYLLIN'
,'CHLORPHENIRAMINE/EPINEPHRINE','CHLORPHENIRAMINE/GUAIFENESIN/PHENYLEPHRINE'
,'CHLORPHENIRAMINE/GUAIFENESIN/PHENYLEPHRINE/PHENYLPROPANOLAMINE','CHLORPHENIRAMINE/GUAIFENESIN/PHENYLEPHRINE/PHENYLPROPANOLAMINE/P'
,'CHLORPHENIRAMINE/GUAIFENESIN/PHENYLPROPANOLAMINE','CHLORPHENIRAMINE/GUAIFENESIN/PSEUDOEPHEDRINE'
,'CHLORPHENIRAMINE/HYDROCODONE','CHLORPHENIRAMINE/HYDROCODONE/MENTHOL/PSEUDOEPHEDRINE'
,'CHLORPHENIRAMINE/HYDROCODONE/NH4/PHENINDAMINE/PHENYLEPHRINE/PYRI','CHLORPHENIRAMINE/HYDROCODONE/PHENINDAMINE/PHENYLEPHRINE/PYRILAMI'
,'CHLORPHENIRAMINE/HYDROCODONE/PHENYLEPHRINE','CHLORPHENIRAMINE/HYDROCODONE/PSEUDOEPHEDRINE'
,'CHLORPHENIRAMINE/HYDROCORTISONE/ISOPROPYL ALCOHOL/PYRILAMINE','CHLORPHENIRAMINE/HYDROCORTISONE/PHENIRAMINE/PYRILAMINE'
,'CHLORPHENIRAMINE/IBUPROFEN/PSEUDOEPHEDRINE','CHLORPHENIRAMINE/ISOPROPYL ALCOHOL/PYRILAMINE'
,'CHLORPHENIRAMINE/METHSCOPOLAMINE','CHLORPHENIRAMINE/METHSCOPOLAMINE/PHENYLEPHRINE'
,'CHLORPHENIRAMINE/METHSCOPOLAMINE/PSEUDOEPHEDRINE','CHLORPHENIRAMINE/PHENINDAMINE/PHENYLPROPANOLAMINE'
,'CHLORPHENIRAMINE/PHENYLEPHRINE','CHLORPHENIRAMINE/PHENYLEPHRINE/PHENYLPROPANOLAMINE'
,'CHLORPHENIRAMINE/PHENYLEPHRINE/PHENYLPROPANOLAMINE/PHENYLTOLOXAM','CHLORPHENIRAMINE/PHENYLEPHRINE/PHENYLPROPANOLAMINE/PYRILAMINE'
,'CHLORPHENIRAMINE/PHENYLEPHRINE/PHENYLTOLOXAMINE','CHLORPHENIRAMINE/PHENYLEPHRINE/PYRILAMINE'
,'CHLORPHENIRAMINE/PHENYLPROPANOLAMINE','CHLORPHENIRAMINE/PHENYLPROPANOLAMINE/PSEUDOEPHEDRINE'
,'CHLORPHENIRAMINE/PHENYLPROPANOLAMINE/PYRILAMINE','CHLORPHENIRAMINE/PSEUDOEPHEDRINE'
,'CHLORPROMAZINE','CITRIC/CODEINE/IPECAC/POTASSIUM/PROMETHAZINE/SODIUM'
,'CITRIC/CODEINE/IPECAC/POTASSIUM/PROMETHAZINE/SODIUM CITRATE','CITRIC/DEXTROMETHORPHAN/IPECAC/POTASSIUM/PROMETHAZINE/SODIUM'
,'CITRIC/IPECAC/PHENYLEPHRINE/POTASSIUM/PROMETHAZINE/SODIUM','CITRIC/IPECAC/POTASSIUM/PROMETHAZINE/SODIUM'
,'CLEMASTINE','CLEMASTINE/PHENYLPROPANOLAMINE','CLOMIPRAMINE','CLOZAPINE','CLOZAPINE (ACCORD)'
,'CLOZAPINE (ACTAVIS)','CLOZAPINE (AUROBINDO)','CLOZAPINE (CARACO)'
,'CLOZAPINE (CLOZARIL)','CLOZAPINE (FAZACLO)','CLOZAPINE (IVAX)','CLOZAPINE (MAYNE)'
,'CLOZAPINE (MYLAN)','CLOZAPINE (SANDOZ)','CLOZAPINE (TEVA)','CLOZAPINE (UDL)','CLOZAPINE (VERSACLOZ)'
,'CODEINE/GUAIFENESIN/PSEUDOEPHEDRINE/TRIPROLIDINE','CODEINE/IPECAC/PHENYLEPHRINE/POTASSIUM/PROMETHAZINE'
,'CODEINE/IPECAC/POTASSIUM GUAIACOLSULFONATE/PROMETHAZINE','CODEINE/PHENYLEPHRINE/POTASSIUM GUAIACOLSULFONATE/PROMETHAZINE'
,'CODEINE/PHENYLEPHRINE/PROMETHAZINE','CODEINE/PHENYLEPHRINE/TRIPROLIDINE','CODEINE/PHENYLPROPANOLAMINE/PROMETHAZINE'
,'CODEINE/POTASSIUM GUAIACOLSULFONATE/PROMETHAZINE','CODEINE/PROMETHAZINE','CODEINE/PSEUDOEPHEDRINE/TRIPROLIDINE'
,'CYCLOBENZAPRINE','CYPROHEPTADINE','DARIFENACIN','DEHYDROCHOLIC ACID/HOMATROPINE','DEHYDROCHOLIC ACID/HOMATROPINE/PHENOBARBITAL'
,'DESIPRAMINE','DEXBROMPHENIRAMINE','DEXBROMPHENIRAMINE/PHENYLEPHRINE','DEXBROMPHENIRAMINE/PSEUDOEPHEDRINE'
,'DEXCHLORPHENIRAMINE','DEXCHLORPHENIRAMINE/DEXTROMETHORPHAN/PSEUDOEPHEDRINE','DEXCHLORPHENIRAMINE/GUAIFENESIN/PSEUDOEPHEDRINE'
,'DEXTROMETHORPHAN/DOXYLAMINE','DEXTROMETHORPHAN/DOXYLAMINE/GUAIFENESIN'
,'DEXTROMETHORPHAN/DOXYLAMINE/PSEUDOEPHEDRINE','DEXTROMETHORPHAN/IPECAC/POTASSIUM GUAIACOLSULFONATE/PROMETHAZINE'
,'DEXTROMETHORPHAN/POTASSIUM GUAIACOLSULFONATE/PROMETHAZINE','DEXTROMETHORPHAN/PROMETHAZINE'
,'DICYCLOMINE','DICYCLOMINE/PHENOBARBITAL','DIMENHYDRINATE','DIMENHYDRINATE/NIACIN'
,'DIPHENHYDRAMINE','DIPHENHYDRAMINE/GUAIFENESIN/MENTHOL/SODIUM CITRATE','DIPHENHYDRAMINE/HYDROCORTISONE'
,'DIPHENHYDRAMINE/HYDROCORTISONE/NYSTATIN','DIPHENHYDRAMINE/HYDROCORTISONE/NYSTATIN/TETRACYCLINE'
,'DIPHENHYDRAMINE/IBUPROFEN','DIPHENHYDRAMINE/LIDOCAINE/NYSTATIN'
,'DIPHENHYDRAMINE/NAPROXEN','DIPHENHYDRAMINE/PHENOL','DIPHENHYDRAMINE/PHENYLEPHRINE','DIPHENHYDRAMINE/PSEUDOEPHEDRINE'
,'DIPHENHYDRAMINE/TRIPELENNAMINE','DIPHENHYDRAMINE/ZINC ACETATE','DIPHENHYDRAMINE/ZINC OXIDE','DOXEPIN'
,'DOXYLAMINE','DOXYLAMINE/PYRIDOXINE','EPHEDRINE/HYDROXYZINE/THEOPHYLLINE','ERGOTAMINE/HYOSCYAMINE/PHENOBARBITAL'
,'FESOTERODINE','FLAVOXATE','FLUOXETINE/OLANZAPINE','HOMATROPINE','HOMATROPINE/HYDROCODONE'
,'HOMATROPINE/HYOSCYAMINE/PANCREATIN/PEPSIN/PHENOBARBITAL/SCOPOLAM','HOMATROPINE/OPIUM/PECTIN'
,'HYDROCODONE/CARBINOXAMINE/PSEUDOEPHEDRINE','HYDROXYZINE','HYDROXYZINE/OXYPHENCYCLIMINE','HYDROXYZINE/PENTAERYTHRITOL TETRANITRATE'
,'HYOSCYAMINE','HYOSCYAMINE/METHAMINE/METHYLENE BLUE/PHENYL SALICYLATE/SODIUM BI'
,'HYOSCYAMINE/METHENAMINE','HYOSCYAMINE/METHENAMINE/METHYLENE BLUE/PHENYL SALICYLATE/SODIUM'
,'HYOSCYAMINE/METHENAMINE/METHYLENE/PHENYL SALICYL/SODIUM PHOS','HYOSCYAMINE/PASSION FLOWER/PHENOBARBITAL/SCOPOLAMINE'
,'HYOSCYAMINE/PHENOBARBITAL','IMIPRAMINE','IPECAC/PHENYLEPHRINE/POTASSIUM GUAIACOLSULFONATE/PROMETHAZINE'
,'LOXAPINE','MECLIZINE','MEPERIDINE/PROMETHAZINE','METHENAMINE/NA BIPHOSPHA/PHENYL SALICYLATE/METHELENE/HYOSCYAMINE'
,'METHSCOPOLAMINE','METHSCOPOLAMINE/PSEUDOEPHEDRINE','NORTRIPTYLINE','OLANZAPINE'
,'ORPHENADRINE CITRATE','ORPHENADRINE HYDROCHLORIDE','OXYBUTYNIN CHLORIDE','PAROXETINE'
,'PERPHENAZINE','PHENYLEPHRINE/POTASSIUM GUAIACOLSULFONATE/PROMETHAZINE','PHENYLEPHRINE/PROMETHAZINE'
,'PHENYLEPHRINE/SCOPOLAMINE','PHENYLEPHRINE/TRIPROLIDINE','POTASSIUM GUAIACOLSULFONATE/PROMETHAZINE'
,'PROMETHAZINE','PROMETHAZINE/PSEUDOEPHEDRINE','PROPANTHELINE','PROTRIPTYLINE','PSEUDOEPHEDRINE/TRIPROLIDINE'
,'SCOPOLAMINE','SOLIFENACIN','THIORIDAZINE','TOLTERODINE','TRIFLUOPERAZINE','TRIHEXYPHENIDYL'
,'TRIMIPRAMINE','TRIPROLIDINE','TROSPIUM'
)
	;
	
/***************Controlled Substances**************/
	-- updating definition information
	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Controlled Substance',
		Category = 'Non-VA Meds',
		ColumnDescription = 'Controlled substances for non-VA meds flag in STORM'
	WHERE ColumnName = 'ControlledSubstance'
	;		

	-- updating variable flag					
	UPDATE ##LookUp_NationalDrug_Stage
	SET ControlledSubstance = 1
	WHERE CSFederalSchedule like 'Schedule%'
	;
	
/***************PDSI Relevant Drugs*************/
	-- updating definition information
	UPDATE  LookUp.ColumnDescriptions
	SET PrintName = 'MPRCalculated_Rx',
		Category = 'PDSI',
		ColumnDescription = 'All medications we care about across projects for use in the MPR code'
	WHERE ColumnName = 'MPRCalculated_Rx'
	;
	
/***************Sum across columns******/
DECLARE  @sql  varchar(max)
SET @sql = 'UPDATE ##LookUp_NationalDrug_Stage
	SET MPRCalculated_Rx = 1  WHERE ' 

SELECT @sql = @sql + COLUMN_NAME + '=1 OR '
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'NationalDrug'
	AND COLUMN_NAME NOT IN (
		'NationaldrugSID'
		,'Sta3n'
		,'NDC'
		,'CMOP'
		,'VUID'
		,'DrugNameWithDose'
		,'DrugNameWithoutDoseSID'
		,'DrugNameWithoutDose'
		,'PrimaryDrugClassCode'
		,'StrengthNumeric'
		,'DosageForm'
		,'CSFederalSchedule'
		,'InactivationDateTime'
		,'Reach_Statin_Rx'
		)
SET @sql = LEFT(@sql, LEN(@sql) - 2)
SET @sql =   @sql  
--select @sql
EXEC(@sql)

--------------------------------------------------------------------
-- PUBLISH
--------------------------------------------------------------------
EXEC [Maintenance].[PublishTable] 'LookUp.NationalDrug','##LookUp_NationalDrug_Stage'

--------------------------------------------------------------------
-- CREATE UNPIVOTED VERSION OF TABLE
--------------------------------------------------------------------
			DECLARE @Columns1 VARCHAR(5000)
	SET @Columns1 = (
			SELECT STRING_AGG(c.name,',')
			FROM  sys.columns as c
			INNER JOIN sys.tables as t on t.object_id = c.object_id
			WHERE t.Name = 'NationalDrug'
				AND c.Name NOT IN (
					'NationalDrugSID'
					,'VUID'
					,'NDC'
					,'CMOP'
					,'Sta3n'
					,'DrugNameWithDose'
					,'DrugNameWithoutDose'
					,'DrugNameWithoutDoseSID'
					,'CSFederalSchedule'
					,'PrimaryDrugClassCode'
					,'StrengthNumeric'
					,'CalculatedStrengthNumeric'
					,'DosageForm'
					,'InactivationDateTime'
					)
				)
--	PRINT @columns1

	DROP TABLE IF EXISTS #StageNationalDrugVertical
	CREATE TABLE #StageNationalDrugVertical (
		NationalDrugSID BIGINT
		,VUID VARCHAR(50)
		,Sta3n SMALLINT
		,DrugCategory VARCHAR(50)
		,FlagValue TINYINT
		)

	DECLARE @Unpivot VARCHAR(5000) = '
		INSERT INTO #StageNationalDrugVertical
		SELECT NationalDrugSID
			,VUID
			,Sta3n
			,DrugCategory
			,FlagValue
		FROM (
			SELECT * FROM [LookUp].[NationalDrug]
			) nd
		UNPIVOT (FlagValue FOR DrugCategory IN (' +
			@Columns1 +')
			) up
		WHERE FlagValue=1
		'
	--PRINT @Unpivot
	EXEC (@Unpivot)

		--	SELECT COUNT(*) FROM #StageNationalDrugVertical
		--	SELECT COUNT(*) FROM (SELECT DISTINCT NationalDrugSID,VUID, DrugCategory FROM #StageNationalDrugVertical) n

	EXEC [Maintenance].[PublishTable] 'LookUp.NationalDrug_Vertical','#StageNationalDrugVertical'

-------------------------------------------------------------------------------
-- CERNER OVERLAY
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS #LookUpVUID_Stage
SELECT DISTINCT  
	VUID
	,NDC
	,CMOP
	,DrugNameWithDose
	,DrugNameWithoutDose
	,CSFederalSchedule
	,PrimaryDrugClassCode
	,StrengthNumeric
	,CalculatedStrengthNumeric
	,DosageForm
	,VUIDRank
	,AchAntiHist_Rx
	,AChAD_Rx
	,AChALL_Rx
	,AlcoholPharmacotherapy_Rx
	,AlcoholPharmacotherapy_notop_Rx
	,Alprazolam_Rx
	,Antidepressant_Rx
	,SSRI_SNRI_Rx
	,Antipsychotic_Geri_Rx
	,Antipsychotic_Rx
	,AntipsychoticSecondGen_Rx
	,Anxiolytics_Rx
	,Benzodiazepine_Rx
	,Bowel_Rx
	,Clonazepam_Rx
	,Lorazepam_Rx
	,Mirtazapine_Rx
	,MPRCalculated_Rx
	,MoodStabilizer_Rx
	,MoodStabilizer_GE3_Rx
	,NaltrexoneINJ_Rx
	,Olanzapine_Rx
	,Opioid_Rx
	,OpioidAgonist_Rx
	,PainAdjAnticonvulsant_Rx
	,PainAdjTCA_Rx
	,PainAdjSNRI_Rx
	,PDSIRelevant_Rx
	,Prazosin_Rx
	,Prochlorperazine_Rx
	,Promethazine_Rx
	,Psychotropic_Rx
	,Reach_AntiDepressant_Rx
	,Reach_AntiPsychotic_Rx
	,Reach_opioid_Rx
	,Reach_statin_Rx
	,Reach_SedativeAnxiolytic_Rx
	,SedatingPainORM_Rx
	,SedativeOpioid_Rx
	,Sedative_zdrug_Rx
	,Stimulant_Rx
	,StimulantADHD_Rx
	,TobaccoPharmacotherapy_Rx
	,Tramadol_Rx
	,Zolpidem_Rx
	,Methadone_Rx
	,OpioidForPain_Rx
	,NaloxoneKit_Rx
	,SSRI_Rx
	,ControlledSubstance
	,CNS_Depress_Rx
	,CNS_ActiveMed_Rx
INTO #LookUpVUID_Stage
FROM (
	SELECT *
		,VUIDRank = DENSE_RANK() OVER(PARTITION BY VUID ORDER BY 
			 ISNULL(InactivationDateTime,'2100-12-31') DESC
			,CASE WHEN DosageForm = '*Unknown at this time*' THEN 1 ELSE 0 END
			,CASE WHEN DrugNameWithoutDose = '*Unknown at this time*' THEN 1 ELSE 0 END
			,OpioidForPain_Rx DESC -- prioritize OpioidForPain over OpioidAgonist because current Cerner sites do NOT have methadone clinics
		)
	FROM [LookUp].[NationalDrug] --31846	31608
	WHERE VUID <> '*Unknown at this time*'
		AND (
			InactivationDateTime IS NULL --21078	21073
			OR InactivationDateTime > '2016-01-01' -- see query "InactivationDateTime Validation" below
			)
	) nd 
WHERE VUIDRank = 1
ORDER BY VUID,VUIDRank

	/*InactivationDateTime Validation
	SELECT DISTINCT VUID FROM [Cerner].[FactPharmacyOutpatientDispensed]
	EXCEPT 
	SELECT DISTINCT nd.VUID
	FROM [LookUp].[NationalDrug]  nd  
	WHERE nd.InactivationDateTime IS NULL
		OR InactivationDateTime > '2016-01-01'
	*/

	DECLARE @NonDistinctCount INT = (SELECT COUNT(VUID) - COUNT(DISTINCT VUID) FROM #LookUpVUID_Stage)
	PRINT @NonDistinctCount

	-- LOG ERROR IF DUPLICATE VUID VALUE IS FOUND
	-- TARGET TABLE WILL NOT BE CHANGED (STATIC UNTIL ERROR IS FIXED)
	IF @NonDistinctCount > 0 
	BEGIN
		EXEC [Log].[Message] 'Error','Duplicate VUID','LookUp.Drug_VUID could not be published due to duplicate VUID value'
		EXEC [Log].[ExecutionEnd] @Status = 'Error'
		RETURN
	END

EXEC [Maintenance].[PublishTable] 'LookUp.Drug_VUID','#LookUpVUID_Stage'

----------------------------------------------------------------------------

EXEC [Log].[ExecutionEnd]

END
;