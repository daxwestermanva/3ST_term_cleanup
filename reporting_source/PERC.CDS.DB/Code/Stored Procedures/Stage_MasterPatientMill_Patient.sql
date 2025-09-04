/*******************************************************************
DESCRIPTION: Master patient table to include PERC CDS business rules for patient information
TEST:
	EXEC [Code].[Stage_MasterPatientMill_Patient]
UPDATE:
	2020-08-21	RAS	Created code for Cerner Millenium data, modeled off previous version
	2020-10-26	RAS	Changed ActualVisitDateTime to DerivedVisitDateTime per source column change
	2020-11-30  CMH Added code to remove test patients from all fact tables
	2020-12-08	RAS	Added comments per validation feedback.
	2021-01-13  For Hospice, Accommodation = Null from [MillCDS].[FactUtilizationOutpatient] and changes related to [MillCDS].[FactPatientContactInfo]
	2022-01-06	RAS	Updated MaritalStatus logic to return "*Implied NULL*" as null value
	2024-05-21	LM	Added County from Millenium data; updated address logic to avoid combining columns from different addresses and reduce unmailable addresses
	2024-19-08  AER Adding FIPS
	2024-09-26  CMH Adding GISURH data
	2024-10-09	LM	Break contact info into separate procedure
DEPENDENCIES:
	-- [Config].[MasterPatientFields]
	-- [LookUp].[ICD10]
	-- [LookUp].[ListMember] (ActivityType MHOC_Homeless) 
	-- [Cerner].[FactPatientDemographic] 
	-- [Cerner].[FactVitalSign]
	-- [Cerner].[FactUtilizationOutpatient] 
	-- [Cerner].[FactDiagnosis]
	-- [Inpatient].[BedSection]
*******************************************************************/

CREATE PROCEDURE [Code].[Stage_MasterPatientMill_Patient]
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.Stage_MasterPatientMill_Patient','Execution of Code.Stage_MasterPatientMill_Patient SP'

DROP TABLE IF EXISTS #StageMasterPatient_Mill
CREATE TABLE #StageMasterPatient_Mill (
	MVIPersonSID INT NULL
	,FieldName VARCHAR(25) NOT NULL
	,FieldValue VARCHAR(200) NULL
	,FieldModifiedDateTime DATETIME2(0) NULL
	)
-----------------------------------------------------------------------------
-- Basic Demographics
-----------------------------------------------------------------------------
DROP TABLE IF EXISTS #Demog_Mill;
SELECT MVIPersonSID
		,PatientSSN=SSN
		,LastName=NameLast
		,FirstName=NameFirst
		,PatientName=NameFullFormatted
		,PreferredName
		,BirthDateTime
		,DeceasedDateTime
		,Gender=CASE WHEN Sex IN ('M','F') THEN Sex ELSE NULL END --getting rid of "unknown at this time" and "missing"
		,MaritalStatus = CASE WHEN MaritalTypeCodeValueSID = -2 THEN NULL ELSE MaritalType END
		,Race
		,SensitiveFlag=CASE WHEN MISSING_SensitiveFlag='Y' THEN 1 
			WHEN MISSING_SensitiveFlag<>'Y' THEN 0 
			ELSE NULL END --If SensitiveFlag is Y at any station then assume sensitive - MISSING FOR NOW
		,TestPatient=0 --setting to 0 because we are only retaining Cerner non-test patients
		,VeteranFlag=NULL
		,ModifiedDateTime
INTO #Demog_Mill
FROM [Cerner].[FactPatientDemographic] WITH(NOLOCK)

UPDATE #Demog_Mill
SET PreferredName = NULL
WHERE PreferredName IN ('SAME', 'NO', 'N', 'Y','UNSPECIFIED', 'UNDISCLOSED', 'UNANSWERED', 'UNANSERED', 'UN', 'UNNOWN', 'NOONE GIVEN')
	OR PreferredName LIKE 'UNK%'
	OR PreferredName LIKE 'UKN%'
	OR PreferredName LIKE 'NONE%'
	OR PreferredName LIKE 'NOT%'
	OR PreferredName LIKE 'NO %'
	OR PreferredName = FirstName
	OR PreferredName = LastName
	OR PreferredName = CONCAT(FirstName, ' ', LastName)
	OR PreferredName = CONCAT(LastName, ' ', FirstName)
	OR PreferredName = CONCAT(LastName, ', ', FirstName)
	OR PreferredName LIKE CONCAT(FirstName,LastName,'%')
	OR PreferredName LIKE CONCAT(LastName,FirstName,'%')

INSERT INTO #StageMasterPatient_Mill (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
SELECT MVIPersonSID
	,FieldName
	,FieldValue 
	,ModifiedDateTime
FROM (
	SELECT MVIPersonSID 
		,CAST(PatientSSN	 AS VARCHAR(100)) AS PatientSSN		
		,CAST(BirthDateTime AS VARCHAR(100)) AS DateOfBirth	
		,CAST(DeceasedDateTime AS VARCHAR(100)) AS DateOfDeath	
		,CAST(VeteranFlag AS VARCHAR(100)) AS Veteran
		,CAST(SensitiveFlag AS VARCHAR(100)) AS SensitiveFlag	
		,CAST(TestPatient AS VARCHAR(100)) AS TestPatient
		,CAST(Race AS VARCHAR(100)) AS Race
		,CAST(PreferredName AS VARCHAR(100)) AS PreferredName
		,ModifiedDateTime	
	FROM #Demog_Mill
	) ph
UNPIVOT (FieldValue FOR FieldName IN (
		PatientSSN		
		,DateOfBirth	
		,DateOfDeath	
		,Veteran	
		,SensitiveFlag	
		,TestPatient
		,Race
		,PreferredName
		)
	) u

DROP TABLE #Demog_Mill


-----------------------------------------------------------------------------
-- Patient Vitals --height and weight (within 5 years)
-----------------------------------------------------------------------------
--Weight - this is all in kg so convert to lbs (multiply by 2.2046)
INSERT INTO #StageMasterPatient_Mill (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
SELECT MVIPersonSID
	,'PatientWeight'
	,Weight
	,WeightDate
FROM (
	SELECT MVIPersonSID
		,Weight= CAST(FLOOR(DerivedResultValueNumeric * 2.2046) as varchar) + ' lbs'
		,CAST(TZPerformedUTCDateTime as date) as WeightDate
		,RN=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY TZPerformedUTCDateTime DESC)
	FROM [Cerner].[FactVitalSign] WITH (NOLOCK)
	WHERE Event in ('Weight Measured', 'Usual Weight', 'Adjusted Body Weight', 'Weight Estimated', 'Patient Stated Weight')
			AND DerivedResultValueNumeric IS NOT NULL
	) a
WHERE RN=1

--Height - in cm so convert to feet/inches (1 cm = 0.3937 inches)
INSERT INTO #StageMasterPatient_Mill (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
SELECT MVIPersonSID
	,'PatientHeight'
	,Height
	,HeightDate
FROM (
	SELECT MVIPersonSID
		,Height= CAST(FLOOR((DerivedResultValueNumeric * 0.3937)/12) as varchar) + 'ft '+ CAST(FLOOR((DerivedResultValueNumeric * 0.3937)-Floor(CAST((DerivedResultValueNumeric * 0.3937) as decimal)/12)*12) as varchar) +'in'
		,CAST(TZPerformedUTCDateTime as date) as HeightDate
		,RN=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY TZPerformedUTCDateTime DESC)
	FROM [Cerner].[FactVitalSign] WITH (NOLOCK)
	WHERE Event like '%Height%'
			AND DerivedResultValueNumeric IS NOT NULL
	) a
WHERE RN=1

-----------------------------------------------------------------------------
-- Percent Servcice Connectedness
-----------------------------------------------------------------------------
INSERT INTO #StageMasterPatient_Mill (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
SELECT MVIPersonSID
	,'PercentServiceConnect'
	,ServiceDisabilityPercent  
	,ServiceRltdDisabilityUpdateDTM 
FROM [Cerner].[FactPatientDemographic] WITH(NOLOCK)
WHERE ServiceDisability IS NOT NULL 

-----------------------------------------------------------------------------
-- Service Separation Date
-----------------------------------------------------------------------------
--DELETE #StageMasterPatient WHERE FieldName = 'ServiceSeparationDate'
--INSERT INTO #StageMasterPatient (MVIPersonSID,FieldName,FieldValue)
--SELECT MVIPersonSID
--	,'ServiceSeparationDate'
--	,MAX(ServiceSeparationDate)
--FROM ?? WITH(NOLOCK)
--GROUP BY MVIPersonSID
--HAVING MAX(ServiceSeparationDate) IS NOT NULL

-----------------------------------------------------------------------------
	-- Sexual Orientation and Pronouns
	-----------------------------------------------------------------------------
	--DELETE #StageMasterPatient WHERE FieldName = 'ServiceSeparationDate'
	DROP TABLE IF EXISTS #Pronouns
	SELECT DISTINCT a.MVIPersonSID
		,CASE WHEN a.OtherText IS NOT NULL THEN a.OtherText
			ELSE a.DerivedSourceString END AS PronounType
	INTO #Pronouns
	FROM [Cerner].[FactSocialHistory] a WITH (NOLOCK) 
	WHERE a.TaskAssay = 'SHX Preferred pronouns'
	AND a.ActiveIndicator=1

	INSERT INTO #StageMasterPatient_Mill (MVIPersonSID,FieldName,FieldValue)
	SELECT MVIPersonSID
		,'Pronouns' AS FieldName
		,LEFT(STRING_AGG(PronounType,', '),100) AS PronounType
	FROM #Pronouns
	GROUP BY MVIPersonSID

	DROP TABLE IF EXISTS #SexualOrientation
	SELECT DISTINCT a.MVIPersonSID
		,CASE WHEN a.DerivedSourceString LIKE 'Something else%' OR a.DerivedSourceString = '*Implied NULL*' THEN CONCAT('Other: ',a.OtherText)
			ELSE a.DerivedSourceString END AS DerivedSourceString
	INTO #SexualOrientation
	FROM [Cerner].[FactSocialHistory] a  WITH (NOLOCK)
	WHERE a.TaskAssay = 'SHX Sexual orientation'
	AND a.ActiveIndicator=1

	INSERT INTO #StageMasterPatient_Mill (MVIPersonSID,FieldName,FieldValue)
	SELECT MVIPersonSID
		,'SexualOrientation' AS FieldName
		,LEFT(STRING_AGG(DerivedSourceString,', ') WITHIN GROUP (ORDER BY CASE WHEN DerivedSourceString LIKE 'Other:%' THEN 2 ELSE 1 END),100) AS SexualOrientation
	FROM #SexualOrientation 
	GROUP BY MVIPersonSID

----------------------------------------------------------------------------------
--Homeless_CDS flag based on MHOC definition
----------------------------------------------------------------------------------
DECLARE @EndDate datetime2,@EndDate_1Yr date

SET @EndDate=dateadd(day, datediff(day, 0, getdate()),0)
SET @EndDate_1Yr=dateadd(day,-366,@EndDate)
  
INSERT INTO #StageMasterPatient_Mill (MVIPersonSID,FieldName,FieldValue)
SELECT DISTINCT 
	MVIPersonSID
	,'Homeless'
	,'1'
FROM (
	/*** Homeless ICD10 ***/
	SELECT MVIPersonSID 
	FROM [Cerner].[FactDiagnosis] as a WITH(NOLOCK)
	INNER JOIN [LookUp].[ICD10] as b on a.NomenclatureSID=b.[ICD10SID]
	WHERE TZDerivedDiagnosisDateTime >= @EndDate_1Yr 
		AND a.SourceVocabulary='ICD-10-CM'
		AND b.Homeless=1

	UNION ALL
	/***Homeless Stop Code per new MHOC definition ***/
	SELECT MVIPersonSID
	FROM [Cerner].[FactUtilizationOutpatient] o
	INNER JOIN [LookUp].[ListMember] l ON o.ActivityTypeCodeValueSID=l.ItemID
		AND TZDerivedVisitDateTime >= @EndDate_1Yr
	WHERE l.List='MHOC_Homeless'

	UNION ALL
	/** Homeless Bed Section **/
	(
	SELECT a.MVIPersonSID
	FROM [Cerner].[FactInpatient] a WITH (NOLOCK)
	INNER JOIN [LookUp].[TreatingSpecialty] b WITH (NOLOCK) on a.DerivedCodeValueSID=b.TreatingSpecialtySID
	WHERE b.Homeless_TreatingSpecialty=1 
			AND (a.TZDischargeDateTime >= @EndDate_1Yr OR a.TZDischargeDateTime IS NULL)
	UNION ALL
	SELECT a.MVIPersonSID
	FROM [Cerner].[FactInpatientSpecialtyTransfer] a WITH (NOLOCK)
	INNER JOIN [LookUp].[TreatingSpecialty] b WITH (NOLOCK) on a.DerivedCodeValueSID=b.TreatingSpecialtySID
	WHERE  (a.TZDerivedBeginEffectiveDateTime >= @EndDate_1Yr OR a.TZDerivedEndEffectiveDateTime >= @EndDate_1Yr OR a.TZDerivedEndEffectiveDateTime IS NULL)
	)
	) u

-----------------------------------------------------------------------------
-- Hospice care in past year
-----------------------------------------------------------------------------
INSERT INTO #StageMasterPatient_Mill (MVIPersonSID,FieldName,FieldValue,FieldModifiedDateTime)
SELECT MVIPersonSID
	,'Hospice'
	,'1'
	,MAX(TZDerivedVisitDateTime)	
FROM (
	SELECT MVIPersonSID
		,TZDerivedVisitDateTime
		,MedicalService
		,Accommodation = Null
		,HospiceCareFlag
	FROM [Cerner].[FactUtilizationOutpatient] WITH (NOLOCK)
	WHERE (HospiceCareFlag=1 
		OR MedicalService = 'Hospice'
		)
		AND TZDerivedVisitDateTime >= @EndDate_1Yr
		
	UNION ALL
	SELECT st.MVIPersonSID
		,st.TZDerivedBeginEffectiveDateTime
		,st.MedicalService
		,st.DerivedAccommodation as Accommodation
		,d.Specialty
	FROM [Cerner].[FactInpatientSpecialtyTransfer] st WITH (NOLOCK)
	LEFT JOIN [Cerner].[DimSpecialty] d WITH (NOLOCK) ON d.CodeValueSID=st.DerivedCodeValueSID
	WHERE (d.PTFCode IN ('96','1F') --hospice bedsections
		OR st.DerivedAccommodation = 'Hospice'
		OR st.MedicalService = 'Hospice'
		)
		AND TZDerivedBeginEffectiveDateTime >= @EndDate_1Yr
	) u
GROUP BY MVIPersonSID

-----------------------------------------------------------------------------
-- Stage and Publish
-----------------------------------------------------------------------------
	--Create table with all MVIPersonSIDs that will be included in final table
	----Get IDs for the patients who are defined in first section with test patient logic.
	----This TestPatiet FieldName is used to get the list of final patients because only this 
	----criteria will return EVERY patient because every patient has either a value 0 or 1.  
	----And it has already been filtered for the patients we want to keep in the table 
	----(mostly non-test patients)
	DROP TABLE IF EXISTS #ExcludeTest
	SELECT DISTINCT MVIPersonSID
	INTO #ExcludeTest
	FROM #StageMasterPatient_Mill
	WHERE FieldName = 'TestPatient' 
	
	--Join the above patient list with all of the patient data in #StageMasterPatient
	----This will filter out data for patients who are not real (e.g., an address for a test patient)
	DROP TABLE IF EXISTS #StageMPMill;
	SELECT st.MVIPersonSID
		,i.MasterPatientFieldID
		,st.FieldName AS MasterPatientFieldName
		,st.FieldValue
		,st.FieldModifiedDateTime
	INTO #StageMPMill
	FROM #StageMasterPatient_Mill st
	LEFT JOIN  [Config].[MasterPatientFields] i ON i.MasterPatientFieldName=st.FieldName
	INNER JOIN #ExcludeTest nt ON nt.MVIPersonSID=st.MVIPersonSID
	WHERE st.MVIPersonSID>0

--------------------------------------------
-- PUBLISH 
--------------------------------------------
EXEC [Maintenance].[PublishTable] 'Stage.MasterPatientMill_Patient','#StageMPMill'

EXEC [Log].[ExecutionEnd]
END