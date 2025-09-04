/*
2021-06-07
Procedure to get 0/1 whether report is being viewed by PERC developer or other user
Using in redirect messaging for SSRS migration.

EXEC App.Admin_PERCUser @UserID='VHA21\vhapalstephr6'
*/

CREATE PROCEDURE App.Admin_PERCUser
@UserID VARCHAR(100)

AS
BEGIN

SELECT PERCUser = MAX(
	CASE WHEN UserName = @UserID THEN 1 ELSE 0 END
	)
FROM [Config].[WritebackUsersToOmit]

END