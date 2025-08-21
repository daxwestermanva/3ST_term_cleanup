

-- =============================================
-- Author:		Claire Hannemann
-- Create date: 8/20/2021
-- Description:	Writeback SP for SMI report
-- =============================================
CREATE PROCEDURE [App].[SMI_PatientReportWriteback]
	-- Add the parameters for the stored procedure here
    @Sta3n varchar(10),
	@MVIPersonSID int,
	@User varchar(MAX),
	@Comments varchar(255)



AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

INSERT INTO [SMI].[PatientReport_Writeback]
SELECT  
	@Sta3n as sta3n
	,@MVIPersonSID as MVIPersonSID
	,1 as PatientReviewed
	,GetDate() as ExecutionDate
	,@User as UserID
	,@Comments as Comments
	,'SMI Cohort' as VariableName

DELETE FROM [SMI].[PatientReport_Writeback]
WHERE Comments = 'Enter Text Here' 
	OR Comments IS NULL
 

END