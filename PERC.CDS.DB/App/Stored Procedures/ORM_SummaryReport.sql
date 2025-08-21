
-- =============================================
-- Author:		Amy Robinson/Meenah Paik
-- Create date: 6/19/2017
-- Description: Main dataset for STORM SummaryReport - uses ORM.MetricTable
-- =============================================
CREATE PROCEDURE [App].[ORM_SummaryReport]
	 @User varchar(100)
	,@Prescriber nvarchar(max)
	,@Station varchar(255)
	,@RiskGroup varchar(100)
	,@Measure varchar(max)
	,@GroupType varchar(100)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	/*
	Declare @User varchar(100)
	Declare @Prescriber nvarchar(max)
	Declare @Station varchar(255)
	Declare @SSN varchar(100)
	Declare @RiskGroup varchar(20)
	Declare @Measure varchar(max)
	Declare @GroupType varchar(20)

	Set @User = 'vha21\vhapalmartins'
	Set @Prescriber = '1450000'
	Set @Station = '640,662'
	Set @RiskGroup = '5,4,2,1'
	Set @Measure = '1,2,3,4,5,6'
	Set @GroupType = '-5'
    Set @SSN = ''
	*/

 SELECT mt.VISN
	  ,mt.GroupID
	  ,mt.GroupType
	  ,mt.ProviderSID
	  ,mt.ProviderName
	  ,mt.Riskcategory
	  ,isnull(mt.AllOpioidPatient,0) as AllOpioidPatient
	  ,isnull(mt.AllOpioidRXPatient,0) as AllOpioidRXPatient
	  ,isnull(mt.AllOUDPatient,0) as AllOUDPatient
	  ,isnull(mt.AllPastYearODCount,0) as AllPastYearODCount
	  ,mt.Permeasure
	  ,mt.Numerator
	  ,mt.Denominator
	  ,mt.Score
	  ,mt.NatScore
	  ,mt.AllTxPatients
	  ,Cast(md.MeasureID as int) as MeasureID
	  ,md.MeasureNameClean
	  ,mt.ChecklistID
	  ,mt.ADMParent_FCDM
	  ,case 
	    when mt.RiskCategory = 10 then 'Very High (Active Status, No Pills on Hand)'
	    when mt.Riskcategory = 9 then 'Very High (Recently Discontinued)'
		when mt.Riskcategory = 5 then 'OUD, No Opioid Rx (Elevated Risk)'
		when mt.Riskcategory = 11 then 'Overdose in the Past Year (Elevated Risk)'
		when mt.Riskcategory = 12 then 'Additional Possible Community Care Overdose In The Past Year'
		when mt.Riskcategory = 4 then 'Very High (Active Opioid Rx)'
		when mt.Riskcategory = 3 then 'High (Active Opioid Rx)'
		when mt.Riskcategory = 2 then 'Medium (Active Opioid Rx)'
		when mt.Riskcategory = 1 then 'Low (Active Opioid Rx)'
		when mt.Riskcategory = 0 then 'All'
		End RiskLabel
	  ,FakeGroup=1
FROM [ORM].[MetricTable] as mt 
LEFT JOIN [ORM].[MeasureDetails] as md on mt.MeasureID=md.MeasureID
WHERE --mt.ChecklistID='640' and mt.GroupID=0 and ProviderSID = 0 
	md.MeasureID <> 9 
	AND mt.ChecklistID	IN (SELECT value FROM string_split(@Station,','))
	AND md.MeasureID	IN (SELECT value FROM string_split(@Measure ,','))
	AND RiskCategory	IN (SELECT value FROM string_split(@RiskGroup ,',')) 
	AND (
		(@GroupType = -5 AND mt.GroupID = 0 AND mt.ProviderSID = 0) 
		OR (
			GroupID IN (SELECT value FROM string_split(@GroupType ,','))
			AND ProviderSID IN (SELECT value FROM string_split(@Prescriber,','))
			)
		)
 
END