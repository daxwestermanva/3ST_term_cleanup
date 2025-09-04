-- =============================================
-- Author:		Elena Cherkasova
-- Create date: 5/14/2018
-- Description:	PastAppt6mo parameter/count for PDSI_LithiumPatientCohort report
-- 2018/06/07 - Jason Bacani - Removed hard coded database references
-- =============================================
CREATE PROCEDURE [App].[p_LithiumPastAppt]

	@Prescriber int,
	@Station NVARCHAR (30)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
SELECT COUNT(DISTINCT PatientICN) as PastAppt6mo
FROM [Pharm].[LithiumPatientReport] as a
WHERE a.integratedSta3n =  @Station 
	AND isnull(PrescriberSID,-1) in (@Prescriber)
	AND FollowUpKey in (2,3)

END
