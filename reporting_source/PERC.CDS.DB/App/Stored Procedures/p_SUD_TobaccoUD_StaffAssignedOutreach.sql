

-- =============================================
-- Author:		<Claire Hannemann>
-- Create date: <4/12/2024>
-- Description:	<App.p_SUD_TobaccoUD_StaffAssignedOutreach>

-- EXEC  [App].[p_SUD_TobaccoUD_StaffAssignedOutreach] '618'
-- =============================================
CREATE PROCEDURE [App].[p_SUD_TobaccoUD_StaffAssignedOutreach]
	@Station varchar(5)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT DISTINCT ISNULL(HF_staffSID2,HF_staffSID1) as Assigned_Outreach_staffSID
		,ISNULL(HF_staff2,HF_staff1) as Assigned_Outreach_staff
	FROM [SUD].[TobaccoUD]
	WHERE Homestation_ChecklistID=@Station 
	ORDER BY Assigned_Outreach_staff
	
END