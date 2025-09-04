 
 
 
 
/************************************************************************************
Author: Amy Robinson 
Create date: <4/5/2016>
Description: An app station default so reports can be sent through subscription
 
 Updates
	2021-09-17	JEB	- Enclave Refactoring
 
************************************************************************************/
CREATE   PROCEDURE [App].[p_Sta6aIDDefault_PBI]  
(
	@User VARCHAR(50)
)
AS
BEGIN
 
	--For inline testing
	--DECLARE @User VARCHAR(50) = 'vha21\VHAPALMINAL'
 
	SELECT 
		LCustomerID
		,ADDomain
		,ADLogin
		,InferredVISN 
		,InferredSta3n
		,InferredChecklistID
	FROM App.UserDefaultParameters WITH (NOLOCK)
	WHERE ADAccount = @User
	;

END