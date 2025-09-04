
/**********************************************************************************************************
* Parameters:
*  
* Purpose:	SSRS Procedure, to pull all Lists for each Domain in [Lookup].[ListMember] 
*
* Example:
*              
* Revision Date/Time:
*	2018-10-26	- Matt Wollner	- Created
**********************************************************************************************************/
CREATE PROCEDURE [App].[Lookup_ListMemberList]
	@Domain VARCHAR(MAX)

AS

SELECT DISTINCT List
FROM [Lookup].[ListMember]
WHERE [Domain] IN (SELECT value FROM string_split(@Domain,','))
ORDER BY 1