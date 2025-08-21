-- =============================================
-- Author: Elena Cherkasova
-- Create date: 4/21/2017
-- Description: Main Data Set for the EBPTemplates_MonthlySummary report
-- Updates
--	2018/08/27 - Jason Bacani - Fixed ambiguous column admparent_fcdm in ORDER BY statement
--  2023/12/01 - Elena - Added Insomnia Relevant Population
-- =============================================
/*  
	EXEC [App].[EBP_MonthlySummary]
	@VISN  = 21,
	@TimePeriod = '2017-11-01,2017-10-01', --2017-06-01,2017-05-07,2017-08-01,2017-01-01,2017-02-01,2017-03-01,2017-04-01,2017-05-01',
	@Facility = '640',--'21,358,459,570,593,612A4,640,654,662',
	@Template = 'Any Dep Template,Any EBP Template,Any PTSD Template,Any SMI Template,ACT Template,BFT Template,CBT-D Template,CBT-I Template,CPT Template,IBCT Template,IPT-D Template,PE Template,SST Template,CM Template'

*/
-- =============================================
CREATE PROCEDURE [App].[EBP_MonthlySummary] 
	@VISN INT,
	@TimePeriod VARCHAR(5000),
	@Facility VARCHAR(500) ,
	@Template VARCHAR(500)

AS
BEGIN	
SET NOCOUNT ON

DECLARE @TimePeriodList TABLE (TimePeriod VARCHAR(max))
DECLARE @FacilityList TABLE (Facility VARCHAR(50))
DECLARE @VISNList TABLE (VISN INT)
DECLARE @TemplateList TABLE (Template VARCHAR(21))

INSERT @TimePeriodList	SELECT value FROM string_split(@TimePeriod, ',')
INSERT @FacilityList	SELECT value FROM string_split(@Facility, ',')
INSERT @VISNList		SELECT value FROM string_split(CAST(@VISN AS VARCHAR),',')
INSERT @TemplateList	SELECT value FROM string_split(@Template, ',')

	--TO TEST FOR ALL STATIONS:
	-- comment out INSERT statements above and uncomment the code below
	/*
	INSERT @TimePeriodList	
		SELECT MAX(CAST([Date] AS DATE)) FROM [EBP].[FacilityMonthly]
	INSERT @VISNList
		SELECT DISTINCT VISN FROM [LookUp].[ChecklistID]
	INSERT @FacilityList 
		SELECT ChecklistID
		FROM [LookUp].[ChecklistID]
		WHERE FacilityLevelID = 3
	INSERT @TemplateList
		SELECT TemplateNameClean
		FROM [Config].[EBP_TemplateLookUp]
	*/
		--DROP TABLE IF EXISTS #ViewResults -- FOR TESTING
SELECT a.StaPa
	,a.admparent_fcdm
	,a.VISN
	,a.LocationOfFacility
	,a.TemplateName
	,a.TemplateValue
	,a.Date2
	,a.[Date]
	,a.[Month]
	,a.[Year]
	,a.TemplateNameClean
	,a.TemplateNameShort
	,a.PTSDKey
	,a.DepKey
	,a.SMIKey
	,a.SUDKey
	,a.InsomniaKey
	,YTDValue
	,TemplateOrder
	,Temp = 1 
	,b.TemplateValue AS NationalTemplateValue
	,b.PTSDkey AS NationalPTSDkey
	,b.Depkey AS NationalDepkey
	,b.SMIkey AS NationalSMIkey 
	,b.SUDkey AS NationalSUDkey
	,b.InsomniaKey AS NationalInsomniaKey
	--INTO #ViewResults -- FOR TESTING
FROM ( 
	SELECT m.StaPa 
		,m.AdmParent_FCDM
		,m.VISN
		,LocationOfFacility
		,m.TemplateName
		,m.TemplateValue
		,CONCAT(LEFT(m.[Month], 3), ' ', YEAR(DATE)) AS Date2
		,m.[Date]
		,m.[Month]
		,m.[Year]
		,m.TemplateNameShort
		,m.TemplateNameClean
		,PTSDKey = 0
		,DepKey = 0
		,SMIKey = 0
		,SUDKey = 0
		,InsomniaKey = 0
		,YTDValue = 0
	FROM [EBP].[FacilityMonthly] m
	INNER JOIN @TimePeriodList AS t ON t.TimePeriod = m.[Date]

	UNION ALL

	SELECT StaPa
		,Admparent_FCDM
		,VISN
		,LocationOfFacility
		,TemplateName
		,TemplateValue 
		,Date2 = 'YTD'
		,CONVERT(DATE,'12-31-2099') AS [Date]
		,[Month] = 'NA'
		,[Year] = 'NA'
		,TemplateNameShort
		,TemplateNameClean
		,PTSDKey
		,DepKey
		,SMIKey
		,SUDKey
		,InsomniaKey
		,TemplateValue -- YTDValue
	FROM [EBP].[DashboardBaseTableSummary]
	) AS a 
LEFT JOIN (
	SELECT StaPa
		,Admparent_FCDM
		,TemplateName
		,TemplateValue
		,PTSDKey
		,DepKey
		,SMIKey
		,SUDKey 
		,InsomniaKey
	FROM [EBP].[DashboardBaseTableSummary]
	WHERE StaPa = '0'
	) AS b ON a.TemplateName = b.TemplateName
INNER JOIN [Config].[EBP_TemplateLookUp] as l on l.TemplateName = a.TemplateName
INNER JOIN @FacilityList AS f ON f.Facility = a.StaPa
INNER JOIN @TemplateList AS t ON t.Template = a.TemplateNameClean
INNER JOIN @VISNList AS v ON v.VISN = a.VISN 
	-- The above join works and is easier for the testing that was added for all stations
	-- but if the report is ever changed to a multi-value parameter, then the data type will
	-- need to be changed in multiple places
ORDER BY a.VISN
	,b.Admparent_FCDM DESC

/* VALIDATION */
---- Check for duplicate rows
--SELECT StaPa,TemplateName,Date2,COUNT(*)
--FROM #ViewResults
--GROUP BY StaPa,TemplateName,Date2
----ORDER BY StaPa,Date2,TemplateName
--HAVING COUNT(*) > 1

END