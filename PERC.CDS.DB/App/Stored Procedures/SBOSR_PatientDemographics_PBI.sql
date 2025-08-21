
-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	5/18/2023
-- Description:	Dataset for patient demographics in the Suicide Behavior and Overdose Summary Report. 
--				One to Many relationship with [App].[SBOSR_SDVDetails] in the report. To be used in PowerBI 
--				visuals (Clinical/Case Factors) as well as patient level data tables. 
--
--				No row duplication expected in this dataset.		
--				
-- Modifications:
--
-- 06-08-2023 CW  Changing main cohort data source to [SBOSR].[SDVDetails_PBI]
--				  Changing STORM data source to [SUD].[Cohort]
-- 10-24-2023 CW  Adding State to County				 
-- =======================================================================================================
CREATE PROCEDURE [App].[SBOSR_PatientDemographics_PBI]

AS
BEGIN
	
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #Cohort
	SELECT 
		 MVIPersonSID
		,SPANPatientID
		,PatientKey
		,CASE 
			WHEN age <20 THEN 1
			WHEN age between 20 and 39 THEN 2
			WHEN age between 40 and 59 THEN 3
			WHEN age between 60 and 79 THEN 4
			WHEN age between 80 and 99 THEN 5
			WHEN age>=100 THEN 6
			End AgeSort
		,CASE 
			WHEN age <20 THEN '<20'
			WHEN age between 20 and 39 THEN '20-39'
			WHEN age between 40 and 59 THEN '40-59'
			WHEN age between 60 and 79 THEN '60-79'
			WHEN age between 80 and 99 THEN '80-99'
			WHEN age>=100 THEN '100+'
			End AgeCategory		
		,BranchOfService
		,County
		,DateOfBirth
		,CASE WHEN DisplayGender='Man' THEN 'Male'
			  WHEN DisplayGender='Woman' THEN 'Female'
			  WHEN DisplayGender='Transgender Man' THEN 'Transgender Male'
			  WHEN DisplayGender='Transgender Woman' THEN 'Transgender Female'
			  ELSE DisplayGender
		 END AS DisplayGender
		,Race
		,ServiceSeparationDate
		,PeriodOfService
		,CASE WHEN (PriorityGroup NOT IN (1,2,3,4,5,6,7,8) OR PrioritySubGroup IN ('e','g')) AND COMPACTEligible=1 THEN 'COMPACT Eligible Only' 
			  WHEN (PriorityGroup IN (1,2,3,4,5,6,7,8) AND PrioritySubGroup NOT IN ('e','g')) AND COMPACTEligible=1 THEN 'COMPACT Eligible'
			  ELSE 'Not Verified as COMPACT Eligible'
		 END AS COMPACTEligible
		,STORM
	INTO #Cohort
	FROM (
			SELECT DISTINCT
				 c.MVIPersonSID
				,c.SPANPatientID
				,c.PatientKey
				,ISNULL(mp.DateOfBirth,CASE WHEN sp.DateOfBirth>'1900-01-01' THEN sp.DateOfBirth ELSE NULL END) AS DateOfBirth
				,mp.Age
				,mp.BranchOfService
				,County=CONCAT(ISNULL(mp.County,'Unreported County'), ', ', mp.State)
				,ISNULL(mp.DisplayGender,CASE WHEN sp.SexCode='M' THEN 'Male' WHEN sp.SexCode='F' THEN 'Female' ELSE NULL END) AS DisplayGender
				,mp.Race
				,mp.ServiceSeparationDate
				,mp.PeriodOfService
				,mp.COMPACTEligible
				,mp.PriorityGroup
				,mp.PrioritySubGroup
				,CASE WHEN a.STORM=1 THEN 1 ELSE 0 END AS STORM
			FROM SBOSR.SDVDetails_PBI c WITH (NOLOCK) 
			LEFT JOIN Common.MasterPatient mp WITH (NOLOCK)	
				ON c.MVIPersonSID=mp.MVIPersonSID				
			LEFT JOIN [PDW].[SpanExport_tbl_Patient] sp WITH (NOLOCK)
				ON c.SPANPatientID = sp.PatientID
			LEFT JOIN SUD.Cohort a WITH (NOLOCK)
				ON c.MVIPersonSID=a.MVIPersonSID
		) Src

	SELECT
		 MVIPersonSID
		,SPANPatientID
		,PatientKey
		,AgeSort
		,AgeCategory
		,BranchOfService
		,County
		,DateOfBirth
		,DisplayGender
		,Race
		,ServiceSeparationDate
		,PeriodOfService
		,COMPACTEligible
		,MAX(STORM) AS STORM
	FROM #Cohort
	GROUP BY MVIPersonSID,SPANPatientID,PatientKey,AgeSort,AgeCategory,BranchOfService,County,DateOfBirth,DisplayGender,Race,ServiceSeparationDate,PeriodOfService,COMPACTEligible

END