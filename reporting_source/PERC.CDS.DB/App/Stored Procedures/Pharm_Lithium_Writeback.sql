
-- =============================================
-- Author:		Sara Tavakoli
-- Create date: 7/13/2016
-- Description:	Writeback SP for Patient Table
-- Updates:
--			2018/04/05 JBacani - Copied from A01 LSV db to PERC_PsychPharm, renamed, and edited for SQL20
--			2023-09-19	LM	Remove string 'Enter Text Here' from writeback responses	
-- =============================================
CREATE PROCEDURE [App].[Pharm_Lithium_Writeback]
	-- Add the parameters for the stored procedure here
    @Sta3n varchar(10),
	@PatientICN int,
	@User varchar(MAX),
	@LabsNotShowing varchar(255),
	@PlanToAddress varchar(255)


AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	INSERT INTO [Pharm].[Lithium_Writeback]
	SELECT DISTINCT
		@Sta3n AS sta3n
		,@PatientICN AS PatientICN
		,1 AS patientreviewed
		,GetDate () AS ExecutionDate
		,@User AS [UserID]
		,SUBSTRING(REPLACE(@LabsNotShowing,'Enter Text Here',''),1,255) AS [LabsNotShowing]
		,SUBSTRING(REPLACE(@PlanToAddress,'Enter Text Here',''),1,255) AS [PlanToAddress]
	;

	DELETE FROM [Pharm].[Lithium_Writeback]
	WHERE ([LabsNotShowing] = 'Enter Text Here' AND  [PlanToAddress] = 'Enter Text Here')
	OR ([LabsNotShowing] = '' AND  [PlanToAddress] = '')
	;

END
