-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <9/19/2016>
-- Description:	Main data date for the Persceptive Reach report
-- =============================================
CREATE PROCEDURE [App].[Disclaimer]

--execute sp_opioid  2012,358,16,0,1
--execute sp_opioid  2012,0,16,0,1
	-- Add the parameters for the stored procedure here
    @User varchar(max),
  @PatientSID varchar(1000),
  @Diagnosis varchar(100)
  
 
  --@PatientICN varchar(1000)
	

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
  
 
 Select 'These documents or records or information  contained herein are confidential and privileged under the provisions of 38 U.S.C. 5705, and it’s implementing regulations. This material cannot be disclosed to anyone without authorization as provided by the law and its regulations. This statute provides for fines up to $20,000 for unauthorized disclosures.' as Disclaimer


END


--go 
--exec [dbo].[sp_SignAppObject] @ObjectName = 'Validation_Diagnosis_LSV' --Edit the name here to equal you procedure name above EXACTLY