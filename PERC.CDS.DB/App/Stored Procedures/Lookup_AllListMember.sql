 
 
 
 
/**********************************************************************************************************
* Parameters:
*  
* Purpose:	SSRS Procedure, to pull all the [Lookup].[ListMember]  joined to each domain
*
* Example:
*              
* Revision Date/Time:
*	2018-10-26	- Matt Wollner	- Created
	2022-05-20	- Rebecca Stephens - Swtiched references to PDW synonyms to CDW synonyms
	2024-06-21	- Liam Mina - Updated healthfactorcategory source due to removal of this column from Dim.HealthFactorType
**********************************************************************************************************/
CREATE PROCEDURE [App].[Lookup_AllListMember]
	@Domain VARCHAR(MAX) 
	,@List VARCHAR(MAX) 
	,@ApprovalStatus VARCHAR(MAX) = 'Pending'
AS
WITH ListMembers AS(
	SELECT DISTINCT 
		 LM.Domain
		,LM.List
		,LM.ApprovalStatus
		,HFT.HealthFactorType AS LookUpName
		,C.HealthFactorType AS LookupCategory
		,LM.CreatedDateTime
	FROM [Dim].[HealthFactorType] HFT  WITH (NOLOCK) 
	INNER JOIN [Lookup].[ListMember] LM  WITH (NOLOCK) 
		ON HFT.HealthFactorTypeSID = LM.ItemID
	LEFT JOIN [Dim].[HealthFactorType] C WITH (NOLOCK) 
		ON HFT.CategoryHealthFactorTypeSID = C.HealthFactorTypeSID
	WHERE LM.Domain = 'HealthFactorType'
	AND HFT.EntryType='Factor' AND C.EntryType='Category'
 
	UNION
 
	SELECT DISTINCT 
		LM.Domain
		,LM.List
		,LM.ApprovalStatus
		,TIU.TIUDocumentDefinition
		,NULL
		,LM.CreatedDateTime
	FROM [Dim].[TIUDocumentDefinition] TIU WITH (NOLOCK) 
	INNER JOIN [Lookup].[ListMember] LM WITH (NOLOCK) 
		ON TIU.TIUDocumentDefinitionSID = LM.ItemID
	WHERE 	LM.Domain = 'TIUDocumentDefinition'
)
 
SELECT *
FROM ListMembers
WHERE Domain IN (SELECT value FROM string_split(@Domain,','))
	AND List IN (SELECT value FROM string_split(@List,','))
	AND ApprovalStatus IN (SELECT value FROM string_split(@ApprovalStatus,','))
ORDER BY Domain
		,List
		,LookUpName