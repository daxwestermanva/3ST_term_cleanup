 
 
 
 
/************************************************************************************
Author: Amy Robinson 
Create date: <4/5/2016>
Description: An app station default so reports can be sent through subscription
 
 Updates
	2021-09-17	JEB	- Enclave Refactoring
 
************************************************************************************/
CREATE   PROCEDURE [App].[p_Sta6aIDDefault]  
(
	@User VARCHAR(50)
)
AS
BEGIN
 
	--For inline testing
	--DECLARE @User VARCHAR(50) = 'vha03\VHAV03CORTEL'
 
	SELECT 
		a.LCustomerID
		,a.ADDomain
		,a.ADLogin
		,ISNULL(b.InferredVISN ,a.InferredVISN) as InferredVISN 
		,ISNULL(b.Sta6aID,a.InferredSta3n) as InferredSta3n
		,ISNULL(b.ChecklistID,a.InferredSta3n) as InferredChecklistID
	FROM [LCustomer].[LCustomer] a WITH (NOLOCK)
	LEFT JOIN [Config].[InferredSta6AID] b WITH (NOLOCK)
		ON SUBSTRING(a.ADLogin,4,3) = b.LocationIndicator
	WHERE a.ADDomain = SUBSTRING(@User,1,PATINDEX('%\%',@User)-1)
		AND a.ADLogin = SUBSTRING(@User,PATINDEX('%\%',@User)+1,99)
	;
	   
END
