
/************************** Cerner Overlay Comments **************************/
--update after Lookup.ND_VM has been implemented

/********************************************************************************************************************
DESCRIPTION: Create Lookup table for Morphine Equivalence
CREATE DATE: 09/11/2017
AUTHOR: Susanna Martins/Cora Bernard
TEST:
	EXEC Code.Lookup_MorphineEquiv_Outpatient_OpioidforPain
UPDATE:
	2020-04-20	SM	UPDATING Lookup_MorphineEquiv_Outpatient_OpioidforPain INSTEAD OF LookUp_MorphineEquivalence. See summary below.
	2020-04-27	RAS	Added exclusion of Dihydorocodeine classified as Codeine (only keep when classified as Dihydrocodeine). Join on "LIKE" results in 2 rows for each Dihydrocodeine drug.
	2020-04-27	RAS	Added SUSP,ORAL to liquid table.
	2020-04-28 - Updated Nasal spray defintions: (1) added number of sprays per bottle 'NasalSprays_PerBottle'
				(2)	corrected butorphanol strengthnumeric to reflect dose of each spray (1mg) and not strength per ml (10mg)
	2020-04-30 - added StrengthPer_NasalSpray for nasal formulations since butorphanol is incorrect in nationaldrug.
	2020-10-29  CLB branched for Cerner
	2021-01-04	RAS	Changed published table to LookUp.MorphineEquiv_Outpatient_OpioidforPain (instead of _vm)
	2022-05-04	RAS	Currently we can use this output as is with "distinct" to join Millennium data using VUID,
					but I added a check at the end of the code to make sure this does not change.
	2022-07-25	SM Added 'FILM,BUCCAL' as 'UnitDose' to DoseType (missing for 7 BUPRENORPHINE formulations, checked in google and these are used for chronic pain management))
********************************************************************************************************************/

/*
April 2020 Update Summary:
	-- using strengthnumeric updated in Lookup.NationalDrug to include values for combination opioid drugs
	-- using dosageform from dim.nationaldrug
	-- correcting dose_type for outpatient MEDD computation: unitdose (tab, patch, sublingual, suppository), liquid (suspension, liquid) and INJ (injectables)
	-- excluding Injectables (we do not compute MEDD fo injectables)
	-- Excluding opioids we should not be computing outpatient MEDD for, this includes:
		-- powder and crystal formulations (we do not know how much is dosed)
		-- injectables
		-- buprenorphrine used for MAT
		-- methadone used for MAT
*/

CREATE PROCEDURE [Code].[Lookup_MorphineEquiv_Outpatient_OpioidforPain]

AS
BEGIN

/*	NOTE: All calculations are for OpioidForPain_Rx = 1 in Lookup.NationalDrug
	Moreover, we only move forward opioids for which we have a conversion factor
	from https://www.cms.gov/Medicare/Prescription-Drug-Coverage/PrescriptionDrugCovContra/Downloads/Oral-MME-CFs-vFeb-2018.pdf
*/

/*	NOTE: We need to add the historical conversion factor as well:
	Best to annotate that the ‘old’ method is method prior to 2017 and STORM Model used this method  to compute MEDD.
	The conversion factor I'm currently using (as of 2020-04) can be labeled to be consistent with calculating MEDD_CDC_Report and annotate its origins 
	As column names are changing, make sure in VS that no other source calls on Lookup.MorphineEquivalence.
*/

EXEC [Log].[ExecutionBegin] 'EXEC Code.Lookup_MorphineEquiv_Outpatient_OpioidforPain','Execution of Lookup_MorphineEquiv_Outpatient_OpioidforPain SP'

/**********CREATE CONVERSION TABLE***********/
DROP TABLE IF EXISTS #Conversion;
CREATE TABLE #Conversion
	 (
	  DrugNamePattern varchar(50) --will be used to match with DrugNameWithDose
	 ,Opioid varchar(50) --the shortened opioid name
	 ,DosageForm varchar(20) --if NULL, use for all dosage forms (will force exclusion of powder, crystal and injectable dosage form later)
	 ,ConversionFactor_Report decimal(10,2) --source unless otherwise listed: https://www.cms.gov/Medicare/Prescription-Drug-Coverage/PrescriptionDrugCovContra/Downloads/Oral-MME-CFs-vFeb-2018.pdf
	 ,ConversionFactor_RiskScore decimal(10,2) --CDC computation at time STORM Model was defined (basically uses one conversion rate for methadone)
	 -- insert conversionfactor for risk score (older method)
	 );
INSERT INTO #Conversion (
	  DrugNamePattern
	 ,Opioid
	 ,DosageForm
	 ,ConversionFactor_Report
	 ,ConversionFactor_RiskScore)
VALUES
	   --check bup and fentanyl dosageform
	   --('%BUPRENORPHINE%','BUPRENORPHINE','Film/tablet',30),	--Removed 4/2020 -- source: https://www.cms.gov/Medicare/Prescription-Drug-Coverage/PrescriptionDrugCovContra/Downloads/Opioid-Morphine-EQ-Conversion-Factors-Aug-2017.pdf
	   ('%BUPRENORPHINE%','BUPRENORPHINE','Patch',12.6,12.6),	--source: https://www.cms.gov/Medicare/Prescription-Drug-Coverage/PrescriptionDrugCovContra/Downloads/Opioid-Morphine-EQ-Conversion-Factors-Aug-2017.pdf
	   ('%BUPRENORPHINE%','BUPRENORPHINE','Patch-Weekly',12.6,12.6),	--CB added for Cerner (better to make another translation table to group all "tab" types, "film" types, etc together to avoid such repeats?)
	   ('%BUPRENORPHINE%','BUPRENORPHINE','Film',0.03,0.03),	-- updated per JT ConversionFactor_RiskScore=ConversionFactor_Report
	   ('%BUPRENORPHINE%','BUPRENORPHINE','Film-oral',0.03,0.03),	--CB added for Cerner
	   ('%BUPRENORPHINE%','BUPRENORPHINE','FILM,BUCCAL',0.03,0.03), --CB added on 8/17/21 for updates to bup/naloxone drugs (some of which are opioid for pain)
	   ('%BUTORPHANOL%','BUTORPHANOL',NULL,7,7), 
	   ('%CODEINE%','CODEINE',NULL,0.15,0.15),
	   ('%DIHYDROCODEINE%','DIHYDROCODEINE',NULL,0.25,0.25),
	   ('%FENTANYL%','FENTANYL','TAB,BUCCAL',0.13,0.13),
	   ('%FENTANYL%','FENTANYL','TAB,SUBLINGUAL',0.13,0.13),
	   ('%FENTANYL%','FENTANYL','Tablet',0.13,0.13),			--CB added for Cerner
	   ('%FENTANYL%','FENTANYL','LOZENGE',0.13,0.13),			-- updated per JT ConversionFactor_RiskScore=ConversionFactor_Report  
	   --('%FENTANYL%','FENTANYL','troche',0.13),				-- source table lists 'troche' but does not exist in Lookup.NationalDrug
	   ('%FENTANYL%','FENTANYL','FILM',0.18,0.18),				-- updated per JT ConversionFactor_RiskScore=ConversionFactor_Report
	   ('%FENTANYL%','FENTANYL','SPRAY,SUBLINGUAL',0.18,0.18),	-- updated per JT ConversionFactor_RiskScore=ConversionFactor_Report
	   ('%FENTANYL%','FENTANYL','SOLN,SPRAY,NASAL',0.16,0.16),	-- updated per JT ConversionFactor_RiskScore=ConversionFactor_Report
	   ('%FENTANYL%','FENTANYL','PATCH',7.2,7.2),
	   ('%HYDROCODONE%','HYDROCODONE',NULL,1,1),
	   ('%HYDROMORPHONE%','HYDROMORPHONE',NULL,4,4),
	   ('%LEVORPHANOL%','LEVORPHANOL',NULL,11,11),	--source table lists as 'levorphanol tartrate.' all DrugNameWithDose have tartrate, all DrugNameWithoutDose do not, so we use the opioid name 'levorphanol' with the tartrate implicit
	   ('%MEPERIDINE%','MEPERIDINE',NULL,0.1,0.1),	--source table lists as 'meperidine hydrochloride.' most but not all DrugNameWithDose have HCL, all DrugNameWithoutDose just have 'meperidine', so we use the opioid name 'meperidine' with the HCL implicit
	   ('%METHADONE%','METHADONE',NULL,NULL,3),		--special case, conversion factor will be added in MEDD_Report calculation when daily dose is summed. MEDD_RiskScore is 3 and computation is the same as other opioids
	   ('%MORPHINE%','MORPHINE',NULL,1,1),
	   ('%OPIUM%','OPIUM',NULL,1,1),--SM??? excluding Opium?
	   ('%OXYCODONE%','OXYCODONE',NULL,1.5,1.5),
	   ('%OXYMORPHONE%','OXYMORPHONE',NULL,3,3),
	   ('%PENTAZOCINE%','PENTAZOCINE',NULL,0.37,0.37),
	   ('%PROPOXYPHENE%','PROPOXYPHENE',NULL,0.23,0.23), --source: https://www.bwc.ohio.gov/downloads/blankpdf/MEDTable.pdf
	   ('%TAPENTADOL%','TAPENTADOL',NULL,0.4,0.4),
	   ('%TRAMADOL%','TRAMADOL',NULL,0.1,0.1);
	   --SUFENTANIL has a tab formulation that is only for inpatient and ED use, so will not compute MEDD

/**********CREATE DOSAGE TYPE TABLE***********/
DROP TABLE IF EXISTS #DoseType;
CREATE TABLE #DoseType (
	DosageForm varchar(50)
	,DoseType varchar(20) --NULL reflects that drug strength is NULL and we cannot compute MEDD
	);
	/* List of drugs with drug strength NULL (will not compute MEDD for these, therefore )
		'FENTANYL CITRATE PWDR'
		'HYDROMORPHONE HCL CRYSTALS'
	*/
INSERT INTO #DoseType (
	 DosageForm
	,DoseType
)
VALUES 
	--Liquid (computation of daily dose is (QTY/DAYSSUPPLY) * StrengthPer_ml)
	('Concentrate',		'Liquid'), --CB added for Cerner
	('ELIXIR',		'Liquid'),
	('LIQUID',		'Liquid'),
	('LIQUID,ORAL', 'Liquid'),
	('SOLN,CONC',	'Liquid'),
	('SOLN,ORAL',	'Liquid'),
	('Solution-Oral',		'Liquid'), --CB added for Cerner
	('Suspension-Oral',		'Liquid'), --CB added for Cerner
	('SYRUP',		'Liquid'), 
	--Nasal Spray (computation of daily dose is (NasalSprays_perBottle * QTY)/DAYSSUPPLY) * StrengthNumeric)
	('SOLN,SPRAY,NASAL','NasalSpray'),
	('Spray-Nasal','NasalSpray'), --CB added for Cerner
	--UnitDose (computation of daily dose is (QTY/DAYSSUPPLY)*StrengthNumeric)
	('CAP,ORAL',		'UnitDose'),
	('CAP,ORAL,IR',		'UnitDose'),
	('CAP,SA',			'UnitDose'),
	('CAP,SPRINKLE,SA', 'UnitDose'),
	('Capsule',	'UnitDose'), --CB added for Cerner
	('Capsule-24 hr Release',	'UnitDose'), --CB added for Cerner
	('Capsule-Extended Release',	'UnitDose'), --CB added for Cerner
	('FILM',			'UnitDose'),
	('FILM-oral',		'UnitDose'), --CB added for Cerner. correct as unitdose?
	('LOZENGE',			'UnitDose'),
	('PATCH',			'UnitDose'),
	('PATCH-Weekly',	'UnitDose'), --CB added for Cerner. assuming this is same as patch in terms of unit dose?
	('SPRAY,SUBLINGUAL','UnitDose'), 
	('Supp-Rectal',		'UnitDose'), --CB added for Cerner
	('Suppository',		'UnitDose'), --CB added for Cerner
	('SUPP,RTL',		'UnitDose'),
	('SUSP',			'UnitDose'),
	('SUSP,ORAL',		'UnitDose'),
	('TAB',				'UnitDose'),
	('TAB,BUCCAL',		'UnitDose'),
	('TAB,EFFERVSC',	'UnitDose'),
	('TAB,IR',			'UnitDose'),
	('Tablet',			'UnitDose'), --CB added for Cerner
	('Tablet-Extended Release',	'UnitDose'), --CB added for Cerner
	('TAB,ORAL',		'UnitDose'),
	('TAB,ORAL DISINTEGRATING',	'UnitDose'),
	('TAB,SA',					'UnitDose'),
	('TAB,SA (EXTENDED RELEASE)','UnitDose'),
	('TAB,SOLUBLE',		'UnitDose'),
	('TAB,SUBLINGUAL',	'UnitDose'),
	('FILM,BUCCAL',	'UnitDose')
	
	--('INJ',		'INJ'), -- should not compute MEDD for this formulation so will exclude (fast acting, not sure of conversion factor, not outpatient)
	--('INJ,LYPHL', 'INJ'), -- should not compute MEDD for this formulation so will exclude
	--('INJ,SOLN',	'INJ'), -- should not compute MEDD for this formulation so will exclude
	--('INJ,SUSP',	'INJ'), -- should not compute MEDD for this formulation so will exclude
	
	--('CRYSTAL',	NULL), -- should not compute MEDD for this formulation so will exclude
	--('POWDER',	NULL), -- should not compute MEDD for this formulation so will exclude

/**********GET LIST OF OPIOIDS PRESCRIBED FOR PAIN***********/
	/*
	SM 04282020 NASAL SPRAY
		Added variable: NasalSprays_perBottle
		Nasal sprays require a new field - number of sprays per bottle dispensed to compute daily dose (QTY(bottles dispensed) * Spraysperbottle /DAYSSUPPLY)
		--StrengthNumeric update required for butorphanol, but not fentanyl
			BUTORPHANOL TARTRATE 10MG/ML SOLN,SPRAY,NASAL 
				-- https://www.drugs.com/pro/butorphanol-nasal-spray.html (one bottle has 14-15 sprays if primed once, 8-10 if primed twice, ie not used every day)
				-- JT decision we will go with 14 sprays per bottle
				-- StrengthNumeric=10, but this is per ml. Per websit,e each spray is 1mg. So will update strengthnumeric to be 1. 
			FENTANYL XXXMCG/SPRAY SOLN,NASAL 
				-- https://reference.medscape.com/drug/lazanda-fentanyl-intranasal-999668 (sprays per bottle =8)
				-- StrengthNumeric from Dim.NationalDrug = strength for each spray	
	*/


DROP TABLE IF EXISTS #OpioidForPain 
SELECT DISTINCT n.NationalDrugSID
	  ,n.Sta3n
	  ,n.VUID
	  ,n.DrugNameWithDose	
	  ,ISNULL(n.CalculatedStrengthNumeric,n.StrengthNumeric) as StrengthNumeric
	  ,UPPER(n.DosageForm) as DosageForm
	  ,d.DispenseUnit
	  ,t.DoseType
	  ,c.Opioid	  
	  ,c.ConversionFactor_Report
	  ,c.ConversionFactor_RiskScore
INTO #OpioidForPain
FROM [LookUp].[NationalDrug] n WITH (NOLOCK)
	LEFT JOIN #DoseType t 
		ON n.DosageForm = t.DosageForm
	LEFT JOIN #Conversion c 
		ON n.DrugNameWithDose LIKE c.DrugNamePattern 
		AND (c.DosageForm = n.DosageForm OR c.DosageForm is NULL)
	LEFT JOIN [Dim].[NationalDrug] AS a WITH (NOLOCK) --Need this for DispenseUnitSID (not in LookUp.NationalDrug)
		ON a.NationalDrugSID = n.NationalDrugSID
	LEFT JOIN [Dim].[DispenseUnit] AS d 
		ON a.DispenseUnitSID = d.DispenseUnitSID
WHERE n.OpioidforPain_Rx = 1 
	-- keeping only formulations where we can compute MEDD for outpatient setting
	AND n.DosageForm not like '%INJ%' -- injectable - not outpatient form. inpatient use/hospice use?
	AND n.DosageForm not like '%IONTOPHORETIC SYSTEM%'-- not outpatient form. inpatient use/hospice use?
	AND n.DosageForm not like '%CRYSTAL%' -- can't compute MEDD because we can't compute daily dose
	AND n.DosageForm not like '%POWDER%'-- can't compute MEDD because we can't compute daily dose
	AND n.DrugNameWithDose not like '%SUFENTANIL%' -- used in ED and inpatient only
	AND NOT (n.DrugNameWithDose LIKE '%DIHYDROCODEINE%' AND Opioid='CODEINE') --Added exclusion of dihydrocodeine catgorized as codeine due to join including "LIKE '%CODEINE%'"

/**********CALCULATE STRENGTH PER ML***********/
DROP TABLE IF EXISTS #Liquids
SELECT NationalDrugSID
	,Sta3n 
	,VUID
	,DrugNameWithDose	
	,Opioid	  
	,StrengthNumeric
	,CAST(CASE --could be automated but tradeoff with code complexity
		WHEN DrugNameWithDose LIKE '%MG/ML%' OR DrugNameWithDose LIKE '%/ ML%' THEN StrengthNumeric
		WHEN DrugNameWithDose LIKE '%/0.5ML%' OR DrugNameWithDose LIKE '%/0.5 ML%' THEN StrengthNumeric/0.5
		WHEN DrugNameWithDose LIKE '%/2.5ML%' OR DrugNameWithDose LIKE '%/2.5 ML%' THEN StrengthNumeric/2.5
		WHEN DrugNameWithDose LIKE '%/5ML%' OR DrugNameWithDose LIKE '%/5 ML%'	  THEN StrengthNumeric/5
		WHEN DrugNameWithDose LIKE '%/10ML%' OR DrugNameWithDose LIKE '%/10 ML%' THEN StrengthNumeric/10
		WHEN DrugNameWithDose LIKE '%/15ML%' OR DrugNameWithDose LIKE '%/15 ML%' THEN StrengthNumeric/15
		WHEN DrugNameWithDose LIKE '%/20ML%' OR DrugNameWithDose LIKE '%/20 ML%' THEN StrengthNumeric/20
		ELSE NULL
		END AS decimal (10,2)) as StrengthPer_mL
	,DosageForm
	,DoseType
	,ConversionFactor_Report
	,ConversionFactor_RiskScore
INTO #Liquids
FROM #OpioidForPain
WHERE DoseType = 'Liquid'

/**********CALCULATE STRENGTH PER NASAL SPRAY***********/
DROP TABLE IF EXISTS #Nasal
SELECT NationalDrugSID
	,Sta3n 
	,VUID
	,DrugNameWithDose	
	,Opioid	  
	,StrengthNumeric
	,CASE WHEN DrugNameWithDose = 'BUTORPHANOL TARTRATE 10MG/ML SOLN,SPRAY,NASAL' THEN 14  --
			WHEN DrugNameWithDose = 'BUTORPHANOL 10 MG/ML NASAL SPRAY 2.5 ML'  THEN 14 -- CB added for Cerner
			WHEN DrugNameWithDose = 'BUTORPHANOL 10 MG/ML NASAL SPRAY [2.5ML]'  THEN 14 -- CB added for Cerner
			WHEN DrugNameWithDose like '%fent%nasal%' THEN 8  
			END as NasalSprays_perBottle
	,CAST(CASE --could be automated but tradeoff with code complexity
		WHEN DrugNameWithDose LIKE 'BUTORPHANOL TARTRATE 10MG/ML SOLN,SPRAY,NASAL'  THEN 1 -- StrengthNumeric=10, but this is per ml. Per website each spray is 1mg.  
		WHEN DrugNameWithDose = 'BUTORPHANOL 10 MG/ML NASAL SPRAY 2.5 ML'  THEN 1 -- CB added for Cerner
		WHEN DrugNameWithDose = 'BUTORPHANOL 10 MG/ML NASAL SPRAY [2.5ML]'  THEN 1 -- CB added for Cerner
		WHEN DrugNameWithDose LIKE 'FENTANYL 100MCG/SPRAY SOLN,NASAL'	THEN StrengthNumeric 
		WHEN DrugNameWithDose LIKE 'FENTANYL 300MCG/SPRAY SOLN,NASAL'	THEN StrengthNumeric
		WHEN DrugNameWithDose LIKE 'FENTANYL 400MCG/SPRAY SOLN,NASAL'	THEN StrengthNumeric
		ELSE NULL
		END AS decimal (10,2)) as StrengthPer_NasalSpray
	,DosageForm
	,DoseType
	,ConversionFactor_Report
	,ConversionFactor_RiskScore
INTO #Nasal
FROM #OpioidForPain
WHERE DoseType = 'NasalSpray'

/**********POPULATE FINAL MORPHINE EQUIVALENCE TABLE***********/
DROP TABLE IF EXISTS #Final
SELECT DISTINCT o.NationalDrugSID
	  ,o.Sta3n 
	  ,o.VUID
	  ,o.DrugNameWithDose	
	  ,o.Opioid
	  ,o.DosageForm
	  ,o.DoseType
	  ,n.NasalSprays_perBottle
	  ,CASE WHEN l.StrengthPer_ml IS NOT NULL OR n.StrengthPer_NasalSpray IS NOT NULL THEN NULL
		ELSE o.StrengthNumeric --from Lookup.NationalDrug 
	   END as StrengthNumeric
	  ,l.StrengthPer_ml  -- for liquids
	  ,n.StrengthPer_NasalSpray
	  ,o.ConversionFactor_Report
	  ,o.ConversionFactor_RiskScore
	  ,CASE
		WHEN o.Opioid = 'METHADONE' THEN 1
		WHEN o.DrugNameWithDose LIKE '%,SA%' THEN 1
		WHEN o.DispenseUnit LIKE '%,SA%' THEN 1
		WHEN o.DosageForm LIKE '%,SA%' THEN 1
		WHEN o.DosageForm LIKE '%PATCH%' THEN 1
		WHEN o.DosageForm LIKE '%24 HR%' THEN 1 --CB added for Cerner
		WHEN o.DosageForm LIKE '%Extended Release%' THEN 1 --CB added for Cerner
		ELSE 0 
		END AS LongActing
INTO #Final
FROM #OpioidForPain o
	LEFT JOIN #Liquids AS l ON o.NationalDrugSID=l.NationalDrugSID
	LEFT JOIN #Nasal as n on o.NationalDrugSID=n.NationalDrugSID

DECLARE @VUIDCount INT = (
	SELECT COUNT(*)-COUNT(DISTINCT VUID)
	FROM (
		SELECT DISTINCT 
			VUID
			,DrugNameWithDose
			,Opioid
			,DosageForm
			,DoseType
			,StrengthNumeric
			,StrengthPer_mL
			,StrengthPer_NasalSpray
			,NasalSprays_perBottle
			,ConversionFactor_Report
			,ConversionFactor_RiskScore
			,LongActing
		FROM #Final
		) v
	)
PRINT @VUIDCount
IF @VUIDCount <> 0 
	BEGIN
		EXEC [Log].[Message] 'Error','Duplicate VUID','LookUp.MorphineEquiv could not be published because distinct values do not exist at VUID level for Millennium joins.'
		EXEC [Log].[ExecutionEnd] @Status = 'Error'
		RETURN
	END


EXEC [Maintenance].[PublishTable] 'LookUp.MorphineEquiv_Outpatient_OpioidforPain','#Final';

EXEC [Log].[ExecutionEnd]

END