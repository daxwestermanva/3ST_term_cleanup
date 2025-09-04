


-- =============================================
-- Author:		Grace Chung
-- Create date: 4/15/2024
-- Description:	Stored procedure for PowerBI report 
-- =============================================
CREATE PROCEDURE [App].[BHIP_MHTCFollowUp_PBI]
AS
BEGIN
 
Select * from [BHIP].[MHTC_FollowUp] WITH (NOLOCK)

END