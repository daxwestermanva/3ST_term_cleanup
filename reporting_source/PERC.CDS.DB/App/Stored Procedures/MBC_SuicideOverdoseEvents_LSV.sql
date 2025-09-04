

-- =============================================
-- Author:		<Liam Mina>
-- Create date: <03/15/2019>
-- Description:	Dataset pulls data from SBOR and SPAN tables for information on suicide and overdose events

-- 2019-03-28 - RAS - Made list of fields explicit for final union.  Consider for future:
					--Create 1 present suicide overdose event table?  Add logic for EventType and Intent to "back end?"
--  2019-04-05 - LM - Added MVIPersonSID to initial select statement
--  2019-04-16 - LM - Added logic to remove duplicates
--	2020-09-21 - RAS - Changed initial #patient to use Common.MasterPatient instead of Present.StationAssignments
--	2022-08-26 - LM - Added eligibility for SP Clinical Telehealth program (suicide event in past year)
--	2025-04-09 - LM - Added overdose dx from community care

-- EXEC [App].[MBC_SuicideOverdoseEvents_LSV] @User = 'VHAMASTER\VHAISBBACANJ'	, @Patient = '1001052545'
-- EXEC [App].[MBC_SuicideOverdoseEvents_LSV] @User = 'vha21\vhapalminal'		, @Patient = '1034449525'
-- =============================================
CREATE PROCEDURE [App].[MBC_SuicideOverdoseEvents_LSV]
(
	@User VARCHAR(MAX),
	@Patient VARCHAR(1000)
)  
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'	; SET @Patient = '1001052545'
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'vha21\vhapalminal'		; SET @Patient = '1011716271'

	
--Step 1: find patient, set permissions
	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT 
		MVIPersonSID
	INTO #Patient
	FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
	WHERE a.PatientICN =  @Patient
		AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;

	SELECT DISTINCT a.MVIPersonSID 
		  ,c.Facility
		  ,a.EntryDateTime
		  ,a.DataSource
		  ,a.[EventDate]
		  ,a.EventType
		  ,a.Intent
		  ,a.[Setting]
		  ,a.[SettingComments]
		  ,a.[SDVClassification]
		  ,a.[VAProperty]
		  ,a.[SevenDaysDx]
		  ,a.[Preparatory]
		  ,a.[Interrupted]
		  ,a.[InterruptedComments]
		  ,a.[Injury]
		  ,a.[InjuryComments]
		  ,CASE WHEN a.[Outcome1Comments] IS NOT NULL THEN CONCAT(a.[Outcome1], ' (', a.[Outcome1Comments],')')
			ELSE a.[Outcome1] END AS Outcome1
		  ,CASE WHEN a.[Outcome2Comments] IS NOT NULL THEN CONCAT(a.[Outcome2], ' (', a.[Outcome2Comments],')')
			ELSE a.[Outcome2] END AS Outcome2
		  ,CASE WHEN a.[MethodType1] IS NULL AND a.[Method1] IS NULL THEN 'None Reported'
			WHEN a.[Method1] IS NULL THEN a.[MethodType1]
			WHEN a.[MethodType1] = a.[Method1] AND a.[MethodComments1] IS NULL THEN a.[MethodType1]
			WHEN a.[MethodType1] = a.[Method1] AND a.[MethodComments1] IS NOT NULL THEN CONCAT(a.[MethodType1],' (',a.[MethodComments1],')')
			WHEN a.[MethodComments1] IS NULL THEN CONCAT(a.[MethodType1],' - ',a.[Method1])
			WHEN a.[MethodComments1] IS NOT NULL THEN CONCAT(a.[MethodType1],' - ',a.[Method1],' (',a.[MethodComments1],')')
			END AS Method1
		  ,CASE WHEN a.[MethodType2] IS NULL AND a.[Method2] IS NULL THEN NULL
			WHEN a.[Method2] IS NULL THEN a.[MethodType2]
			WHEN a.[MethodType2] = a.[Method2] AND a.[MethodComments2] IS NULL THEN a.[MethodType2]
			WHEN a.[MethodType2] = a.[Method2] AND a.[MethodComments2] IS NOT NULL THEN CONCAT(a.[MethodType2],' (',a.[MethodComments2],')')
			WHEN a.[MethodComments2] IS NULL THEN CONCAT(a.[MethodType2],' - ',a.[Method2])
			WHEN a.[MethodComments2] IS NOT NULL THEN CONCAT(a.[MethodType2],' - ',a.[Method2],' (',a.[MethodComments2],')')
			END AS Method2
		  ,CASE WHEN a.[MethodType3] IS NULL AND a.[Method3] IS NULL THEN NULL
			WHEN a.[Method3] IS NULL THEN a.[MethodType3]
			WHEN a.[MethodType3] = a.[Method3] AND a.[MethodComments3] IS NULL THEN a.[MethodType3]
			WHEN a.[MethodType3] = a.[Method3] AND a.[MethodComments3] IS NOT NULL THEN CONCAT(a.[MethodType3],' (',a.[MethodComments3],')')
			WHEN a.[MethodComments3] IS NULL THEN CONCAT(a.[MethodType3],' - ',a.[Method3])
			WHEN a.[MethodComments3] IS NOT NULL THEN CONCAT(a.[MethodType3],' - ',a.[Method3],' (',a.[MethodComments3],')')
			END AS Method3
		  ,a.[AdditionalMethodsReported]
		  ,a.Comments  
		  ,a.EventOrderDesc
		  ,CASE WHEN a.EventOrderDesc = 1 AND a.EventType = 'Suicide Event' AND (e.IntakeDate IS NOT NULL AND e.DischargeDate IS NULL)
				THEN 'Veteran is currently receiving evidence-based psychotherapy for suicide prevention from the SP 2.0 Clinical Telehealth Program'
			 WHEN a.EventOrderDesc = 1 AND a.EventType = 'Suicide Event' AND a.Intent = 'Yes' AND ISNULL(a.EventDateFormatted, a.EntryDateTime) >= DateAdd(month,-12,getdate())  
				AND (e.MVIPersonSID IS NULL OR e.DischargeDate < ISNULL(a.EventDateFormatted, a.EntryDateTime)) --only display for events with known suicidal intent that occurred in past year
				THEN 'Veteran may be eligible for SP 2.0 Clinical Telehealth Program for evidence-based psychotherapy for suicide prevention'
			WHEN a.EventOrderDesc = 1 AND a.EventType = 'Suicide Event' AND e.DischargeDate IS NOT NULL
				THEN 'Veteran has received evidence-based psychotherapy for suicide prevention from the SP 2.0 Clinical Telehealth Program'
			ELSE NULL
			END AS CVTHMessage	
	FROM  [OMHSP_Standard].[SuicideOverdoseEvent] a WITH (NOLOCK)
	INNER JOIN #Patient p 
		ON p.MVIPersonSID=a.MVIPersonSID
	LEFT JOIN [LookUp].[ChecklistID] as c WITH (NOLOCK) 
		ON c.ChecklistID=a.ChecklistID
	LEFT JOIN (SELECT * FROM [Present].[SPTelehealth] WITH (NOLOCK) WHERE RowNum = 1) AS e  
		ON p.MVIPersonSID = e.MVIPersonSID
	WHERE a.EventType NOT IN ('Ideation','Non-Suicidal SDV')
	UNION ALL
	SELECT DISTINCT * FROM 
		(SELECT TOP 3 b.MVIPersonSID 
		  ,c.Facility
		  ,b.EpisodeStartDate
		  ,DataSource='Community Care Dx'
		  ,[EventDate]=NULL
		  ,EventType=
			CASE WHEN IntentionalSelfHarm=1 OR UndeterminedIntent=1 THEN 'Suicide Event'
				WHEN Accidental=1 THEN 'Accidental Overdose'
				END
		  ,Intent=NULL
		  ,[Setting]=NULL
		  ,[SettingComments]=NULL
		  ,[SDVClassification]=
			CASE WHEN IntentionalSelfHarm=1 THEN CONCAT(b.Type, ' (Intentional)')
				WHEN UndeterminedIntent=1 THEN CONCAT(b.Type, ' (Undetermined Intent)')
				WHEN Accidental=1 THEN CONCAT(b.Type, ' (Accidental)')
				END
		  ,[VAProperty]=NULL
		  ,[SevenDaysDx]=NULL
		  ,[Preparatory]=NULL
		  ,[Interrupted]=NULL
		  ,[InterruptedComments]=NULL
		  ,[Injury]=NULL
		  ,[InjuryComments]=NULL
		  ,Outcome1=NULL
		  ,Outcome2=NULL
		  ,Method1=NULL
		  ,Method2=NULL
		  ,Method3=NULL
		  ,[AdditionalMethodsReported]=NULL
		  ,Comments  =NULL
		  ,EpisodeID
		  ,CVTHMessage=NULL
		FROM CommunityCare.ODUniqueEpisode b WITH (NOLOCK)
		INNER JOIN #Patient p
			ON b.MVIPersonSID=p.MVIPersonSID
		LEFT JOIN [LookUp].[ChecklistID] as c WITH (NOLOCK) 
			ON b.ChecklistID=c.ChecklistID 
		WHERE b.ExposeRdl=1
		AND EpisodeStartDate > DATEADD(year,-1,getdate())
		AND b.Type<>'Emergency Complaint no ICD billed'
		ORDER BY EpisodeStartDate DESC
		) x
		

END