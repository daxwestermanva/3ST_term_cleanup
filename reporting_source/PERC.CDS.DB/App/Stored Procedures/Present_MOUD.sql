


-- =============================================
-- Author:		Sohoni, Pooja
-- Create date: 2018-12-07
-- Description:	App stored procedure to pull in current MOUD per PatientICN for reports. This procedure
-- can be used across any reports (STORM, PDSI, etc.)
-- =============================================
CREATE PROCEDURE [App].[Present_MOUD]

    @User VARCHAR(MAX),
    @Patient VARCHAR(1000)

	--declare @user varchar(max)
	--declare @patient varchar(1000)
	--set @user='vha21\vhapalsohonp'
	--set @patient= '1003244106' 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


--First, create a table with all the patients (ICNs) that the user has permission to see

IF OBJECT_ID('tempdb..#Patient') IS NOT NULL
DROP TABLE #Patient
SELECT permission.PatientICN, b.MVIPersonSID, b.Sta3n_Loc as Sta3n --Parent query gets ALL PatientSIDs and locations for the patient
INTO  #Patient
--Subquery checks user's access to the patient and gets the PatientICN
FROM (
		SELECT PatientICN
		FROM [Present].[StationAssignments] as pat  WITH (NOLOCK)
		INNER JOIN (SELECT Sta3n FROM [App].[Access](@User)) as Access on pat.Sta3n_Loc = Access.Sta3n
		WHERE PatientICN = @Patient
    ) as Permission
INNER JOIN [Present].[StationAssignments] b  WITH (NOLOCK) on Permission.PatientICN=b.PatientICN

--Then, using that table, select the relevant non-VA controlled substance prescriptions

SELECT DISTINCT p.PatientICN
			   ,a.MOUD
			   ,a.NonVA
			   ,a.Inpatient
			   ,a.Rx
			   ,a.OTP
			   ,a.CPT
			   ,a.CPRS_Order
			   ,a.MOUDDate
			   ,a.Prescriber
			   ,a.StaPa AS Location
			   ,CASE WHEN Inpatient = 1 THEN 'Inpatient'
			    WHEN Rx = 1 THEN 'Outpatient Prescription'
				WHEN OTP = 1 THEN 'OTP'
				WHEN CPT = 1 THEN 'CPT'
				WHEN CPRS_Order = 1 THEN 'CPRS Order'
				END AS Source
FROM [Present].[MOUD] AS a  WITH (NOLOCK)
INNER JOIN #Patient p on p.MVIPersonSID=a.MVIPersonSID

END