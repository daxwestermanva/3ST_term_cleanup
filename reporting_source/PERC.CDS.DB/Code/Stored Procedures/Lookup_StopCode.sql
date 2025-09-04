
-- =============================================
-- Author:		<Tigran Avoundjian>
-- Create date: <1/14/2015>
-- Description:	<Pivoted Stop Code Lookup crosswalk>
-- Updates:
--	12/7/15		ST - Added Emergency Room stop
--	2019-02-15	Jason Bacani - Refactored to use [Maintenance].[PublishTable]; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
--	2020-04-20	RAS - Moved publish table to end of script - changed updates to update temp table instead of permanent table.
--	2020-09-21	RAS - Removed 499 from Reach_MH_Stop. Code ENVIRON HEALTH REG EXAM and I think this was a mistake in using "BETWEEN"
--	2021-06-24	LM - Added 555 and 556 to MHRecent_Stop and removed from OtherRecent_Stop
--	2022-04-13	LM - Added peer support stop code
--	2022-05-10	LM - Removed unused columns; added telephone MH; formatting and cleanup
--	2022-06-13	LM - Cerner overlay for stop codes other than MH
--	2022-09-19	LM - Replaced MillCDS view with Cerner synonym
--  2023-05-10  CW - Updating SUDTx_NoDxReq_Stop variable; including 545 now
--  20241119    TG - Adding RRTP stop codes to SUD Treatment credit
--	2025-05-06	LM	Renamed to remove _VM
-- =============================================
CREATE PROCEDURE [Code].[Lookup_StopCode]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.Lookup_StopCode', @Description = 'Execution of Code.Lookup_StopCode SP'

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
		WHERE b.Name = 'StopCode'
			AND a.Name NOT IN (
				'StopCodeSID'
				,'Sta3n'
				,'StopCodeName'
				,'StopCode'
				,'InactiveDate'
				--'InactiveFlag'
				)
			AND a.Name NOT IN (
				SELECT DISTINCT ColumnName
				FROM [LookUp].[ColumnDescriptions]
				WHERE TableName = 'StopCode'
				) --order by COLUMN_NAME
		) AS a

    --remove any deleted columns
	DELETE [LookUp].[ColumnDescriptions]
	WHERE TableName = 'StopCode' 
		AND ColumnName NOT IN (
			SELECT a.name as ColumnName
			FROM  sys.columns as a 
			INNER JOIN sys.tables as b on  a.object_id = b.object_id
			WHERE b.Name = 'StopCode'
			)
		;
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
	WHERE T.TableName = 'StopCode';

	DECLARE @Insert AS VARCHAR(4000);;

	DROP TABLE IF EXISTS ##LookUp_StopCode_Stage
	SET @Insert = '
	SELECT [StopCodeSID]
		  ,[Sta3n]
		  ,[StopCodeName]
		  ,CAST([StopCode] AS VARCHAR) AS StopCode
		  ,[InactiveDateTime] AS InactiveDate
		  ,'+ @Columns + ' 
	INTO ##LookUp_StopCode_Stage
	FROM [Dim].[StopCode]
	UNION ALL
	SELECT [BillTransactionAliasSID]
		  ,[Sta3n]=200
		  ,[StopCodeName]=AliasDescription
		  ,[AliasName]
		  ,InactiveDate=CASE WHEN [EndEffectiveDateTime] < getdate() THEN [EndEffectiveDateTime] ELSE NULL END 
		  ,'+ @Columns + ' 
	FROM [Cerner].[DimStopCode]
	'
	EXECUTE (@Insert);

---------------------------------------------------------------------------------------------------
/****Updating variable flags and adding definitions****/
---------------------------------------------------------------------------------------------------

	/**************OAT Stop Code********/
	UPDATE ##LookUp_StopCode_Stage
	SET OAT_Stop = 1
	WHERE StopCode = '523' AND Sta3n > 200
	--VistA only; use ActivityTypes for Cerner MH

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'OAT clinic',
	Category = 'OAT clinic',
	ColumnDescription = 'OAT clinic, SUD treatment ',
	DefinitionOwner = 'OMHSP'
	WHERE ColumnName = 'OAT'

	/**************INCARCERATED VETERANS RE-ENTRY [smallint] null********/
	UPDATE ##LookUp_StopCode_Stage
	SET Incarcerated_Stop = 1
	WHERE StopCode = '591' AND Sta3n > 200
	--VistA only; use ActivityTypes for Cerner MH

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Incarcerated',
	Category = 'Incarcerated',
	ColumnDescription = 'Incarceration Stop Code',
	DefinitionOwner = 'Healthcare for Re-Entry Veterans by Jessica Blue-Howells'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'Incarcerated_Stop'

/**************VETERANS JUSTICE OUTREACH [smallint] null********/
	UPDATE ##LookUp_StopCode_Stage
	SET Justice_Outreach_Stop = 1
	WHERE StopCode = '592' AND Sta3n > 200
	--VistA only; use ActivityTypes for Cerner MH

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'JUSTICE OUTREACH (incarcerated)',
	Category = 'JUSTICE OUTREACH, incarcerated',
	ColumnDescription = 'JUSTICE OUTREACH Stop Code, incarcerated ',
	DefinitionOwner = 'Healthcare for Re-Entry Veterans by Jessica Blue-Howells'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'Justice_Outreach_Stop'

		/*********** GeneralMentalHealth stopcode**************/

	UPDATE ##LookUp_StopCode_Stage
	SET GeneralMentalHealth_Stop = 1
	WHERE StopCode in (
		'502','509',
		'510','512','516',
		'525',
		'540',
		'550','557','558',
		'561','562',
		'571','572','576','577'
		) AND Sta3n > 200
		--VistA only; use ActivityTypes for Cerner MH
		--Cerner equivalent stop codes, in case we ever switch to them: '51A','51B','52B')

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Gen MH Outpatient',
	Category = 'Mental Health',
	ColumnDescription = 'General Mental Health for PDSI defined by NEPEC'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'GeneralMentalHealth_Stop'


	
	
				/*********** PrimaryCare_PDSI stopcode**************/

		UPDATE ##LookUp_StopCode_Stage
	SET PrimaryCare_PDSI_Stop = 1
	WHERE StopCode IN ('301','322','342','348') --VistA and Cerner
		OR (StopCode IN ('534','539') AND Sta3n > 200) --VistA only


	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Primary Care',
	Category = 'Primary Care',
	ColumnDescription = 'Primary Care for PDSI defined by NEPEC'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'PrimaryCare_PDSI_Stop'

	/*********** Education stopcode**************/

	UPDATE ##LookUp_StopCode_Stage
	SET ORM_OS_Education_Stop = 1
	WHERE StopCode in ('721','722','723','724') --VistA only; these stopcodes don't exist in Cerner

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Opioid Safety Initiative Education',
	Category = 'ORM_OS_Education',
	ColumnDescription = 'Opioid Safety Education'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'ORM_OS_Education_Stop'


	

			  /*************CIH_Stop (Complimentary and Integrative Health) *********/
	UPDATE ##LookUp_StopCode_Stage
	SET ORM_CIH_Stop = 1
	WHERE StopCode in ('139','159','436') --Cerner and VistA

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Complimentary and Integrative Health Encounter',
	Category = 'ORM_CIH',
	ColumnDescription = 'Complimentary and Integrative Health as defined by MCAO Program Office'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'ORM_CIH_Stop'



		  /*************Reach_Homeless_Stop*********/
	UPDATE ##LookUp_StopCode_Stage
	SET Reach_Homeless_Stop = 1
	WHERE StopCode in ('504','507','508','511','522','528','529','530','555','556')
		AND Sta3n > 200  --VistA only; use ActivityTypes for Cerner MH

	-- updated based on Michal Wilson recommendations email 6/15/17, updated 6/30/17

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Mental Health Encounter',
	Category = 'Reach_MH',
	ColumnDescription = 'Homeless Encounter as defined by Perceptive Reach (SMITREC)'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'Reach_Homeless_Stop'


	  /*************Reach_EmergencyRoom_Stop [smallint] null*********/
	UPDATE ##LookUp_StopCode_Stage
	SET Reach_EmergencyRoom_Stop = 1
	WHERE StopCode IN ('130','297') --Cerner and VistA

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Emergency Room Encounter',
	Category = 'Reach_EmergencyRoom',
	ColumnDescription = 'Emergency Room Encounter as defined by Perceptive Reach (SMITREC)'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'Reach_EmergencyRoom_Stop'

	  /*************Reach_MH_Stop [smallint] null*********/
	UPDATE ##LookUp_StopCode_Stage
	SET Reach_MH_Stop = 1
	WHERE StopCode IN ('500','501','502','503','504','505','506','507','508','509'
	,'510','511','512','513','514','515','516','517','518','519'
	,'520','521','522','523','524','525','526','527','528','529'
	,'530','531','532','533','534','535','536','537','538','539'
	,'540','541','542','543','544','545','546','547','548','549'
	,'550','551','552','553','554','555','556','557','558','559'
	,'560','561','562','563','564','565','566','567','568','569'
	,'570','571','572','573','574','575','576','577','578','579'
	,'580','581','582','583','584','585','586','587','588','589'
	,'590','591','592','593','594','595','596','597','598','599') 
	AND Sta3n > 200  --VistA only; use ActivityTypes for Cerner MH
	
	--Cerner equivalent stop codes, in case we ever switch to them: ('51A','51B','52A','52B','53A','53B','54A','54B','55A','55B','56A','57A','58A','59A')
	
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Mental Health Encounter',
	Category = 'Reach_MH',
	ColumnDescription = 'Mental Health Encounter as defined by Perceptive Reach (SMITREC)'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'Reach_MH_Stop'


  /*************SUDTx_NoDxReq_Stop [smallint] null*********/
	UPDATE ##LookUp_StopCode_Stage
	SET SUDTx_NoDxReq_Stop = 1
	WHERE StopCode IN (
			 '513','514','519'
			,'523'
			,'545' --STORM applies CPT rules for credit (per JT, contact must be >11 min for credit)
			,'547','548','560'
			)
		AND Sta3n > 200 --VistA only; use ActivityTypes for Cerner MH

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'SUD Outpatient',
	Category = 'SUDTreatments',
	ColumnDescription = 'Stop codes for SUD treatment, no diagnosis required'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'SUDTx_NoDxReq_Stop'

	/*************SUDTx_DxReq_Stop [smallint] null*********/
	UPDATE ##LookUp_StopCode_Stage
	SET SUDTx_DxReq_Stop = 1
	WHERE StopCode IN (
			 '502','503','505','506','509'
			,'510','512','516'
			,'522','524','525','527','528','529'
			,'530','531','532','533','534','535','536','537','538'
			,'540','542','546'
			,'550','552','553','554','557','558','559'
			,'561','562','563','564','565','566','567','568','569'
			,'570','571','572','573','574','575','576','577','578','579'
			,'580','581','582','583','584'
			,'586','586','587','597','598','598','599','588','594','595' -- Added RRTP stop code at JT's guidance (2024-11-19)
	)
	AND Sta3n > 200  --VistA only; use ActivityTypes for Cerner MH
	
	--Cerner equivalent stop codes, in case we ever switch to them: ('51A','51B','52B','53B','54A','55A','56A','57A','58A')

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'SUD Treatment - SUD Dx Required',
	Category = 'SUDTreatments',
	ColumnDescription = 'Stop codes for SUD treatment, SUD diagnosis required'
	--StopCodePrimaryOrSecondaryFlag = 'Primary'
	WHERE ColumnName = 'SUDTx_DxReq_Stop'


	/*************************Hospice*****/
	UPDATE ##LookUp_StopCode_Stage
	SET Hospice_Stop = 1
	WHERE StopCode = '351' --Cerner and VistA

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Hospice',
	Category = 'Hospice',
	ColumnDescription = 'Stop code for hospice care'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'Hospice_Stop'

	/*********************EmergencyRoom**********ST 12.7.15**/

	UPDATE ##LookUp_StopCode_Stage
	SET EmergencyRoom_Stop = 1
	WHERE  StopCode IN ('102','130','131')  --VistA and Cerner

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Emergency Room',
	Category = 'Emergency Room',
	ColumnDescription = 'Stop code for emergency room or urgent care'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'EmergencyRoom_Stop'

	
	/*********************PeerSupport**********/

	UPDATE ##LookUp_StopCode_Stage
	SET PeerSupport_Stop = 1
	WHERE StopCode = '183'

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Peer Support',
	Category = 'Peer Support',
	ColumnDescription = 'Stop code for peer support'
	--StopCodePrimaryOrSecondaryFlag = 'Secondary'
	WHERE ColumnName = 'PeerSupport_Stop'

	/**************RM_PhysicalTherapy_Stop [smallint] null*****/
	
	UPDATE ##LookUp_StopCode_Stage
	SET RM_PhysicalTherapy_Stop = 1
	WHERE StopCode IN ('177','201','205') --VistA and Cerner

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Physical Therapy',
	Category = 'RehabilitationMedicine',
	ColumnDescription = 'Stop codes for physical therapy visits'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'RM_PhysicalTherapy_Stop'

    /**************Homeless_Stop [smallint] null********/
	UPDATE ##LookUp_StopCode_Stage
	SET MHOC_Homeless_Stop = 1
	WHERE StopCode IN (
		 '504','507','508'
		,'511'
		,'522','528','529'
		,'530'
		,'555','556'
		,'590','591','592'
	) AND Sta3n > 200 --VistA only; use ActivityType for Cerner MH

--222 with secondary stop 529
--527 with secondary stop 511,522,529,591 or 592
--568 with secondary stop 529
--674 with secondary stop 555

--Cerner equivalent stop codes, in case we ever switch to them: ('52A','54A','55A','59A)

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'MHOC Homeless',
	Category = 'MHOC_Homeless',
	ColumnDescription = 'Stop codes for MHOC homeless visits'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'MHOC_Homeless_Stop'

	/**************RM_ChiropracticCare_Stop [smallint] null********/
	UPDATE ##LookUp_StopCode_Stage
	SET RM_ChiropracticCare_Stop = 1
	WHERE StopCode = '436' --Cerner and VistA
	
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Chiropractic Care',
	Category = 'RehabilitationMedicine',
	ColumnDescription = 'Stop codes for chiropractic care visits'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'RM_ChiropracticCare_Stop'

	/**************RM_ActiveTherapies_Stop [smallint] null********/
	UPDATE ##LookUp_StopCode_Stage
	SET RM_ActiveTherapies_Stop = 1
	WHERE StopCode IN ('202','214','372','373','33A') 

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Active Therapies',
	Category = 'RehabilitationMedicine',
	ColumnDescription = 'Stop codes for active therapies visits'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'RM_ActiveTherapies_Stop'

	/**************RM_OccupationalTherapy_Stop [smallint] null********/
	UPDATE ##LookUp_StopCode_Stage
	SET RM_OccupationalTherapy_Stop = 1
	WHERE StopCode IN ('206','207','208','213','222','223','228','230') 

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Occupational Therapy',
	Category = 'RehabilitationMedicine',
	ColumnDescription = 'Stop codes for occupational therapy visits'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'RM_OccupationalTherapy_Stop'

	/**************RM_SpecialtyTherapy_Stop [smallint] null********/
	UPDATE ##LookUp_StopCode_Stage
	SET RM_SpecialtyTherapy_Stop = 1
	WHERE StopCode IN (
		 '195','196','197','198','199'
		,'210','211','215','219'
		,'295'
		,'417','418'
		,'17A','18A','22A','42A')  --VistA and Cerner


	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Specialty Therapy',
	Category = 'RehabilitationMedicine',
	ColumnDescription = 'Stop codes for specialty therapy visits'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'RM_SpecialtyTherapy_Stop'

	/**************RM_OtherTherapy_Stop [smallint] null********/
	UPDATE ##LookUp_StopCode_Stage
	SET RM_OtherTherapy_Stop = 1
	WHERE StopCode IN ('216','296') --VistA and Cerner

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Other Therapy',
	Category = 'RehabilitationMedicine',
	ColumnDescription = 'Stop codes for other rehabilitation medicine therapy visits'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'RM_OtherTherapy_Stop'

	/**************RM_PainClinic_Stop [smallint] null********/
	UPDATE ##LookUp_StopCode_Stage
	SET RM_PainClinic_Stop = 1
	WHERE StopCode IN ('420','420C'); --Cerner and VistA

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Pain Clinic',
	Category = 'RehabilitationMedicine',
	ColumnDescription = 'Stop codes for pain clinic visits'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'RM_PainClinic_Stop'

			/****************************Medication reconciliation *****************/

	--,Rx_MedManagement_Stop [smallint] null
	UPDATE ##LookUp_StopCode_Stage
	SET Rx_MedManagement_Stop = 1
	WHERE StopCode IN ('160','176') --VistA and Cerner
	;

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Medication Reconciliation',
	Category = 'MedicationReconciliation',
	ColumnDescription = 'Stop codes for medication reconcilation visits'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'Rx_MedManagement_Stop';

			/****************************OUD therapy diagnosis required at the visit*****************/

	--,OUDTx_DxReq_Stop [smallint] null
	UPDATE ##LookUp_StopCode_Stage
	SET OUDTx_DxReq_Stop = 1
	WHERE StopCode = '523' AND Sta3n > 200 --VistA only; use ActivityType for Cerner MH


	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'OUD Treatment - OUD Dx Required',
	Category = 'OUDTreatments',
	ColumnDescription = 'Stop codes for OUD treatment, OUD diagnosis required'
	--StopCodePrimaryOrSecondaryFlag = 'Primary'
	WHERE ColumnName = 'OUDTx_DxReq_Stop';

		/****************************ORM timely appointment *****************/

	--,ORM_TimelyAppt_Stop [smallint] null
	UPDATE ##LookUp_StopCode_Stage
	SET ORM_TimelyAppt_Stop = 1
	WHERE StopCode IN (
				'118','119'
				,'120','121','125'
				,'135','136','137'
				,'142','143','145','147','148'
				,'156','157','158','159'
				,'160','162'
				,'170','171','172','173','174','176','177','178','179'
				,'180','181','182','183','184','185','186','187','188'
				,'190','195','196','197','198','199'
				,'201','205','206','207','208'
				,'210','211','213','214','215','216'
				,'221','222','224','225'
				,'230','231','240'
				,'250'
				,'290','291','292','293','295','296'
				,'301','302','303','303','304','305','306','307','308','309'
				,'310','312','313','314','315','316','317','318','319'
				,'320','321','321C','322','323','324','325','326','327','328','329','329C'
				,'330','331','332','335','336','337','338','339'
				,'340','342','345','346','347','348','349'
				,'350','351','352','353','354'
				,'372','373','394'
				,'401','402','403','404','405','406','407','408','409'
				,'410','411','412','413','414','415','416','417','418','419'
				,'420','420C','421','424','425','426','427','427C'
				,'431','432','433','433','434','434C','435'
				,'441','443'
				,'457','490'
				,'602','603','604','606','607','608'
				,'610','611'
				,'642','644','645','646','647','648'
				,'651','652','653','656','658'
				,'673'
				,'720'
				,'12A','14A','15A','16A','17A','18A'
				,'22A'
				,'31A','32A','33A'
				,'41A','42A','44A'
				,'61A','62A'
			)
		OR (StopCode IN ('502','503','505','506','509'
				,'510','512','513','514','516','519'
				,'523','524','525','527','528','529'
				,'531','533','534','538','539'
				,'540','542','545','546','547','548'
				,'550','552','553','554','557','558'
				,'560','561','562','564','565','566','567','568'
				,'571','572','576','577','579'
				,'580','582','583','584','586','587','588'
				,'593','595','596','597','598','599'	
		) AND Sta3n > 200
			)
		;
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'ORM Timely Appointment',
	Category = 'ORM',
	ColumnDescription = 'Stop codes for ORM Timely Appointment'
	--StopCodePrimaryOrSecondaryFlag = 'Primary'
	WHERE ColumnName = 'ORM_TimelyAppt_Stop';

	;
	/************* AnyStopCode(PastAppt-Excludes Emergency Dept and Urgent Care*********/
	UPDATE ##LookUp_StopCode_Stage
	SET Any_Stop = 1
	WHERE StopCode NOT IN ('0','130','131'
		,'850','853','854','855','856','856','857','858','859','861'
		,'CBIAR','PRO','REUSE') 


			;
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Any Appointment'
		,Category = 'AnyAppointment'
		,ColumnDescription = 'AnyAppointment'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'Any_Stop'

	;
	/************* ClinRelevantStopCode*********/
	UPDATE ##LookUp_StopCode_Stage
	SET ClinRelevant_Stop = 1
	WHERE StopCode IN (
			 '118','119'
			,'120','121','125'
			,'135','136','137'
			,'142','143','145','147','148'
			,'156','157','158','159'
			,'160','162'
			,'170','171','172','173','174','176','177','178','179'
			,'180','181','182','183','184','185','186','187','188'
			,'190','195','196','197','198','199'
			,'201','205','206','207','208'
			,'210','211','213','214','215','216'
			,'221','222','224','225'
			,'230','231'
			,'240'
			,'250'
			,'290','291','292','293','295','296'
			,'301','302','303','304','305','306','307','308','309'
			,'310','312','313','314','315','316','317','318','319'
			,'320','321','322','323','324','325','326','327','328','329'
			,'321C','329C'
			,'330','331','332','335','336','337','338','339'
			,'340','342','345','346','347','348','349'
			,'350','351','352','353','354'
			,'372','373'
			,'394'
			,'401','402','403','404','405','406','407','408','409'
			,'410','411','412','413','414','415','416','417','418','419'
			,'420','420C','421','424','425','426','427','427C'
			,'431','432','433','434','434C','435'
			,'441','443'
			,'457'
			,'490'
			,'602','603','604','606','607','608'
			,'610','611'
			,'642','644','645','646','647','648'
			,'651','652','653','656','658'
			,'673'
			,'720'
			,'12A','14A','15A','16A','17A','18A'
			,'22A'
			,'31A','32A','33A'
			,'41A','42A','44A'
			,'61A','62A'
			)
		OR 
		(StopCode IN ('502','503','505','506','509'
			,'510','512','513','514','516','519'
			,'523','524','525','527','528','529'
			,'531','533','534','538','539'
			,'540','542','545','546','547','548'
			,'550','552','553','554','557','558'
			,'560','561','562','564','565','566','567','568'
			,'571','572','576','577','579'
			,'580','582','583','584','586','587','588'
			,'593','595','596','597','598','599')
			AND Sta3n > 200
			)

		;

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Any Clinical Appointment'
		,Category = 'ClinRelevant'
		,ColumnDescription = 'ClinRelevant'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'ClinRelevant_Stop'
	;
	/************* PCStopCode*********/
	UPDATE ##LookUp_StopCode_Stage
	SET PC_Stop = 1
	WHERE StopCode IN ('170','171','172','178','182','318','322','323','326','338','342','348','350','14A','32A')



	;
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Primary Care Appointment'
		,Category = 'PC'
		,ColumnDescription = 'PC'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'PC_Stop'

	;
	/************* PainStopCode*********/
	UPDATE ##LookUp_StopCode_Stage
	SET Pain_Stop = 1
	WHERE StopCode IN ('420','420C')

	;
	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Specialty Pain'
		,Category = 'Pain'
		,ColumnDescription = 'Pain'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'Pain_Stop'

	;
	/************* OtherStopCode*********/
	UPDATE ##LookUp_StopCode_Stage
	SET Other_Stop = 1
	WHERE StopCode NOT IN (
			--Emergency Department
			'130','131'
			--Primary care
			,'323'
			,'32A' --Cerner PC
			--Pain
			,'420' 
			,'420C'
			--MHOC_MentalHealth
			,'156','157','292'
			,'502','503','505','506','509'
			,'510','512','513','514','516','519'
			,'523','524','525','527'
			,'531','532','533','534','535','536','537','538','539'
			,'540','542','545','546','547','548'
			,'550','552','553','554','557','558','559' 
			,'560','561','562','563','564','565','566','567','568'
			,'571','572','573','574','575','576','577','578','579'
			,'580','581','582','583','584','586','587','588','589'
			,'593','594','595','596','597','598','599'
			,'713'
			--MHOC_Homeless
			,'504','507','508','511'
			,'522','528','529','530'
			,'555','556','590','591','592'
			--Cerner MH
			,'51A','51B','52A','52B','53A','53B','54A','54B','55A','55B','56A','57A','58A','59A'
			--Cerner other
			,'850','853','854','855','856','856','857','858','859','861'
			,'CBIAR','PRO','REUSE'
			) 
			;


	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Other'
		,Category = 'Other'
		,ColumnDescription = 'All stop codes not for Emergency, Primary Care, Pain, Mental Health, or Homeless clinics'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'Other_Stop'
	;

	/*************Cancer Stop Code**************/
	UPDATE ##LookUp_StopCode_Stage
	SET Cancer_Stop = 1
	WHERE stopcode in ('94', '330', '431', '904' /*Chemotherapy*/, '308'/*Hematology/Oncology*/, '316'/*Oncology/Tumor*/)

		UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Cancer',
	Category = 'Cancer',
	ColumnDescription = 'Stop codes for Cancer'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'Cancer_Stop'


	/*************MHOC Mental Health**************/
	UPDATE ##LookUp_StopCode_Stage
	SET MHOC_MentalHealth_Stop = 1
	WHERE StopCode in ('156','157', --MHOC_HBPC_Stop
						'502','509','510','550','557','558', --MHOC_GeneralMentalHealth_Stop
						'516','519','525','540','542','561','562','580','581', --MHOC_PTSD_Stop 
						'513','514','523','545','547','548','560', --MHOC_SUD_Stop
						'535','536','568','573','574','575', --MHOC_TSES_Stop
						'582','583','584', --MHOC_PRRC_Stop
						'546','552','567', --MHOC_MHICM_Stop
						'534','539', --MHOC_PCMHI_Stop
						'586','587','588','593','594','595','596','597','598','599', --MHOC_Residential_Stop
						'292','503','505','506','512','524','527','531','532','533','537','538','553','554','559','563','564','565',
						'566','571','572','576','577','578','579','589','713') --MHOC_OtherMentalHealth_Stop
				AND Sta3n > 200

		--Cerner equivalent stop codes, in case we ever switch to them: ('51A','51B','52B','53A','53B','54B','55B','56A','57A','58A')

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'MHOC Mental Health',
	Category = 'MHOC_MentalHealth',
	ColumnDescription = 'Stop codes for Mental Health defined by MHOC'
	--StopCodePrimaryOrSecondaryFlag = 'Both'
	WHERE ColumnName = 'MHOC_MentalHealth_Stop'


	/*************Telephone Mental Health/Homeless**************/
	UPDATE ##LookUp_StopCode_Stage
	SET Telephone_MH_Stop = 1
	WHERE stopcode in (
			 '527','528'
			,'530','536','537'
			,'542','545','546'
			,'579','584','597')
			AND Sta3n > 200

	UPDATE [LookUp].[ColumnDescriptions]
	SET PrintName = 'Telephone Mental Health',
	Category = 'Telephone_MentalHealth',
	ColumnDescription = 'Stop codes for telephone Mental Health and Homeless visits'
	--StopCodePrimaryOrSecondaryFlag = 'Primary'
	WHERE ColumnName = 'Telephone_MH_Stop'


-------------------------------------------------------------------------------------------
/****Publish****/
-------------------------------------------------------------------------------------------		
	EXEC [Maintenance].[PublishTable] '[LookUp].[StopCode]', '##LookUp_StopCode_Stage'
	DROP TABLE IF EXISTS ##LookUp_StopCode_Stage

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END