
/*******************************************************************************************************************************
Developer(s)	: Alston, Steven
Create Date		: October 08, 2021
Object Name		: [App].[vwPBILSVUserAuthorization]
Description		: Used in PBI models/reports for capturing LSV user Sta3n access information
--               
REVISON LOG		:

Version		Date			Developer				Description
1.0			10/08/2021		Alston, Steven			Initial Version
*******************************************************************************************************************************/
CREATE   VIEW [App].[vwPBILSVUserAuthorization]

AS  
	SELECT
        LCustomerID AS UserSID
        ,Sta3n 
        ,ADAccount 
    FROM LCustomer.AllAuthorization
    WHERE 1=1 
    AND Sta3n > 0
;