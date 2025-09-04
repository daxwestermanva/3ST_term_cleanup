-- =============================================
-- Author:		Amy Robinson
-- Create date: <July 25 2017>
-- Description:	List all our reports for a parameter
-- =============================================
CREATE PROCEDURE  [App].[p_Reports]


	-- Add the parameters for the stored procedure here
 @Project as varchar(100)
    
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON; 
  
  select * 
From Maintenance.CurrentReports
where Project = @Project
order by ReportName
  
  
END


--go 
--exec [dbo].[sp_SignAppObject] @ObjectName = 'Admin_DiagnosisValidation_LSV' --Edit the name here to equal you procedure name above EXACTLY