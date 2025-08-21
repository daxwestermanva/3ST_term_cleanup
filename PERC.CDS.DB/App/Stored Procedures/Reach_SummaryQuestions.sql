-- =============================================
-- Author:		Amy Robinson
-- Create date: 9/19/16
-- Description:	Questions dataset for summary report
-- Modifications:
--	2020-09-16	LM	Pointed to _VM tables
-- =============================================
CREATE PROCEDURE [App].[Reach_SummaryQuestions]
	-- Add the parameters for the stored procedure here
	@User varchar(MAX),
    @VISN varchar(max),
    @TopPercent varchar(10)
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

 SELECT a.MVIPersonSID
	  ,Question
	  ,QuestionNumber
	  ,QuestionStatus
	  ,Top01Percent
 FROM [REACH].[HealthFactors] as a WITH (NOLOCK)
 INNER JOIN [REACH].[PatientReport] as b WITH (NOLOCK) on a.MVIPersonSID = b.MVIPersonSID
 INNER JOIN [LookUp].[ChecklistID] as c WITH (NOLOCK) on b.ChecklistID=c.ChecklistID
 WHERE c.VISN in (SELECT value FROM string_split(@VISN ,',')) 
	AND Top01Percent in (SELECT value FROM string_split(@TopPercent ,','))



END