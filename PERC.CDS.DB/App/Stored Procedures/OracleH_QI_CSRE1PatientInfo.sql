

-- =============================================
-- Author:		Grace Chung
-- Create date: 1/11/2023
-- Description:	Stored procedure for PowerBI report 
-- =============================================
CREATE PROCEDURE [App].[OracleH_QI_CSRE1PatientInfo]
AS
BEGIN
 
Select * from [OracleH_QI].[CSRE1PatientInfo] WITH (NOLOCK)

END