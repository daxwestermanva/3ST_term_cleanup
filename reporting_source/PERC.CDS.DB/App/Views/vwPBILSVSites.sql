
/*******************************************************************************************************************************
Developer(s)	: Alston, Steven
Create Date		: October 08, 2021
Object Name		: [App].[vwPBILSVSites]
Description		: Used in PBI models/reports for capturing LSV VA Sites
--               
REVISON LOG		:

Version		Date			Developer				Description
1.0			10/08/2021		Alston, Steven			Initial Version
*******************************************************************************************************************************/
CREATE   VIEW [App].[vwPBILSVSites]

AS  

	SELECT 
		VISN
		,Sta3n 
	FROM Dim.VistaSite 
	WHERE Active = 'Y'
;