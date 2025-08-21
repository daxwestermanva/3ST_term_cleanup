-- =============================================
-- Author: Bhavani Bandi 
-- Create date: 4/22/2017
-- Description: Main Data Set for the EBPTemplates_QuarterlySummary report
-- Modifications: 2017-11-30 RAS: Changed procedure and table names and updated report accordingly.
-- =============================================
/*  
	EXEC [App].[EBP_QuarterlySummary]
	@VISN  = 21,
	@TimePeriod = '2017-10-01,2017-07-01,2017-04-01,2017-01-01,2016-10-01',
	@Facility = '21,358,459,570,593,612,640,654,662',
	@Template = 'Any Dep Template,Any EBP Template,Any PTSD Template,Any SMI Template,ACT Template,BFT Template,CBT-D Template,CBT-I Template,CPT Template,IBCT Template,IPT-D Template,PE Template,SST Template'

*/
-- =============================================
--DROP PROCEDURE [App].[EBP_EBPTemplates_QuarterlySummary]

CREATE PROCEDURE [App].[EBP_QuarterlySummary]  
@VISN INT,
@TimePeriod VARCHAR(max),
@Facility VARCHAR(500) ,
@Template VARCHAR(500)

AS
BEGIN	
SET NOCOUNT ON

DECLARE @TimePeriodList TABLE (TimePeriod VARCHAR(max))
DECLARE @FacilityList TABLE (Facility VARCHAR (500))
DECLARE @TemplateList TABLE (Template VARCHAR(500))

INSERT @TimePeriodList	SELECT value FROM string_split(@TimePeriod, ',')
INSERT @FacilityList	SELECT value FROM string_split(@Facility, ',')
INSERT @TemplateList	SELECT value FROM string_split(@Template, ',')


SELECT * FROM EBP.QuarterlySummary --[App].[EBP_DashboardBaseTable_QuarterlySummary]
INNER JOIN @FacilityList AS f ON f.Facility = ChecklistID
INNER JOIN @TemplateList AS t ON t.Template = TemplateNameClean
INNER JOIN @TimePeriodList AS t1 ON cast(t1.TimePeriod as date) = cast([Date] as varchar)
WHERE VISN = @VISN
ORDER BY VISN,  [admparent_fcdm] DESC

END