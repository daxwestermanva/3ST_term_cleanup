-- =============================================
-- Author:		Rebecca Stephens (RAS)
-- Create date: 2018-05-09
-- Description:	Back up writeback tables
--Modifications
-- 051918 added parameter to back up to OMHSP_PERC_SbxB
-- 2024-04-15	LM	Changed default backupDB to CDSArchive
-- =============================================
CREATE PROCEDURE [Maintenance].[CreateBackUps_Daily]
AS
BEGIN

DECLARE @BackUpDB VARCHAR(50)='OMHSP_PERC_CDSArchive' --only if needed, otherwise will use same DB as table

	EXEC [Tool].[DoBackUp] 'Writeback','REACH',@BackUpDB
	EXEC [Tool].[DoBackUp] 'WritebackHistoric','REACH',@BackUpDB
	EXEC [Tool].[DoBackUp] 'SSNLookup_AuditWriteback','CDS',@BackUpDB

	--EXEC [Tool].[DoBackUp] '',''
	--EXEC [Tool].[DoBackUp] '',''

	EXEC [Tool].[DoBackUp] 'PatientReport_Writeback','SMI',@BackUpDB 

	EXEC [Tool].[DoBackUp] 'Lithium_Writeback','Pharm' ,@BackUpDB

	EXEC [Tool].[DoBackUp] 'Antidepressant_Writeback','Pharm' ,@BackUpDB
	EXEC [Tool].[DoBackUp] 'Writeback','PDSI' ,@BackUpDB

	EXEC [Tool].[DoBackup] 'HRF_Writeback','CaringLetters',@BackUpDB
	EXEC [Tool].[DoBackup] 'HRF_Mailings','CaringLetters',@BackUpDB

	EXEC [Tool].[DoBackup] 'VCL_Writeback','CaringLetters',@BackUpDB
	EXEC [Tool].[DoBackup] 'VCL_Mailings','CaringLetters',@BackUpDB

END