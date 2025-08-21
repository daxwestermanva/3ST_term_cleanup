





/***********************************************************
AUTHOR:			Liam Mina
DATE:			2025-02-07
DESCRIPTION:	Non-deduplicated version of SuicideOverdoseEvent dataset for purposes of displaying events on facility-level dashboards based on where event was reported
MODIFICATIONS:

***********************************************************/
CREATE VIEW [OMHSP_Standard].[vwSuicideOverdoseEvent_FacilityReported]
AS 
SELECT [MVIPersonSID]
      ,[SPANPatientID]
      ,[SPANEventID]
      ,[PatientICN]
      ,[VisitSID]
      ,[DocFormActivitySID]
      ,[Sta3n]
      ,[ChecklistID]
      ,[EntryDateTime]
      ,[DataSource]
      ,[EventDate]
      ,[EventDateFormatted]
      ,[EventType]
      ,[Intent]
      ,[Setting]
      ,[SettingComments]
      ,[SDVClassification]
      ,[VAProperty]
      ,[SevenDaysDx]
      ,[Preparatory]
      ,[Interrupted]
      ,[InterruptedComments]
      ,[Injury]
      ,[InjuryComments]
      ,[Outcome1]
      ,[Outcome1Comments]
      ,[Outcome2]
      ,[Outcome2Comments]
      ,[MethodType1]
      ,[Method1]
      ,[MethodComments1]
      ,[MethodType2]
      ,[Method2]
      ,[MethodComments2]
      ,[MethodType3]
      ,[Method3]
      ,[MethodComments3]
      ,[AdditionalMethodsReported]
      ,[Comments]
      ,[ODProvReview]
      ,[ODReviewDate]
      ,[Overdose]
      ,[Fatal]
      ,[PreparatoryBehavior]
      ,[UndeterminedSDV]
      ,[SuicidalSDV]
      ,[EventOrderDesc]
      ,[AnyEventOrderDesc]
	  ,CONCAT(AnyEventOrderDesc,'-',MVIPersonSID) AS EventCountIndicator
FROM [OMHSP_Standard].[SuicideOverdoseEvent] a WITH (NOLOCK)
UNION 
SELECT TOP 1 WITH TIES a.[MVIPersonSID]
      ,a.[SPANPatientID]
      ,a.[SPANEventID]
      ,a.[PatientICN]
      ,b.[VisitSID]
      ,b.[DocFormActivitySID]
      ,b.[Sta3n]
      ,b.[ChecklistID]
      ,b.[EntryDateTime]
      ,b.[TIUDocumentDefinition]
      ,b.[EventDate]
      ,b.[EventDateFormatted]
      ,a.[EventType]
      ,a.[Intent]
      ,b.[Setting]
      ,b.[SettingComments]
      ,b.[SDVClassification]
      ,b.[VAProperty]
      ,b.[SevenDaysDx]
      ,b.[Preparatory]
      ,b.[Interrupted]
      ,b.[InterruptedComments]
      ,b.[Injury]
      ,b.[InjuryComments]
      ,b.[Outcome1]
      ,b.[Outcome1Comments]
      ,b.[Outcome2]
      ,b.[Outcome2Comments]
      ,b.[MethodType1]
      ,b.[Method1]
      ,b.[MethodComments1]
      ,b.[MethodType2]
      ,b.[Method2]
      ,b.[MethodComments2]
      ,b.[MethodType3]
      ,b.[Method3]
      ,b.[MethodComments3]
      ,b.[AdditionalMethodsReported]
      ,a.[Comments]
      ,b.[ODProvReview]
      ,b.[ODReviewDate]
      ,a.[Overdose]
      ,a.[Fatal]
      ,a.[PreparatoryBehavior]
      ,a.[UndeterminedSDV]
      ,a.[SuicidalSDV]
      ,a.[EventOrderDesc]
      ,a.[AnyEventOrderDesc]
	  ,CONCAT(a.AnyEventOrderDesc,'-',a.MVIPersonSID) AS EventCountIndicator
FROM [OMHSP_Standard].[SuicideOverdoseEvent] a WITH (NOLOCK)
INNER JOIN [OMHSP_Standard].[SBOR] b WITH (NOLOCK)
	ON a.MVIPersonSID=b.MVIPersonSID AND a.EventDateFormatted=b.EventDateFormatted AND a.SDVClassification=b.SDVClassification AND a.ChecklistID<>b.ChecklistID
LEFT JOIN [OMHSP_Standard].[SuicideOverdoseEvent] c WITH (NOLOCK)
	ON c.MVIPersonSID=b.MVIPersonSID AND c.EventDateFormatted=b.EventDateFormatted AND c.SDVClassification=b.SDVClassification AND c.ChecklistID=b.ChecklistID 
WHERE c.MVIPersonSID IS NULL
ORDER BY ROW_NUMBER() OVER (PARTITION BY b.MVIPersonSID, b.EventDateFormatted, b.SDVClassification ORDER BY b.EntryDateTime DESC)