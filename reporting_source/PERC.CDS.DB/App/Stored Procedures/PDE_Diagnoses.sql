
/* =============================================
-- Author: Elena Cherkasova (EC)		 
-- Create date: 2024-01-18
-- Description: Data set for PDE Diagnoses subreport. Currently focused on suicide-related diagnoses during PDE admission.

 EXEC [App].[PDE_Diagnoses] 
    @MVIPersonSID=''
   ,@DisDay=''
   ============================================= */
CREATE PROCEDURE [App].[PDE_Diagnoses]

  @MVIPersonSID INT
 ,@DisDay date

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT * FROM PDE_Daily.Diagnoses
WHERE MVIPersonSID=@MVIPersonSID
and DisDay=@DisDay
ORDER BY MVIPersonSID desc
;

END