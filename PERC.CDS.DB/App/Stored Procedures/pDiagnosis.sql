-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <9/19/2016>
-- Description:	Main data date for the Persceptive Reach report
-- =============================================
CREATE PROCEDURE [App].[pDiagnosis]

--execute sp_opioid  2012,358,16,0,1
--execute sp_opioid  2012,0,16,0,1
	-- Add the parameters for the stored procedure here
    @User varchar(max),
  @Station varchar(1000)
  
  
 
  --@PatientICN varchar(1000)
	

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
  
select ColumnName,PrintName 
from LookUp.ColumnDescriptions where tablename = 'icd10'
order by PrintName

END


--go 
--exec [dbo].[sp_SignAppObject] @ObjectName = 'Validation_Diagnosis_LSV' --Edit the name here to equal you procedure name above EXACTLY