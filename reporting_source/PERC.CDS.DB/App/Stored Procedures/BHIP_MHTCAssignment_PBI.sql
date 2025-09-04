

-- =============================================
-- Author:		Grace Chung
-- Create date: 1/11/2023
-- Description:	Stored procedure for PowerBI report 
-- =============================================
CREATE PROCEDURE [App].[BHIP_MHTCAssignment_PBI]
AS
BEGIN
 
Select * from [App].[vwBHIP_MHTC_Assignment] WITH (NOLOCK)

END