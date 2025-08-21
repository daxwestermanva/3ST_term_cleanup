-- =============================================
-- Author:		Amy Robinson
-- Create date: 9/19/16
-- Description:	code for out reach status question section of the summary report
-- Modifications: 
	-- 20191205 - RAS - Updated for v02, including using MVIPersonSID
	-- 20200415 - LM -	Added max release date
	-- 20200916 - LM - Pointed to _VM table
	-- 2025-05-06 - LM - Updated references to point to REACH 2.0 objects
/*
EXEC [App].[Reach_Summary] @visn=21,@User='vha21/v21palstephr6',@TopPercent=1
*/
-- =============================================
CREATE PROCEDURE [App].[Reach_Summary]
	-- Add the parameters for the stored procedure here
    @VISN varchar(max),
	@User varchar(MAX),
    @TopPercent varchar(10)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT DISTINCT
	 b.VISN
	,b.ChecklistID
	,b.ADMPARENT_FCDM AS Facility
	,p.MVIPersonSID
	,Top01Percent
	,isnull(CareEvaluationChecklist,0) AS CareEvaluationChecklist
	,isnull(InitiationChecklist,0) AS InitiationChecklist
	,isnull(ProviderAcknowledgement,0) AS ProviderAcknowledgement
	,isnull(PatientDeceased,0) AS PatientDeceased
	,CASE WHEN FollowUpWiththeVeteran = 5 THEN 4 
		ELSE isnull(FollowUpWiththeVeteran,0) 
		END AS FollowUpWiththeVeteran
	,ReleaseDate=(SELECT max(ReleaseDate) FROM [REACH].[RiskScoreHistoric])
FROM [REACH].[PatientReport] AS p WITH(NOLOCK)
LEFT JOIN [LookUp].[ChecklistID] AS b WITH(NOLOCK) ON p.ChecklistID = b.ChecklistID
LEFT JOIN [REACH].[QuestionStatus] AS a WITH(NOLOCK) ON p.MVIPersonSID = a.MVIPersonSID 
WHERE b.VISN IN (SELECT value FROM string_split(@VISN ,','))
	AND Top01Percent IN (SELECT value FROM string_split(@TopPercent ,','))
    
END