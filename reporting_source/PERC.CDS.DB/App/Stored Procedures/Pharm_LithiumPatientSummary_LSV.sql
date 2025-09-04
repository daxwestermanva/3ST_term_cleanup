-- =============================================
-- Author:		<Cherkasova,Elena>
-- Create date: <4/9/18>
-- Description:	main data set for lithium patient report
-- =============================================

CREATE PROCEDURE [App].[Pharm_LithiumPatientSummary_LSV]
	@PatientICN varchar(100)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

Select a.*, ElapsedTime = DATEDIFF(day, maxlabdate, GETDate ())
FROM [Pharm].[LithiumPatientReport] as a
		where patientICN = @PatientICN
END
