
-- =============================================
-- Author:		Tolessa Gurmessa
-- Create date: 2/14/2022
-- Description: OPPE Report based on ORM_Summary Report
-- =============================================
CREATE PROCEDURE [App].[ORM_OPPEReport]
	 @User varchar(100)
	,@Prescriber nvarchar(max)
	,@Station varchar(255)
	--,@RiskGroup varchar(20)
	,@Measure varchar(max)
	,@GroupType varchar(20)

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
	  ,isnull(mt.AllLTOTCount,0) as AllLTOTCount
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
	  ,FakeGroup=1
	  ,DueNinetyDays
FROM [ORM].[OPPEMetric] as mt 
LEFT JOIN [ORM].[MeasureDetails] as md on mt.MeasureID=md.MeasureID
WHERE --mt.ChecklistID='640' and mt.GroupID=0 and ProviderSID = 0 
	md.MeasureID <> 9 
	AND mt.ChecklistID	IN (SELECT value FROM string_split(@Station,','))
	AND md.MeasureID	IN (SELECT value FROM string_split(@Measure ,',')) 
	AND (
		(@GroupType = '-5' AND mt.GroupID = 0 AND mt.ProviderSID = 0) 
		OR 
		(
			GroupID IN (SELECT value FROM string_split(@GroupType ,','))
			AND ProviderSID IN (SELECT value FROM string_split(@Prescriber,','))
			)
		)
 
END