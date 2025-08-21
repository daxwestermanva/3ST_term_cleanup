
-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <1/24/2017>
-- Description:	Main data date for the Measurement based care report
-- 2019/01/09 - Jason Bacani - Added NOLOCKs; Formatting
-- 2019/01/16 - Jason Bacani - Refactored to utilize MVIPersonSID
-- 2019/04/26 - Liam Mina - added NationalPatientRecordFlag to ActiveFlag partition to account for different active statuses of different types of PRFs
-- 2020/06/02 - Liam Mina - added time zone conversion to prevent duplicate records due to time zone issues
-- 2020/09/16 - Pointed to _VM tables
-- 2021/09/13 - Jason Bacani - Enclave Refactoring - Counts confirmed; Some formatting; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
-- 2021/10/07 - Liam Mina - pointed to CDS tables for patient record flag history
-- 2023/04/01 - LM - Added flag owner facility

-- Sample execution:
--		EXEC [App].[MBC_PatientRecordFlag_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @Patient = '1009250029'
--		EXEC [App].[MBC_PatientRecordFlag_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @Patient = '1009047973'
-- =============================================
CREATE PROCEDURE [App].[MBC_PatientRecordFlag_LSV]
(
	@User varchar(max),
	@Patient varchar(1000)
) 
AS
BEGIN
	SET NOCOUNT ON;
 	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @Patient VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @Patient = '1009250029'
	--DECLARE @User VARCHAR(MAX), @Patient VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @Patient = '1000671025'

	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT 
		MVIPersonSID, PatientICN
	INTO #Patient
	FROM [Common].[MasterPatient] b WITH (NOLOCK)
	WHERE b.PatientICN =  @Patient
		AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;

	SELECT DISTINCT 
		NationalPatientRecordFlag='HIGH RISK FOR SUICIDE'
		,ActiveFlag=CASE WHEN h.ActiveFlag IS NULL THEN 'Z' ELSE h.ActiveFlag END
		,CAST(h.ActionDateTime AS Date) AS ActionDateTime
		,h.ActionType AS PatientRecordFlagHistoryAction
		,h.ActionTypeDescription AS ActionName
		,h.OwnerChecklistID
		,h.OwnerFacility
	FROM #Patient AS p
	LEFT JOIN [OMHSP_Standard].[PRF_HRS_CompleteHistory]  AS h WITH(NOLOCK)
		ON p.MVIPersonSID=h.MVIPersonSID
	
	UNION ALL

	SELECT DISTINCT 
		NationalPatientRecordFlag='BEHAVIORAL'
		,ActiveFlag=CASE WHEN h.ActiveFlag IS NULL THEN 'Z' ELSE h.ActiveFlag END
		,CAST(h.ActionDateTime AS Date) AS ActionDateTime
		,h.ActionType AS PatientRecordFlagHistoryAction
		,h.ActionTypeDescription AS ActionName
		,h.OwnerChecklistID
		,h.OwnerFacility
	FROM #Patient AS p
	LEFT JOIN [PRF].[BehavioralMissingPatient]  AS h WITH(NOLOCK)
		ON p.MVIPersonSID=h.MVIPersonSID AND h.NationalPatientRecordFlag = 'BEHAVIORAL'

	UNION ALL

	SELECT DISTINCT 
		NationalPatientRecordFlag='MISSING PATIENT'
		,ActiveFlag=CASE WHEN h.ActiveFlag IS NULL THEN 'Z' ELSE h.ActiveFlag END
		,CAST(h.ActionDateTime AS Date) AS ActionDateTime
		,h.ActionType AS PatientRecordFlagHistoryAction
		,h.ActionTypeDescription AS ActionName
		,h.OwnerChecklistID
		,h.OwnerFacility
	FROM #Patient AS p
	LEFT JOIN [PRF].[BehavioralMissingPatient]  AS h WITH(NOLOCK)
		ON p.MVIPersonSID=h.MVIPersonSID AND h.NationalPatientRecordFlag = 'MISSING PATIENT' 
	; 

END