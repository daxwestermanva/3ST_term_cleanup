






-- =============================================
-- Author:		Meenah Paik
-- Create date: 10/26/2021
-- Description:	Writeback SP for Measures
-- =============================================
CREATE PROCEDURE [App].[PDSI_Writeback_Measures]
	-- Add the parameters for the stored procedure here

	@MVIPersonSID INT


AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT 
	MVIPersonSID
	,Measure
FROM [PDSI].[PatientDetails] a
WHERE MeasureUnmet = 1 
	AND MVIPersonSID = @MVIPersonSID 

END