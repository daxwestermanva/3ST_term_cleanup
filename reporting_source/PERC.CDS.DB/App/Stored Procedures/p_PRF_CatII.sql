
/* =============================================
-- Author:		Liam Mina
-- Create date: 2024-09-19
-- Description:	Cat II Pt Record Flag parameter list for use in Cat II Flag reports
-- Updates:
--	
-- =============================================*/
CREATE PROCEDURE [App].[p_PRF_CatII]
	@Facility varchar(500)
AS
BEGIN

--DECLARE @Facility varchar(500) = '528A5,640,688'

DECLARE @FacilityList TABLE (Facility varchar(5))
INSERT @FacilityList SELECT value FROM string_split(@Facility,',')

SELECT DISTINCT 
	LocalPatientRecordFlag
FROM [PRF].[ActiveCatII_Counts] a WITH (NOLOCK)
INNER JOIN @FacilityList c ON LEFT(c.Facility,3) = LEFT(a.OwnerChecklistID,3)

END