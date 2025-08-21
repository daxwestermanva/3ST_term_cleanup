-- =============================================
-- Author:		Sohoni, Pooja
-- Create date: 2018-08-06
-- Description:	Populate the risk mitigations list in STORM Definitions report.
-- =============================================
CREATE PROCEDURE [App].[ORM_Definitions_RiskMitigationsList]

AS
BEGIN

	SET NOCOUNT ON;
	SELECT 
       [MeasureName]
      ,[RiskMitigationStrategy]
      ,[Description]
      ,[Category]
,MeasureID
  FROM ORM.MeasureDetails
where [category] is not null
and measureid not in (9)

END