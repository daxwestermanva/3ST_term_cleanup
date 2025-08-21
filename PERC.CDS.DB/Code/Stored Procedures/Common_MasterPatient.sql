
/*******************************************************************
DESCRIPTION: Master patient table to include PERC CDS business rules for patient information
TEST:

	EXEC [Code].[Stage_MasterPatientVistA_Patient]
	EXEC [Code].[Stage_MasterPatientMill_Patient]
	EXEC [Code].[Common_MasterPatient]
UPDATE:
	2020-08-07	RAS	Created SP, incorporating CDS rules for patient information using
					Present_StationAssignments, and views in development for demographics, etc.
					Definitions differ from PDW_DWS_MasterPatient (e.g., VeteranFlag, TestPatientFlag)
					and includes additional fields (e.g., marital status, race, service connectedness)
	2020-08-18	RAS	Changed BirthDateTime limitation to <= '1900-01-01' instead of '1914-01-01' to align 
					with RealPatients code that this is replacing. This was decided in a meeting with JT
					a while back, but I am not sure why.
	2020-08-21	RAS	Added ISNULL for PatientSSN to pull from SPatient if MVIPerson table contains null value.
	2020-10-21	RAS	V02 - Making code modular to implement overlaying of Cerner data in a more coherent way
	2020-12-02	RAS Added note regarding DeceasedFlag to research later.
	2021-01-07	LM	Added period of service, branch of service, and OEF/OIF status
	2021-01-22	RAS	Added code to determine if staging tables have too low of a row count to continue running the SP.
	2021-03-26	HES Added code to include priority and sub-priority groups.
	2021-04-09	RAS	Updated enrollment priority group section to remove time limitation and improve efficiency.
	2021-05-13	LM	Adding PossibleTestPatient column; for now only including some of these patients manually. 
					Awaiting decision from leadership as to adding all CDWPossibleTestPatients because some of them are real patients.
	2021-05-18	JEB	Enclave work - updated NDim Synonym use. No logic changes made.
	2021-05-18  JEB Enclave work - updated [SStaff].[SStaff] Synonym use. No logic changes made.	
	2021-05-18  JEB Enclave work - updated [SVeteran].[SMVIPerson] Synonym use. No logic changes made.	
	2021-08-18  JEB Enclave work - Enclave Refactoring - Counts confirmed based on Non Deleted CDW records; Some additional formatting; Added WITH (NOLOCK); Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	2022-01-06	RAS	Added MaritalStatus from EHR data if not available from SVeteran table.
	2022-02-23	LM	Included patients where PossibleTestPatient IS NULL - there is no PossibleTestPatient (i.e., CDWPossibleTestPatientFlag) value in the Cerner data and Test Patients are already excluded in MillCDS code
	2022-08-30	RAS	Added 1 additional PatientICN to test patients for STORM display.
	2023-01-26	LM	Added preferred name, pronouns, sexual orientation, COMPACT Act eligibility
	2023-07-12	LM	Added patient alias
	2023-08-10	LM  Remove alias per decision with JT on 8/10/2023; largely seems to be used for reasons other than privacy
	2024-08-14	LM	Added VHA Eligibility Flag
	2024-10-09	LM	Broke contact info and patient data into separate procedures
	2024-11-14	LM	Removed Alias and DisplayName columns
	2025-04-15	LM	Updated Age to use MVI date of death to align with XLA
*******************************************************************/

CREATE PROCEDURE [Code].[Common_MasterPatient]
AS
BEGIN
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] 'EXEC Code.Common_MasterPatient','Execution of Code.Common_MasterPatient SP'

	-----------------------------------------------
	-- CHECK PREREQUISITES
	-----------------------------------------------
	/**Make sure staging tables are populated correctly**/
	DECLARE @VistaThreshold INT = 100000000
	DECLARE @MillThreshold INT = 1000000
	
	DECLARE @VistaCount BIGINT = (SELECT COUNT_BIG(*) FROM [Stage].[MasterPatientVistA_Patient] WITH (NOLOCK))
	DECLARE @MillCount BIGINT = (SELECT COUNT_BIG(*) FROM [Stage].[MasterPatientMill_Patient] WITH (NOLOCK))
	IF	(
		@VistaCount   < @VistaThreshold
		OR @MillCount < @MillThreshold
		)
	BEGIN 
		DECLARE @ErrorMsg varchar(500)=
			CASE WHEN @VistaCount < @VistaThreshold AND @MilLCount < @MillThreshold  THEN 'Staging tables MasterPatientVistA and MasterPatientMill: '
				WHEN @VistaCount < @VistaThreshold THEN 'Stage.MasterPatientVistA: '
				WHEN @MilLCount < @MillThreshold THEN 'Stage.MasterPatientMill: '
				END
			+ 'Row count insufficient to proceed with MasterPatient code'
		EXEC [Log].[Message] 'Error','Missing dependency',@ErrorMsg
		EXEC [Log].[ExecutionEnd] @Status='Error' --Log end in case of error
		PRINT @ErrorMsg;
		THROW 51000,@ErrorMsg,1
	END

	-----------------------------------------------------------------------------------
	-- Determine which patients appear in VistA data, Cerner data, or both
	-----------------------------------------------------------------------------------
	----Used MasterPatientFieldName = 'TestPatient' to get distinct patients because this is a field 
	----that will not be NULL and has already been limited to relevant patients in the staging tables
	DROP TABLE IF EXISTS #SourceEHR;
	WITH VistAPat AS (
		SELECT a.MVIPersonSID			
		FROM [Stage].[MasterPatientVistA_Patient] a WITH (NOLOCK)
		INNER JOIN [Config].[MasterPatientFields] i WITH (NOLOCK)
			ON i.MasterPatientFieldID = a.MasterPatientFieldID
			AND i.MasterPatientFieldName = 'TestPatient' 
		UNION ALL
		SELECT DISTINCT a.MVIPersonSID			
		FROM [Stage].[MasterPatientVistA_Contact] a WITH (NOLOCK)
		INNER JOIN [Config].[MasterPatientFields] i WITH (NOLOCK)
			ON i.MasterPatientFieldID = a.MasterPatientFieldID
		)
	,MillPat AS (
		SELECT a.MVIPersonSID			
		FROM [Stage].[MasterPatientMill_Patient] a WITH (NOLOCK)
		INNER JOIN [Config].[MasterPatientFields] i WITH (NOLOCK)
			ON i.MasterPatientFieldID = a.MasterPatientFieldID
			AND i.MasterPatientFieldName = 'TestPatient'
		UNION ALL
		SELECT DISTINCT a.MVIPersonSID			
		FROM [Stage].[MasterPatientMill_Contact] a WITH (NOLOCK)
		INNER JOIN [Config].[MasterPatientFields] i WITH (NOLOCK)
			ON i.MasterPatientFieldID = a.MasterPatientFieldID
		)
	SELECT DISTINCT
		ISNULL(v.MVIPersonSID,m.MVIPersonSID) AS MVIPersonSID 
		,CASE 
			WHEN v.MVIPersonSID IS NULL THEN 'M'	--Cerner Millenium ONLY patient (no match found in VistA)
			WHEN m.MVIPersonSID IS NULL THEN 'V'	--Vista ONLY patient (no match found in Millenium)
			ELSE 'VM' 								--Otherwise, there is a match, so found in both
		END AS SourceEHR 
	INTO #SourceEHR
	FROM VistAPat v
	FULL OUTER JOIN MillPat m 
		ON m.MVIPersonSID=v.MVIPersonSID

----------------------------------------------------------------------------
	-- HARMONIZE THE 2 SOURCES OF DATA
	----------------------------------------------------------------------------

	--Combine staging tables for non-address fields that require most recently entered or changed data  
	DROP TABLE IF EXISTS #recent;
	SELECT TOP 1 WITH TIES
		 s.MVIPersonSID
		,i.MasterPatientFieldName
		,s.FieldValue
		,s.FieldModifiedDateTime
	INTO #recent
	FROM (
		SELECT 
			 MVIPersonSID
			,MasterPatientFieldID
			,FieldValue
			,FieldModifiedDateTime
		FROM [Stage].[MasterPatientVistA_Patient] WITH (NOLOCK) 
		UNION ALL
		SELECT 
			 MVIPersonSID
			,MasterPatientFieldID
			,FieldValue
			,FieldModifiedDateTime
		FROM [Stage].[MasterPatientMill_Patient] WITH (NOLOCK) 
		) s
	INNER JOIN [Config].[MasterPatientFields] i WITH (NOLOCK)
		ON i.MasterPatientFieldID = s.MasterPatientFieldID
		AND i.VistAMillMethod = 'DATE'
		AND i.Category = 'Patient'
	ORDER BY ROW_NUMBER() OVER(PARTITION BY s.MVIPersonSID, i.MasterPatientFieldID ORDER BY s.FieldModifiedDateTime DESC)

	--Combine staging tables for fields that require max value across EHRs  
	DROP TABLE IF EXISTS #max;
	SELECT 
		 s.MVIPersonSID
		,s.MasterPatientFieldID
		,i.MasterPatientFieldName
		,MAX(s.FieldValue) AS FieldValue 
	INTO #max
	FROM (
		SELECT 
			 MVIPersonSID
			,MasterPatientFieldID
			,FieldValue
			,FieldModifiedDateTime
		FROM [Stage].[MasterPatientVistA_Patient] WITH (NOLOCK) 
		UNION ALL
		SELECT 
			 MVIPersonSID
			,MasterPatientFieldID
			,FieldValue
			,FieldModifiedDateTime
		FROM [Stage].[MasterPatientMill_Patient] WITH (NOLOCK)
		) s
	INNER JOIN [Config].[MasterPatientFields] i WITH (NOLOCK)
		ON i.MasterPatientFieldID = s.MasterPatientFieldID
		AND i.VistAMillMethod = 'MAX'
		AND i.Category = 'Patient'
	GROUP BY s.MVIPersonSID, s.MasterPatientFieldID, i.MasterPatientFieldName

	--Combine staging tables for fields that require min value across EHRs  
	DROP TABLE IF EXISTS #min;
	SELECT 
		 s.MVIPersonSID
		,s.MasterPatientFieldID
		,i.MasterPatientFieldName
		,MIN(s.FieldValue) AS FieldValue 
	INTO #min
	FROM (
		SELECT 
			 MVIPersonSID
			,MasterPatientFieldID
			,FieldValue
			,FieldModifiedDateTime
		FROM [Stage].[MasterPatientVistA_Patient] WITH (NOLOCK)
		UNION ALL
		SELECT 
			 MVIPersonSID
			,MasterPatientFieldID
			,FieldValue
			,FieldModifiedDateTime
		FROM [Stage].[MasterPatientMill_Patient] WITH (NOLOCK) 
		) s
	INNER JOIN [Config].[MasterPatientFields] i WITH (NOLOCK)
		ON i.MasterPatientFieldID = s.MasterPatientFieldID
		AND i.VistAMillMethod = 'MIN'
		AND i.Category = 'Patient'
	GROUP BY s.MVIPersonSID, s.MasterPatientFieldID, i.MasterPatientFieldName

	--Combine all data and pivot fields to prepare for staging
	DROP TABLE IF EXISTS  #PivotMP
	SELECT 
		 MVIPersonSID
		,PatientSSN
		,Race
		,SexualOrientation
		,Pronouns
		,PreferredName
		,PercentServiceConnect
		,DateOfDeath
		,Veteran
		,SensitiveFlag
		,ServiceSeparationDate
		,Homeless
		,Hospice
		,DateOfBirth
		,TestPatient
		,PossibleTestPatient
		,MaritalStatus
	INTO #PivotMP
	FROM (
		SELECT MVIPersonSID
			,MasterPatientFieldName
			,FieldValue
		FROM #recent
		UNION ALL 
		SELECT MVIPersonSID
			,MasterPatientFieldName
			,FieldValue
		FROM #max
		UNION ALL 
		SELECT MVIPersonSID
			,MasterPatientFieldName
			,FieldValue
		FROM #min
		) a
	PIVOT (MAX(FieldValue) FOR MasterPatientFieldName IN (
		PatientSSN
		,Race
		,SexualOrientation
		,Pronouns
		,PreferredName
		,PercentServiceConnect
		,DateOfDeath
		,Veteran
		,SensitiveFlag
		,ServiceSeparationDate
		,Homeless
		,Hospice
		,DateOfBirth
		,TestPatient
		,PossibleTestPatient
		,MaritalStatus
		)	) p

	DROP TABLE IF EXISTS #RecentAddress
	DROP TABLE IF EXISTS #max
	DROP TABLE IF EXISTS #min
	
	DROP TABLE IF EXISTS #HeightWeightDates
	SELECT MVIPersonSID,FieldModifiedDateTime,MasterPatientFieldName,FieldValue
	INTO #HeightWeightDates
	FROM #recent WHERE MasterPatientFieldName IN ('PatientHeight','PatientWeight')

	DROP TABLE IF EXISTS #recent

	---------------------------------------------------
	-- EDIPI 
	---------------------------------------------------
	--There are some cases of multiple records/patient in MillCDS.FactPatientDemographic due to multiple SSNs/EDIPIs.
	--As we figure out the best way to deal with that, prioritize EDIPIs from this table when there is also a match on SSN. 
	DROP TABLE IF EXISTS #EDIPI
	SELECT TOP 1 WITH TIES
		 mvi.MVIPersonSID
		,ISNULL(d.EDIPI,e.EDIPI) AS EDIPI --use value from Millenium data if available
	INTO #EDIPI
	FROM [SVeteran].[SMVIPersonSiteAssociation] AS e WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON e.MVIPersonSID = mvi.MVIPersonSID 
	LEFT OUTER JOIN [Cerner].[FactPatientDemographic] d WITH (NOLOCK)
		ON e.MVIPersonSID = d.MVIPersonSID
	WHERE e.MVIAssigningAuthoritySID = 3 
		AND (e.ActiveMergedIdentifierCode IS NULL or e.ActiveMergedIdentifierCode = 'A')
	ORDER BY ROW_NUMBER() OVER(PARTITION BY e.MVIPersonSID ORDER BY CASE WHEN e.PersonSSN = d.SSN THEN 0 ELSE 1 END, e.MessageModifiedDateTime DESC)

	
	---------------------------------------------------
	-- Military Service (currently VistA only)
	---------------------------------------------------
	DROP TABLE IF EXISTS #PeriodOfService
	SELECT TOP 1 WITH TIES
		ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
		,p.PeriodOfService
	INTO #PeriodOfService
	FROM [SPatient].[SPatient] p WITH (NOLOCK) 
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON p.PatientSID = mvi.PatientPersonSID 
	ORDER BY ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY p.PatientEnteredDateTime DESC, p.EligibilityStatusDateTime DESC)

	DROP TABLE IF EXISTS #BranchOfService
	SELECT TOP 1 WITH TIES
		ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
		,b.BranchOfService
		,ms.PatientSID
	INTO #BranchOfService
	FROM [SPatient].[MilitaryServiceEpisode] ms WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON ms.PatientSID = mvi.PatientPersonSID 
	INNER JOIN [Dim].[BranchOfService] AS b WITH (NOLOCK) 
		ON ms.BranchOfServiceSID = b.BranchOfServiceSID
	ORDER BY ROW_NUMBER() OVER(PARTITION BY ISNULL(mvi.MVIPersonSID,0) ORDER BY ms.ServiceSeparationDate DESC, ms.ServiceEntryDate DESC, b.BranchOfServiceSID DESC)
	
	DROP TABLE IF EXISTS #OEFOIF
	SELECT TOP 1 WITH TIES
		 ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
		,o.LocationOfService AS OEFOIFStatus
	INTO #OEFOIF
	FROM [PatSub].[OEFOIFService] o WITH (NOLOCK) 
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON o.PatientSID = mvi.PatientPersonSID 
	ORDER BY ROW_NUMBER() OVER(PARTITION BY ISNULL(mvi.MVIPersonSID,0) ORDER BY o.RecordedDateTime DESC, VistACreateDate DESC)
	
	DROP TABLE IF EXISTS #MilitaryService
	SELECT p.MVIPersonSID
		,p.PeriodOfService
		,b.BranchOfService
		,o.OEFOIFStatus
	INTO #MilitaryService
	FROM #PeriodOfService p
	LEFT JOIN #BranchOfService b 
		ON p.MVIPersonSID=b.MVIPersonSID
	LEFT JOIN #OEFOIF o 
		ON p.MVIPersonSID=o.MVIPersonSID

	DROP TABLE IF EXISTS #PeriodOfService
	DROP TABLE IF EXISTS #BranchOfService
	---------------------
	-- FIND ENROLLMENT PRIORITY GROUPS AND PRIORITY SUB GROUPS
	---------------------
	-- Get only most recent record for each patient
	DROP TABLE IF EXISTS #ADR_MostRecent
	SELECT 
		 a.MVIPersonSID
		,MAX(a.RecordModifiedDate) MaxRecordModifiedDate
	INTO #ADR_MostRecent
	FROM [ADR].[ADREnrollHistory] a WITH (NOLOCK) 
	GROUP BY a.MVIPersonSID

	-- Get details and make sure there is only 1 possible record with rank=1
	DROP TABLE IF EXISTS #ADRPriority;
	SELECT Ranked.* 
	INTO #ADRPriority
	FROM (
		SELECT a.MVIPersonSID
			,a.ADRPriorityGroupSID
			,c.PrioritySubGroupName
			,a.ADRPrioritySubGroupSID
			,a.RecordModifiedDate
			,b.EnrollStatusName
			,b.EnrollCategoryName
			,RANK() OVER (
				PARTITION BY a.MVIPersonSID ORDER BY a.RecordModifiedDate DESC, a.RecordModifiedCount DESC -- RAS added RecordModifiedCount for records with duplicate date at rank 1
				) RecordRank
		FROM [ADR].[ADREnrollHistory] a WITH (NOLOCK) 
		INNER JOIN #ADR_MostRecent mr 
			ON mr.MVIPersonSID = a.MVIPersonSID 
			AND mr.MaxRecordModifiedDate = a.RecordModifiedDate
		INNER JOIN [NDim].[ADREnrollStatus] b WITH (NOLOCK) 
			ON a.ADREnrollStatusSID = b.ADREnrollStatusSID
		INNER JOIN [NDim].[ADRPrioritySubGroup] c WITH (NOLOCK) 
			ON a.ADRPrioritySubGroupSID = c.ADRPrioritySubGroupSID
		) Ranked
	WHERE Ranked.RecordRank=1
	
	--	select count(*),count(distinct mvipersonsid) from #ADRPriority
	DROP TABLE IF EXISTS #ADR_MostRecent
	---------------------
	-- GET COMPACT ACT ELIGIBILITY
	---------------------
	DROP TABLE IF EXISTS #COMPACT
	SELECT TOP 1 WITH TIES
		 MVIPersonSID
		,CompactEligible
	INTO #COMPACT 
	FROM (
		SELECT c.MVIPersonSID
			,CompactEligible = 1
		FROM PatSub.SecondaryEligibility a WITH (NOLOCK)
		INNER JOIN Dim.Eligibility b WITH (NOLOCK) on a.EligibilitySID=b.EligibilitySID
		INNER JOIN Common.vwMVIPersonSIDPatientPersonSID c WITH (NOLOCK) 
			ON a.PatientSID=c.PatientPersonSID
		WHERE b.Eligibility = 'COMPACT ACT ELIGIBLE'
		UNION
		SELECT MVIPersonSID
			,CompactEligible = 1
		FROM #ADRPriority 
		WHERE ADRPriorityGroupSID BETWEEN 1 AND 8
			AND PrioritySubGroupName NOT IN ('e','g')
		) a
	ORDER BY ROW_NUMBER() OVER(PARTITION BY a.MVIPersonSID ORDER BY a.CompactEligible DESC)

	---------------------
	-- GET VETERAN STATUS AND SENSITIVE FLAG FROM ADR TABLES
	---------------------
	DROP TABLE IF EXISTS #ADR_Veteran
	SELECT r.* 
	INTO #ADR_Veteran
	FROM (SELECT
		 a.MVIPersonSID
		,VeteranFlag = CASE WHEN a.VeteranFlag = 'Y' THEN 1
			WHEN a.VeteranFlag = 'N' THEN 0 
			ELSE NULL END
		,ActiveDutyFlag = CASE WHEN a.ActiveDutyFlag = 'Y' THEN 1
			WHEN a.ActiveDutyFlag = 'N' THEN 0
			ELSE NULL END
		,SensitiveFlag = CASE WHEN a.SensitiveFlag = 'Y' THEN 1
			WHEN a.SensitiveFlag = 'N' THEN 0
			ELSE NULL END
		,ActiveDutyDate
		,RANK() OVER (
				PARTITION BY a.MVIPersonSID ORDER BY a.RecordModifiedDate DESC, a.RecordModifiedCount DESC 
				) RecordRank
		FROM [Veteran].[ADRPerson] a WITH (NOLOCK) 
	) r
	WHERE r.RecordRank = 1
	
	--	select count(*),count(distinct mvipersonsid) from #ADR_Veteran

	---------------------------------------------------
	-- SEXUAL ORIENTATION AND PRONOUNS
	---------------------------------------------------
	DROP TABLE IF EXISTS #SexualOrientation
	SELECT MVIPersonSID
		,LEFT(STRING_AGG(SexualOrientationType,', ') WITHIN GROUP (ORDER BY CASE WHEN SexualOrientationType LIKE 'Other:%' THEN 2 ELSE 1 END),100)
			AS SexualOrientation
	INTO #SexualOrientation 
	FROM (
		SELECT DISTINCT a.MVIPersonSID
			,CASE WHEN b.TypeCode='OTH' THEN CONCAT('Other: ',c.SexualOrientationDescription)
				ELSE b.SexualOrientationType END AS SexualOrientationType
		FROM [Veteran].[MVIPersonSexualOrientation] a WITH (NOLOCK)
		INNER JOIN [NDim].[MVISexualOrientationType] b WITH (NOLOCK)
			ON a.MVISexualOrientationTypeSID = b.MVISexualOrientationTypeSID
		INNER JOIN [SVeteran].[SMVIPerson] c WITH (NOLOCK)
			ON a.MVIPersonSID = c.MVIPersonSID
		WHERE b.MVISexualOrientationTypeSID > 0 --exclude missing and unknown
		AND a.StatusCode='A'--include only active records
		) s
	GROUP BY s.MVIPersonSID

	DROP TABLE IF EXISTS #Pronouns
	SELECT MVIPersonSID
		,LEFT(STRING_AGG(PronounType,', ') WITHIN GROUP (ORDER BY CASE WHEN PronounType LIKE 'Other:%' THEN 2 ELSE 1 END),100) AS Pronouns
	INTO #Pronouns 
	FROM (
		SELECT DISTINCT a.MVIPersonSID
			,CASE WHEN b.TypeCode='OTH' THEN CONCAT('Other: ',c.PronounDescription)
				ELSE b.PronounType END AS PronounType
		FROM [Veteran].[MVIPersonPreferredPronoun] a WITH (NOLOCK)
		INNER JOIN [NDim].[MVIPronounType] b WITH (NOLOCK)
			ON a.MVIPronounTypeSID = b.MVIPronounTypeSID
		INNER JOIN [SVeteran].[SMVIPerson] c WITH (NOLOCK)
			ON a.MVIPersonSID = c.MVIPersonSID
		WHERE b.MVIPronounTypeSID>0 --exclude missing and unknown
		) p
	GROUP BY p.MVIPersonSID

	DROP TABLE IF EXISTS #PreferredName
	SELECT DISTINCT MVIPersonSID
		,PreferredName = CASE WHEN PreferredName LIKE CONCAT(FirstName,MiddleName,'%') AND LEN(PreferredName)>2 THEN CONCAT(FirstName,' ',MiddleName)
			ELSE PreferredName END
	INTO #PreferredName
	FROM SVeteran.SMVIPerson WITH (NOLOCK)
	WHERE PreferredName NOT IN ('SAME', 'NO', 'N', 'Y','UNSPECIFIED', 'UNDISCLOSED', 'UNANSWERED', 'UNANSERED', 'UN', 'UNNOWN', 'NOONE GIVEN')
	AND PreferredName NOT LIKE 'UNK%'
	AND PreferredName NOT LIKE 'UKN%'
	AND PreferredName NOT LIKE 'NONE%'
	AND PreferredName NOT LIKE 'NOT%'
	AND PreferredName NOT LIKE 'NO %'
	AND PreferredName <> FirstName
	AND PreferredName <> LastName
	AND PreferredName <> CONCAT(FirstName, ' ', LastName)
	AND PreferredName <> CONCAT(FirstName, ' ', MiddleName, ' ', LastName)
	AND PreferredName <> CONCAT(LastName, ' ', FirstName)
	AND PreferredName <> CONCAT(LastName, ' ', FirstName, ' ', MiddleName)
	AND PreferredName <> CONCAT(LastName, ', ', FirstName)
	AND PreferredName <> CONCAT(LastName, ', ', FirstName, ' ', MiddleName)
	AND PreferredName NOT LIKE CONCAT(FirstName,LastName,'%')
	AND PreferredName NOT LIKE CONCAT(LastName,FirstName,'%')
	AND PreferredName NOT LIKE CONCAT(LastName,MiddleName,'%')
	

	---------------------------------------------------------------------------------
	-- Race/Ethnicity
	---------------------------------------------------------------------------------
	DROP TABLE IF EXISTS #OHERace
	SELECT DISTINCT MVIPersonSID
		,Ethnicity
		,Race as RaceLabel 
		,CASE WHEN Combined_RaceEthnicity = 'Unknown' THEN 'Unknown' 
			ELSE REPLACE(LTRIM(CONCAT( AIAN,ASIAN,BLACK,NHOPI,WHITE,HISP)),'  ',', ') END AS Race
	INTO #OHERace
	FROM (
	SELECT MVIPersonSID
		,Combined_RaceEthnicity
		,Ethnicity
		,Race
		,CASE WHEN AIAN =1	THEN '  AMERICAN INDIAN OR ALASKA NATIVE'			END AIAN
		,CASE WHEN ASIAN =1 THEN '  ASIAN'										END ASIAN
		,CASE WHEN BLACK =1 THEN '  BLACK OR AFRICAN AMERICAN'					END BLACK
		,CASE WHEN NHOPI =1 THEN '  NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER'	END NHOPI
		,CASE WHEN WHITE =1 THEN '  WHITE'										END WHITE
		,CASE WHEN HISP =1	THEN '  HISPANIC OR LATINO'							END HISP
	FROM PDW.OHE_Consortium_RaceEthnicity as a WITH (NOLOCK)
	INNER JOIN Common.MVIPersonSIDPatientPersonSID as b WITH (NOLOCK) on a.PatientICN = b.PatientICN
	) as a 

	---------------------------------------------------------------------------------
	-- COMBINE EHR AND MVI DATA, STAGE AND PUBLISH
	---------------------------------------------------------------------------------
	DROP TABLE IF EXISTS #StageMasterPatientVM
	SELECT mv.MVIPersonSID
		,PatientICN				= mv.MVIPersonICN
		,PatientSSN				= ISNULL(mv.PersonSSN,p.PatientSSN)
		,e.EDIPI
		,mv.LastName
		,mv.FirstName
		,mv.MiddleName
		,mv.NameSuffix
		,PreferredName			= ISNULL(pn.PreferredName,p.PreferredName)
		,PatientName			= RTRIM(CONCAT(mv.LastName,', ',mv.FirstName,' ',mv.MiddleName))
		,LastFour				= RIGHT(ISNULL(mv.PersonSSN,p.PatientSSN),4)
		,NameFour				= LEFT(mv.LastName,1)+RIGHT(ISNULL(mv.PersonSSN,p.PatientSSN),4)
		,PatientSSN_Hyphen		= SUBSTRING(ISNULL(mv.PersonSSN,p.PatientSSN),0,4) +'-' + SUBSTRING(ISNULL(mv.PersonSSN,p.PatientSSN),4,2)+'-'+SUBSTRING(ISNULL(mv.PersonSSN,p.PatientSSN),6,4)	
		,DateOfBirth			= CAST(ISNULL(mv.BirthDateTime,p.DateOfBirth) AS DATE)
		,p.DateOfDeath
		,DateOfDeath_SVeteran	= mv.DeathDateTime
		,DateOfDeath_Combined	= CAST(ISNULL(mv.DeathDateTime,p.DateOfDeath) AS DATE) --Use MVI data unless CDW SPatient has a death date and MVIPerson does NOT
		,Age					= (CONVERT(INT,CONVERT(CHAR(8),ISNULL(CAST(mv.DeathDateTime AS DATE),GETDATE()),112))-CONVERT(CHAR(8),ISNULL(mv.BirthDateTime,p.DateOfBirth),112))/10000
		,Gender					= CASE WHEN mv.Gender IN ('M','F') THEN mv.Gender ELSE NULL END --getting rid of "unknown at this time" and "missing"
		,mv.SelfIdentifiedGender
		,DisplayGender			= ISNULL(CASE WHEN mv.SelfIdentifiedGender='*Unknown at this time*' THEN NULL ELSE mv.SelfIdentifiedGender END ,CASE WHEN mv.Gender='M' THEN 'Male' WHEN mv.Gender='F' THEN 'Female' ELSE NULL END)
		,Pronouns				= ISNULL(pr.Pronouns,p.Pronouns)
		,SexualOrientation		= ISNULL(s.SexualOrientation,p.SexualOrientation)
		,MaritalStatus			= ISNULL(CASE WHEN mv.MVIMaritalStatusSID IN (-1,0) THEN NULL ELSE ms.MaritalStatus END,p.MaritalStatus)
		,Veteran				= CASE WHEN p.Veteran = 1 OR v.VeteranFlag = 1 THEN 1 ELSE ISNULL(p.Veteran, v.VeteranFlag) END
		,SensitiveFlag			= CASE WHEN p.SensitiveFlag = 1 OR v.SensitiveFlag = 1 THEN 1 ELSE ISNULL(p.SensitiveFlag, v.SensitiveFlag) END
		
			--Checks to see if a Patient is enrolled in VHA Benefits and has a Valid PriorityGroup. A Valid Priority group is 1-8
		,CASE WHEN (pg.EnrollCategoryName = 'Enrolled' AND pg.EnrollStatusName = 'Verified' AND pg.ADRPriorityGroupSID BETWEEN 1 AND 8) THEN 'Eligible Veteran'
			/* Checks to see if a Patient is enrolled in VHA Benefits and DOESN'T have a Valid Priority Group and checks if Veteran Flag is Yes and ActiveDuty flag is No or null.
			or checks if Veteran Flag is Yes and ActiveDuty flag is yes, ActiveDutyDate has to be before RecordModifiedDate.
			This statement checks when both VeteranFlag and ActiveDutyFlag is yes, if the ActiveDutyDate is before the RecordModifiedDate we assume that they just haven't updated the ActiveDutyFlag which makes the veteranflag more reliable.
			OR
			Checks to see if the EnrollStatusName is not 'Verified', 'Deceased', or null. It also checks to see if EnrollCategoryName is not 'Enrolled' or null.
			This means that the patient is not enrolled in VHA Benefits. It then checks for Veteran Status.
			First, it checks if Veteran Flag is Yes and ActiveDuty flag is No or null. Then, it checks if Veteran Flag is Yes and ActiveDuty flag is yes, ActiveDutyDate has to be before RecordModifiedDate.
			This statement checks when both VeteranFlag and ActiveDutyFlag is yes, if the ActiveDutyDate is before the RecordModifiedDate we assume that they just haven't updated the ActiveDutyFlag which makes the veteranflag more reliable.
			*/
			WHEN (((pg.EnrollCategoryName = 'Enrolled' AND pg.EnrollStatusName = 'Verified') AND (pg.ADRPriorityGroupSID NOT BETWEEN 1 AND 8 OR pg.ADRPriorityGroupSID IS NULL))
					AND ((v.VeteranFlag = 1  AND (v.ActiveDutyFlag = 0 OR v.ActiveDutyFlag IS NULL)) 
						OR (v.VeteranFlag = 1 AND v.ActiveDutyFlag = 1 AND v.ActiveDutyDate < pg.RecordModifiedDate)))
				OR ((((pg.EnrollStatusName NOT LIKE 'Verified' AND (pg.EnrollStatusName NOT LIKE 'Deceased' OR pg.EnrollStatusName IS NULL)) OR pg.EnrollStatusName IS NULL) AND (pg.EnrollCategoryName <> 'Enrolled' OR pg.EnrollCategoryName IS NULL)) 
					AND ((v.VeteranFlag = 1  AND (v.ActiveDutyFlag = 0 OR v.ActiveDutyFlag is null)) 
						OR(v.VeteranFlag = 1 AND v.ActiveDutyFlag = 1 AND v.ActiveDutyDate < pg.RecordModifiedDate))) then 'Ineligible Veteran'
			/* Checks to see if the EnrollStatusName is not 'Verified', 'Deceased', or null. It also checks to see if EnrollCategoryName is not 'Enrolled' or null.
			This means that the patient is not enrolled in VHA Benefits
			We then check to see if ActiveDutyFlag is Yes. 
			This means that the patient is not eligible for VHA benfits and is currently active military */
			WHEN (((pg.EnrollStatusName NOT LIKE 'Verified' and pg.EnrollStatusName NOT LIKE 'Deceased') OR pg.EnrollStatusName IS NULL) AND (pg.EnrollCategoryName <> 'Enrolled' OR pg.EnrollCategoryName IS NULL)) 
				AND v.ActiveDutyFlag = 1 then 'Ineligible Active Duty'
			/*Checks to see if the EnrollStatusName is Deceased
			This means that the patient is no longer eligible VHA benefits and is deceased */
			WHEN pg.EnrollStatusName LIKE 'Deceased' THEN 'Ineligible Deceased'
			/* This means that the patient is not eligible and they are not a Veteran or Active Military. */
			ELSE 'Ineligible Other'
			END AS VHAEligibilityFlag
		
		
		,p.PossibleTestPatient
		,TestPatient =			CASE WHEN mv.MVIPersonICN IN ('1011494520','1011525934','1011547668','1011555358','1011566187','1013673699','1015801211','1015811652'
																,'1017268821','1018177176','1019376947','1011530765','1016996220'
								)  THEN 1 
								WHEN mv.TestRecordIndicatorCode IN ('A','T','U') THEN 1 --local or enterprise test records in MPI
								ELSE p.TestPatient END
		,ISNULL(OHE.Race,p.Race) as Race
		,PatientHeight			= h.FieldValue
		,HeightDate				= h.FieldModifiedDateTime
		,PatientWeight			= w.FieldValue
		,WeightDate				= w.FieldModifiedDateTime
		,p.PercentServiceConnect
		,p.ServiceSeparationDate
		,ml.PeriodOfService
		,ml.BranchOfService
		,ml.OEFOIFStatus
		,PriorityGroup			= pg.ADRPriorityGroupSID
		,PrioritySubGroup		= pg.PrioritySubGroupName
		,CompactEligible		= CASE WHEN c.CompactEligible = 1 THEN 1 ELSE 0 END
		,p.Homeless
		,p.Hospice
		,ehr.SourceEHR
	INTO #StageMasterPatientVM
	FROM [SVeteran].[SMVIPerson] mv WITH (NOLOCK)
	INNER JOIN [NDim].[MVIMaritalStatus] ms WITH (NOLOCK) 
		ON mv.MVIMaritalStatusSID = ms.MVIMaritalStatusSID
	INNER JOIN #SourceEHR ehr 
		ON ehr.MVIPersonSID = mv.MVIPersonSID
	INNER JOIN #PivotMP p 
		ON p.MVIPersonSID = mv.MVIPersonSID
	LEFT JOIN #MilitaryService ml 
		ON mv.MVIPersonSID = ml.MVIPersonSID
	LEFT JOIN #ADRPriority pg 
		ON mv.MVIPersonSID = pg.MVIPersonSID
	LEFT JOIN #EDIPI e
		ON mv.MVIPersonSID = e.MVIPersonSID
	LEFT JOIN #ADR_Veteran v
		ON mv.MVIPersonSID = v.MVIPersonSID
	LEFT JOIN #SexualOrientation s
		ON mv.MVIPersonSID = s.MVIPersonSID
	LEFT JOIN #Pronouns pr
		ON mv.MVIPersonSID = pr.MVIPersonSID
	LEFT JOIN #PreferredName pn
		ON mv.MVIPersonSID = pn.MVIPersonSID
	LEFT JOIN #COMPACT c
		ON mv.MVIPersonSID = c.MVIPersonSID
	LEFT JOIN (SELECT * FROM #HeightWeightDates WHERE MasterPatientFieldName = 'PatientHeight') h
		ON mv.MVIPersonSID = h.MVIPersonSID
	LEFT JOIN (SELECT * FROM #HeightWeightDates WHERE MasterPatientFieldName = 'PatientWeight') w
		ON mv.MVIPersonSID = w.MVIPersonSID
	LEFT JOIN #OHERace AS OHE 
		ON mv.MVIPersonSID = OHE.MVIPersonSID
	WHERE (
		p.PossibleTestPatient=0 
		OR p.PossibleTestPatient IS NULL 
		--manually including patients we know are real, and have had HRF flag or REACH VET. Later we may include all possible test patients
		OR mv.MVIPersonICN in ('1002965733','1001330531','1042450426','1014420023','1009242966','1050031552','1004949232')
		--test patients for CRISTAL and STORM
		OR mv.MVIPersonICN IN (
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
		)

DROP TABLE IF EXISTS #SourceEHR
DROP TABLE IF EXISTS #PivotMP
DROP TABLE IF EXISTS #EDIPI
DROP TABLE IF EXISTS #MilitaryService
DROP TABLE IF EXISTS #ADRPriority
DROP TABLE IF EXISTS #COMPACT
DROP TABLE IF EXISTS #ADR_Veteran
DROP TABLE IF EXISTS #SexualOrientation
DROP TABLE IF EXISTS #Pronouns
DROP TABLE IF EXISTS #PreferredName
DROP TABLE IF EXISTS #OHERace
DROP TABLE IF EXISTS #HeightWeightDates


DROP TABLE IF EXISTS #StageMasterPatientVM2
SELECT DISTINCT MVIPersonSID
		,PatientICN
		,PatientSSN	
		,EDIPI
		,LastName
		,FirstName
		,MiddleName
		,NameSuffix
		,PreferredName
		,PatientName
		,LastFour			
		,NameFour				
		,PatientSSN_Hyphen		
		,DateOfBirth			
		,DateOfDeath
		,DateOfDeath_SVeteran	
		,DateOfDeath_Combined	
		,Age					
		,Gender					
		,SelfIdentifiedGender
		,DisplayGender			
		,Pronouns				
		,SexualOrientation		
		,MaritalStatus			
		,Veteran				
		,SensitiveFlag	
		,VHAEligibilityFlag
		,PossibleTestPatient
		,TestPatient				
		,Race
		,PatientHeight
		,HeightDate				
		,PatientWeight
		,WeightDate		
		,CASE WHEN PercentServiceConnect=-1 AND Veteran=0 AND (PriorityGroup IS NULL OR PriorityGroup=-1) THEN NULL
			WHEN PercentServiceConnect=-1 THEN 'NSC'
			WHEN PercentServiceConnect IS NOT NULL THEN CONCAT(PercentServiceConnect,'%')
			ELSE NULL END AS PercentServiceConnect
		,ServiceSeparationDate
		,PeriodOfService
		,BranchOfService
		,OEFOIFStatus
		,PriorityGroup			
		,PrioritySubGroup		
		,CompactEligible		
		,Homeless
		,Hospice
		,SourceEHR
	INTO #StageMasterPatientVM2
	FROM #StageMasterPatientVM a

	
DROP TABLE IF EXISTS #StageMasterPatientVM

--Identify patients who have any records where DoDFlag=0 (VA patients) vs all records with DoDFlag=1 (DoD only)
DROP TABLE IF EXISTS #DoDFlag
SELECT DISTINCT a.MVIPersonSID, MIN(DoDFlag) DoDFlag
INTO #DoDFlag
FROM #StageMasterPatientVM2 a WITH (NOLOCK)
INNER JOIN (
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactAppointment WITH (NOLOCK) WHERE StaPa IS NOT NULL 
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactBHL WITH (NOLOCK) WHERE StaPa IS NOT NULL
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactDiagnosis WITH (NOLOCK) WHERE StaPa IS NOT NULL 
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactImmunization WITH (NOLOCK) WHERE StaPa IS NOT NULL 
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactInpatient WITH (NOLOCK) WHERE StaPa IS NOT NULL
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactInpatientSpecialtyTransfer WITH (NOLOCK) WHERE StaPa IS NOT NULL
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactLabResult WITH (NOLOCK) WHERE StaPa IS NOT NULL 
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactNoteTitle WITH (NOLOCK) WHERE StaPa IS NOT NULL 
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactPharmacyBCMA WITH (NOLOCK) WHERE StaPa IS NOT NULL
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactPharmacyClinicOrderDispensed WITH (NOLOCK) WHERE StaPa IS NOT NULL
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactPharmacyInpatientDispensed WITH (NOLOCK) WHERE StaPa IS NOT NULL
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactPharmacyInpatientOrder WITH (NOLOCK) WHERE StaPa IS NOT NULL
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactPharmacyNonVAMedOrder WITH (NOLOCK) WHERE StaPa IS NOT NULL
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactPharmacyOutpatientDispensed WITH (NOLOCK) WHERE StaPa IS NOT NULL
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactPharmacyOutpatientOrder WITH (NOLOCK) WHERE StaPa IS NOT NULL
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactPowerForm WITH (NOLOCK) WHERE StaPa IS NOT NULL
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactProcedure WITH (NOLOCK) WHERE StaPa IS NOT NULL
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactUtilizationOutpatient WITH (NOLOCK) WHERE StaPa IS NOT NULL 
UNION 
SELECT DISTINCT MVIPersonSID, DoDFlag FROM Cerner.FactVitalSign WITH (NOLOCK) WHERE StaPa IS NOT NULL
)b
ON a.MVIPersonSID=b.MVIPersonSID
GROUP BY a.MVIPersonSID

--Drop patients who have no VistA records and whose Cerner records all have DoDFlag=1
DELETE FROM #StageMasterPatientVM2
WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM #DoDFlag WHERE DoDFlag=1)
AND SourceEHR='M'

/*********************************************************************************************************************
Prevent table from updating if the patient count is lower than it was the last time it was published.
Row counts generally increase by a few hundred to a few thousand each run due to new enrollees, etc.
Patient population (combined current and historic) should not shrink. Decreases likely mean incomplete data at run time.
**********************************************************************************************************************/

DECLARE @LastRunCount BIGINT = (SELECT COUNT_BIG(*) FROM [Common].[MasterPatient_Patient] WITH (NOLOCK))
DECLARE @CurrentCount BIGINT = (SELECT COUNT_BIG(*) FROM #StageMasterPatientVM2)

IF	@CurrentCount < @LastRunCount
	
BEGIN 
	DECLARE @ErrorMsg2 varchar(500)= 'Row count insufficient to proceed with Code.Common_MasterPatient'
	EXEC [Log].[Message] 'Error','Row Counts',@ErrorMsg2
	EXEC [Log].[ExecutionEnd] @Status='Error' --Log end in case of error
	PRINT @ErrorMsg2;
	THROW 51000,@ErrorMsg2,1
END


	EXEC [Maintenance].[PublishTable] 'Common.MasterPatient_Patient','#StageMasterPatientVM2'


	--TRUNCATE TABLE [Stage].[MasterPatientVistA]
	--TRUNCATE TABLE [Stage].[MasterPatientMill]
	
	DROP TABLE IF EXISTS #StageMasterPatientVM2

	EXEC [Log].[ExecutionEnd]

END