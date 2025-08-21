
/*******************************************************************************************************************************
Developer(s)	: Alston, Steven
Create Date		: October 08, 2021
Object Name		: [App].[vwPBILSVUsers]
Description		: Used in PBI models/reports for capturing LSV user information
--               
REVISON LOG		:

Version		Date			Developer				Description
1.0			10/08/2021		Alston, Steven			Initial Version
*******************************************************************************************************************************/
CREATE   VIEW [App].[vwPBILSVUsers]

AS  

	SELECT DISTINCT 
		LCustomerID AS UserSID
		,ADDomain + '\'+ ADLogin AS ADAccount
		,ADDomain AS Domain
		,ADLogin AS UserName 
		,Email AS UserPrincipalName 
	FROM LCustomer.LCustomer
;