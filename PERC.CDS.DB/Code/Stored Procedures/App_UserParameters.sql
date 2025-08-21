

CREATE PROCEDURE [Code].[App_UserParameters]
AS

BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
DROP TABLE IF EXISTS #UserDefaults
SELECT DISTINCT
	a.LCustomerID
	,a.ADDomain
	,a.ADLogin
	,ISNULL(b.InferredVISN ,a.InferredVISN) as InferredVISN 
	,ISNULL(LEFT(b.Sta6aID,3),a.InferredSta3n) as InferredSta3n
	,ISNULL(b.ChecklistID,a.InferredSta3n) as InferredChecklistID
	,aa.ADAccount
INTO #UserDefaults
FROM [LCustomer].[LCustomer] a WITH (NOLOCK)
INNER JOIN [LCustomer].[AllAuthorization] aa WITH (NOLOCK)
	ON a.LCustomerID=aa.LCustomerID
LEFT JOIN [Config].[InferredSta6AID] b WITH (NOLOCK)
	ON SUBSTRING(a.ADLogin,4,3) = b.LocationIndicator


EXEC [Maintenance].[PublishTable] 'App.UserDefaultParameters','#UserDefaults'

DROP TABLE IF EXISTS #Users
SELECT DISTINCT
	a.LCustomerID
	,a.ADDomain
	,a.ADLogin
	,aa.ADAccount
	,aa.Sta3n
	,ch.VISN
	,ch.ChecklistID
	,ch.Facility
INTO #Users
FROM [LCustomer].[LCustomer] a WITH (NOLOCK)
INNER JOIN [LCustomer].[AllAuthorization] aa WITH (NOLOCK)
	ON a.LCustomerID=aa.LCustomerID
INNER JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
	ON aa.Sta3n=ch.STA3N
WHERE aa.Sta3n>0


EXEC [Maintenance].[PublishTable] 'App.UserPermissions','#Users'

EXEC [Log].[ExecutionEnd]

END