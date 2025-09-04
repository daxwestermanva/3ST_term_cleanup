/*******************************************************************
DESCRIPTION: Master patient table to include PERC CDS business rules for patient information
TEST:
	EXEC [Code].[Stage_MasterPatientVistA_Patient]
UPDATE:
	2020-08-07	RAS	Created SP, incorporating CDS rules for patient information using
					Present_StationAssignments, and views in development for demographics, etc.
					Definitions differ from PDW_DWS_MasterPatient (e.g., VeteranFlag, TestPatientFlag)
					and includes additional fields (e.g., marital status, race, service connectedness)
	2020-08-18	RAS	Changed BirthDateTime limitation to <= '1900-01-01' instead of '1914-01-01' to align 
					with RealPatients code that this is replacing. This was decided in a meeting with JT
					a while back, but I am not sure why.
	2020-08-21	RAS	Added ISNULL for PatientSSN to pull from SPatient if MVIPerson table contains null value.
	2020-10-20	RAS	Branched MasterPatient to VistA-specific code to implement modular approach for Cerner Overlay.
	2020-12-08	RAS	Added comments per validation feedback. Corrected WorkPhoneNumber to use the entry from OrdinalNumber = 13
	2021-05-05	LM	Removed CDWPossibleTestPatient as an indicator for test patients to be removed; 
					added PossibleTestPatient to flag these patients
	2021-05-14  JEB Change Synonym DWS_ reference to proper PDW_ reference
	2021-08-17	JEB Enclave Refactoring - Counts confirmed; Some additional formatting; Added WITH (NOLOCK)
	2021-09-23	JEB Enclave Refactoring - Removed use of Partition ID
	2021-11-18	LM	Adjusted address where clause from NOT LIKE '%NONE%' to NOT LIKE '%NONE' to avoid excluding addresses where 
					'none' is part of a valid address (e.g., Cannoneer)
	2022-01-06	RAS	Added MaritalStatus from SPatient
	2022-03-11	RAS	Added County and GISURH to address information
	2022-04-05	LM	Changed address query to get most recently updated address rather than address from most recently updated VistA record
	2022-06-23	LM	Pointed to Lookup.StopCode_VM
	2022-08-24	RAS	Added additional test patients used in STORM.
	2022-08-30	RAS	Removed 3 ICNs for test patient display that appear to be real records and NOT actual test.
	2024-04-04	LM	Refined address query
	2024-08-19  AER Adding FIPS
	2024-09-18	LM	Added preferred name from SPatient table
	2024-10-08	LM	Move temp address query from MasterPatient code to this stage code
	2024-10-09	LM	Break contact info into separate procedure
	2024-11-14	LM	Update service connected field to differentiate NSC from unknown (null); Update marital status query to more accurately identify unknown/missing records
CDS DEPENDENCIES:
	-- [Config].[MasterPatientFields]
	-- [LookUp].[ICD10]
	-- [LookUp].[StopCode]
	-- [Inpatient].[BedSection]
*******************************************************************/

CREATE PROCEDURE [Code].[Stage_MasterPatientVistA_Patient]
AS
BEGIN

	EXEC [Log].[ExecutionBegin] 'EXEC Code.Stage_MasterPatientVistA_Patient','Execution of Code.Stage_MasterPatientVistA_Patient SP'

	DROP TABLE IF EXISTS #StageMasterPatient
	CREATE TABLE #StageMasterPatient (
		MVIPersonSID INT NOT NULL
		,FieldName VARCHAR(25) NOT NULL
		,FieldValue VARCHAR(200) NULL
		,FieldModifiedDateTime DATETIME2(0) NULL
		)
	-----------------------------------------------------------------------------
	-- Basic Demographics
	-----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #SPatientDemog;
	WITH MaritalStatus AS (
		SELECT TOP 1 WITH TIES 
			mvi.MVIPersonSID
			,MaritalStatus = CASE WHEN d.MaritalStatusCode IN ('U','*') THEN 'UNKNOWN' ELSE s.MaritalStatus END -- U='UNKNOWN', *='*Unknown at this time*'
		FROM [SPV].[SPatient_SPatient] s WITH (NOLOCK)
		INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
			ON s.PatientSID = mvi.PatientPersonSID 
		LEFT JOIN [Dim].[MaritalStatus] d WITH (NOLOCK)
			ON s.MaritalStatusSID=d.MaritalStatusSID AND d.MaritalStatus NOT LIKE '%DO NOT USE%'
		WHERE mvi.MVIPersonSID > 0 
		ORDER BY ROW_NUMBER() OVER(PARTITION BY mvi.MVIPersonSID ORDER BY CASE WHEN d.MaritalStatusCode IN ('U','*') THEN 1 ELSE 0 END, s.VistaEditDate DESC)
		)				
		SELECT 
		 mvi.MVIPersonSID
		,PatientICN		= MAX(s.PatientICN)
		,PatientSSN		= MAX(s.PatientSSN)
		,BirthDateTime	= MIN(s.BirthDateTime)
		,DeathDateTime	= MAX(s.DeathDateTime)
		,VeteranFlag	= MAX(CASE WHEN s.VeteranFlag = 'N' THEN 0 ELSE 1 END) --If VeteranFlag is Y or NULL at any station then assume Veteran
		,SensitiveFlag	= MAX(CASE WHEN s.SensitiveFlag = 'Y' THEN 1 ELSE 0 END) --If SensitiveFlag is Y at any station then assum sensitive
		,TestPatient	= MIN(CASE WHEN s.TestPatientFlag = 'Y' THEN 1
								WHEN s.BirthDateTime <= '1900-01-01' THEN 1 ELSE 0 END) 
		,PossibleTestPatient = MIN(CASE WHEN s.CDWPossibleTestPatientFlag = 'Y' THEN 1 ELSE 0 END)--If likely test patient at EVERY station, otherwise assume real
		,ModifiedDateTime =MAX(s.VistaEditDate)
		,MaritalStatus = MAX(ms.MaritalStatus)
	INTO #SPatientDemog
	FROM [SPV].[SPatient_SPatient] s WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON s.PatientSID = mvi.PatientPersonSID 
	LEFT JOIN MaritalStatus ms ON ms.MVIPersonSID = mvi.MVIPersonSID
	WHERE mvi.MVIPersonSID > 0
	GROUP BY mvi.MVIPersonSID
	CREATE UNIQUE CLUSTERED INDEX CIX_SPatient_MVI ON #SPatientDemog(MVIPersonSID)

	--ADD RACE
	--Just report race as is.  If we need to standardize results, then we will need
	----to add joins to LookUp.RaceTranslationTable/Lookup.StandardRace
		----SELECT DISTINCT Race FROM [PatSub].[PatientRace] ORDER BY 1
	DROP TABLE IF EXISTS #DemogWithRace;
	WITH Race AS (
		SELECT a.MVIPersonSID
				,STRING_AGG(a.Race, ', ') WITHIN GROUP (ORDER BY a.Race) AS Race
		FROM (
			SELECT	
				 mvi.MVIPersonSID
				,r.Race
			FROM [PatSub].[PatientRace] r WITH (NOLOCK)
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON r.PatientSID = mvi.PatientPersonSID 
			WHERE r.Race NOT IN ('UNKNOWN BY PATIENT','DECLINED TO ANSWER','*Unknown at this time*','*Missing*')
			GROUP BY mvi.MVIPersonSID, r.Race--,sr.RaceName
			) a
		WHERE a.MVIPersonSID > 0
		GROUP BY a.MVIPersonSID
		)
	SELECT 
		 d.MVIPersonSID
		,d.PatientICN		
		,d.PatientSSN		
		,d.BirthDateTime	
		,d.DeathDateTime	
		,d.VeteranFlag	
		,d.SensitiveFlag	
		,d.TestPatient
		,d.PossibleTestPatient
		,d.MaritalStatus
		,r.Race
		,d.ModifiedDateTime	
	INTO #DemogWithRace
	FROM #SPatientDemog d
	LEFT JOIN Race r ON r.MVIPersonSID = d.MVIPersonSID

	INSERT INTO #StageMasterPatient (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
	SELECT MVIPersonSID
		,FieldName
		,FieldValue 
		,ModifiedDateTime
	FROM (
		SELECT MVIPersonSID 
			,CAST(PatientSSN AS VARCHAR(100)) AS PatientSSN		
			,CAST(BirthDateTime AS VARCHAR(100)) AS DateOfBirth	
			,CAST(DeathDateTime AS VARCHAR(100)) AS DateOfDeath	
			,CAST(VeteranFlag AS VARCHAR(100)) AS Veteran
			,CAST(SensitiveFlag AS VARCHAR(100)) AS SensitiveFlag	
			,CAST(TestPatient AS VARCHAR(100)) AS TestPatient
			,CAST(PossibleTestPatient AS VARCHAR(100)) AS PossibleTestPatient
			,CAST(MaritalStatus AS VARCHAR(100)) AS MaritalStatus
			,CAST(Race AS VARCHAR(100)) AS Race
			,ModifiedDateTime	
		FROM #DemogWithRace
		WHERE TestPatient=0 -- Only include real patients, or specifically chosen test patients
			OR PatientICN IN ( --test patients for CRISTAL and STORM
				 '1011494520'
				,'1011525934'
				,'1011547668'
				,'1011555358'
				,'1011566187'
				,'1013673699'
				,'1015801211'
				,'1015811652'
				,'1017268821'
				,'1018177176'
				,'1019376947'
				,'1011530765'
				,'1016996220'
				,'1047127261'
				) 
		) ph
	UNPIVOT (FieldValue FOR FieldName IN (
			PatientSSN		
			,DateOfBirth	
			,DateOfDeath	
			,Veteran	
			,SensitiveFlag	
			,TestPatient
			,PossibleTestPatient
			,MaritalStatus
			,Race
			)
		) u

	DROP TABLE #SPatientDemog,#DemogWithRace

	-----------------------------------------------------------------------------
	-- Patient Vitals --height and weight (within 5 years)
	-----------------------------------------------------------------------------
	--SIDs for Height and Weight
	DROP TABLE IF EXISTS #VitalSID;
	SELECT VitalTypeSID
		  ,CAST(VitalTypeIEN as TINYINT) as VitalTypeIEN
		  ,VitalType
	INTO #VitalSID
	FROM [Dim].[VitalType] WITH (NOLOCK)
	WHERE VitalTypeIEN in ('8','9') 

	DROP TABLE IF EXISTS #HeightWeight;
	SELECT 
		 v1.MVIPersonSID
		,v1.VitalSignTakenDateTime
		,v1.VitalResult
		,v1.VitalType
		,v1.VitalTypeIEN
	INTO #HeightWeight
	FROM 
		(	
			SELECT 
				 ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
				,v.VitalSignTakenDateTime
				,v.VitalResult AS VitalResult_Orig
				,v.VitalResultNumeric
				,CASE 
					WHEN t.VitalTypeIEN = 9 THEN v.VitalResult + ' lbs '
					WHEN t.VitalTypeIEN = 8 THEN 
						(
							CASE
								WHEN CAST(TRY_CAST(v.VitalResult AS DECIMAL) AS VARCHAR) IS NULL THEN v.VitalResult
								ELSE CAST(FLOOR(CAST(v.VitalResult AS DECIMAL)/12) AS VARCHAR) + 'ft ' + CAST(v.VitalResult - FLOOR(CAST(v.VitalResult AS DECIMAL)/12)*12 AS VARCHAR) + 'in'
							END
						)
					END AS VitalResult
				  ,t.VitalType
				  ,t.VitalTypeIEN
				  ,ROW_NUMBER() OVER(PARTITION BY ISNULL(mvi.MVIPersonSID,0), t.VitalTypeIEN ORDER BY v.VitalSignTakenDateTime DESC) AS RN
			FROM [Vital].[VitalSign] v WITH (NOLOCK)
			LEFT OUTER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON v.PatientSID = mvi.PatientPersonSID 
			INNER JOIN #VitalSID t 
				ON v.VitalTypeSID = t.VitalTypeSID
			WHERE v.VitalSignTakenDateTime > DATEADD(YEAR,-5,CAST(GETDATE() AS DATE))
				AND v.VitalResult IS NOT NULL
		) v1
	WHERE v1.RN = 1

	INSERT INTO #StageMasterPatient (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
	SELECT MVIPersonSID
		,'PatientHeight'
		,VitalResult
		,VitalSignTakenDateTime
	FROM #HeightWeight
	WHERE VitalTypeIEN=8
	UNION ALL
	SELECT MVIPersonSID
		,'PatientWeight'
		,VitalResult
		,VitalSignTakenDateTime
	FROM #HeightWeight
	WHERE VitalTypeIEN=9

	DROP TABLE #VitalSID,#HeightWeight

	-----------------------------------------------------------------------------
	-- Percent Servcice Connectedness
	-----------------------------------------------------------------------------
	INSERT INTO #StageMasterPatient (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
	SELECT 
		a.MVIPersonSID
		,'PercentServiceConnect' AS FieldName
		,a.ServiceConnectedPercentage
		,a.SCEffectiveDateTime
	FROM 
		(
			SELECT 
				 mvi.MVIPersonSID
				,CASE WHEN e.ServiceConnectedPercent IS NULL AND e.ServiceConnectedFlag='N' THEN -1 --NSC
					WHEN e.ServiceConnectedPercent IS NULL AND e.ServiceConnectedFlag='Y' THEN 0
					ELSE e.ServiceConnectedPercent END AS ServiceConnectedPercentage
				,e.SCEffectiveDateTime
				,ROW_NUMBER() OVER(PARTITION BY mvi.MVIPersonSID ORDER BY e.SCEffectiveDateTime DESC) AS RN
			FROM [SPatient].[SPatientDisability] e WITH (NOLOCK)
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON e.PatientSID = mvi.PatientPersonSID
			WHERE e.ServiceConnectedPercent IS NOT NULL OR e.ServiceConnectedFlag IN ('N','Y')
		) a
	WHERE a.RN = 1 
	
	-----------------------------------------------------------------------------
	-- Service Separation Date
	-----------------------------------------------------------------------------
	--DELETE #StageMasterPatient WHERE FieldName = 'ServiceSeparationDate'
	INSERT INTO #StageMasterPatient (MVIPersonSID,FieldName,FieldValue)
	SELECT 
		 mvi.MVIPersonSID
		,'ServiceSeparationDate' AS FieldName
		,MAX(m.ServiceSeparationDate)
	FROM [SPatient].[MilitaryServiceEpisode] m WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON m.PatientSID = mvi.PatientPersonSID 
	GROUP BY mvi.MVIPersonSID
	HAVING MAX(m.ServiceSeparationDate) IS NOT NULL

	-----------------------------------------------------------------------------
	-- Sexual Orientation and Pronouns
	-----------------------------------------------------------------------------
	--DELETE #StageMasterPatient WHERE FieldName = 'ServiceSeparationDate'
	DROP TABLE IF EXISTS #Pronouns
	SELECT DISTINCT MVIPersonSID, b.PronounType
	INTO #Pronouns
	FROM [Patient].[PreferredPronoun] a WITH (NOLOCK) 
	INNER JOIN [Dim].[PronounType] b WITH (NOLOCK) 
		ON a.PronounTypeSID = b.PronounTypeSID
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON a.PatientSID = mvi.PatientPersonSID 
	WHERE b.PronounType NOT IN ('*Unknown at this time*','*Missing*')

	INSERT INTO #StageMasterPatient (MVIPersonSID,FieldName,FieldValue)
	SELECT MVIPersonSID
		,'Pronouns' AS FieldName
		,LEFT(STRING_AGG(PronounType,', ') WITHIN GROUP (ORDER BY PronounType),100)  AS PronounType
	FROM #Pronouns
	GROUP BY MVIPersonSID

	DROP TABLE IF EXISTS #SexualOrientation
	SELECT DISTINCT mvi.MVIPersonSID
		,CASE WHEN b.SexualOrientationType='Another Option, please describe' AND c.SexualOrientationDescription IS NOT NULL 
			THEN CONCAT('Other: ', c.SexualOrientationDescription)
			ELSE b.SexualOrientationType END AS SexualOrientationType
	INTO #SexualOrientation
	FROM [Patient].[SexualOrientation] a  WITH (NOLOCK)
	INNER JOIN [Dim].[SexualOrientationType] b  WITH (NOLOCK)
		ON a.SexualOrientationTypeSID=b.SexualOrientationTypeSID
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi  WITH (NOLOCK)
		ON a.PatientSID = mvi.PatientPersonSID
	LEFT JOIN [SPatient].[SPatientBirthSex] c 
		ON a.PatientSID=c.PatientSID AND b.SexualOrientationType='Another Option, please describe'
	WHERE b.SexualOrientationType NOT IN ('*Unknown at this time*','*Missing*')
	AND a.StatusCode='ACTIVE'--include only active records

	INSERT INTO #StageMasterPatient (MVIPersonSID,FieldName,FieldValue)
	SELECT MVIPersonSID
		,'SexualOrientation' AS FieldName
		,LEFT(STRING_AGG(SexualOrientationType,', ') WITHIN GROUP (ORDER BY CASE WHEN SexualOrientationType LIKE 'Other:%' THEN 2 ELSE 1 END, SexualOrientationType),100) AS SexualOrientation
	FROM #SexualOrientation 
	GROUP BY MVIPersonSID

	INSERT INTO #StageMasterPatient (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
	SELECT DISTINCT mvi.MVIPersonSID
		,'PreferredName' AS FieldName
		,a.PreferredName
		,a.VistAEditDate
	FROM  [SPatient].[SPatientBirthSex] a  WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi  WITH (NOLOCK)
		ON a.PatientSID = mvi.PatientPersonSID
	INNER JOIN [SVeteran].[SMVIPerson] b WITH (NOLOCK)
		ON mvi.MVIPersonSID = b.MVIPersonSID
	WHERE a.PreferredName IS NOT NULL
		AND a.PreferredName NOT IN ('SAME', 'NO', 'N', 'Y','UNSPECIFIED', 'UNDISCLOSED', 'UNANSWERED', 'UNANSERED', 'UN', 'UNNOWN', 'NOONE GIVEN')
		AND a.PreferredName NOT LIKE 'UNK%'
		AND a.PreferredName NOT LIKE 'UKN%'
		AND a.PreferredName NOT LIKE 'NONE%'
		AND a.PreferredName NOT LIKE 'NOT%'
		AND a.PreferredName NOT LIKE 'NO %'
		AND a.PreferredName <> b.FirstName
		AND a.PreferredName <> b.LastName
		AND a.PreferredName <> CONCAT(b.FirstName, ' ', b.LastName)
		AND a.PreferredName <> CONCAT(b.FirstName, ' ', b.MiddleName, ' ', b.LastName)
		AND a.PreferredName <> CONCAT(b.LastName, ' ', b.FirstName)
		AND a.PreferredName <> CONCAT(b.LastName, ' ', b.FirstName, ' ', b.MiddleName)
		AND a.PreferredName <> CONCAT(b.LastName, ', ', b.FirstName)
		AND a.PreferredName <> CONCAT(LastName, ', ', b.FirstName, ' ', b.MiddleName)
		AND a.PreferredName NOT LIKE CONCAT(b.FirstName,b.LastName,'%')
		AND a.PreferredName NOT LIKE CONCAT(b.LastName,b.FirstName,'%')
		AND a.PreferredName NOT LIKE CONCAT(b.LastName,b.MiddleName,'%')

	----------------------------------------------------------------------------------
	--Homeless_CDS flag based on MHOC definition
	----------------------------------------------------------------------------------
	DECLARE @EndDate datetime2,@EndDate_1Yr date

	SET @EndDate=dateadd(day, datediff(day, 0, getdate()),0)
	SET @EndDate_1Yr=dateadd(day,-366,@EndDate)
  
	/*** Homeless ICD10 ***/
	DROP TABLE IF EXISTS #Homeless_icd
	SELECT DISTINCT a.MVIPersonSID
	INTO #Homeless_icd
	FROM 
		(
			-- Outpatient
			SELECT DISTINCT mvi.MVIPersonSID 
			FROM [Outpat].[VDiagnosis] a1 WITH (NOLOCK)
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON a1.PatientSID = mvi.PatientPersonSID 
			INNER JOIN [LookUp].[ICD10] b1 WITH (NOLOCK) 
				ON a1.ICD10SID = b1.ICD10SID
			WHERE a1.VisitDateTime >= @EndDate_1Yr 
				and b1.Homeless = 1
			UNION
			--Inpatient
			SELECT DISTINCT mvi.MVIPersonSID
			FROM [Inpat].[InpatientDiagnosis] a2 WITH (NOLOCK)
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON a2.PatientSID = mvi.PatientPersonSID 
			INNER JOIN [LookUp].[ICD10] b2 WITH (NOLOCK)
				ON a2.ICD10SID = b2.ICD10SID
			WHERE (a2.DischargeDateTime BETWEEN @EndDate_1Yr AND @EndDate 
					OR a2.DischargeDateTime IS NULL) 
				AND b2.Homeless = 1
		) a;


	/***Homeless Stop Code per new MHOC definition ***/
	-- Primary stopcodes defined in Lookup.Stopcode
	DROP TABLE IF EXISTS #Visit_PrimaryStopcodes;
	SELECT DISTINCT mvi.MVIPersonSID 
	INTO #Visit_PrimaryStopcodes
	FROM [Outpat].[Visit] V WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON V.PatientSID = mvi.PatientPersonSID 
	INNER JOIN [Lookup].[StopCode] S WITH (NOLOCK)
		ON V.PrimaryStopCodeSID = S.StopCodeSID
	WHERE V.VisitDatetime >= @EndDate_1Yr
		AND S.MHOC_Homeless_Stop = 1

	--Custom definitions using primary and secondary stop code positions
	DROP TABLE IF EXISTS #Visits_Custom_Joined_Stopcodes
	SELECT 
		 mvi.MVIPersonSID
		,v.VisitSID
		,psc.StopCode AS PrimaryStopCode	
		,ssc.StopCode AS SecondaryStopCode
	INTO #Visits_Custom_Joined_Stopcodes
	FROM [Outpat].[Visit] v WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON v.PatientSID = mvi.PatientPersonSID 
	LEFT JOIN [LookUp].[StopCode] psc WITH (NOLOCK) 
		ON psc.StopCodeSID = v.PrimaryStopCodeSID
	LEFT JOIN [LookUp].[StopCode] ssc WITH (NOLOCK) 
		ON ssc.StopCodeSID = v.SecondaryStopCodeSID
	WHERE v.VisitDateTime >= @EndDate_1Yr
		AND ((psc.StopCode = '527' AND ssc.StopCode IN ('511', '522', '529')) 
			OR (psc.StopCode IN ('222', '536', '568') AND ssc.StopCode = '529') 
			OR (psc.StopCode = '674' AND ssc.StopCode = '555') 
			OR (psc.StopCode = '590')
			)

	-- Unioning Patients flagged as homeless based on Stopcodes rules
	DROP TABLE IF EXISTS #Homeless_Stopcode;
	SELECT DISTINCT MVIPersonSID
	INTO #Homeless_Stopcode
	FROM (
		SELECT MVIPersonSID FROM #Visit_PrimaryStopcodes
		UNION ALL
		SELECT MVIPersonSID FROM #Visits_Custom_Joined_Stopcodes
		) as b 
		;

	/** Homeless Bed Section **/
	DROP TABLE IF EXISTS #Homeless_bedsection; 
	SELECT DISTINCT a.MVIPersonSID
	INTO  #Homeless_bedsection 
	FROM [Inpatient].[Bedsection] a WITH (NOLOCK)
	WHERE a.Homeless_TreatingSpecialty = 1 
		AND (a.DischargeDateTime >= @EndDate_1Yr OR a.DischargeDateTime IS NULL)
		AND a.Sta3n_EHR > 200

	--Unioning ICD, StopCode, BedSection
	INSERT INTO #StageMasterPatient (MVIPersonSID,FieldName,FieldValue)
	SELECT DISTINCT 
		MVIPersonSID
		,'Homeless'
		,'1'
	FROM (
		SELECT MVIPersonSID FROM #Homeless_icd
		UNION ALL
		SELECT MVIPersonSID FROM #Homeless_stopcode
		UNION ALL
		SELECT MVIPersonSID FROM #Homeless_bedsection 
		) as a
	;

	DROP TABLE #Homeless_icd,#Homeless_Stopcode,#Homeless_bedsection

	-----------------------------------------------------------------------------
	-- Hospice in past year
	-----------------------------------------------------------------------------
	INSERT INTO #StageMasterPatient (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
	SELECT 
		 u.MVIPersonSID
		,'Hospice' AS FieldName
		,'1' AS FieldValue
		,MAX(u.VisitDateTime) AS FieldModifiedDateTime
	FROM (
			SELECT 
				 mvi.MVIPersonSID
				,ov.VisitDateTime
			FROM [Outpat].[Visit] ov WITH (NOLOCK) 
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON ov.PatientSID = mvi.PatientPersonSID 
			WHERE (ov.PrimaryStopCodeSID IN (SELECT DISTINCT StopCodeSID FROM [Dim].[StopCode] WITH (NOLOCK) WHERE StopCode LIKE '351') 
					OR ov.SecondaryStopCodeSID IN (SELECT DISTINCT StopCodeSID FROM [Dim].[StopCode] WITH (NOLOCK) WHERE StopCode LIKE '351')
					)
				AND ov.VisitDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE)) AS DATETIME2(0))
		
			UNION ALL
			SELECT 
				bvm.MVIPersonSID
				,ISNULL(bvm.DischargeDateTime,GETDATE()) AS VisitDateTime
			FROM [Inpatient].[BedSection] bvm WITH (NOLOCK)
			WHERE bvm.Homeless_TreatingSpecialty = 1
				AND (bvm.Census = 1 OR bvm.DischargeDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE)) AS DATETIME2(0))	)
				AND bvm.Sta3n_EHR > 200
		) u
	GROUP BY u.MVIPersonSID
	ORDER BY MAX(u.VisitDateTime)

	-----------------------------------------------------------------------------
	-- Stage and Publish
	-----------------------------------------------------------------------------
	--Get IDs for the patients who are defined in first section as non-test patients or Easter Bunny
	DROP TABLE IF EXISTS #ExcludeTest
	SELECT DISTINCT MVIPersonSID
	INTO #ExcludeTest
	FROM #StageMasterPatient
	WHERE FieldName = 'TestPatient' 

	DROP TABLE IF EXISTS #StageMPVistA;
	SELECT st.MVIPersonSID
		,i.MasterPatientFieldID
		,st.FieldName AS MasterPatientFieldName
		,st.FieldValue
		,st.FieldModifiedDateTime
	INTO #StageMPVistA
	FROM #StageMasterPatient st
	INNER JOIN [Config].[MasterPatientFields] i WITH (NOLOCK)
		ON i.MasterPatientFieldName = st.FieldName
	INNER JOIN #ExcludeTest nt 
		ON nt.MVIPersonSID=st.MVIPersonSID
		
	EXEC [Maintenance].[PublishTable] 'Stage.MasterPatientVistA_Patient','#StageMPVistA'

	EXEC [Log].[ExecutionEnd]
END