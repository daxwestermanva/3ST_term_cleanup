

-- =============================================
-- Author:		<Tolessa Gurmessa>
-- Create date: <03/06/2024>
-- Description:	Adopted from [App].[MBC_Patient_LSV_v02] for DoD OUD Patient Reprot LSV
-- 2024-03-11  TG modifying the SP to pull the datasets from its version in the Code schema
-- 2024-03-13  TG adding cohorts, so that users can filter

-- =============================================
CREATE PROCEDURE [App].[ORM_DoDOUDPatient_LSV]
(
	@User VARCHAR(MAX)
	,@Cohort varchar(10)
	,@Quarter VARCHAR(17)
)
WITH RECOMPILE

AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @Patient VARCHAR(1000); SET @User = 'VHA21\VHAPALMINAL'; SET @Patient = '1002058830'
	--DECLARE @User VARCHAR(MAX), @Cohort VARCHAR(1000); SET @User = 'VHA21\VHAPALMINAL'; SET @Cohort = 2

	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	
	SELECT *
	FROM ORM.DoDOUDPatientReport r WITH(NOLOCK)
	WHERE EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	AND (
				(@Cohort=3) -- All patients in table 			 
				OR (@Cohort = 1 and OUD_DoD = 1 AND OUD = 0) 
				OR (@Cohort = 2 and OUD = 1 AND OUD_DoD = 1) 
				
			)
	AND (r.FYQ IN (SELECT value FROM string_split(@Quarter ,',')))
END