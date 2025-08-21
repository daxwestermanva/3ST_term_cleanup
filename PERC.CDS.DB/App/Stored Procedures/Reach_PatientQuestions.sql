-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <9/19/2016>
-- Description:	Main data date for the Persceptive Reach report
-- Testing:
	--EXEC [App].[Reach_PatientQuestions] 'vha21\vhapalstephr6',44345627
-- Modifications:	
	-- 2019-10-9 - SG updated code with [Config].[REACH_OutreachStatusQuestions]
	-- 20191204 - RAS - Updated to v02 with MVIPersonSID
	-- 2020-10-15 - LM - Pointed to _VM tables
	-- 2021-05-26 - LM - Changed to NOT hide care evaluation questions when 'no changes indicated' was selected
	-- 2022-01-12 - LM - Get only most recent values for questions 18 and 19
	-- 2022-11-18 - LM - Added new care evaluation health factors
-- =============================================
CREATE PROCEDURE [App].[Reach_PatientQuestions]

--execute sp_opioid  2012,358,16,0,1
--execute sp_opioid  2012,0,16,0,1
	-- Add the parameters for the stored procedure here
    @User varchar(max),
	@Patient INT
	

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	--SET NOCOUNT ON;

	--TESTING
	--DECLARE @User varchar(max)='vha21\vhapalstephr6'
	--DECLARE @Patient INT	  = --enter MVIPersonSID

	SELECT DISTINCT
		 p.MVIPersonSID
		,a.HealthFactorDateTime AS EntryDate
		,a.StaffName 
		,a.Comments
		,CASE WHEN b.QuestionNumber NOT IN (27,28) THEN ISNULL(a.QuestionStatus ,0) END AS QuestionStatus
		,b.Question
		,CASE WHEN b.QuestionType ='Patient Status' THEN ' Patient Status' 
			ELSE b.QuestionType END AS QuestionType
		,b.DashboardOrder
		,b.QuestionNumber
		,b.Role
		,c.ProviderAssigned
		,c.NoCareChanges
		,CASE 
			WHEN ISNULL(c.ProviderAssigned,-1) IN (-1, 0) AND b.QuestionNumber IN (8,9,10,11,13,14,15,16,17,21,26,29,30) THEN 1 
			WHEN ISNULL(c.ProviderAssigned,-1) = 1 AND b.QuestionNumber IN (27,28) THEN 1 
			WHEN ISNULL(c.NoCareChanges,-1) = 1 AND b.QuestionNumber IN (8,9,10,11,21,29,30) AND QuestionStatus IS NULL  THEN 1 
			WHEN c.Outreachattempted = 0 AND b.QuestionNumber IN (13,14,15,16) THEN 1 
			WHEN ISNULL(c.OutreachUnsucc,-1) = 1 AND b.QuestionNumber IN (13,14,15,16) THEN 1 
			WHEN ISNULL(c.NoCareChanges,-1) = 0 AND b.QuestionNumber = 12 THEN 1 
			WHEN  b.QuestionNumber IN (17,26)  AND ISNULL(a.QuestionStatus,0) = 0 THEN 1 
			ELSE 0 END AS HideQuestion
	FROM [REACH].[PatientReport] AS p WITH (NOLOCK)
	INNER JOIN (
		SELECT QuestionNumber,Question,QuestionType,DashboardOrder,Role
		FROM [Config].[REACH_OutreachStatusQuestions] WITH (NOLOCK)
		WHERE QuestionNumber NOT IN (18,19)
		) AS b ON 1=1
	LEFT JOIN [REACH].[HealthFactors] AS a WITH (NOLOCK)
		ON p.MVIPersonSID = a.MVIPersonSID
		AND a.QuestionNumber = b.QuestionNumber 
		AND a.MostRecentFlag =1
	LEFT JOIN (
		SELECT DISTINCT
			 MVIPersonSID
			,ProviderAcknowledgement AS ProviderAssigned
			,NoCareChanges
			,CASE WHEN FollowUpWiththeVeteran > 0 THEN 1 ELSE 0 END Outreachattempted
			,CASE WHEN FollowUpWiththeVeteran =1  THEN 1 ELSE 0 END OutreachUnsucc 
		FROM [REACH].[QuestionStatus] WITH (NOLOCK) 
		) AS c ON p.MVIPersonSID = c.MVIPersonSID
	WHERE p.MVIPersonSID = @Patient

UNION ALL
 
	SELECT a.MVIPersonSID
		  ,w.EntryDate
		  ,w.UserName AS StaffName 
		  ,NULL AS Comments
		  ,ISNULL(w.QuestionStatus,0) as QuestionStatus
		  ,b.Question
		  ,' Patient Status' AS QuestionType
		  ,5 AS DashboardOrder
		  ,b.QuestionNumber
		  ,'Coordinator' AS Role
		  ,0 AS ProviderAssigned
		  ,0 AS NoCareChanges
		  ,0 AS HideQuestion
	FROM [REACH].[ActivePatient] a WITH (NOLOCK)
	INNER JOIN (
		SELECT QuestionNumber,Question,QuestionType,DashboardOrder,Role 
		FROM [Config].[REACH_OutreachStatusQuestions] WITH (NOLOCK)
		WHERE QuestionNumber IN (18,19)
		) AS b ON 1=1
	LEFT JOIN (
		SELECT m.MVIPersonSID,a.QuestionNumber,a.QuestionStatus,a.EntryDate,a.UserName
			,ROW_NUMBER() OVER (PARTITION BY m.MVIPersonSID, a.QuestionNumber ORDER BY EntryDate DESC, QuestionStatus DESC) AS rn
		FROM [REACH].[Writeback] a WITH (NOLOCK)
		INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] m WITH (NOLOCK) ON a.PatientSID=m.PatientPersonSID
		) AS w ON
			b.QuestionNumber = w.QuestionNumber 
			AND a.MVIPersonSID = w.MVIPersonSID
			AND rn=1
	WHERE a.MVIPersonSID=@Patient

END

--go 