

-- =============================================
-- Author:		<Claire Hannemann>
-- Create date: <6/9/2025>
-- Description:	<[App].[p_ORM_NewOpioidNoRiskReview_Prescriber]>

-- EXEC  [App].[p_ORM_NewOpioidNoRiskReview_Prescriber] 'VHA21\VHAPALHanneC','640'
-- =============================================
CREATE PROCEDURE [App].[p_ORM_NewOpioidNoRiskReview_Prescriber]

	@User varchar(25)
   ,@Station varchar(100)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


DROP TABLE IF EXISTS #Default
SELECT StaffSID AS DefaultStaffSID
INTO #Default
FROM [ORM].[NewOpioidNoRiskReview] as pat WITH (NOLOCK)
INNER JOIN [SStaff].[SStaff] s WITH (NOLOCK)
	on pat.providersid=s.staffsid
WHERE SUBSTRING(@User, CHARINDEX('\', @User) + 1, LEN(@User)) = s.NetworkUsername
 
SELECT DISTINCT pat.ProviderSID
	, pat.MostRecentPrescriber
	, ISNULL(d.DefaultStaffSID,pat.ProviderSID) as DefaultStaffSID --= (SELECT DefaultStaffSID FROM #Default)
FROM [ORM].[NewOpioidNoRiskReview] as pat WITH (NOLOCK)
INNER JOIN (SELECT * FROM [LCustomer].[AllAuthorization] WHERE ADAccount = @User) as Access 
	on LEFT(pat.ChecklistID,3) = Access.Sta3n
LEFT JOIN #Default d on 1=1
WHERE pat.ChecklistID=@Station
ORDER BY pat.MostRecentPrescriber
	


END