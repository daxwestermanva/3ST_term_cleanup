-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <1/24/2017>
-- Description:	Main data date for the Measurement based care report; Used by CRISTAL SSRS reports
-- Updates
--	2019-01-09 - Jason Bacani - Refactored to use MVIPersonSID for future when CDS tables have MVIPersonSID; Performance tuning; formatting; NOLOCKs
--  2019-04-05 - LM - Added MVIPersonSID to initial select statement
--  2020-09-21 - RAS - Changed initial patient selection to use MasterPatient and SPatient join. This is not a permanent solution.
--	2020-11-02 - LM - Added RxStatus
--  2022-06-15 - AR - pointing to Rockies MPR
--	2022-06-24 - LM - Updating to reflect changes in Present.Medications
--  2022-11-15   AR Fixing gap between time it's written and time it makes it into MPR where it's pulling from previous trial

-- EXEC [App].[MBC_Medications_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @Patient = 1001092794
-- EXEC [App].[MBC_Medications_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @Patient = 1011997759
-- 2022-01-27 TG changed the language to be displayed for Anxiolytics.
-- =============================================
CREATE PROCEDURE [App].[MBC_Medications_LSV]
(
    @User VARCHAR(MAX),
    @Patient VARCHAR(1000)
) 
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @Patient VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @Patient = 1016338347
	--DECLARE @User VARCHAR(MAX), @Patient VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @Patient = 1012614757
	--DECLARE @User VARCHAR(MAX), @Patient VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @Patient = 1016844989

	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT 
		a.MVIPersonSID
	INTO #Patient
	FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
	WHERE a.PatientICN =  @Patient
		and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;

	SELECT DISTINCT 
		a.DrugNameWithoutDose
		,ISNULL(o.MPRToday,m.MPRToday) AS MPRToday 
		,CASE WHEN RxStatus IN ('Active','Suspended') 
			THEN CAST(DATEDIFF(M,ISNULL(o.TrialEndDateTime,m.TrialEndDateTime) ,GETDATE()) + ISNULL(o.MonthsInTreatment, m.MonthsInTreatment ) AS numeric(18,1))
			ELSE CAST(ISNULL(o.MonthsInTreatment, m.MonthsInTreatment ) AS numeric(18,1)) 
			END AS MonthsInTreatment
		,a.PrescriberName
		,d.Facility 
		,CASE WHEN ISNULL(o.MPRToday,m.MPRToday) IS NULL THEN 0 ELSE 1 END AS MPRCalculated_Rx 
		,CASE 
			WHEN a.OpioidForPain_rx   = 1 THEN 'Opioid'
			WHEN a.Anxiolytics_Rx     = 1 THEN 'Co-Prescribed Sedating Medications'
			WHEN a.SedatingPainORM_rx = 1 THEN 'Pain Medications (Sedating)'
			END AS ORM_MedType
		,a.CHOICE
		,a.RxStatus
		,CASE WHEN a.DrugStatus = 'ActiveRx' THEN 0 ELSE 1 END AS ExcludeCRISTAL
	FROM #Patient AS p 
	INNER JOIN [Present].[Medications] AS a WITH (NOLOCK)
		ON p.MVIPersonSID = a.MVIPersonSID
		AND (a.NationalDrugSID > 0 OR a.VUID > 0)
	LEFT JOIN [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Drug] AS m WITH (NOLOCK)
		ON a.DrugNameWithoutDose = m.DrugNameWithoutDose 
		AND m.MVIPersonSID = a.MVIPersonSID
		AND m.MostRecentTrialFlag = 'True' and m.ActiveMedicationFlag='True'
		AND a.Sta3n <> 200
  LEFT JOIN [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Opioid] AS o WITH (NOLOCK)
		ON a.DrugNameWithDose = o.DrugNameWithDose 
		AND o.MVIPersonSID = a.MVIPersonSID
		AND o.MostRecentTrialFlag = 'True' and o.ActiveMedicationFlag='True'
		AND a.Sta3n <> 200
	LEFT JOIN [LookUp].[Sta6a] AS c WITH (NOLOCK)
		ON a.Sta6a = c.Sta6a
	LEFT JOIN [LookUp].[ChecklistID] AS d WITH (NOLOCK)
		ON c.ChecklistID = d.ChecklistID
	--ORDER BY a.DrugNameWithoutDose
	;

END