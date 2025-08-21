-- =============================================
-- Author:		Amy Robinson
-- Create date: 2022-11-18
-- Description:	Back up to archive
-- =============================================
CREATE PROCEDURE [Maintenance].[CreateBackUps_Monthly]
AS
BEGIN

DECLARE @BackUpDB VARCHAR(50)='OMHSP_PERC_CDSArchive' --only if needed, otherwise will use same DB as table
DECLARE @TStamp VARCHAR(10)  ='_'+CONVERT(CHAR(8),GETDATE(),112) --date of run formatted yyymmdd

--order of parameters TableName,SchemaName,Database, Suffix

--If not passed 
  --database - backup will be saved database of run
  --suffix - will be _BK

EXEC [Tool].[DoBackUp] 'RiskScore','ORM',@BackUpDB,@TStamp
	      --Creates Table OMHSP_PERC_CDSArchive.ORM.RiskScore_yyyymmdd
  
  
  
 
END