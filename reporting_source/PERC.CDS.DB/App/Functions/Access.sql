
/************************************************************************************
DESCRIPTION: Function returns a list of Sta3ns for which the User has patient-level permission to view data
MODIFICATIONS:
	--	2018-05-16	JEB	Consolidate PERC_PERC/PERC_PsychPharm to current version, with reformatting applied	
	--	2021-04-15	RAS	Added condition where Sta3n>0 because fn is used to return list of PHI-level permissioned stations
	--	2021-09-16	JEB	Enclave Refactoring
************************************************************************************/
CREATE FUNCTION [App].[Access] 
	(@User VARCHAR(50))
RETURNS @IDTable TABLE (Sta3n int ) 
AS 
BEGIN 
	INSERT INTO @IDTable (Sta3n)
		-- DECLARE @User VARCHAR(50)  = 'VHA21\VHAPALSTEPHR6'
	SELECT DISTINCT Sta3n
	FROM [LCustomer].[AllAuthorization] WITH (NOLOCK)
	WHERE ADAccount = @User 
		AND Sta3n > 0
		;
	RETURN ;
END