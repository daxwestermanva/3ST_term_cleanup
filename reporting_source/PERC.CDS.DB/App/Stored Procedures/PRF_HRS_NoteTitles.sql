
/* =============================================
-- Author: Rebecca Stephens (RAS)		 
-- Create date: 2017-06-28
-- Description:	Main dataset for high risk note title report
-- Modifications:
	--2019-11-22	LM	Added SBOR and CSRE notes; changed to pull 'inactive' status from the TIU status
	--2020-01-28	LM	Added CSRE to UsedInReports = 1
	--2020-09-10	LM	Removed miscellaneous note titles 'not used in reports'; Cerner overlay
	--2022-08-15    SAA_JJR - Updated source of facility location from [MillCDS].[DimVALocation] to [MillCDS].[DimLocations];New table includes DoD location data	
 EXEC [App].[PRF_HRS_NoteTitles] @Facility='668'
   ============================================= */
CREATE PROCEDURE [App].[PRF_HRS_NoteTitles]
	@Facility varchar(12)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

DROP TABLE IF EXISTS #include
SELECT b.Sta3n
	  ,b.TIUDocumentDefinitionSID
	  ,b.TIUDocumentDefinitionPrintName
	  ,b.TIUDocumentDefinition
	  ,CASE WHEN List='HRF_FlagReview_TIU' THEN 1 ELSE 0 END AS HRF_FlagReview_TIU
	  ,CASE WHEN List='SuicidePrevention_SafetyPlan_TIU' THEN 1 ELSE 0 END AS SuicidePrevention_SafetyPlan_TIU
	  ,CASE WHEN List='SuicidePrevention_SBOR_TIU' THEN 1 ELSE 0 END AS SuicidePrevention_SBOR_TIU
	  ,CASE WHEN List='SuicidePrevention_CSRE_TIU' THEN 1 ELSE 0 END AS SuicidePrevention_CSRE_TIU
	  ,c.TIUStatus
  INTO #include
  FROM [Lookup].[ListMember] AS l WITH (NOLOCK)
  INNER JOIN Dim.TIUDocumentDefinition b WITH (NOLOCK)
	ON l.ItemID = b.TIUDocumentDefinitionSID
  INNER JOIN Dim.TIUStatus c WITH (NOLOCK)
	ON b.TIUStatusSID = c.TIUStatusSID
	WHERE List IN ('SuicidePrevention_CSRE_TIU','SuicidePrevention_SBOR_TIU','SuicidePrevention_SafetyPlan_TIU','HRF_FlagReview_TIU')
  UNION ALL
  SELECT b.Sta3n
	  ,b.TIUDocumentDefinitionSID
	  ,b.TIUDocumentDefinition
	  ,b.TIUDocumentDefinition
	  ,CASE WHEN List='HRF_FlagReview_TIU' THEN 1 ELSE 0 END AS HRF_FlagReview_TIU
	  ,CASE WHEN List='SuicidePrevention_SafetyPlan_TIU' THEN 1 ELSE 0 END AS SuicidePrevention_SafetyPlan_TIU
	  ,CASE WHEN List='SuicidePrevention_SBOR_TIU' THEN 1 ELSE 0 END AS SuicidePrevention_SBOR_TIU
	  ,CASE WHEN List='SuicidePrevention_CSRE_TIU' THEN 1 ELSE 0 END AS SuicidePrevention_CSRE_TIU
	  ,b.TIUStatus
  FROM [Lookup].[ListMember] AS l WITH (NOLOCK)
  INNER JOIN Cerner.DimPowerFormNoteTitle b WITH (NOLOCK)
	ON l.ItemID = b.TIUDocumentDefinitionSID
	AND l.Domain = b.TIUDocumentDefinitionType
	WHERE List IN ('SuicidePrevention_CSRE_TIU','SuicidePrevention_SBOR_TIU','SuicidePrevention_SafetyPlan_TIU','HRF_FlagReview_TIU')

  ;
  
SELECT DISTINCT 
	 Sta3n
	,TIUDocumentDefinitionPrintName
	,TIUDocumentDefinition
	,CASE 
		WHEN HRF_FlagReview_TIU=1 then 'Flag Review Note'
	    WHEN SuicidePrevention_SafetyPlan_TIU=1 then 'Safety Plan Note'
		WHEN SuicidePrevention_SBOR_TIU=1 then 'Suicide Behavior Report Note'
		WHEN SuicidePrevention_CSRE_TIU=1 THEN 'Risk Assessment Note'
		END AS Category
	,CASE WHEN (HRF_FlagReview_TIU=1 OR SuicidePrevention_SafetyPlan_TIU=1 OR SuicidePrevention_SBOR_TIU=1 OR SuicidePrevention_CSRE_TIU=1) AND TIUStatus='Active' THEN 1 ELSE 0 END AS UsedInReports
FROM #INCLUDE
WHERE ((HRF_FlagReview_TIU=1 OR SuicidePrevention_SafetyPlan_TIU=1 OR SuicidePrevention_SBOR_TIU=1 OR SuicidePrevention_CSRE_TIU=1))
	AND (Sta3n=LEFT(@Facility,3) OR (Sta3n=200 AND @Facility in (SELECT DISTINCT ChecklistID FROM [Lookup].[ChecklistID] WITH (NOLOCK) WHERE getdate()>IOCDate)))


;

END