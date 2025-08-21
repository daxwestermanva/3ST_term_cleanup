

/**********************************************************************************************************
* Parameters:
*  
* Purpose:	SSRS Procedure, to pull all ApprovalStatus in [Lookup].[ListMember] 
*
* Example:
*              
* Revision Date/Time:
*	2018-10-26	- Matt Wollner	- Created
**********************************************************************************************************/
CREATE PROCEDURE [App].[Lookup_ListMemberApprovalStatus]
	
AS


SELECT DISTINCT [ApprovalStatus]
FROM [Lookup].[ListMember]
UNION
SELECT 'Pending' AS [ApprovalStatus]
ORDER BY  1