-- =============================================
-- Author:		<Paik, Meenah>
-- Create date: <02/04/2016>
-- Description:	<ICD proc codes for ORM definitions report>
-- Modifications:
   -- 2019-10-11 - RAS - Changed to pull directly from LookUp ICD9Proc
   -- 2020-12-29 - PS  - ICD10 instead of ICD9
   -- 2022-05-05 - RAS - Added code to use LookUp.ListMember, but need SignObject security in place so 
						 -- app SP can query CDW directly

-- TESTING:
	/* Possible parameters:
		-- 'Psych_Therapy'
		--	,'RM_ActiveTherapies'
		--	,'RM_OccupationalTherapy'
		--	,'RM_ChiropracticCare'
		--	,'CIH'
	*/
-- EXEC [App].[ORM_Definitions_ICDProc] 'Psych_Therapy_ICD10Proc,RM_ActiveTherapies_ICD10Proc'
-- EXEC [App].[ORM_Definitions_ICDProc] 'Psych_Therapy,RM_ActiveTherapies'
-- =============================================
CREATE PROCEDURE [App].[ORM_Definitions_ICDProc]
	@ICDproc1 varchar(max)
AS
BEGIN

	SET NOCOUNT ON;

  DECLARE @ICDList TABLE (ICDProc1 VARCHAR(MAX))
  -- Add values to the table
  INSERT @ICDList SELECT value FROM string_split(@ICDproc1, ',')

SELECT DISTINCT 
	ICD10ProcedureDescription as ICDProcedureDescription
    ,ICD10ProcedureCode as ICDProcedureCode
    ,up.ICDProc1
FROM (
	SELECT * FROM [LookUp].[ICD10Proc] WITH (NOLOCK)
	) p 
UNPIVOT (ICDProcValue FOR ICDProc1 IN 
	(Psych_Therapy_ICD10Proc
	,RM_ActiveTherapies_ICD10Proc
	,RM_OccupationalTherapy_ICD10Proc
	,RM_ChiropracticCare_ICD10Proc
	,CIH_ICD10Proc
	) 
	) up
INNER JOIN @ICDList l on l.ICDProc1=up.ICDProc1
WHERE ICDProcValue=1

--SELECT DISTINCT 
--	lm.AttributeValue AS ICDProcedureCode
--	,d.ICD10ProcedureDescription AS ICDProcedureDescription
--	,lm.List AS ICDProc1
--FROM [LookUp].[ListMember] lm
--INNER JOIN [Dim].[ICD10ProcedureDescriptionVersion] d ON d.ICD10ProcedureSID = lm.ItemID
--INNER JOIN @ICDList l on l.ICDProc1 = lm.List
--WHERE lm.Domain = 'ICD10PCS'
--	AND d.CurrentVersionFlag = 'Y'

END