
/**********************************************************************************************************
* Parameters:
*  
* Purpose:	SSRS Procedure, to pull all Domains in [Lookup].[ListMember] 
*
* Example:
*              
* Revision Date/Time:
*	2018-10-26	- Matt Wollner	- Created
**********************************************************************************************************/
CREATE PROCEDURE [App].[Lookup_ListMemberDomain]
	
AS

SELECT DISTINCT [Domain]
FROM [Lookup].[ListMember]
ORDER BY 1