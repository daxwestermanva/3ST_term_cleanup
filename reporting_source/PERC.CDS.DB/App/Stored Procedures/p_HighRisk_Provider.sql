
/* =============================================
-- Author: Rebecca Stephens (RAS)		 
-- Create date: 2017-06-28
-- Description:	Main dataset for high risk patient tracking report


 EXEC [App].[p_HighRisk_Provider] @Facility='640',@LastActionDescription='4'
   ============================================= */
CREATE PROCEDURE [App].[p_HighRisk_Provider]
	 @Facility varchar(15),
	 @LastActionType varchar(10)
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

DECLARE @ActionList TABLE ([LastActionType] VARCHAR(5))
INSERT @ActionList  SELECT value FROM string_split(@LastActionType, ',')

SELECT DISTINCT ProviderName, Facility
FROM (
	SELECT
		a.AssignedSPC AS ProviderName
		,a.OwnerChecklistID as Facility
		,a.LastActionType
	FROM [PRF_HRS].[PatientReport_v02] a WITH(NOLOCK)
	INNER JOIN @ActionList b ON a.[LastActionType] = b.LastActionType
	UNION ALL
	SELECT
		'All SPCs/SPCMs' as ProviderName
		,OwnerChecklistID as Facility
		,LastActionType
	FROM [PRF_HRS].[PatientReport_v02] WITH(NOLOCK)
	) a 
WHERE  @Facility=a.Facility
ORDER BY ProviderName

;

END