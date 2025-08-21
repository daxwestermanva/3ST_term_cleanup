
/* =============================================
Author:		 Sohoni, Pooja
Create date: 2020-09-15
Description: Labs mapping table with merged Cerner and VistA data
-- 2020-09-15 PS branched from Code.LookUp_Lab and made changes to pull in Cerner data
-- 2020-11-08 LM added WITH(NOLOCK)
-- 2020-06-24 JJR_SAA Updated tagging for use in sharing code for ShareMill;adjusted position of ending tag
-- 2021-07-15 AI Enclave Refactoring - Counts confirmed
-- 2023-10-24 AER Updating business rules for CERNER to use LOINC instead of lab name
-- 2023-11-22 AER Pointing CERNER data to dim lab
-- 2023-12-01 AER Updating cerner logic for cloz. labs
-- 2024-06-22 LM  Removed reference to OpCode (removed from CDW table and removal does not impact results)
============================================= */

CREATE   PROCEDURE [Code].[Lookup_Lab]
AS
BEGIN
  
/* 
ALTER TABLE [LookUp].[Lab]
ADD [NewColumnName] BIT NULL

*/

/**************************************************************************************************/
/*** Add new rows to [LookUp].[ColumnDescriptions] if they exist in LookUp.Lab *************/
/**************************************************************************************************/

DECLARE @TableName VARCHAR(50) = 'Lab'

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
		inner join   sys.tables as b on   a.object_id = b.object_id
		WHERE b.Name = @TableName
			AND a.Name NOT IN (
			--enter columns you are pulling from CDW dim table here:
				'LabChemTestSID' 
				,'Sta3n' 
				,'LabChemTestName' 
				,'LabChemPrintTestName' 
				,'LOINCSID'
				,'LOINC'
				,'TopographySID'
				,'Topography'
				,'WorkloadCode'
				)
				
			AND a.Name NOT IN (
				SELECT DISTINCT ColumnName
				FROM [LookUp].[ColumnDescriptions] 
				WHERE TableName =  @TableName
				) --order by COLUMN_NAME
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
/**************************************************************************************************/
/*** Pull complete data from Dim.LOINC with fields from LookUp.Lab***/
/**************************************************************************************************/
	/*##SHAREMILL BEGIN##*/
	DECLARE @Columns VARCHAR(Max);

	SELECT @Columns = CASE 
			WHEN @Columns IS NULL
				THEN '0 as ' + T.ColumnName
			ELSE @Columns + ', 0 as ' + T.ColumnName
			END
	FROM  Lookup.ColumnDescriptions AS T
  where T.TableName = 'Lab';
 -- select @Columns

	DROP TABLE IF EXISTS #Prep
	SELECT DISTINCT 
		CAST(labchemtest.LabChemTestSID AS BIGINT) LabChemTestSID
		,labchemtest.Sta3n
		,labchemtest.LabChemTestName
		,labchemtest.LabChemPrintTestName
		,labchem.LOINCSID
		,labchem.TopographySID
		,loinc.LOINC
		,t.Topography
		,w.WorkloadCode
	INTO #Prep
	FROM [Chem].[LabChem] labchem WITH (NOLOCK)
    INNER JOIN [Dim].[LabChemTest] labchemtest WITH (NOLOCK) 
		ON labchem.LabChemTestSID = labchemtest.LabChemTestSID
		AND labchem.LabChemCompleteDateTime >= GETDATE() - 720
		AND labchem.Sta3n > 0
		AND labchem.PatientSID > 0 
	LEFT JOIN [Dim].[LOINC] loinc WITH (NOLOCK)
		ON labchem.LOINCSID = loinc.LOINCSID
		--AND loinc.OpCode NOT IN ('d','x') --OpCode has been removed from the table.  The only values for OpCode in the SPV table are 1, U, and I
	LEFT JOIN [Dim].[Topography] t WITH (NOLOCK)
		ON labchem.TopographySID = t.TopographySID
	LEFT JOIN [Dim].[NationalVALabCode] w WITH (NOLOCK)
		ON labchem.LabChemTestSID = w.LabChemTestSID

	DECLARE @Insert AS VARCHAR(4000);
	DROP TABLE IF EXISTS ##LookUp_Lab_Stage
	SET @Insert = '
	SELECT m.*,
	' + @Columns + ' 
    INTO ##LookUp_Lab_Stage 
    FROM (
		SELECT DISTINCT *,''LabChemTestSID'' as LabChemTestSIDSouce
		FROM #Prep
		UNION ALL
    SELECT DISTINCT cast(DiscreteTaskAssaySID as bigint) DiscreteTaskAssaySID
			,Sta3n = CAST(200 AS SMALLINT)
			,case when SourceString = ''*Implied NULL*''  or sourcestring is null then DiscreteTaskAssay else SourceString end LabChemTestName
			,DiscreteTaskAssay as LabChemPrintTestName
			,NomenclatureSID as LOINCSID
			,SpecimenTypeCodeValueSID  as TopographySID
			,mill.SourceIdentifier as LOINC
			,SpecimenType as Topography
			,null as WorkloadCode,''DiscreteTaskAssaySID''
		FROM Cerner.DimLab  mill
    where isnumeric(DiscreteTaskAssayID) = 1
		) m
';
  
	exec (@Insert);/*##SHAREMILL END##*/



/**************************************************************************************************/
/***** Updating Lab variable flags and adding definitions. ************************/
/**************************************************************************************************/	

	/*** Morphine UDS**************/
	-- updating definition information
	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Heroin/Morphine drug screens',
		Category = 'Heroin/Morphine drug screens',
		ColumnDescription = 'Drug screens for heroin/morphine'
	WHERE ColumnName = 'Morphine_UDS';


	UPDATE ##LookUp_Lab_Stage
	SET Morphine_UDS = 1
	where sta3n <> 200 and  (labchemtestname like '%morphine%'
		or labchemtestname like '%heroin%'
		or (LabChemTestName like '%opiate%' and LabChemTestName not like '%SYNTHETIC%') 
		or Labchemtestname like '%URINE OPI%' 
		or Labchemtestname like '%URINE OP'  
		or (labchemprinttestname like '%6-MAM%' 
			or labchemtestname like '%6-monoacet%' 
			or labchemtestname like '%6-MAM%' 
			or labchemtestname like '%6%MAM%')
		or LabChemTestName like '%Medical UDS%'
		or LabChemTestSID in ('1200148076',
		'1200118041')
		);

		
	/*** NonMorphineOpioid_UDS**************/
	-- updating definition information

	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Non-morphine opioid compounds drug screens',
		Category = 'Non-morphine opioid compounds drug screens',
		ColumnDescription = 'Drug screens for opioid compounds other than morphine and heroin'
	WHERE ColumnName = 'NonMorphineOpioid_UDS';


	UPDATE ##LookUp_Lab_Stage
	SET NonMorphineOpioid_UDS = 1
	where sta3n <> 200 and (labchemtestname like '%codeine%'
		or labchemtestname like '%fentanyl%'
		or (labchemtestname like '%opiate%' and labchemtestname like '%synthetic%')
		or labchemtestname like '%oxycodone%'
		or labchemtestname like '%propoxyphene%'
		or labchemtestname like '%hydrocodone%'
		or labchemtestname like '%hydromorphone%'
		or labchemtestname like '%oxymorphone%'
		or labchemtestname like '%tramadol%'
		or labchemtestname like '%opioid%'
		or labchemtestname like '%acetylmethadol%'
		or labchemtestname like '%alfentanil%'
		or labchemtestname like '%analgesics%'
		or labchemtestname like '%butorphanol tartrate%'
		or labchemtestname like '%dihydrocodein%'
		or labchemtestname like '%dihydromorphin%'
		or labchemtestname like '%fen & metabolite%'
		or labchemtestname like '%hydrocodein%'
		or labchemtestname like '%levorphanol%'
		or labchemtestname like '%meperidine%'
		or labchemtestname like '%nalbuphine hydrochloride%'
		or labchemtestname like '%oxycotin%'
		or labchemtestname like '%oxycontin%'
		or labchemtestname like '%pentazocine%'
		or labchemtestname like '%percodan%'
		or labchemtestname like '%pethidine%'
		or labchemtestname like '%propox%'
		or labchemtestname like '%suboxone%'
		or labchemtestname like '%sufentanil%'
		or labchemtestname like '%tapentadol%'
		or labchemtestname like '%medical UDS%'
		or LabChemTestSID in ('1200148076',
		'1200118041')
	);

		/*** NonOpioidAbusable_UDS**************/
	-- updating definition information

	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Non-opioid abusable substances',
		Category = 'Non-opioid abusable substances',
		ColumnDescription = 'Drug screens for non-opioid abusable substances'
	WHERE ColumnName = 'NonOpioidAbusable_UDS';

	UPDATE ##LookUp_Lab_Stage
	SET NonOpioidAbusable_UDS = 1
	WHERE sta3n <> 200 and (
			LabChemTestName LIKE '%ALLOBARBITAL%'
			OR LabChemTestName LIKE '%Allylbarbital%'
			OR LabChemTestName LIKE '%Alprazolam%'
			OR LabChemTestName LIKE '%Amobarbital%'
			OR LabChemTestName LIKE '%AMPH%'
			OR LabChemTestName LIKE '%URINE AMP'
			OR LabChemTestName LIKE '%AMPH/METH%'
			OR LabChemTestName LIKE '%APROBARBITAL%'
			OR LabChemTestName LIKE '%Ativan%'
			OR LabChemTestName LIKE '%BATH SALTS%'
			OR LabChemTestName LIKE '%barbital%'
			OR LabChemTestName LIKE '%BARBITURATE%'
			OR LabChemTestName LIKE '%BARTIT%'
			OR LabChemTestName LIKE '%BARBITUAT%'
			OR LabChemTestName LIKE '%URINE BARB'
			OR LabChemTestName LIKE '%BENZFETAMINE%'
			OR LabChemTestName LIKE '%Benzaphetamine%'
			OR LabChemTestName LIKE '%Benzphetamine%'
			OR LabChemTestName LIKE '%BENZODIA%'
			OR LabChemTestName LIKE '%BENZO CONF%'
			OR LabChemTestName LIKE '%BENZO SCREEN%'
			OR LabChemTestName LIKE '%URINE BENZ%'
			OR LabChemTestName LIKE '%Benzoylecgonine%'
			OR LabChemTestName LIKE '%BROMAZEPAM%'
			OR LabChemTestName LIKE '%Butabarbital%'
			OR LabChemTestName LIKE '%Butalbital%'
			OR LabChemTestName LIKE '%BUTYLONE%'
			OR LabChemTestName LIKE '%BZE%'
			OR LabChemTestName LIKE '%CANNAB%'
			OR LabChemTestName LIKE '%CARISOPRODOL%'
			OR LabChemTestName LIKE '%CATHINONE%'
			OR LabChemTestName LIKE '%CHLORDIAZEP%'
			OR LabChemTestName LIKE '%CLOBAZAM%'
			OR LabChemTestName LIKE '%Clonazepam%'
			OR LabChemTestName LIKE '%Clorazepate%'
			OR LabChemTestName LIKE '%Cocaethlene%'
			OR LabChemTestName LIKE '%COCAETHYLENE%'
			OR LabChemTestName LIKE '%Cocaine%'
			OR LabChemTestName LIKE '%URINE COC'
			OR LabChemTestName LIKE '%Demoxepam%'
			OR LabChemTestName LIKE '%DESALKYLHALAZEPAM%'
			OR LabChemTestName LIKE '%Diazepam%'
			OR LabChemTestName LIKE '%ECSTASY%'
			OR LabChemTestName LIKE '%EPHEDRINE%'
			OR LabChemTestName LIKE '%ESTAZOLAM%'
			OR (
				LabChemTestName LIKE '%ETHANOL%'
				AND LabChemTestName NOT LIKE '%PHOSPHOETHANOLAMINE%'
				)
			OR LabChemTestName LIKE '%Ethchlorvynol%'
			OR Labchemtestname LIKE '%ETHYL GLUCURONIDE%'
			OR LabChemTestName LIKE '%ETG%'
			OR LabChemTestName LIKE '%Ethyl Sulfate%'
			OR Labchemtestname LIKE '%GLUCURONIDE%'
			OR (
				LabChemTestName LIKE '%ETOH%'
				AND LabChemTestName NOT LIKE '%ACETOHEXAMIDE%'
				)
			OR LabChemTestName LIKE '%FLUNITRAZEPAM%'
			OR LabChemTestName LIKE '%Flurazepam%'
			OR LabChemTestName LIKE '%Hydroxybenzoyllecgonine%'
			OR LabChemTestName LIKE '%HYDROXYBUTYRIC%'
			OR LabChemTestName LIKE '%HALAZEPAM%'
			OR LabChemTestName LIKE '%HYPNOTICS%'
			OR LabChemTestName LIKE '%INHALANT%'
			OR LabChemTestName LIKE '%KETAMINE%'
			OR LabChemTestName LIKE '%Lorazepam%'
			OR LabChemTestName LIKE '%LORMETAZEPAM%'
			OR LabChemTestName LIKE '%LSD%'
			OR LabChemTestName LIKE '%LYSERGIC ACID DIETHYLAMIDE%'
			OR LabChemTestName LIKE '%LYSERGIDE%'
			OR LabChemTestName LIKE '%MARIJUANA%'
			OR LabChemTestName LIKE '%MDA%'
			OR LabChemTestName LIKE '%MDEA%'
			OR LabChemTestName LIKE '%MDMA%'
			OR Labchemtestname LIKE '%MDPV%'
			OR LabChemTestName LIKE '%Mecloqualone%'
			OR Labchemtestname LIKE '%MEPHEDRONE%'
			OR LabChemTestName LIKE '%Mephenytoin%'
			OR LabChemTestName LIKE '%Mephobarbital%'
			OR LabChemTestName LIKE '%Meprobamate%'
			OR LabChemTestName LIKE '%Mescaline%'
			OR LabChemTestName LIKE '%METHAMPHET%'
			OR LabChemTestName LIKE '%mAMP'
			OR LabChemTestName LIKE '%METHAQUALONE%'
			OR LabChemTestName LIKE '%METHARBITAL%'
			OR LabChemTestName LIKE '%Methocarbamol%'
			OR Labchemtestname LIKE '%Methylenedioxypyrovalerone%'
			OR LabChemTestName LIKE '%methylester%'
			OR Labchemtestname LIKE '%METHYLONE%'
			OR LabChemTestName LIKE '%Methylph%'
			OR LabChemTestName LIKE '%METHYLYPHENIDATE%'
			OR LabChemTestName LIKE '%MIDAZOLAM%'
			OR LabChemTestName LIKE '%METHORPHAN%'
			OR LabChemTestName LIKE '%NITRAZEPAM%'
			OR LabChemTestName LIKE '%NORCLOBAZAM%'
			OR LabChemTestName LIKE '%Nordiazepam%'
			OR LabChemTestName LIKE '%NORFLUNITRAZEPAM%'
			OR LabChemTestName LIKE '%NORKETAMINE%'
			OR LabChemTestName LIKE '%Oxazepam%'
			OR LabChemTestName LIKE 
			'%PAIN MGT PROF/MEDMATCH URINE%'
			OR LabChemTestName LIKE '%Pentobarbital%'
			OR LabChemTestName LIKE '%PHENCYCLIDINE%'
			OR LabChemTestName LIKE '%PHENTERMINE%'
			OR LabChemTestName LIKE '%PCP%'
			OR LabChemTestName LIKE '%PHENOBARB%'
			OR LabChemTestName LIKE '%Prazepam%'
			OR LabChemTestName LIKE '%PSILOCIN%'
			OR LabChemTestName LIKE '%Psilocybin%'
			OR LabChemTestName LIKE '%QUALLUDES%'
			OR LabChemTestName LIKE '%QUAZEPAM%'
			OR LabChemTestName LIKE '%RITALIN%'
			OR LabChemTestName LIKE '%Secobarbital%'
			OR LabChemTestName LIKE '%STIMULANTS%'
			OR Labchemtestname LIKE '%SYNTHETICS%'
			OR LabChemTestName LIKE '%Talbutal%'
			OR LabChemTestName LIKE '%TRANQUILIZERS%'
			OR LabChemTestName LIKE '%Temazepam%'
			OR (
				LabChemTestName LIKE '%THC%'
				AND LabChemTestName NOT LIKE '%NO THC%'
				)
			OR LabChemTestName LIKE '%Triazolam%'
			OR LabChemTestName LIKE '%TOLUENE%'
			OR (
				LabChemTestName LIKE '%TOX%'
				AND LabChemTestName NOT LIKE '%TRANSPLANT%'
				AND LabChemTestName NOT LIKE '%CREATININE%'
				)
			OR LabChemTestName LIKE '%URINE DAS%'
			OR LabChemTestName LIKE '%XANAX%'
			OR LabChemTestName LIKE '%ZOLPIDEM%'
			OR LabChemTestName LIKE '%Medical UDS%'
			OR LabChemTestSID in ('1200148076',
			'1200118041'))
			AND (LabChemTestName NOT LIKE '%TOXO%'
			AND LabChemTestName NOT LIKE '%PERTU%'
			AND LabChemTestName NOT LIKE '%SHIG%'
			AND LabChemTestName NOT LIKE '%C%DIFF%'
			AND LabChemTestName NOT LIKE '%E%COLI%')
			;

/*** eGFR Blood**************/
	-- updating definition information

	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'eGFR Blood',
		Category = 'eGFR Blood',
		ColumnDescription = 'eGFR Blood'
	WHERE ColumnName = 'EGFR_Blood';

		UPDATE ##LookUp_Lab_Stage
		SET [EGFR_Blood] = 1
		WHERE sta3n <> 200 and (labchemtestsid in (
		'1200000545',
		'1200001186',
		'1200001186',
		'1200001010',
		'1400000307',
		'1000002293',
		'800000310',
		'800000310'
		) or LOINC='33914-3'
		)
		and (topography like '%Blood%' or topography like '%plas%' or topography like '%serum%') 
		and topography not like '%rice lake%' and topography not like '%urine%'
		and labchemtestname not like 'FIBRO%' --ask lab to fix this on their end
		;
/*** Creatinine Blood**************/
	-- updating definition information

	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Creatinine Blood',
		Category = 'Creatinine Blood',
		ColumnDescription = 'Creatinine Blood'
	WHERE ColumnName = 'Creatinine_Blood';

		UPDATE ##LookUp_Lab_Stage
		SET Creatinine_Blood = 1
		WHERE sta3n <> 200 and (Loinc in ('20624-3','2162-6','2161-8','12190-5','38483-4','2160-0') or labchemtestsid in ('1400000419',
		'1400070061',
		'1000073694',
		'1200063883',
		'1200063883',
		'1000065089'))
		and (topography like '%blood%' or topography like '%plasma%' or topography like '%serum%') and topography not like '%urine%'
		and labchemtestname not in ('_BCR-ABL:ABL RATIO-PCR', 'HCV NS5A CODONS ANALYZED', 'OMBITASVIR RESISTANCE PREDICTED')
		;

/*** Hemoglogin Blood**************/
	-- updating definition information

	UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Hemoglogin Blood',
		Category = 'Hemoglogin Blood',
		ColumnDescription = 'Hemoglogin Blood'
	WHERE ColumnName = 'Hemoglobin_Blood';

		UPDATE ##LookUp_Lab_Stage
		SET Hemoglobin_Blood = 1
		WHERE sta3n <> 200 and (Loinc in ('14134-1','717-9','718-7','721-1') -- Hgb
		 or labchemtestsid in ('800075498'))
		 and (topography like '%blood%' or topography like '%plasma%' or topography like '%serum%') and topography not like '%urine%' 
     and labchemtestsid not in ('800064930') --Arteriol blood gas from SLC”


 --ALT_Blood
              UPDATE ##LookUp_Lab_Stage
              SET ALT_Blood =1
              WHERE sta3n <> 200 and Labchemtestsid > 1 
              and (labchemtestname like 'ALT%' or labchemtestname like '%Alanine transaminase%' or labchemtestname like '%alanine aminotrans%' or labchemtestname like '%GPT%'  
                       or labchemprinttestname like 'ALT%' or labchemprinttestname like '%Alanine transaminase%' or labchemprinttestname like '%alanine aminotrans%' or labchemprinttestname like '%GPT%' 
                       or loinc like '%1742-6%' or loinc like '%1743-4%')
              and (topography like '%blood%' 
                       or topography like '%plasma%' 
                       or topography like '%serum%'
                        or topography like 'ser/pla'
                       )
              and labchemtestname not like '%ratio%'
              and labchemtestname not like '%altern%'
              and labchemtestname not like '%allergen%'
              and labchemtestname not like '%tenuis%'
              and labchemtestname not like '%amylase%'
              and loinc not in ('21108-6','16135-6','16136-4','6020-2', '5964-2','9363-3')

 --AST_Blood
              UPDATE ##LookUp_Lab_Stage
              SET AST_Blood =1
              WHERE sta3n <> 200 and Labchemtestsid > 1 
              and (labchemtestname like 'AST%' or labchemtestname like '%Aspartate transaminase%' or labchemtestname like '%aspartate aminotrans%' or labchemtestname like '%SGOT%'  or labchemtestname like '%ASAT%'  or labchemtestname like '%AspAT%' 
              or labchemprinttestname like 'AST%' or labchemprinttestname like '%Aspartate transaminase%' or labchemprinttestname like '%aspartate aminotrans%' or labchemprinttestname like '%SGOT%' or labchemprinttestname  like '%ASAT%'  or labchemprinttestname  like '%AspAT%'
              or loinc like '%1920-8%')
              and (topography like '%blood%' 
              or topography like '%plasma%' 
              or topography like '%serum%'
              or topography like 'ser/pla'
              )
              and (labchemtestname not like '%ratio%'
              )

--Sodium_Blood 
              UPDATE ##LookUp_Lab_Stage
              SET Sodium_Blood = 1
              WHERE sta3n <> 200 and Labchemtestsid > 1 
              and (labchemtestname like '%sodium%' or LabChemPrintTestName like '%sodium%'
              or loinc in ('32717-1','2951-2','2950-4','2947-0'))
              and labchemtestname not like '%FondaparinuxO%'
              and topography not like '%urine%'
              and topography not like '%feces%'
              and (topography like '%blood%' 
              or topography like '%plasma%' 
              or topography like 'ser/pla'  
              or topography like '%BLD%'
              or (topography like '%serum%' and topography not like '%rice lake%')
              );


--ProLactin_Blood
              UPDATE ##LookUp_Lab_Stage
              SET ProLactin_Blood =1
              WHERE sta3n <> 200 and LabChemTestSID > 1 and  (LabChemTestName like '%lactin%' or loinc like '2842-3')
              and LabChemTestName not like '%macro%' and labchemtestname not like '%monomeric%' and LabChemTestName not like 'Monemeric%' 
              and LabChemTestName not like 'MP%' and labchemtestname not like '% Diluted%' and LabChemTestName not like '%,dilute%'
              and LabChemTestName not like 'Dilute%' and LabChemTestName not like '% Dilution%'
              and topography not like '%urine%'
              and topography not like '%feces%'
              and (topography like '%blood%' 
              or topography like '%plasma%' 
              or topography like 'ser/pla'  
              or topography like '%BLD%'
              or (topography like '%serum%' and topography not like '%rice lake%')
              );
   
 --LDL_Blood    
              UPDATE ##LookUp_Lab_Stage
              SET LDL_Blood =1
              WHERE sta3n <> 200 and LabChemTestSID > 1 and  (LabChemTestName like '%LDL%') and labchemtestname not like '%density pattern%' and labchemtestname not like '%pattern%'
              and labchemtestname not like '%ratio%' and labchemtestname not like '%peak%' and labchemtestname not like '%small%' 
              and labchemtestname not like '%large%' and labchemtestname not like '%medium%' and labchemtestname not like '%particle%'
              and labchemtestname not like '%phenotype%' and LabChemTestName not like '%apob%' and labchemtestname not like '%vldl%'
              and labchemtestname not like '%fraction%' and labchemtestname not like 'APOLIPOPROTEIN B-LDL%'
              and labchemtestname not like 'LIPOPROT.(IDL+VLDL3)%' and labchemtestname not like 'LEG LDL%'
              and labchemtestname not like '%LDL Size%' and labchemtestname not like 'Non%HDL%'
              and labchemtestname not like 'Non-Fasting%' and labchemtestname not like 'remnant%'
              and labchemtestname not in (
              'LDL 1',
              'LDL 2',
              'LDL 3',
              'LDL 4',
              'LDL 5',
              'LDL 6',
              'LDL 7')
              and topography not like '%urine%'
              and topography not like '%feces%'
              and (topography like '%blood%' 
              or topography like '%plasma%' 
              or topography like 'ser/pla'  
              or topography like '%BLD%'
              or (topography like '%serum%' and topography not like '%rice lake%')
              );


--HDL_Blood
              UPDATE ##LookUp_Lab_Stage
              SET HDL_Blood =1
              WHERE sta3n <> 200 and LabChemTestSID > 1 and  (LabChemTestName like '%HDL%' or loinc='2085-9')
              and LabChemTestName not like '%CHOL/HDL%'
              and LabChemTestName not like '%Particle number%'
              and LabChemTestName not like '%size%'
              and LabChemTestName not like '%ratio%'
              and LabChemTestName not like '%large%'
              and LabChemTestName not like '%HDL-2%'
              and LabChemTestName not like '%HDL-3%'
              and LabChemTestName not like '%non HDL%'
              and LabChemTestName not like '%non-hdl%'
              and LabChemTestName not like '%CHOLESTEROL/HDL%'
              and LabChemTestName not like 'APOLIPOPROTEIN A-HDL'
              and LabChemTestName not like '%HDL 2%'
              and LabChemTestName not like '%HDL 3%'
              and LabChemTestName not like 'HDL Risk%'
              and LabChemTestName not like 'HDL,non%'
              and LabChemTestName not like 'LEG HDL%'
              and LabChemTestName not like '%NHDL%'
              and LabChemTestName not like '%W-CHOLESTEROL TOTAL/HDL%'
              and topography not like '%urine%'
              and topography not like '%feces%'
              and (topography like '%blood%' 
              or topography like '%plasma%' 
              or topography like 'ser/pla'  
              or topography like '%BLD%'
              or (topography like '%serum%' and topography not like '%rice lake%')
              );
              
--TotalCholesterol_Blood             
              UPDATE ##LookUp_Lab_Stage
              SET TotalCholesterol_Blood = 1
              WHERE sta3n <> 200 and LabChemTestSID > 1 and  (LabChemTestName like '%chol%' or loinc='2093-3')
              and LabChemTestName not like '%Acetyl%'
              and labchemtestname not like '%LDL Chol%'
              and LabChemTestName not like '%HDL Chol%'
              and LabChemTestName not like 'PSEUDOCHOLINESTERASE'
              and LabChemTestName not like '%CATECHOLAMINE%'
              and LabChemTestName not like '%ratio%'
              and LabChemTestName not like '%DEOXYCHOLIC ACID%'
              and LabChemTestName not like 'LDL-Chol'
              and LabChemTestName not like '%LDL chol%'
              and LabChemTestName not like 'Acetycholine%'
              and LabChemTestName not like '%CRYS%'
              and LabChemTestName not like '%cholinesterase%'
              and LabChemTestName not like '%cholic acid%'
              and LabChemTestName not like '%risk factor%'
              and LabChemTestName not like '%rank%'
              and LabChemTestName not like '%testosterone%'
              and LabChemTestName not like '%CHOLERAE%'
              and LabChemTestName not like '%pleural%'
              and LabChemTestName not like '%chol/hdl%'
              and LabChemTestName not like '%CHOLECYSTOKININ%'
              and LabChemTestName not like 'Alpha%'
              and LabChemTestName not like 'Cholestanol%'
              and LabChemTestName not like '%peritoneal%'
              and LabChemTestName not like '%mitocholdria%'
              and LabChemTestName not like '11-HYDROXYETIOCHOLANOLONE%'
              and LabChemTestName not like '11-KETOETIOCHOLANOLONE'
              and LabChemTestName not like '%LYSOPHOSPHATIDYL%'
              and LabChemTestName not like '%Body fluid%' --questionable
              and LabChemTestName not like '%catechol%'
              and LabChemTestName not like 'CHOL CRYS,BF(wx)'
              and LabChemTestName not like '%fluid%' ---Look into what this means
              and LabChemTestName not like 'CHOLESTERYL ESTERS [MAYO]%'
              and LabChemTestName not like 'CHOLESTROL LDL DIRECT%'
              and LabChemTestName not like 'CHOLYLGLYCINE%'
              and LabChemTestName not like 'CHYLOMICRONS CHOLESTEROL%'
              and LabChemTestName not like 'Direct LDL-%'
              and LabChemTestName not like 'ETIOCHOLANOLONE%'
              and LabChemTestName not like 'HDL %'
              and LabChemTestName not like '%HDL-Chol%'
              and LabChemTestName not like '%LDL Chol%'
              and LabChemTestName not like 'IDL Chol%'
              and LabChemTestName not like 'IDL-Chol%'
              and LabChemTestName not like 'HYPERCHOLESTEROLEMIA%'
              and LabChemTestName not like '%LDL-Chol%'
              and LabChemTestName not like 'Low density%'
              and LabChemTestName not like 'PHOSPHATIDYLCHOLINE%'
              and LabChemTestName not like 'PRE-BETA VLD CHOL%'
              and LabChemTestName not like '%cholera%'
              and LabChemTestName not like '%VLDL%'
              and LabChemTestName not like '%Total/HDL%'
              and LabChemTestName not like 'Nash cholesterol%'
              and LabChemTestName not like 'Leg chol%'
              and LabChemTestName not like 'CHOLESTEROL LDL%'
              and LabChemTestName not like '_DIBUCAINE NO. (OF CHOLINEST PNL)%'
              and LabChemTestName not like '%VLD chol%'
              and LabChemTestName not like '7-DEHYDROCHOLESTEROL-Q'
              and LabChemTestName not like 'LDL-CHOLESTEROL%'
              and LabChemTestName not like 'LDL Direect%'
              and LabChemTestName not like 'lipo chol%'
              and LabChemTestName not like 'LDLc chol%'
              and LabChemTestName not like 'Upper limit%'
              and LabChemTestName not like 'urine%'
              and LabChemTestName not like 'LDL Direct chol%'
              and LabChemTestName not like 'LIPO-CHOLESTEROL%'
              and LabChemTestName not like 'CHOLESTEROL/HDL%'
              and LabChemTestName not like '.IDL CHOLESTEROL%'
              and LabChemTestName not like '%NASH Chol%'
              and LabChemTestName not like 'lp%'
              and LabChemtestName not like '.lp%'
              and LabChemTestName not like ' lp%'
              and topography not like '%urine%'
              and topography not like '%feces%'
              and (topography like '%blood%' 
              or topography like '%plasma%' 
              or topography like 'ser/pla'  
              or topography like '%BLD%'
              or (topography like '%serum%' and topography not like '%rice lake%')
              );

              UPDATE ##LookUp_Lab_Stage
              SET Potassium_Blood = 1
              WHERE sta3n <> 200 and LabChemTestSID > 1 and  (LabChemTestName like '%potassium%' or loinc in 
              ('32713-0',
              '39789-3',
              '14172-1',
              '15202-5',
              '22760-3',
              '2821-7',
              '2823-3',
              '2828-2',
              '6298-4'))
              and LabChemTestName not like '%urine%'
              And LabChemTestName not like '%24%'
              and LabChemTestName not like '%stool%'
              and LabChemTestName not like '%Feces%'
              and LabChemTestName not like '%fecal%'
              and LabChemTestName not like 'LEG POTASSIUM%'
              and LabChemTestName not like '%Gas%'
              and LabChemTestName not like '%excretion%'
              and LabChemTestName not like 'voltage%'
              and LabChemTestName not like 'ur%'
              and LabChemTestName not like 'Reinfusion Potassium%'
              and LabChemTestName not like '%body fluid%'
              and LabChemTestName not like 'Reservoir Potassium%'
              and LabChemTestName not like 'POTASSIUM/CREATININE RATIO%'
              and LabChemTestName not like 'Potassium-(K UroRisk)%'
              and LabChemTestName not like 'POTASSIUM,UR%'
              and LabChemTestName not like 'POTASSIUM, PLATELET FREE%'
              and LabChemTestName not like 'POTASSIUM, ANC%'
              and LabChemTestName not like 'CELL SAVER POTASSIUM%'
              and LabChemTestName not like 'COMPUTED POTASSIUM%'
              and topography not like '%urine%'
              and topography not like '%feces%'
              and (topography like '%blood%' 
              or topography like '%plasma%' 
              or topography like 'ser/pla'  
              or topography like '%BLD%'
              or (topography like '%serum%' and topography not like '%rice lake%')
              )

-- A1c_Blood
              UPDATE ##LookUp_Lab_Stage
              SET A1c_Blood=1
              WHERE sta3n <> 200 and Labchemtestsid > 1 
              and (labchemtestname like '%A1c%')
              and labchemtestname not like 'A1C LYSED RBCS%'
              and labchemtestname not like 'D-A1C Comment%'
              and labchemtestname not like 'LEG A1C%'
              and topography not like '%urine%'
              and topography not like '%feces%'
              and (topography like '%blood%' 
              or topography like '%plasma%' 
              or topography like 'ser/pla'  
              or topography like '%BLD%'
              or (topography like '%serum%' and topography not like '%rice lake%')
              );
 
 --Trig_Blood      
              UPDATE ##LookUp_Lab_Stage
              SET Trig_Blood=1
              WHERE sta3n <> 200 and Labchemtestsid > 1 
              and (labchemtestname like '%trig%' or LabChemPrintTestName like '%trig%')
              and labchemtestname not like '%lamotrigine%'
              and LabChemTestName not like 'LAMOTRIGNINE%'
              and labchemtestname not like 'lp(a)%'
              and labchemtestname not like '%fl%'
              and LabChemTestName not like '%old%'
              and LabChemTestName not like '%peritoneal%'
              and labchemtestname not like 'UPPER LIMIT (TRIG)%'
              and labchemtestname not like '%pleural%'
              and labchemtestname not like 'PRE-BETA VLD TRIG%'
              and labchemtestname not like 'CHOL./TRIGL. RATIO-Q'
              and labchemtestname not like '%NASH TRIGLYCERIDES%'
              and labchemtestname not like '%RANK (TRIG)%'
              and labchemtestname not like '_NEUTRAL FATS (TRIGLYCERIDES)%'
              and labchemtestname not like 'ALPHA-HIGH DENSITY TRIGLYCERIDE'
              and labchemtestname not like 'BETA-VLD TRIG'
              and labchemtestname not like '%trachomatis%'
              and labchemtestname not like '%trach%'
              and labchemtestname not like 'CHL TRACH IGA%'
              and labchemtestname not like 'CHYLOMICRON%'
              and labchemtestname not like 'D-TRIGLYCERIDE'
              and labchemtestname not like '%TROPICALIS%'
              and labchemtestname not like '%TRANSGLUTAMINASE%'
              and labchemtestname not like 'setomelanomma rostrat%'
              and labchemtestname not like 'NEUTRAL FECAL FATS/TRIGLYCERIDES%'
              and labchemtestname not like 'LEG TRIGLYCERIDES%'
              and topography not like '%urine%'
              and topography not like '%feces%'
              and (topography like '%blood%' 
              or topography like '%plasma%' 
              or topography like 'ser/pla'  
              or topography like '%BLD%'
              or (topography like '%serum%' and topography not like '%rice lake%'))

--Glucose_Blood
              UPDATE ##LookUp_Lab_Stage
              SET Glucose_Blood=1
              WHERE sta3n <> 200 and Labchemtestsid > 1 
              and (labchemtestname like '%gluc%' or LabChemPrintTestName like '%gluc%')
              and labchemtestname not like '%beta%' and labchemtestname not like '%urine%'
              and labchemtestname not like '%d-glucan%'
              and labchemtestname not like '%GLUCURONIDE%'
              and labchemtestname not like '%postpartum%'
              and labchemtestname not like '%prenatal%'
              and labchemtestname not like '%S/S%'
              and labchemtestname not like '%spinal%'
              and labchemtestname not like '%glucuronyl%'
              and labchemtestname not like '%pleural%'
              and labchemtestname not like '%fungitell%'
              and labchemtestname not like 'URN%'
              and labchemtestname not like '%Nash%'
              and labchemtestname not like '%B-Glucan%'
              and labchemtestname not like '%ur glucos%'
              and labchemtestname not like '%alcohol%'
              and labchemtestname not like '%lactose%'
              and labchemtestname not like '%hr%gluc%'
              and labchemtestname not like '%min%gluc%'
              and labchemtestname not like '%gram gluc%'
              and labchemtestname not like 'ACID A-GLUCOSIDASE%'
              and labchemtestname not like 'ACID-ALPHA-GLUCOSIDASE-Q%'
              and labchemtestname not like '%D glucan%'
              and labchemtestname not like '%fluid%'
              and labchemtestname not like '%csf%'
              and labchemtestname not like 'GLUCOSE VARIATION%'
              and labchemtestname not like '%capillary%'
              and labchemtestname not like 'd-gluc%'
              and labchemtestname not like 'abg%'
              and labchemtestname not like 'd-mean blood%'
              and labchemtestname not like '%average%'
              and labchemtestname not like '%ave. gluc%'
              and labchemtestname not like '%avg gluc%'
              and labchemtestname not like 'ethyl gluc%'
              and labchemtestname not like '.Mycophenolic Acid Glucoronide%'
              and labchemtestname not like ' METER VS SERUM (GLUC)'
              and labchemtestname not like ' GLUCOSE/2 HOUR {Ref.Lab}%'
              and labchemtestname not like ' GLUCOSE/24hr.%'
              and labchemtestname not like '%BUPRENORPHINE%'
              and labchemtestname not like '%glipiz%'
              and labchemtestname not like 'GLUC 24HR%'
              and labchemtestname not like '%glucagon%'
              and labchemtestname not like 'glucose%hr%'
              and labchemtestname not like 'glucose%phos%'
              and labchemtestname not like '%peritoneal%'
              and labchemtestname not like '%post prand%'
              and labchemtestname not like 'GLUCOSE PROFICIENCY%'
              and labchemtestname not like '%glucose ur%'
              and labchemtestname not like '%GLUCOSE TOLERANCE TEST%'
              and labchemtestname not like '%gtt%'
              and labchemtestname not like '2HPP%'
              and labchemtestname not like 'GESTATIONAL DIABETES SCREEN%'
              and labchemtestname not like 'GLUCOCEREBROSIDASE (451780)%'
              and labchemtestname not like '%GAS%'
              and labchemtestname not like '%GLU2HR%'
              and labchemtestname not like 'GLUCOCEREBROSIDASE (451780)%'
              and labchemtestname not like 'glucogan%'
              and labchemtestname not like 'GLUCOSE%MIN'
              and labchemtestname not like 'glucose%hour%'
              and labchemtestname not like 'GLUCOSE, 24H UR%'
              and labchemtestname not like '%synovial%'
              and labchemtestname not like '%DIALYSATE%'
              and labchemtestname not like 'Glucose, UR%'
              and labchemtestname not like 'glucose%24%h'
              and labchemtestname not like 'glucose%arteria%'
              and labchemtestname not like 'GLUCOSE,GESTATIONAL%'
              and labchemtestname not like 'GLUCOSE,PERIT'
              and labchemtestname not like 'GLUCOSE,SYNOV(O)%'
              and labchemtestname not like 'glucose%venous%'
              and labchemtestname not like '%GLUCOSE-BODY FLD%'
              and labchemtestname not like '%critical%'
              and labchemtestname not like '%ratio%'
              and labchemtestname not like 'GRAMS OF GLUCOSE GIVEN%'
              and labchemtestname not like 'GLUCOSE-6-PD%'
              and labchemtestname not like 'GLUCOSE,UR (POC)%'
              and labchemprinttestname not like '%min%'
              and labchemprinttestname not like 'ur glu%'
              and labchemprinttestname not like 'gtt%'
              and labchemtestname not like 'ua%gluc%'
              and labchemtestname not like 'ur. glu%'
              and labchemtestname not like 'NORBUPRENORPINE(Fr+Nor.Glucoronide)U%'
              and labchemtestname not like 'MYCOPHENOLIC ACID GLUCORONIDE%'
              and labchemtestname not like 'GLUCOSE,PERICARD(O)%'
              and labchemtestname not like 'LEG GLUCOSE%'
              and labchemtestname not like 'GLUCOSE,24h calc%'
              and labchemtestname not like '%gestational%'
              and labchemtestname not like 'gluc%min%'
              and labchemtestname not like 'gluc%pp'
              and labchemtestname not like 'gluc%2h%'
              and labchemtestname not like 'gluc%ua%'
              and labchemtestname not like 'ALPHA-GLUCOSIDASE%'
              and labchemtestname not like 'CALC MEAN GLUCOSE%'
              and labchemtestname not like '%ua%gluc%'
              and labchemtestname not like 'GLUCOMETER CORRELATION INTERPRETATION%'
              and labchemtestname not like 'Glucose 1'
              and labchemtestname not like 'Glucose 4'
              and labchemtestname not like 'Glucose Calc%'
              and labchemtestname not like 'GLUCOSE EXCRETION (SY/BH/CN)'
              and labchemtestname not like 'SYNTHETIC GLUCOCORTICOID SCRN, UR'
              and labchemtestname not like 'PB MEAN BLOOD GLUCOSE'
              and labchemtestname not like 'NUCMED GLUCOSE'
              and labchemtestname not like '%LTT%'
              and labchemtestname not like 'NEUTRAL A-GLUCOSID.'
              and labchemtestname not like 'NEUTRAL A-GLUCOSID.'
              and labchemtestname not like 'ACCEPTABLE WHOLE BLOOD GLUCOSE RANGE%'
              and labchemtestname not like 'FASTING OGGT GLUCOSE-100g'
              and labchemtestname not like 'MYCOPHENOLIC ACID GLUCRONIDE -'
              and labchemtestname not like 'MPA GLUCORONIDE-QD'
              and labchemtestname not like 'GLUCOSE (PRE 75g)'
              and labchemtestname not like 'GLUCOMETER %METER COORELATION'
              and labchemtestname not like 'GLUCOSE-PERICARDIAL'
              and labchemtestname not like 'GLUCOSE-SYN FLD'
              and topography not like '%urine%'
              and topography not like '%feces%'
              and (topography like '%blood%' 
              or topography like '%plasma%' 
              or topography like 'ser/pla'  
              or topography like '%BLD%'
              or (topography like '%serum%' and topography not like '%rice lake%'))

			  


-- BandNeutrophils_Blood
              UPDATE ##LookUp_Lab_Stage
              SET BandNeutrophils_Blood=1
              WHERE sta3n <> 200 and Labchemtestsid > 1 
              and (labchemtestname like '%band%' or labchemprinttestname like '%band%')
              and labchemtestname not like '%kd%' and labchemtestname not like '%protein%'
              and labchemtestname not like '%OLIGOCLONAL%'
              and labchemtestname not like '%abnormal band%'
              and labchemtestname not like '%kb%'
              and labchemtestname not like '%abn band%'
              and labchemtestname not like '.UPE BAND(%)'
              and labchemtestname not like 'ASPERGIL%'
              and labchemtestname not like '%burgdorferi%'
              and labchemtestname not like 'ACREMONIUM (Cephalosporium)%'
              and labchemtestname not like 'ABSOLUTE SEGS/BANDS # (MANUAL)%'
              and labchemtestname not like 'ABNORMAL BAND 3 S/O RANDOM%'
              and labchemtestname not like 'BAND RESOLUTION%'
              and labchemtestname not like '%Body fluid%'
              and labchemtestname not like 'BAND/NEUTRPHIL%'
              and labchemtestname not like 'BANDING RESOLUTION%'
              and labchemtestname not like 'BANDING TECHNIQUE%'
              and labchemtestname not like 'TYPE OF BANDING/STAINING'
              and labchemtestname not like 'PIGEON SERUM BAND%'
              and labchemtestname not like '%OLIGOCLON%'
              and labchemtestname not like '%MONOCLONAL BAND%'
              and labchemtestname not like '%lyme%'
              and labchemtestname not like '%IFE%'
              and labchemtestname not like '%histoplasma%'
              and labchemtestname not like '%GTG%'
              and labchemtestname not like 'FAENIA RETIVIRGULA BAND%'
              and labchemtestname not like 'FL BANDS%'
              and labchemtestname not like 'D-Bands%'
              and labchemtestname not like 'CSF%'
              and labchemtestname not like '%Midband%'
              and labchemtestname not like '%abn%band%'
              and labchemtestname not like '%SPEP%'
              and labchemtestname not like 'ABN prot%'
              and labchemtestname not like '_BAND 3 FLUORESCENCE STAIN,RBC (OF PNL)'
              and labchemtestname not like 'AUREOBASIDIUM PULLULANS BAND%'
              and labchemtestname not like 'BAND MAN%'
              and labchemtestname not like 'BANDS,CSF%'
              and labchemtestname not like '%fluid%'
              and labchemtestname not like 'THERMOACTINOMYCES VULGARIS #1 BAND%'
              and labchemtestname not like 'zz%'
              and labchemtestname not like 'M Band%'
              and labchemtestname not like 'M-Band%'
              and labchemtestname not like 'EOS.Band%'
              and labchemtestname not like 'P-BANDS%'
              and labchemtestname not like 'RBC Band%'
              and labchemtestname not like 'ABS BAND%'
              and labchemtestname not like 'Band Level:'
              and labchemtestname not like 'BASOPHIL-BANDS%'
              and topography not like '%urine%'
              and topography not like '%feces%'
              and (topography like '%blood%' 
              or topography like '%plasma%' 
              or topography like 'ser/pla'  
              or topography like '%BLD%'
              or (topography like '%serum%' and topography not like '%rice lake%'))
;


-------------------------------------------------------------------------------------------------------
--CLOZAPINE monitoring related labs - per John Forno updated 11.05.19 SM
--Absolute Neutrophil Count
--Polys/Neutrophils
--WBC Total
--Clozapine Blood Level
-------------------------------------------------------------------------------------------------------

;/****Abs Neutrophil count************updated JF 031319 **********/
-- updating definition information  
UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Absolute Neutrophil Count',
		Category = 'Neutrophils',
		ColumnDescription = 'Measure of the number of neutrophils (type of White blood cell) present in the blood.'
	WHERE ColumnName = 'AbsoluteNeutrophilCount_Blood';
          
-- Updated ANC search code  jf - updated 11/5/19 SM
	WITH CTE_ANC AS 
		(		
		SELECT DISTINCT A.LabChemTestSID
		FROM 
			[Dim].[LabChemTest] AS A
			LEFT JOIN [Dim].[NationalVALabCode] AS C WITH(NOLOCK) ON A.NLTNationalVALabCodeSID = C.NationalVALabCodeSID
			LEFT JOIN [Dim].[LabChemTestPanelList] AS D WITH(NOLOCK) ON A.LabChemTestSID = D.PanelLabChemTestSID
			LEFT JOIN [Dim].[LabChemTest] AS E WITH(NOLOCK)
				ON IIF(D.LabChemTestSID IS NOT NULL, D.LabChemTestSID, -1) = E.LabChemTestSID AND E.LabTestType IN ('B','I')
			LEFT JOIN [Dim].[AccessioningInstitution] AS F WITH(NOLOCK) ON A.LabChemTestSID = F.LabChemTestSID 
			LEFT JOIN [Dim].[AccessionArea] AS G WITH(NOLOCK) ON F.AccessionAreaSID = G.AccessionAreaSID
		WHERE a.sta3n <> 200 and 
			(    A.LabChemTestName LIKE 'ANC%'                 
              OR A.LabChemTestName LIKE '%Abs%neu%'
              OR A.LabChemTestName LIKE 'ABS%GRAN%'
              OR A.LabChemTestName LIKE 'ABS%POL%'
              OR A.LabChemTestName LIKE '%NEUT%ABS%'
              OR A.LabChemTestName LIKE 'NE%#%'
              OR A.LabChemTestName LIKE '%NEUT #%'
              OR A.LabChemTestName LIKE 'NE#'
              OR A.LabChemTestName LIKE 'NEUT%NUMB%'
              OR A.LabChemTestName LIKE '%Neu%Cou%'
              OR A.LabChemTestName LIKE '%GRAN%ABS%'
              OR A.LabChemTestName LIKE '%GRAN%AUTO%'
              OR A.LabChemTestName LIKE '%GR%#%'            
              OR A.LabChemTestName LIKE '%SEG%#%'                                
              OR A.LabChemTestName LIKE '%SEG%NEU%#%' 
              OR A.LabChemTestName LIKE '%TOTAL%NEUT%'
              OR A.LabChemTestName LIKE '%#NEU%'
              OR A.LabChemTestName LIKE 'CLOZ%NEUT#%'
              OR A.LabChemTestName LIKE 'NE(10e3)'  
			  OR A.LabChemTestName LIKE 'Neutrophils (AUTO)' 
              OR A.LabChemTestName = 'NEUTROPHIL'
              OR A.LabChemTestName = 'GRANS (AUTO)'
			  OR A.LabChemTestName = 'NEUTROPHIL-A'
			)
			AND
			(	  A.LabChemTestName NOT LIKE 'Z%'
			  AND A.LabChemTestName NOT LIKE '%DC%'
			  AND A.LabChemTestName NOT LIKE '%D/C%'
			  AND A.LabChemTestName NOT LIKE '%PRE%'
			  AND A.LabChemTestName NOT LIKE '%BEFORE%'
			  AND A.LabChemTestName NOT LIKE '%THRU%'
			  AND A.LabChemTestName NOT LIKE '%(%-%)%'
			  AND A.LabChemTestName NOT LIKE '%T USE%'
			  AND A.LabChemTestName NOT LIKE '%INACT%'
			  AND A.LabChemTestName NOT LIKE '%<%'
		
			  AND A.LabChemTestName NOT LIKE '%ANCA%'
              AND A.LabChemTestName NOT LIKE '%ANTINEUTRO%'
              AND A.LabChemTestName NOT LIKE '%ANCIL%'
              AND A.LabChemTestName NOT LIKE '%BANDS%'
              AND A.LabChemTestName NOT LIKE '%CANNA%'
              AND A.LabChemTestName NOT LIKE '%POC%'
              AND A.LabChemTestName NOT LIKE '%URIN%'
              AND A.LabChemTestName NOT LIKE '%HYPER%'
              AND A.LabChemTestName NOT LIKE '%HYPO%'
              AND A.LabChemTestName NOT LIKE '%IMM%'
              AND A.LabChemTestName NOT LIKE '%CAP%'
              AND A.LabChemTestName NOT LIKE '%FLUID%'
              AND A.LabChemTestName NOT LIKE '%PERITONEAL%'
              AND A.LabChemTestName NOT LIKE '%GRANULOMA%'
              AND A.LabChemTestName NOT LIKE '%NEUTRO%[%]'
              AND A.LabChemTestName NOT LIKE 'GRANULOCYTE[%] (AUTO)'
              AND A.LabChemTestName NOT LIKE '%CLOT%'
              AND A.LabChemTestName NOT LIKE '%PADR%'
              AND A.LabChemTestName NOT LIKE '%ATH#%'
              AND A.LabChemTestName NOT LIKE '%THC%'
              AND A.LabChemTestName NOT LIKE '%Q#%'
              AND A.LabChemTestName NOT LIKE '%~%'
			)
			AND
			(	(	G.AccessionArea NOT LIKE '%ANCIL%'
                AND G.AccessionArea NOT LIKE 'ZZ%'
                AND G.AccessionArea NOT LIKE '%QUEST%'
                AND G.AccessionArea NOT LIKE '%ARUP%'
                AND G.AccessionArea NOT LIKE '%REFERENCE%'
                AND G.AccessionArea NOT LIKE '%LAB%CORP%'
                AND G.AccessionArea NOT LIKE '%CHEM%'
                AND G.AccessionArea NOT LIKE '%URIN%'
                AND G.AccessionArea NOT LIKE '%MICRO%'
                AND G.AccessionArea NOT LIKE '%FLUID%'
                AND G.AccessionArea NOT LIKE '%SEROLOGY%'
                AND G.AccessionArea NOT LIKE '%SEMEN%'
				)
				OR G.AccessionArea IS NULL
			)
			AND
			(	  C.WorkloadCode NOT LIKE '85099%'
              AND C.WorkloadCode NOT LIKE '85101%'
              AND C.WorkloadCode NOT LIKE '85128%'
              AND C.WorkloadCode NOT LIKE '81028%'
              AND C.WorkloadCode NOT LIKE '82237%'
              AND C.WorkloadCode NOT LIKE '82730%'
              AND C.WorkloadCode NOT LIKE '94578%'
              AND C.WorkloadCode NOT LIKE '92629%'
              AND C.WorkloadCode NOT LIKE '83380%'
              AND C.WorkloadCode NOT LIKE '85084%'
              AND C.WorkloadCode NOT LIKE '85093%'
              AND C.WorkloadCode NOT LIKE '81909%'
              AND C.WorkloadCode NOT LIKE '93748%'
              AND C.WorkloadCode NOT LIKE '85293%'
              AND C.WorkloadCode NOT LIKE '89108%'
              AND C.WorkloadCode NOT LIKE '83280%'
              AND C.WorkloadCode NOT LIKE '82426%'
              AND C.WorkloadCode NOT LIKE '85077.8636'
			)	
			AND
			(	(	E.LabChemTestName NOT LIKE '%COOX%'
				AND E.LabChemTestName NOT LIKE '%CHEM%'
				AND E.LabChemTestName NOT LIKE '%CELL%COUNT%'
				AND E.LabChemTestName NOT LIKE '%FLUID%'
				AND E.LabChemTestName NOT LIKE '%CD4%'
				AND E.LabChemTestName NOT LIKE 'Z%'
				)
				OR E.LabChemTestName IS NULL
			)
			AND A.LabTestType NOT LIKE 'N'
			AND A.LabChemTestSID NOT IN( 1000102760  -- 'GR #' in 598
										,1200106139  -- 'NEUTROPHIL' in 516			
										) 
		)

		UPDATE ##LookUp_Lab_Stage
		SET AbsoluteNeutrophilCount_Blood = 1
		WHERE sta3n <> 200 and LabChemTestSID IN( SELECT LabChemTestSID FROM CTE_ANC )
              ;

/****Polys/Neutrophils***********************************/
-- updating definition information -- Added by J Forno 03-2019
UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'Neutrophil Percent',
		Category = 'Neutrophils',
		ColumnDescription = 'Percent of mature neutrophils (type of White blood cell) present in the blood.'
	WHERE ColumnName = 'PolysNeutrophils_Blood'
;
--PolysNeutrophils_Blood  updated 11.05.19 SM
WITH CTE_POLY AS
	(	
	SELECT DISTINCT  A.LabChemTestSID
	FROM 
		[Dim].[LabChemTest] AS A WITH(NOLOCK)
		LEFT JOIN [Dim].[CollectionSample] AS B WITH(NOLOCK) ON A.CollectionSampleSID = B.CollectionSampleSID 
		LEFT JOIN [Dim].[NationalVALabCode] AS C WITH(NOLOCK) ON A.NLTNationalVALabCodeSID = C.NationalVALabCodeSID
		LEFT JOIN [Dim].[LabChemTestPanelList] AS D WITH(NOLOCK) ON A.LabChemTestSID = D.PanelLabChemTestSID
		LEFT JOIN [Dim].[NationalVALabCode] AS E WITH(NOLOCK) ON A.NationalVALabCodeSID = E.NationalVALabCodeSID 
		LEFT JOIN [Dim].[LabChemTest] AS F WITH(NOLOCK) ON IIF(D.LabChemTestSID IS NOT NULL, D.LabChemTestSID, -1) = F.LabChemTestSID AND F.LabTestType IN ('B','I')
		LEFT JOIN [Dim].[AccessioningInstitution] AS G WITH(NOLOCK) ON A.LabChemTestSID = G.LabChemTestSID 
		LEFT JOIN [Dim].[AccessionArea] AS H WITH(NOLOCK) ON G.AccessionAreaSID = H.AccessionAreaSID	
	WHERE a.sta3n <> 200 and 
		A.LabChemTestSID IN ( 1000000171 )
		OR   
		(	   A.LabChemTestName LIKE '%Poly%'
			OR A.LabChemTestName LIKE '%NEUT%'  
			OR A.LabChemTestName LIKE '%GRAN%'
			OR A.LabChemTestName LIKE '%PMN%'
			OR A.LabChemTestName LIKE '%SEGS%'
			OR A.LabChemTestName LIKE '%GR%AUTO%'
			OR A.LabChemTestName = 'NE%'
			OR A.LabChemTestName = 'SEG%'
		    OR A.LabChemTestName = 'SEG %'
		)
		AND
	    ( (    F.LabChemTestName LIKE '%CBC%'
			OR F.LabChemTestName LIKE '%HEMOG%'
			OR F.LabChemTestName = 'CELL-COUNT-CAPD'
		  )
		  OR F.LabChemTestName IS NULL
		)	
		AND
		( (    C.WorkloadCode LIKE '85078%'
			OR C.WorkloadCode LIKE '85077%'
			OR C.WorkloadCode LIKE '85099%'
			OR C.WorkloadCode LIKE '85098%'
			OR C.WorkloadCode LIKE '85122%'
			OR C.WorkloadCode LIKE '85569%'
			OR C.WorkloadCode LIKE '85652%'
			OR C.WorkloadCode LIKE '85249%'
			OR C.WorkloadCode LIKE '*Missing*'
			OR C.WorkloadCode LIKE '*Unknown at this time*'
		   )
		   OR C.WorkloadCode IS NULL
		)
		AND 
		(     C.WorkloadCode NOT LIKE '%.8121'
		  AND C.WorkloadCode NOT LIKE '%.9999'
		  AND C.WorkloadCode NOT LIKE '%.8053'
		  AND C.WorkloadCode NOT LIKE '%.4393'
		)	
		AND 
		( (		AccessionArea NOT LIKE '%ANCIL%'
			AND AccessionArea NOT LIKE '%URIN%'
			AND AccessionArea NOT LIKE '%COAG%'
			AND AccessionArea NOT LIKE '%QUEST%'
			AND AccessionArea NOT LIKE '%LAB%CO%'
			AND AccessionArea NOT LIKE '%BONE%'
			AND AccessionArea NOT LIKE '%PARA%'
			AND AccessionArea NOT LIKE 'SURG%'
			AND AccessionArea NOT LIKE 'FLUID%'
			AND AccessionArea NOT LIKE 'CHEMI%'
			AND AccessionArea NOT LIKE 'TOXIC%'
			AND AccessionArea NOT LIKE 'ARUP%'
			AND AccessionArea NOT LIKE 'SPECIALTY%'
			AND AccessionArea NOT LIKE 'SEMEN%'	
			)
			OR AccessionArea IS NULL
		)
		AND 
		(		DefaultTopography NOT LIKE 'SER%'
			AND DefaultTopography NOT LIKE 'PLAS%'
			AND DefaultTopography NOT LIKE '%URIN%'
		)
		AND
		(		A.LabChemTestName NOT LIKE 'Z%'
			AND A.LabChemTestName NOT LIKE '%DC%'
			AND A.LabChemTestName NOT LIKE '%D/C%'
			AND A.LabChemTestName NOT LIKE '%PRE%'
			AND A.LabChemTestName NOT LIKE '%OLD%'
			AND A.LabChemTestName NOT LIKE '%BEFORE%'
			AND A.LabChemTestName NOT LIKE '%THRU%'
			AND A.LabChemTestName NOT LIKE '%T USE%'
			AND A.LabChemTestName NOT LIKE '%INACT%'
			AND A.LabChemTestName NOT LIKE '%ANCA%'
			AND A.LabChemTestName NOT LIKE '%ANCIL%'
			AND A.LabChemTestName NOT LIKE '%#%'
			AND A.LabChemTestName NOT LIKE '%ABS%'
			AND A.LabChemTestName NOT LIKE '%NEU%ABS%'
			AND A.LabChemTestName NOT LIKE '%GRAN%ABS%'
			AND A.LabChemTestName NOT LIKE '%SEG #%'
			AND A.LabChemTestName NOT LIKE '%SEG#%'
			AND A.LabChemTestName NOT LIKE '%GRAN%#%'
			AND A.LabChemTestName NOT LIKE '%GR%#%'
			AND A.LabChemTestName NOT LIKE '%NE%#%'
			AND A.LabChemTestName NOT LIKE '%NEUTRAL%'
			AND A.LabChemTestName NOT LIKE '%CHROM%'
			AND A.LabChemTestName NOT LIKE '%FLUID%'
			AND A.LabChemTestName NOT LIKE '%HYPER%'
			AND A.LabChemTestName NOT LIKE '%HYPO%'
			AND A.LabChemTestName NOT LIKE '%VAC%'
			AND A.LabChemTestName NOT LIKE '%PELG%'
			AND A.LabChemTestName NOT LIKE '%FECAL%'
			AND A.LabChemTestName NOT LIKE '%CSF%'
			AND A.LabChemTestName NOT LIKE '%SER%'
			AND A.LabChemTestName NOT LIKE '%SYN%'
			AND A.LabChemTestName NOT LIKE '%PLATE%'
			AND A.LabChemTestName NOT LIKE '%BAND%'
			AND A.LabChemTestName NOT LIKE '%BI-LOB%'
			AND A.LabChemTestName NOT LIKE '%CAST%'
			AND A.LabChemTestName NOT LIKE '%IMM%'
			AND A.LabChemTestName NOT LIKE '%LYM%'
			AND A.LabChemTestName NOT LIKE '%MUCO%'
			AND A.LabChemTestName NOT LIKE '%CHLOR%'
			AND A.LabChemTestName NOT LIKE '%TOXIC%'
			AND A.LabChemTestName NOT LIKE 'AGRAN%'
			AND A.LabChemTestName NOT LIKE 'DEGEN%'
			AND A.LabChemTestName NOT LIKE '%CYTO%'
			AND A.LabChemTestName NOT LIKE '%NUMB%'
			AND A.LabChemTestName NOT LIKE '%MACRO%'
			AND A.LabChemTestName NOT LIKE '%TDM%'
			AND A.LabChemTestName NOT LIKE '%CD%'
			AND A.LabChemTestName NOT LIKE '%BF%'	
			AND A.LabChemTestName NOT LIKE 'NEUTROPHIL'
			AND A.LabChemTestName NOT LIKE 'GRANULOCYTE (AUTO)'
			AND A.LabChemTestName NOT LIKE 'Neutrophils (AUTO)'
			AND A.LabChemTestName NOT LIKE 'TOTAL NEUTROPHIL' 
			AND A.LabChemTestName NOT LIKE 'TOTAL GRANULOCYTE'
			AND A.LabChemTestName NOT LIKE 'Neutrophils (Manual)'
			AND A.LabChemTestName NOT LIKE 'NEUTROPHIL-A'
		)
		AND A.LabTestType NOT LIKE 'N'
	)


UPDATE ##LookUp_Lab_Stage
SET PolysNeutrophils_Blood = 1
WHERE sta3n <> 200 and LabChemTestSID IN( SELECT LabChemTestSID FROM CTE_POLY )

/****WBC Total Count ******Updated March 2019 John Forno*****/
-- updating definition information
UPDATE LookUp.ColumnDescriptions
	SET PrintName = 'WBC Total',
		Category = 'WBC Total',
		ColumnDescription = 'White Blood Cell Total Count from CBC.'
	WHERE ColumnName = 'WhiteBloodCell_Blood';

-- WBC Total count -- updated SM 11.05.19
WITH CTE_WBC AS 
(             
SELECT DISTINCT A.LabChemTestSID
FROM 
	[Dim].LabChemTest AS A WITH(NOLOCK)
	LEFT JOIN [Dim].[CollectionSample] AS B WITH(NOLOCK) ON A.CollectionSampleSID = B.CollectionSampleSID 
	LEFT JOIN [Dim].[NationalVALabCode] AS C WITH(NOLOCK) ON A.NLTNationalVALabCodeSID = C.NationalVALabCodeSID
	LEFT JOIN [Dim].[LabChemTestPanelList] AS D WITH(NOLOCK) ON A.LabChemTestSID = D.PanelLabChemTestSID
	LEFT JOIN [Dim].[LabChemTest] AS E WITH(NOLOCK) ON IIF(D.LabChemTestSID IS NOT NULL, D.LabChemTestSID, -1) = E.LabChemTestSID  AND E.LabTestType IN ('B','I')
	LEFT JOIN [Dim].[AccessioningInstitution] AS F WITH(NOLOCK) ON A.LabChemTestSID = F.LabChemTestSID 
	LEFT JOIN [Dim].[AccessionArea] AS G WITH(NOLOCK) ON F.AccessionAreaSID = G.AccessionAreaSID
WHERE a.sta3n <> 200 and 
	(A.LabChemTestName LIKE '%WBC%'
	 OR A.LabChemTestName LIKE '%WHITE%'
	)
	AND
    ( ( E.LabChemTestName LIKE '%CBC%'
		OR E.LabChemTestName LIKE '%HEMOG%'
	  )
	  OR E.LabChemTestName IS NULL
	)	
	AND
	( ( C.WorkloadCode LIKE '85569%'
		OR C.WorkloadCode LIKE '85030%'
		OR C.WorkloadCode LIKE '*Missing*'
		OR C.WorkloadCode LIKE '*Unknown at this time*'
	   )
	   OR C.WorkloadCode IS NULL
	)
	AND 
	( C.WorkloadCode NOT LIKE '%.8121'
	  AND C.WorkloadCode NOT LIKE '%.9999'
	  AND C.WorkloadCode NOT LIKE '%.8053'
	  AND C.WorkloadCode NOT LIKE '%.4393'
	)	
	AND
	( A.LabChemTestName NOT LIKE 'Z%'
	  AND A.LabChemTestName NOT LIKE 'XX%'
	  AND A.LabChemTestName NOT LIKE '%DC%'
	  AND A.LabChemTestName NOT LIKE '%D/C%'
	  AND A.LabChemTestName NOT LIKE '%PRE%'
	  AND A.LabChemTestName NOT LIKE '%BEFORE%'
	  AND A.LabChemTestName NOT LIKE '%THRU%'
	  AND A.LabChemTestName NOT LIKE '%T USE%'
	  AND A.LabChemTestName NOT LIKE '%INACT%'
	  AND A.LabChemTestName NOT LIKE '%ENDED%'
	  AND A.LabChemTestName NOT LIKE '%PRIOR%'
	  AND A.LabChemTestName NOT LIKE '%POC%'
	  AND A.LabChemTestName NOT LIKE '%ANC%'
	  AND A.LabChemTestName NOT LIKE '%SPERM%'
	  AND A.LabChemTestName NOT LIKE '%SEMEN%'
	  AND A.LabChemTestName NOT LIKE '%FECAL%'
	  AND A.LabChemTestName NOT LIKE '%STOOL%'
	  AND A.LabChemTestName NOT LIKE '%O&P%'
	  AND A.LabChemTestName NOT LIKE '%IMMUNO%'
	  AND A.LabChemTestName NOT LIKE '%BONE%'
	  AND A.LabChemTestName NOT LIKE '%NRBC%'
	  AND A.LabChemTestName NOT LIKE '%ASH%'
	  AND A.LabChemTestName NOT LIKE '%VACUOLES%'
	  AND A.LabChemTestName NOT LIKE '%ALLERG%'
	  AND A.LabChemTestName NOT LIKE '%LEG%'
	  AND A.LabChemTestName NOT LIKE '%FINGER%'
	  AND A.LabChemTestName NOT LIKE '%NUCLEATED%'
	  AND A.LabChemTestName NOT LIKE '%NRBC%'
	  AND A.LabChemTestName NOT LIKE '%ABSOL%'
	  AND A.LabChemTestName NOT LIKE '%BF%'
	  AND A.LabChemTestName NOT LIKE '%FLUID%'
	  AND A.LabChemTestName NOT LIKE '%FL%'
	  AND A.LabChemTestName NOT LIKE '%CSF%'
	  AND A.LabChemTestName NOT LIKE '%PERICARDIAL%'
	  AND A.LabChemTestName NOT LIKE '%PERITONEAL%'
	  AND A.LabChemTestName NOT LIKE '%SYN%'
	  AND A.LabChemTestName NOT LIKE '%UR%'
	  AND A.LabChemTestName NOT LIKE '%/100%'
	  AND A.LabChemTestName NOT LIKE '%IGE%'
	  AND A.LabChemTestName NOT LIKE '%FREEZER%'
	  AND A.LabChemTestName NOT LIKE '%CD4%'
	)
	AND 
	( (	AccessionArea NOT LIKE '%ZZ%'
		AND AccessionArea NOT LIKE '%FLOW%'	
		AND AccessionArea NOT LIKE 'MYCO%'
		AND AccessionArea NOT LIKE 'ARUP'	
	   )
	   OR AccessionArea IS NULL
	)
	AND
	( ( B.DefaultTopography NOT LIKE 'SERUM'
		AND B.DefaultTopography NOT LIKE 'PLASMA'
		AND B.DefaultTopography NOT LIKE 'URINE'
	   )
	   OR B.DefaultTopography IS NULL
	)
	AND A.LabTestType NOT LIKE 'N'
)

UPDATE ##LookUp_Lab_Stage
	SET WhiteBloodCell_Blood = 1 
	WHERE sta3n <> 200 and LabChemTestSID IN( SELECT LabChemTestSID FROM CTE_WBC )


/****Clozapine Blood Level****Updated March 2019 John Forno**/
-- updating definition information
UPDATE Lookup.ColumnDescriptions
	SET PrintName = 'Clozapine Blood Level',
		Category = 'Clozapine Blood Level',
		ColumnDescription = 'Measure of the level of Clozapine present in the blood.'
	WHERE ColumnName = 'Clozapine_Blood';

-- Clozapine blood level         -- updated SM 11.05.19
	WITH CTE_CLOZ AS 
		(SELECT DISTINCT LabChemTestSID 
		 FROM [Dim].[LabChemTest] WITH(NOLOCK)
		 WHERE sta3n <> 200 and    
		     (LabChemTestName LIKE '%CLOZ%'
		 	 ) AND
		 	 (LabChemTestName NOT LIKE 'Z%'
		 	 AND LabChemTestName NOT LIKE 'X%'
		 	 AND LabChemTestName NOT LIKE '%DC%'
		 	 AND LabChemTestName NOT LIKE '%D/C%'
		 	 AND LabChemTestName NOT LIKE '%PRE%'
		 	 AND LabChemTestName NOT LIKE '%THRU%'
		 	 AND LabChemTestName NOT LIKE '%T USE%'
		 	 AND LabChemTestName NOT LIKE '%INACT%'
		 	 AND LabChemTestName NOT LIKE '%ENDED%'
		 	 AND LabChemTestName NOT LIKE '%PRIOR%'
		 	 AND LabChemTestName NOT LIKE '%(...%'
		 	 AND LabChemTestName NOT LIKE '%4/00%'
		 	 AND LabChemTestName NOT LIKE '%(TO%'
		 	 AND LabChemTestName NOT LIKE '%98%'
		 	 AND LabChemTestName NOT LIKE '%CBC%'
		 	 AND LabChemTestName NOT LIKE '%WBC%'
		 	 AND LabChemTestName NOT LIKE '%NEUT%'
		 	 AND LabChemTestName NOT LIKE '%HEMA%'
		 	 )
		)

	UPDATE ##LookUp_Lab_Stage
	SET Clozapine_Blood = 1
	WHERE sta3n <> 200 and LabChemTestSID IN( SELECT LabChemTestSID FROM CTE_CLOZ )
;
-------------------------------Cerner labs are lonic based once VISTA labs are identified use their LOINCs to update CERNER results
-----CERNER names are totally different so they need their own logic

UPDATE ##LookUp_Lab_Stage
SET A1c_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE A1c_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET AbsoluteNeutrophilCount_Blood = 1
WHERE     sta3n = 200
      AND loinc IN ('751-8') or 
      ((LabChemTestName like '%NEUT%' and LabChemTestName like '%abs%')
      or (LabChemPrintTestName like '%NEUT%' and LabChemPrintTestName like '%abs%'))

UPDATE ##LookUp_Lab_Stage
SET ALT_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE ALT_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET AST_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE AST_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET BandNeutrophils_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE BandNeutrophils_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET Creatinine_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE Creatinine_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET EGFR_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE EGFR_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET Glucose_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE Glucose_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET HDL_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE HDL_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET Hemoglobin_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE Hemoglobin_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET LDL_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE LDL_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET Morphine_UDS = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE Morphine_UDS = 1)

UPDATE ##LookUp_Lab_Stage
SET NonMorphineOpioid_UDS = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE NonMorphineOpioid_UDS = 1)

UPDATE ##LookUp_Lab_Stage
SET NonOpioidAbusable_UDS = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE NonOpioidAbusable_UDS = 1)

UPDATE ##LookUp_Lab_Stage
SET Platelet_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE Platelet_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET PolysNeutrophils_Blood = 1
WHERE     sta3n = 200
      AND loinc IN ('770-8','764-1', '769-0')
      or (  (LabChemTestName like '%Neut%' and
 ( LabChemPrintTestName like '%pct%' or LabChemPrintTestName like '%/%%' escape '/'  ))
 or (LabChemPrintTestName in ('Segs Man'))
 )


UPDATE ##LookUp_Lab_Stage
SET Potassium_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE Potassium_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET ProLactin_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE ProLactin_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET Sodium_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE Sodium_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET TotalCholesterol_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE TotalCholesterol_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET Trig_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE Trig_Blood = 1)

UPDATE ##LookUp_Lab_Stage
SET WhiteBloodCell_Blood = 1
WHERE     sta3n = 200
      AND (loinc IN ('6690-2', '6690-2', '26466-3', '814-4') or
      LabChemPrintTestName like '%wbc%' 
          or LabChemPrintTestName like '%white blood%' or  LabChemTestName like '%wbc%' 
          or LabChemTestName like '%white blood%'  )            

UPDATE ##LookUp_Lab_Stage
SET Clozapine_Blood = 1
WHERE     sta3n = 200
      AND loinc IN (SELECT DISTINCT LOINC
                    FROM ##LookUp_Lab_Stage
                    WHERE Clozapine_Blood = 1)
      or LabChemTestName like '%CLOZAPINE%'
      or LabChemTestName like 'Total (Cloz+Norcloz) LC'
      or LOINC = '12375-2'


	EXEC [Maintenance].[PublishTable] '[LookUp].[Lab]', '##LookUp_Lab_Stage'

END