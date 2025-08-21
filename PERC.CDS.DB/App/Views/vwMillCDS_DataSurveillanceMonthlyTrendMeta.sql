
/*******************************************************************************************************************************
Developer(s)	: Alston, Steven
Create Date		: October 08, 2021
Object Name		: [App].[vwMillCDS_DataSurveillanceMonthlyTrendMeta]
Description		: Pulls metadata details that supports Data Surveillance analysis
--               
REVISON LOG		:

Version		Date			Developer				Description
1.0			10/08/2021		Alston, Steven			Initial Version
*******************************************************************************************************************************/
CREATE   VIEW [App].[vwMillCDS_DataSurveillanceMonthlyTrendMeta]

AS  
	SELECT
		[Domain]
		,[PrintName]
		,ValueSet AS [Category]
		,UPPER(REPLACE(ValueSet,'_','')) AS CategoryLookupID
		,[Vocabulary]
		,Value AS [Code]
		,ValueDescription AS [CodeDescription]
		,[VM]
	FROM [MillCDS].[DataSurveillanceMonthlyTrendMeta]
;