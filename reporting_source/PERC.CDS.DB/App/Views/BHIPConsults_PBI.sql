


-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	3/18/2025
-- Description:	To be used as Fact source in BHIP Care Coordination Power BI report.
--				Adapted from [App].[BHIP_Consults_PBI]
--
--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 7/29/2025  CW  Adding TestPatients
--
--
-- =======================================================================================================

CREATE VIEW [App].[BHIPConsults_PBI] AS

	SELECT MVIPersonSID
		,ToRequestServiceName
		,RequestDateTime
		,CPRSStatus
		,Facility
		,ProvisionalDiagnosis
		,ConsultActivityComment
		,ActivityDateTime
		,ActionFollowUp
		,Team
		,ChecklistID
		,PatientName
		,DateofBirth
		,LastFour
		,ReportMode='All Data'
	FROM BHIP.Consults_PBI
	UNION
	SELECT MVIPersonSID
		,BHIPToRequestServiceName
		,BHIPRequestDateTime
		,BHIPCPRSStatus
		,Facility
		,BHIPProvisionalDiagnosis
		,BHIPConsultActivityComment
		,BHIPActivityDateTime
		,ActionFollowUp='Follow Up Appointment'
		,Team
		,CheckListID
		,PatientName
		,DateOfBirth
		,LastFour
		,ReportMode
	FROM App.PBIReports_TestPatients