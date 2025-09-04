
/********************************************************************************************************************
DESCRIPTION: All Production and Development reports active in last year.
CREATED BY: Shalini Gupta
TEST: EXEC [App].[Monitoring_ActiveReports] 'Development'

10/22/2019: SG added SubReport column
2019-10-24	RAS	Added temp table to manually enter comments, instructions, etc. To be joined on ReportName.
2021-06-07	RAS Added detail for migration to new BISL server
2021-07-16  EC  Updated after migration
2023-02-07	RAS	Minor refactoring now that test URL changed from "Development" to "Test"
********************************************************************************************************************/

CREATE PROCEDURE [App].[Monitoring_ActiveReports]
	 @Environment VARCHAR(55)

AS
BEGIN
SET NOCOUNT ON

-- Enter manual comments, instructions, etc into temporary table.
DROP TABLE IF EXISTS #ReportDetails;
CREATE TABLE #ReportDetails(
	ReportName VARCHAR(150) NOT NULL
	,Comments VARCHAR(1000) NULL
	)
INSERT INTO #ReportDetails
VALUES ('CRISTAL_PatientDetails','Open from CRISTAL_PatientLookUp. Enter patient to look up, click on patient name when a list is returned, and make sure CRISTAL_PatientDetails opens with patient information.')
	,('EBPTemplates_Clinician_PDF', 'Open from EBP_Clinician. Click on "Export to PDF" link in top bar')
	,('EBPTemplates_Clinician','Click on provider name to make sure drill-through to Clinician_detail works')
	,('sub_HRF_PatientTracking_Appts','Open HRF_PatientTracking. Expand detail (click + by patient name) and make sure visit information displays')
	,('sub_PDE_PatientTracking_Appts','Open PDE_PatientTracking. Expand detail (click + by patient name) and make sure visit information displays')
	--REACH
	,('REACH_PatientDetails','Open REACH_FacilityMasterList. Click on patient name and make sure PatientDetails opens correctly. Review PatientDetails to ensure information on bottom section from Questions_Subreport and top middle section from Risk_Subreport is appearing')
	,('sub_Reach_PatientDetails_Questions','Open REACH_FacilityMasterList. Click on patient name to open REACH_PatientDetails. Review PatientDetails to ensure information on bottom section from Questions_Subreport is appearing')
	,('sub_Reach_PatientDetails_Risk','Open REACH_FacilityMasterList. Click on patient name to open REACH_PatientDetails. Review PatientDetails to ensure information in top middle section from Risk_Subreport is appearing')
	,('REACH_PatientTransfer','Open REACH_PatientDetails. Under Patient Status (bottom left), click on "Send then patient info" link used to tranfer patient.')
	,('REACH_FacilityMasterList_ErrorMessage','This is an empty report in case we need to quickly post an error message when the report is not working.')
	--ORM
	,('sub_ORM_DashboardUse','Open ORM_DashboardUse_National and make sure all 3 charts render correctly.')
	,('sub_ORM_DashboardUseYTD','Open ORM_DashboardUse_National and make sure all 3 charts render correctly.')
	,('ORM_Diagnosis','Drill-through. Open from PatientLookUp or ORM_PatientReport')
	,('ORM_PatientChartNote','Drill-through. Open from ORM_PatientReport')
	--Pharm
	,('LithiumPatientCohortWriteback','Writeback. Access from LithiumPatientCohort')
	,('AntidepressantMPRWriteback','Writeback. Access from AntidepressantMPR')


SELECT a.Environment
	,a.GroupName
	,a.ReportName 
	,a.ReportPath
	,ReportURL= CASE
		WHEN a.Environment = 'Production' THEN CONCAT('https://vaww.pbi.cdw.va.gov/PBIRS/pages/ReportViewer.aspx?/RVS/OMHSP_PERC/SSRS/',a.Environment,'/CDS/',a.GroupName,'/',a.ReportName)
		WHEN a.Environment = 'Test' THEN CONCAT('https://vaww.pbi.cdw.va.gov/PBI_RS/report/RVS/OMHSP_PERC/SSRS/',a.Environment,'/CDS/',a.GroupName,'/',a.ReportName)
		ELSE CONCAT('https://vaww.pbi.cdw.va.gov/PBI_RS/report/RVS/OMHSP_PERC/SSRS/',a.Environment,'/CDS/',a.GroupName,'/',a.ReportName)
		END
	,a.SubReport
	,d.Comments
FROM
(
    SELECT DISTINCT
		 Environment=SUBSTRING(rl.ReportPath,CHARINDEX('SSRS/',rl.ReportPath)+5,CHARINDEX('/CDS',rl.ReportPath)-21)
        ,GroupName= CASE WHEN rl.ReportPath LIKE '%Production%' THEN (RIGHT(rl.ReportPath,LEN(rl.ReportPath) - CHARINDEX('/',rl.ReportPath,34)))
			WHEN rl.ReportPath LIKE '%Test%' THEN (RIGHT(rl.ReportPath,LEN(rl.ReportPath) - CHARINDEX('/',rl.ReportPath,26)))
			ELSE 'Other' END
    	,ReportName = rl.ReportFileName
        ,rl.ReportPath
        ,SubReport = CASE 
			WHEN rl.ReportFileName like '%sub%' 
			THEN 'Yes' ELSE NULL END
    FROM [PDW].[BISL_SSRSLog_DOEx_ExecutionLog] el
    INNER JOIN [PDW].[BISL_SSRSLog_DOEx_Reports] rl ON el.ReportKey = rl.ReportKey
    WHERE el.TimeStart > DATEADD(YEAR, -1, GETDATE())
    	AND el.ReportAction in ('Render','DrillThrough','Execute')
    	AND rl.ReportPath like ('%RVS/OMHSP_PERC/SSRS/%') and rl.ReportPath like ('%CDS%') 
    ) as a
LEFT JOIN #ReportDetails as d ON d.ReportName = a.ReportName
WHERE (a.Environment = @Environment) 
ORDER BY a.Environment, a.ReportPath, a.ReportName

END