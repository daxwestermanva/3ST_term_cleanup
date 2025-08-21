

-- =============================================
-- Author:		Amy Robinson
-- Create date: 6/20/2017
-- Description:	Writeback SP for CRISTAL
-- Updates
--	2018-08-13 - RAS -  Changed schemas to CRISTAL and renamed "writeback" for clarification, especially with upcoming expansion and more users outside VCL
--	2019-01-10 - Jason Bacani - Formatting; NOLOCKs; Explicit field list for insert
--	2022-01-24 - LM - Because procedure is now used in STORM as well as CRISTAL, added Report parameter and renamed
--
-- EXEC [App].[SSNLookup_AuditWriteback] @User = 'VHAMASTER\VHAISBBACANJ_TestOnly', @SSN = '999999999'
-- =============================================
CREATE PROCEDURE [App].[SSNLookup_AuditWriteback]
(
	@ICN VARCHAR(55),
	@User VARCHAR(55),
	@Report VARCHAR(100)
)
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @SSN VARCHAR(255); SET @User = 'VHAMASTER\VHAISBBACANJ_TestOnly'; SET @SSN = '999999999'

	INSERT INTO [CDS].[SSNLookup_AuditWriteback]
	(
		PatientICN
		,UserID
		,ExecutionDate
		,Report
	)
	SELECT DISTINCT
		@ICN AS PatientSSN 
		,@User AS UserID
		,GETDATE() AS ExecutionDate
		,@Report AS Report
	;

END