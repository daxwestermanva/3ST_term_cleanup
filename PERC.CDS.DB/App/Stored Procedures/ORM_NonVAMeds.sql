
-- =============================================
-- Author:		Sohoni, Pooja
-- Create date: 2018-09-11
-- Description:	Pulling in non-VA controlled substance prescriptions for STORM
-- EXEC App.ORM_NonVAMeds @User='vha21\vhapalmartins',@Patient='1003443733'
-- 07-11-2022	CW	Adding in all controlled substances
-- 01-14-2024	SM  updating to integrated Present.NonVAMeds
-- 02-06-2024	SM	added 12m lookback/active non va meds since integrated Present.NonVAMeds is more expansive for RV 2.0 implementation
-- 02-18-2024	SM	updated where clause to meet tall and skinny NonVAMed format 
-- 02-20-2024	SM	correcting opioidagonist where clause to include same timeframe
-- 02-24-2024	SM	correcting alias
-- =============================================
CREATE   PROCEDURE [App].[ORM_NonVAMeds] 
  
    @User VARCHAR(MAX),
    @Patient VARCHAR(1000)
 
 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


 
--First, create a table with all the patients (ICNs) that the user has permission to see
DROP TABLE IF EXISTS #Patient
SELECT pat.PatientICN,pat.MVIPersonSID, pat.Sta3n_Loc as Sta3n --Parent query gets ALL PatientSIDs and locations for the patient
INTO  #Patient
FROM  [Present].[StationAssignments] as pat  WITH (NOLOCK)
INNER JOIN (SELECT Sta3n FROM [App].[Access](@User)) as Access on pat.Sta3n_Loc = Access.Sta3n
WHERE PatientICN = @Patient
 
 
--Then, using that table, select the relevant non-VA controlled substance prescriptions
SELECT DISTINCT 
	p.PatientICN
	,DocumentedDate=nvm.[InstanceFromDate] -- keeping name in report, [Present].[NonVAMed] has updated names when integrated
	,PharmacyOrderableItem=nvm.OrderName   -- keeping name in report, [Present].[NonVAMed] has updated names when integrated
	,DrugNameWithoutDose=nvm.DrugNameWithoutDose_Max  -- keeping name in report, [Present].[NonVAMed] has updated names when integrated
FROM  [Present].[NonVAMed] AS nvm  WITH (NOLOCK)
INNER JOIN #Patient p on p.MVIPersonSID=nvm.MVIPersonSID
LEFT join (
			select MVIPersonSID
			from [Present].[NonVAMed] 
			where 1=1
			AND SetTerm in ('OpioidAgonist_RX')
			AND [InstancetoDate] IS NULL	
			AND [InstanceFromDate] >=  DATEADD(month, -12, CAST(GETDATE() AS DATE))
			) b on nvm.MVIPersonSID=b.MVIPersonSID
WHERE SetTerm in ('OpioidforPain','Anxiolytic','SedatingPainORM_Rx','ControlledSubstance') --expanding to include all controlled substances
AND nvm.[InstancetoDate] IS NULL	
AND nvm.[InstanceFromDate] >=  DATEADD(month, -12, CAST(GETDATE() AS DATE))
and b.MVIpersonSID is NULL -- exclude OpioidAgonist_RX

END