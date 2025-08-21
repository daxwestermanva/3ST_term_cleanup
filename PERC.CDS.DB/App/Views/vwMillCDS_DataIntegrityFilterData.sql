


/*******************************************************************************************************************************
Developer(s)	: Campbell, Drew
Create Date		: March 03, 2022
Object Name		: [App].[vwMillCDS_DataIntegrityFilterData]
Description		: Pulls only the fields needed to create the filters within the Data Integrity Fact Table Report
--               
REVISON LOG		:

Version		Date			Developer				Description
1.0			03/03/2022		Campbell, Drew			Initial Version

*******************************************************************************************************************************/
CREATE       VIEW [App].[vwMillCDS_DataIntegrityFilterData]
AS  

	SELECT
	TableName
	,DataType
	,ColumnName
	,ColumnRequired
	FROM MILLCDS.DataSurveillanceFnl
	;