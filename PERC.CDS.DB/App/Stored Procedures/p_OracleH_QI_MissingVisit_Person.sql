

-- =============================================
-- Author: Liam Mina
-- Create date: 3/19/2025
-- Description: 
-- =============================================
/* 
	EXEC [App].[p_OracleH_QI_MissingVisit_Person] @ChecklistID='668'
	
	
*/
-- =============================================
CREATE PROCEDURE [App].[p_OracleH_QI_MissingVisit_Person] 
(
	@ChecklistID VARCHAR(MAX)
	,@PersonType VARCHAR(10)
) 

AS
BEGIN	
SET NOCOUNT ON

	
	SELECT DISTINCT b.StaffName AS ReferenceName
		,b.PersonStaffSID AS ReferenceSID
		,b.Stapa
	FROM [OracleH_QI].[PossibleMHVisits] b WITH (NOLOCK)
	WHERE b.StaPa=@ChecklistID AND @PersonType='Provider'
	UNION ALL
	SELECT DISTINCT c.PatientName AS ReferenceName
		,b.MVIPersonSID AS ReferenceSID
		,b.StaPa
	FROM [OracleH_QI].[PossibleMHVisits] b WITH (NOLOCK)
	INNER JOIN Common.MasterPatient c WITH (NOLOCK)
		ON b.MVIPersonSID=c.MVIPersonSID
	WHERE @PersonType='Patient' AND b.StaPa = @ChecklistID
	ORDER BY ReferenceName


END