
-- =============================================
-- Author:		Amy Robinson/Pooja
-- Create date: 2018-05-30
-- Description:	Code to display errors or other messages at the top of reports.
				--To use, add this dataset to your report and copy the sample table from Admin.ReportTemplate into your report.

-- Testing:	EXEC [App].[Admin_ErrorNotice_v02] 'Test'

-- Updates
	--	2019-01-10 - Jason Bacani - Formatting; NOLOCKs
	--	2020-08-03 - RAS - V02 - Added report name parameter and pivoted table.  
						 --Allows simpler use in reports and can display multiple messages.
-- =============================================
CREATE PROCEDURE [App].[Admin_ErrorNotice_v02]
	@ErrorNoticeReportName VARCHAR(50)
AS
BEGIN
	SET NOCOUNT ON; 
  
	--For testing:
	--DECLARE @ErrorNoticeReportName VARCHAR(50) = 'REACH_MasterList'

	SELECT ErrorDate
		  ,ErrorDescription
		  ,CloseDate
		  ,ErrorNoticeReportName
		  ,DisplayKey
	FROM (
		SELECT ErrorDate
		  ,ErrorDescription
		  ,CloseDate
		  ,PDSI_FacilitySummary
		  ,PDSI_ProviderSummary
		  ,PDSI_PatientDetail
		  ,PDSI_PatientDetailQuickView
		  ,MH008
		  ,Antidepressant
		  ,AcademicDetailing
		  ,Lithium
		  ,Delirium
		  ,STORM_Summary
		  ,STORM_PatientDetail
		  ,STORM_PatientDetailQuickView
		  ,STORM_PatientLookup
		  ,HRF
		  ,HRF_NoteTitle
		  ,REACH_Summary
		  ,REACH_PatientDetail
		  ,REACH_MasterList
		  ,PDE
		  ,CRISTAL
		  ,EBP_Clinician
		  ,EBP_Summary
		  ,SPPRITE
		  ,Test
	FROM [Config].[ErrorNotice_v02] WITH (NOLOCK)
	) p
	UNPIVOT (DisplayKey FOR ErrorNoticeReportName IN (
		PDSI_FacilitySummary
		  ,PDSI_ProviderSummary
		  ,PDSI_PatientDetail
		  ,PDSI_PatientDetailQuickView
		  ,MH008
		  ,Antidepressant
		  ,AcademicDetailing
		  ,Lithium
		  ,Delirium
		  ,STORM_Summary
		  ,STORM_PatientDetail
		  ,STORM_PatientDetailQuickView
		  ,STORM_PatientLookup
		  ,HRF
		  ,HRF_NoteTitle
		  ,REACH_Summary
		  ,REACH_PatientDetail
		  ,REACH_MasterList
		  ,PDE
		  ,CRISTAL
		  ,EBP_Clinician
		  ,EBP_Summary
		  ,SPPRITE
		  ,Test
		  )
		) u

	WHERE ErrorDate <= GetDate()
		AND (CloseDate IS NULL or CloseDate > GetDate())
		AND DisplayKey=1
		AND ErrorNoticeReportName=@ErrorNoticeReportName
	ORDER BY ErrorDate DESC
  
END