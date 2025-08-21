



-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	5/6/2025
-- Description:	To be used as Dim source for Power BI star schema model. Will have
--				indicators for patient level case factors and demographics as related 
--				to case finder cohort. Will also include dates for most recent
--				mental health (MostRecentMH), primary care (MostRecentPC), 
--				emergency dept (MostRecentED) and inpatient (MostRecentInpt).
--				
--				There CANNOT be any row duplication in this dataset.
--
--				Code adapted from [App].[SUD_CaseFinderCohort_PBI].
--
-- Modifications:
-- 6/9/2025  CW  Adding in Demo patients from view 
--
-- =======================================================================================================

CREATE VIEW [App].[SUDCaseFinder_Cohort_PBI] AS

	--CohortPrep: Deriving general demographics for SUD case finder cohort; ensuring no row duplication with this first step
	WITH CohortPrep AS (
	SELECT
		 MVIPersonSID
		,PatientICN
		,SUDDxPastYear=MAX(SUDDxPastYear)
		,SUDDx=MAX(SUDDx)
	FROM SUD.CaseFinderCohort WITH (NOLOCK)
	GROUP BY MVIPersonSID, PatientICN
	),

	--Cohort: adding in demographics for the PBI report
	Cohort AS (
	SELECT 
		 MVIPersonSID
		,FullPatientName
		,PatientICN
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
		,CASE WHEN DisplayGender='Man' THEN 'Male'
			  WHEN DisplayGender='Woman' THEN 'Female'
			  WHEN DisplayGender='Transgender Man' THEN 'Transgender Male'
			  WHEN DisplayGender='Transgender Woman' THEN 'Transgender Female'
			  ELSE DisplayGender
		 END AS DisplayGender
		,Race
		,PeriodOfService
		,PhoneNumber
		,CASE WHEN (PriorityGroup NOT IN (1,2,3,4,5,6,7,8) OR PrioritySubGroup IN ('e','g')) AND COMPACTEligible=1 THEN 'COMPACT Eligible Only' 
			  WHEN (PriorityGroup IN (1,2,3,4,5,6,7,8) AND PrioritySubGroup NOT IN ('e','g')) AND COMPACTEligible=1 THEN 'COMPACT Eligible'
			  ELSE 'Not Verified as COMPACT Eligible'
		 END AS COMPACTEligible
		,PriorityGroup
		,PrioritySubGroup
		,ServiceSeparationDate
		,Zip
		,DoDSlicer
		,SUDDxSlicer
	FROM (
			SELECT DISTINCT
				 c.MVIPersonSID
				,c.PatientICN
				,mp.Age
				,mp.BranchOfService
				,mp.DisplayGender
				,mp.Race
				,mp.PeriodOfService
				,mp.COMPACTEligible
				,mp.PriorityGroup
				,mp.PrioritySubGroup
				,ServiceSeparationDate
				,mp.Zip
				,mp.PhoneNumber
				,DoDSlicer=
					CASE WHEN mp.ServiceSeparationDate <= GETDATE() AND mp.ServiceSeparationDate >= DATEADD(YEAR,-1,CAST(GETDATE() as date)) THEN 'DoD Separation - Past Year' 
							WHEN mp.ServiceSeparationDate IS NULL THEN 'No DoD Separation Date on File'
							ELSE 'DoD Separation - Over Year Ago' END
				,SUDDxSlicer=
					CASE WHEN c.SUDDxPastYear=1 THEN 'Substance Use Disorder - Past Year' 
							WHEN c.SUDDx=1 THEN 'Substance Use Disorder - Past 5 Years (Excluding Past Year)'
							ELSE 'Rule / Out Recent Substance Use' END
				,FullPatientName=CONCAT(mp.PatientName,' (',mp.LastFour,')')
			FROM CohortPrep c WITH (NOLOCK)
			LEFT JOIN Common.MasterPatient mp WITH (NOLOCK)	
				ON c.MVIPersonSID=mp.MVIPersonSID
			LEFT JOIN Common.MVIPersonSIDPatientPersonSID psid WITH (NOLOCK)
				ON mp.MVIPersonSID=psid.MVIPersonSID) Src
	),

	--RiskFactorCount: Getting count for column labeled "Est. Priority", which helps providers sort based on level of risk
	RiskFactorCount AS (
	SELECT DISTINCT MVIPersonSID, COUNT(DISTINCT RiskType) RiskTypeCount
	FROM SUD.CaseFinderRisk WITH (NOLOCK)	
	WHERE SortKey NOT IN (13,14,15,23,24)
	GROUP BY MVIPersonSID)
	,

	--Inpatient: Getting most recent inpatient admit, will be highlighting current admissions (Census=1) in PBI report
	Inpatient AS (
	--Prioritize current admissions, followed by most recent discharge date
	SELECT TOP (1) WITH TIES
		 c.MVIPersonSID
		,i.DischargeDateTime
		,i.Census
		,MostRecentInpat= --When census=1, output current date (will highlight in color in the report as well)
			CASE WHEN Census=1 THEN cast(GETDATE() as date) ELSE cast(DischargeDateTime as date) END 
	FROM SUD.CaseFinderCohort AS c WITH (NOLOCK)	
	INNER JOIN Inpatient.BedSection i WITH (NOLOCK)	
		ON c.MVIPersonSID=i.MVIPersonSID
	WHERE (DischargeDateTime >= DATEADD(year,-1,GETDATE()) OR Census = 1)
	ORDER BY ROW_NUMBER() OVER (PARTITION BY c.MVIPersonSID ORDER BY (CASE WHEN Census=1 THEN 1 ELSE 0 END) DESC, DischargeDateTime DESC)
	),

	--Outpat: Most recent outpatient visits for mental health, primary care, and emergency department
	Outpat AS (
	SELECT MVIPersonSID
		,MostRecentMH=CAST(MAX(MostRecentMH) as DATE)
		,MostRecentPC=CAST(MAX(MostRecentPC) as DATE)
		,MostRecentED=CAST(MAX(MostRecentED) as DATE)
	FROM (	SELECT MVIPersonSID
				,MostRecentMH=CASE WHEN ApptCategory='MHRecent' THEN maxVisitDateTime ELSE NULL END
				,MostRecentPC=CASE WHEN ApptCategory='PCRecent' THEN maxVisitDateTime ELSE NULL END
				,MostRecentED=CASE WHEN ApptCategory='EDRecent' THEN maxVisitDateTime ELSE NULL END	
			FROM (	SELECT c.MVIPersonSID
						,a.ApptCategory
						,maxVisitDateTime=MAX(VisitDateTime)
					FROM SUD.CaseFinderCohort AS c WITH (NOLOCK)	
					INNER JOIN Present.AppointmentsPast a WITH (NOLOCK)	
						ON c.MVIPersonSID=a.MVIPersonSID
					WHERE ApptCategory IN ('MHRecent', 'PCRecent', 'EDRecent') AND MostRecent_ICN=1
					GROUP BY c.MVIPersonSID, a.ApptCategory
				 ) Src
		 ) Src2
	GROUP BY MVIPersonSID),

	--Visits: Getting visit information for ApptRange slicer
	Visits AS (
	SELECT DISTINCT
		p.MVIPersonSID
		,VisitDateTime=MAX(VisitDateTime)
	FROM SUD.CaseFinderCohort AS p 
	LEFT JOIN ( SELECT MVIPersonSID, VisitDatetime, ApptCategory
				FROM [Present].[AppointmentsPast] WITH (NOLOCK)
				WHERE (ApptCategory IN ('MHRecent','PCRecent'))
				AND MostRecent_ICN=1) as a
			ON a.MVIPersonSID = p.MVIPersonSID
	GROUP BY p.MVIPersonSID),

	--ApptRange: Creating slicer values re: Last Mental Health or Primary Care Visit
	ApptRange AS (
	SELECT MVIPersonSID
		,VisitSlicer
		,VisitSlicerSort=CASE WHEN VisitSlicer='None in Past Year' THEN 1
						 WHEN VisitSlicer='Past 3 Months' THEN 2
						 WHEN VisitSlicer='Past 6 Months' THEN 3
						 WHEN VisitSlicer='Past Year' THEN 4 --changing order
						 END
	FROM (
		SELECT MVIPersonSID
			,VisitSlicer=
				CASE WHEN VisitDateTime >= DATEADD(day, -90, GETDATE()) THEN 'Past 3 Months'
					 WHEN VisitDateTime >= DATEADD(day, -180, GETDATE()) THEN 'Past 6 Months'
					 WHEN VisitDateTime >= DATEADD(day, -365, GETDATE()) THEN 'Past Year'
					 ELSE 'None in Past Year' END
		FROM Visits) Src
	),

	--Test patient demographics for visuals
	TestPatients AS (
	SELECT DISTINCT
		 MVIPersonSID
		,PatientICN
		,FullPatientName
		,Age
		,AgeSort
		,AgeCategory
		,BranchOfService
		,DisplayGender
		,Race
		,PeriodOfService
		,PhoneNumber
		,COMPACTEligible
		,PriorityGroup
		,PrioritySubGroup
		,ServiceSeparationDate
		,Zip
		,DoDSlicer
		,SUDDxSlicer
		,AppointmentDate
		,Census
		,VisitSlicer
		,VisitSlicerSort
		,RiskTypeCount
		,ReportMode
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)
	)

	--Final table for Power BI report
	SELECT 
		 c.MVIPersonSID
		,c.FullPatientName
		,c.PatientICN
		,c.AgeSort
		,c.AgeCategory		
		,c.BranchOfService
		,c.DisplayGender
		,c.Race
		,c.PeriodOfService
		,c.PhoneNumber
		,c.COMPACTEligible
		,c.PriorityGroup
		,c.PrioritySubGroup
		,c.ServiceSeparationDate
		,c.Zip
		,c.DoDSlicer
		,c.SUDDxSlicer
		,o.MostRecentMH
		,o.MostRecentPC
		,o.MostRecentED
		,i.MostRecentInpat
		,i.Census
		,a.VisitSlicer
		,a.VisitSlicerSort
		,RiskTypeCount=ISNULL(r.RiskTypeCount,0)
		,ReportMode='All Data'
	FROM Cohort c
	LEFT JOIN RiskFactorCount r
		ON c.MVIPersonSID=r.MVIPersonSID
	LEFT JOIN Outpat o
		ON c.MVIPersonSID=o.MVIPersonSID
	LEFT JOIN Inpatient i
		ON c.MVIPersonSID=i.MVIPersonSID
	LEFT JOIN ApptRange a
		ON c.MVIPersonSID=a.MVIPersonSID

	UNION

	--Test patient data
	SELECT 
		 MVIPersonSID
		,FullPatientName
		,PatientICN
		,AgeSort
		,AgeCategory		
		,BranchOfService
		,DisplayGender
		,Race
		,PeriodOfService
		,PhoneNumber
		,COMPACTEligible
		,PriorityGroup
		,PrioritySubGroup
		,ServiceSeparationDate
		,Zip
		,DoDSlicer
		,SUDDxSlicer
		,MostRecentMH=AppointmentDate
		,MostRecentPC=AppointmentDate
		,MostRecentED=AppointmentDate
		,MostRecentInpat=AppointmentDate
		,Census
		,VisitSlicer
		,VisitSlicerSort
		,RiskTypeCount
		,ReportMode
	FROM TestPatients;