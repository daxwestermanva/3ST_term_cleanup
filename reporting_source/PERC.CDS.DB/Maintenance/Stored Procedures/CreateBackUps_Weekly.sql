-- =============================================
-- Author:		Rebecca Stephens (RAS)
-- Create date: 2018-05-09
-- Description:	Back up static tables tables
-- 2018-05-19	SM	added db parameter to back up in SbxB and added more tables
-- 2021-01-25	RAS	Changed REACH RiskScore and RiskScoreHistoric to _VM versions.
-- 2023-02-14	LM	Removed backups for Dim.GroupType (move to config) and Dim.InpatientType (no longer exists in CDS)
-- 2024-04-15	LM	Changed default backupDB to CDSArchive
-- 2024-06-17   TG  Removed backups for REACHSTORM_APGMetricTable
-- =============================================
CREATE PROCEDURE [Maintenance].[CreateBackUps_Weekly]
AS
BEGIN

DECLARE @BackUpDB VARCHAR(50)='OMHSP_PERC_CDSArchive' --only if needed, otherwise will use same DB as table
	------------------------------------------------------------------
	-- PERC Tables
	------------------------------------------------------------------

	EXEC [Tool].[DoBackUp] 'Definitions','REACH' ,@BackUpDB

	-- added 051918 SM
	EXEC [Tool].[DoBackUp] 'RiskFactorCurrent','REACH' ,@BackUpDB
	EXEC [Tool].[DoBackUp] 'RiskFactors','REACH' ,@BackUpDB
	EXEC [Tool].[DoBackUp] 'RiskScore','REACH' ,@BackUpDB
	EXEC [Tool].[DoBackUp] 'RiskScoreHistoric','REACH' ,@BackUpDB
	
	EXEC [Tool].[DoBackup] 'HRF_Cohort','CaringLetters',@BackUpDB
	EXEC [Tool].[DoBackup] 'HRF_NCOA_BadAddress_DoNotSend','CaringLetters',@BackUpDB
	EXEC [Tool].[DoBackup] 'HRF_NCOA_UpdateAddress','CaringLetters',@BackUpDB
	EXEC [Tool].[DoBackup] 'HRF_NCOA_BadAddress_SecureDestroy','CaringLetters',@BackUpDB

	EXEC [Tool].[DoBackup] 'VCL_Cohort','CaringLetters',@BackUpDB
	EXEC [Tool].[DoBackup] 'VCL_NCOA_BadAddress','CaringLetters',@BackUpDB
	EXEC [Tool].[DoBackup] 'VCL_NCOA_UpdateAddress','CaringLetters',@BackUpDB

	EXEC [Tool].[DoBackUp] 'MonthlyMetrics','REACH',@BackUpDB
	

	EXEC [Tool].[DoBackUp] 'IDUCohort','SUD',@BackUpDB

	EXEC [Tool].[DoBackUp] 'DashboardHits','CDS',@BackUpDB

	--EXEC [Tool].[DoBackUp] '',''

	
END