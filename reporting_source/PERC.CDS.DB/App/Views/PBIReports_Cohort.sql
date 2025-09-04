


-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	3/24/2025
-- Description:	To be used as Dim source in CaseFactors and Clinical_Insights cross-drill Power BI report.
--				Code used to generate the data source is housed in [Code].[Common_PBIReportsCohort].
--
--				Row duplication is NOT expected in this dataset.
--
-- Modifications:
-- 5/15/2025 -- Adding in Demo Mode data; logic in line with SUD Case Finder Demo data
--
--
-- =======================================================================================================

CREATE VIEW [App].[PBIReports_Cohort] AS

	SELECT DISTINCT MVIPersonSID
		,PatientICN
		,FlowEligible
		,HomelessSlicer
		,FullPatientName
		,MailAddress
		,StreetAddress
		,MailCityState
		,PhoneNumber
		,Zip
		,AgeSort
		,AgeCategory
		,BranchOfService
		,DateOfBirth
		,DisplayGender
		,Race
		,ServiceSeparationDate
		,DoDSeprationType
		,PeriodOfService
		,COMPACTEligible
		,BHIPAssessment
	FROM Common.PBIReportsCohort WITH (NOLOCK)

	UNION

	SELECT DISTINCT MVIPersonSID
		,PatientICN
		,FlowEligible
		,HomelesSlicer
		,FullPatientName
		,MailAddress
		,StreetAddress
		,MailCityState
		,PhoneNumber
		,Zip
		,AgeSort
		,AgeCategory
		,BranchOfService
		,DateOfBirth
		,DisplayGender
		,Race
		,ServiceSeparationDate
		,DoDSeprationType
		,PeriodOfService
		,COMPACTEligible
		,BHIPAssessment
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)