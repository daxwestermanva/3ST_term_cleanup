
-- =============================================
-- Author:		Rebecca Stephens
-- Create date: 2020-08-03
-- Description:	CPT definitions to be used with CDWWork and CDWWork2
-- Modifications:
	-- 2020-08-03	RAS	Branched from LookUp_CPT and altered code to include Millennium data from CDWWork2
	-- 2020-09-01   PS	altered the code so it more closely mimics current CDS architecture
	-- 2020-11-13	RAS	Removed DISTINCTs from query to create ##LookUp_CPT_Stage.  Added group by to Millenium section to remove unnecessary duplicate SIDs.
	-- 2021-05-14  JJR_SA - Added tag for identifying code to Share in ShareMill
	-- 2021-06-03  JJR_SA - Updated tagging for use in sharing code for ShareMill;adjusted position of ending tag
	-- 2023-01-06  TG - adding HCPCS codes for OTP as provided by Joyce, Vilija R
	-- 2023-01-09  AR - adding HCPCS codes for OTP summary variable
	-- 2024-09-06  TG - Adding Cancer_CPT codes because the existing ones are wrong.
	-- 2024-09-11  TG - Adding Hospice_CPT flag and codes
	-- 2025-03-06  LM - Rename to remove _VM

-- =============================================
CREATE   PROCEDURE [Code].[LookUp_CPT]
AS
BEGIN

DECLARE @TableName VARCHAR(50) = 'CPT'

/*** adding variables from to [LookUp].[ColumnDescriptions]****/
	INSERT INTO [LookUp].[ColumnDescriptions]
	WITH (TABLOCK)
	SELECT DISTINCT
		 Object_ID as TableID
		,a.TableName
		--Name of column from the table
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
				 'CPTName'
				,'Sta3n'
				,'CPTCode'
				,'CPTDescription'
				,'CPTSID'
				,'InactiveFlag'
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
	
	--DECLARE @TableName VARCHAR(50) = 'CPT'

	DECLARE @Columns VARCHAR(Max);

	SELECT @Columns = CASE 
			WHEN @Columns IS NULL
				THEN '0 as ' + T.ColumnName
			ELSE @Columns + ', 0 as ' + T.ColumnName
			END
	FROM  [LookUp].[ColumnDescriptions] AS T
	WHERE T.TableName = @TableName

	DECLARE @Insert AS VARCHAR(4000);

	DROP TABLE IF EXISTS ##LookUp_CPT_Stage
	SET @Insert = '
	SELECT CPTSID
		  ,Sta3n
		  ,CPTName
		  ,CPTDescription
		  ,CPTCode
		  ,InactiveFlag
		  ,' + @Columns + ' 
	INTO ##LookUp_CPT_Stage
	FROM ('
	/*##SHAREMILL BEGIN##*/
	SET @Insert =  @Insert + N'
		SELECT nom.NomenclatureSID as CPTSID
			,200 AS Sta3n
			,MAX(dc.CPTName) as CPTName
			,nom.SourceString as CPTDescription
			,nom.SourceIdentifier as CPTCode
			,nom.InactiveFlag
		FROM [Cerner].[DimNomenclature] nom WITH (NOLOCK)
		LEFT JOIN [Dim].[CPT] dc WITH (NOLOCK) ON nom.SourceIdentifier = dc.CPTCode
		WHERE nom.SourceVocabulary IN (''CPT4'',''HCPCS'')
			AND nom.PrincipleType = ''Procedure''
		GROUP BY nom.NomenclatureSID
				,nom.SourceString 
				,nom.SourceIdentifier
				,nom.InactiveFlag
		UNION ALL
		SELECT CPTSID, Sta3n, CPTName, CPTDescription, CPTCode, InactiveFlag
		FROM [Dim].[CPT] WITH (NOLOCK)'/*##SHAREMILL END##*/
		SET @Insert =  @Insert + N') u'
	EXEC (@Insert);
	 
	--SELECT * FROM ##LookUp_CPT_Stage
	--SELECT COUNT(*),COUNT(DISTINCT CPTSID) FROM ##LookUp_CPT_Stage

/**************************************************************************************************/
/***** Updating variable flags and definitions. ************************/
/**************************************************************************************************/	
--DECLARE @TableName VARCHAR(50) = 'CPT'

	--AntipsychoticDepot
	UPDATE ##LookUp_CPT_Stage
	SET Rx_AntipsychoticDepot_CPT = 1
	WHERE CPTCode IN (
			'J0401'
			--,'J0400'	AF - Removed 1/30 - Short activing per Fresno Feedback
			--,'J3230'  AF  - Removed 1/30 - Short activing per Fresno Feedback
			,'J3080'
			,'J2680'
			,'J1631'
			--,'J1630'	AF - Removed 1/30 - Short activing per Fresno Feedback
			--,'J1970','J2950' removed by SMITREC
			,'S0166'
			,'J2358'
			,'J2426'
			,'C9255'
			,'J3310'
			,'J2794'
			,'S0163'
			,'C9125'
			,'J2330'
			,'J2980'
			,'J3400'
			--,'J3486' AF - Removed 1/30 - Short activing per Fresno Feedback
			,'C9204'
			)
			;

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Long Active Antipsychotic Injection',
		Category = 'MedicationInjection',
		ColumnDescription = 'Codes for injection of long active antipsyphotics'
	WHERE ColumnName = 'Rx_AntipsychoticDepot_CPT'
		AND TableName=@TableName

	--Cancer Therapy
	--NOTE: 2020-08-03 - RAS - This is wrong. Logic does not return anything and this column is not being used in CDS.
	UPDATE ##LookUp_CPT_Stage
	SET Cancer_CPT = 1
	WHERE --CPTCode IN (
			--'94'  --(Chemotherapy)
			--, '330'  --(Chemotherapy)
			--, '431'  --(Chemotherapy)
			--, '904' --(Chemotherapy)
			--, '308' --(Hematology/Oncology)
			--, '316' --(Oncology/Tumor)
			--);
(cptcode like '964%' or (cptcode like '965[0-4]%' and cptname like '%CHEMO%'))
	or
	(cptname like '%radiation%therapy%' or cptname like '%RADIATION%DOSIMETRY%'
	or cptname like '%RADIATION%TX%' or cptname like '%RADIATION%MANAG%' or cptname like 'APPLY%RADIAT%')


	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Cancer therapy',
		Category = 'Cancer therapy',
		ColumnDescription = 'Codes for Cancer therapy includes chemotherapy and oncology visits'
	WHERE ColumnName = 'Cancer_CPT'
		AND TableName=@TableName

--Hospice CPT
	UPDATE ##LookUp_CPT_Stage
	SET Hospice_CPT = 1
	WHERE cptname like '%HOSPICE%' and 
		(
		CPTCode in ('99377','99378','G0065','G0182','G9687','G9718','G9720','G9857','G9858','G9861','S0271','S9126','T2042','T2043')
		or (CPTCode like 'G94%' and CPTName like '%HOSPICE%')
		or (CPTCode like 'M102%' and CPTName like '%HOSPICE%')
		or (CPTCode like 'Q50%' and CPTName like '%HOSPICE%' and CPTCode not in ('Q5001','Q5002','Q5009'))
		)


	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Hospice Care',
		Category = 'Hospice Care',
		ColumnDescription = 'Codes for hospice care'
	WHERE ColumnName = 'Hospice_CPT'
		AND TableName=@TableName



	--Coping skills/Stress Management Training
	UPDATE ##LookUp_CPT_Stage
	SET Psych_Assessment_CPT = 1
	WHERE CPTCode IN (
			'90801'
			,'90802'
			,'90839'
			,'90840'
			,'90791'
			,'90792'
			,'96150'
			,'96151'
			,'H0002'
			,'H0031'
			);

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Coping skills/Stress Management Training',
		Category = 'PsychosocialTreatments',
		ColumnDescription = 'Codes for psychosocial treatment for coping skills/stress management training'
	WHERE ColumnName = 'Psych_Assessment_CPT'
		AND TableName=@TableName

	--Psychotherapy
	UPDATE ##LookUp_CPT_Stage
	SET Psych_Therapy_CPT = 1
	WHERE CPTCode IN (
			'90804'
			,'90805'
			,'90806'
			,'90807'
			,'90808'
			,'90809'
			,'90810'
			,'90811'
			,'90812'
			,'90813'
			,'90814'
			,'90815'
			,'90816'
			,'90817'
			,'90818'
			,'90819'
			,'90820'
			,'90821'
			,'90822'
			,'90823'
			,'90824'
			,'90825'
			,'90826'
			,'90827'
			,'90828'
			,'90829'
			,'90839'
			,'90840'
			,'90845'
			,'90846'
			,'90847'
			,'90849'
			,'90853'
			,'90855'
			,'90857'
			,'96152'
			,'96153'
			,'96154'
			,'96155'
			,'97532'
			,'98960'
			,'98961'
			,'98962'
			,'99401'
			,'99402'
			,'99403'
			,'99404'
			,'99411'
			,'99412'
			,'99510'
			,'4306F'
			,'H0004'
			,'H0017'
			,'H0018'
			,'H0019'
			,'H0023'
			,'H0024'
			,'H0025'
			,'H0030'
			,'H0032'
			,'H0035'
			,'H0046'
			,'H2001'
			,'H2014'
			,'H2012'
			,'H2017'
			,'H2018'
			,'H2019'
			,'H2020'
			,'H2027'
			,'G0177'
			,'S9454'
			,'T2048'
			,'90832'
			,'90833'
			,'90834'
			,'90836'
			,'90837'
			,'90838'
			,'90875'
			,'90853'
			);

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Psychotherapy Procedures',
		Category = 'PsychosocialTreatments',
		ColumnDescription = 'Codes for psychotherapy procedures'
	WHERE ColumnName = 'Psych_Therapy_CPT'
		AND TableName=@TableName

	--Physical Therapy
	UPDATE ##LookUp_CPT_Stage
	SET RM_PhysicalTherapy_CPT = 1
	WHERE CPTCode IN (
			'95831'
			,'95832'
			,'95833'
			,'95834'
			,'95851'
			,'95852'
			,'96000'
			,'96125'
			,'97001'
			,'97002'
			,'97036'
			,'97110'
			,'97112'
			,'97113'
			,'97116'
			,'97140'
			,'97150'
			,'97530'
			,'97533'
			,'97750'
			,'97799'
			,'G0151'
			,'G0237'
			,'G0238'
			);

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Physical Therapy',
		Category = 'RehabilitationMedicine',
		ColumnDescription = 'Codes for physical therapy procedures'
	WHERE ColumnName = 'RM_PhysicalTherapy_CPT'
		AND TableName=@TableName

	UPDATE ##LookUp_CPT_Stage
	SET RM_ChiropracticCare_CPT = 1
	WHERE CPTCode IN (
			'98940'
			,'98941'
			,'98942'
			,'98943'
			);

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Chiropractic Care',
		Category = 'RehabilitationMedicine',
		ColumnDescription = 'Codes for chiropractice care procedures'
	WHERE ColumnName = 'RM_ChiropracticCare_CPT'
		AND TableName=@TableName

	--Active Therapies
	UPDATE ##LookUp_CPT_Stage
	SET RM_ActiveTherapies_CPT = 1
	WHERE CPTCode IN (
			'97005'
			,'97006'
			,'H2032'
			,'G0176'
			,'S9449'
			,'S9451'
			,'S9970'
			);

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Active Therapies',
		Category = 'RehabilitationMedicine',
		ColumnDescription = 'Codes for active therapy procedures'
	WHERE ColumnName = 'RM_ActiveTherapies_CPT'
		AND TableName=@TableName

	--Occupational Therapy
	UPDATE ##LookUp_CPT_Stage
	SET RM_OccupationalTherapy_CPT = 1
	WHERE CPTCode IN (
			'97003'
			,'97004'
			,'97535'
			,'97537'
			,'97545'
			,'97546'
			,'97755'
			,'G0152'
			);

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Occupational Therapy',
	Category = 'RehabilitationMedicine',
	ColumnDescription = 'Codes for occupational therapy procedures'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'RM_OccupationalTherapy_CPT'
		AND TableName=@TableName

	--Specialty Therapy
	UPDATE ##LookUp_CPT_Stage
	SET RM_SpecialtyTherapy_CPT = 1
	WHERE CPTCode IN (
			'97542'
			,'97760'
			,'97761'
			,'97762'
			);

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Specialty Therapy',
		Category = 'RehabilitationMedicine',
		ColumnDescription = 'Codes for specialty therapy procedures'
	WHERE ColumnName = 'RM_SpecialtyTherapy_CPT'
		AND TableName=@TableName

	UPDATE ##LookUp_CPT_Stage
	SET RM_OtherTherapy_CPT = 1
	WHERE CPTCode IN (
		'99456'
		,'G0128'
		,'V57'
			);

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Other Therapy',
	Category = 'RehabilitationMedicine',
	ColumnDescription = 'Codes for other therapy procedures'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'RM_OtherTherapy_CPT'
		AND TableName=@TableName

	UPDATE ##LookUp_CPT_Stage
	SET Detox_CPT = 1
	WHERE CPTCode IN ('H0008','H0009','H0010','H0011','H0012','H0013','H0014') 

	UPDATE ##LookUp_CPT_Stage
	SET Rx_MedManagement_CPT = 1
	WHERE CPTCode IN (
		'99605'
		,'99606'
		,'99607'
		,'90862'
		,'1160F'
		);

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Medication Reconciliation',
	Category = 'MedicationReconciliation',
	ColumnDescription = 'Codes for medication reconciliation procedures'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'Rx_MedManagement_CPT'
		AND TableName=@TableName

	UPDATE ##LookUp_CPT_Stage
	SET Rx_NaltrexoneDepot_CPT = 1
	WHERE CPTCode = 'J2315'
		;

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Naltrexone depot',
		Category = 'DepotMedication',
		ColumnDescription = 'Code for naltrexone depot injection'
	WHERE ColumnName = 'Rx_NaltrexoneDepot_CPT'
		AND TableName=@TableName

	--CAM Therapy
	--Note that there is a list of CPT codes that only qualify if they are accompanied
	--by a qualifying stop code. We are already capturing the parent stop codes, so 
	--it is not necessary to include these special cases in the list below. For documentation,
	--they are listed here:
			--96156 Health behavior reassessment
			--96158 Health behavior intervention, individual, initial 30m
			--96159 Health behavior intervention, individual, add. 15m
			--96164 Health behavior intervention, group, initial 30m
			--96165 Health behavior intervention, group, add. 15m
			--96167 Health behavior intervetion, family w/ patient, initial 30m
			--96168 Health behavior intervetion, family w/ patient, add. 15m
			--96170 Health behavior intervetion, family no patient, initial 30m
			--96171 Health behavior intervetion, family no patient, add. 15m
			--97100 Therapeutic exercises 15m
			--97112 Neuromuscular reeducation 15m
			--97150 Group therapeutic activities
			--97530 Therapeutic activities
			--97535 Self-care management training
			--97802 Initial assessment medical nutrition 15m
			--97803 Follow up medical nutrition 15m
			--97804 Medical nutrition group 30m
			--98960 Self-management education 1pt
			--98961 Self-management education 2-4pt
			--98962 Self-management education 5-8pt
			--99078 Health education
			--99199 Special service, procedure, or report
			--99202-99205 Office outpatient visit new
			--99212-99215 Office outpatient visit established
			--99401-99404 Preventive counseling
			--99406-99407 Behavioral change, smoking
			--99408 AUDIT/DAST
			--99411-99412 Preventive counseling
			--99499 Unlisted evaluation and management service
			--E0746 Electromyography biofeedback device
			--G0270-G0271 Medical nutrition therapy reassessment
			--G0175 Scheduled interdisciplinary team
			--G0176 Music/art therapy for mental health
			--H2032 Activity therapy 15m
			--S5190 Wellness
			--S9452 Nutrition classes, non-physician
			--S9445 Patient education, individual
			--S9446 Patient education, group
			
	UPDATE ##LookUp_CPT_Stage
	SET CAM_CPT = 1
	WHERE CPTCode IN (
		    '05912T', ---	Health and well-being coaching, individual, initial
			'05913T', ---	Health and well-being coaching, individual, followup
			'05914T', ---	Health and well-being coaching group
			'90875', ---	Psychophysiological therapy incorporating biofeedback 30m
			'90876', ---	Psychophysiological therapy incorporating biofeedback 45m
			'90880', ---	Hypnotherapy
			'90901', ---	Biofeedback training any method
			'90912', ---	Biofeedback training, perineal muscles, anorectal or urethral sphincter, including EMG and/or manometry init. 15m
			'90913', ---	Biofeedback training, perineal muscles, anorectal or urethral sphincter, including EMG and/or manometry add. 15m
			'97124', ---	Massage Therapy 
			'97140', ---	Manual Therapy 1/> regions
			'97799', ---	Physical medicine procedure
			'97810', ---	Acupunct w/o Stimul 15 min
			'97811', ---	Acupunct w/o Stimul Addl 15 m
			'97813', ---	Acupunct w/ Stimul 15 min
			'97814', ---	Acupunct w/ Electrical Stim
			'98925', ---	Osteopathic manipulation 1-2 regions
			'98926', ---	Osteopathic manipulation 3-4 regions
			'98927', ---	Osteopathic manipulation 5-6 regions
			'98928', ---	Osteopathic manipulation 7-8 regions
			'98929', ---	Osteopathic manipulation 9-10 regions
			'98940', ---	Chiropractic manipulation 1-2 regions
			'98941', ---	Chiropractic manipulation 3-4 regions
			'98942', ---	Chiropractic spinal, 5 regions
			'98943', ---	Chiropractic extraspinal, 1 or more regions
			'S8930', ---	E-STIM AUR ACP PNT EA 15 min 1-1 PT
			'S8940', ---	Equestrian/hippotherapy
			'S9451', ---	Exercise class, non-physician
			'S9454'  ---	Stress management class, non-physician
			);

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'CAM therapy',
		Category = 'CAM therapy',
		ColumnDescription = 'Codes for Complementary and Alternative Medicine'
	WHERE ColumnName = 'CAM_CPT'
		AND TableName=@TableName

-- Updating the newly added columns
		UPDATE ##LookUp_CPT_Stage
	SET Methadone_OTP_HCPCS = 1
	WHERE CPTCode IN ('G2067','G2078','H0020','J1230','S0109');

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Methadone OTP',
		Category = 'Methadone OTP',
		ColumnDescription = 'HCPCS Codes for Methadone Opioid Treatment Program'
	WHERE ColumnName = 'Methadone_OTP_HCPCS'
		AND TableName=@TableName

		UPDATE ##LookUp_CPT_Stage
	SET Buprenorphine_OTP_HCPCS = 1
	WHERE CPTCode IN ('G2068','G2069','G2070','G2071','G2072','G2079','J0571','J0572',
	                  'J0573','J0574','J0575','J0592');

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Buprenorphine OTP',
		Category = 'Buprenorphine OTP',
		ColumnDescription = 'HCPCS Codes for Buprenorphine Opioid Treatment Program'
	WHERE ColumnName = 'Buprenorphine_OTP_HCPCS'
		AND TableName=@TableName

		UPDATE ##LookUp_CPT_Stage
	SET Naltrexone_OTP_HCPCS = 1
	WHERE CPTCode IN ('G2073','J2315');

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Naltrexone OTP',
		Category = 'Naltrexone OTP',
		ColumnDescription = 'HCPCS Codes for Naltrexone Opioid Treatment Program'
	WHERE ColumnName = 'Naltrexone_OTP_HCPCS'
		AND TableName=@TableName
    
    
   ---any drug spec OTP  plus non spec codes
		UPDATE ##LookUp_CPT_Stage
	SET OTP_HCPCS = 1
	WHERE  Naltrexone_OTP_HCPCS = 1 or Methadone_OTP_HCPCS = 1 or Buprenorphine_OTP_HCPCS =1
  or CPTCode in ('G1028','G2074','G2075','G2076','G2077','G2080')
  
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Opioid Treatment Program',
		Category = 'Opioid Treatment',
		ColumnDescription = 'HCPCS Codes for Opioid Treatment Program'
	WHERE ColumnName = 'OTP_HCPCS'
		AND TableName=@TableName



EXEC [Maintenance].[PublishTable] 'LookUp.CPT', '##LookUp_CPT_Stage'

END
;