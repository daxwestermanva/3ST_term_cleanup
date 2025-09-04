


-- =============================================
-- Author:		Liam Mina
-- Create date: 2021-10-08
-- Description:	Get SSN and network username for all staff, to get permissions for CRISTAL and STORM SSN lookup reports

-- UPDATE:	

-- =============================================

CREATE PROCEDURE [Code].[Present_SStaff]
AS
BEGIN

DROP TABLE IF EXISTS #Staff
SELECT DISTINCT
	NetworkUsername
	,StaffSSN
INTO #Staff
FROM SStaff.SStaff WITH (NOLOCK)
; 

CREATE CLUSTERED INDEX UserName ON #Staff (NetworkUsername)
;
	
EXEC [Maintenance].[PublishTable] '[Present].[SStaff]', '#Staff'


DROP TABLE IF EXISTS #StaffSID
SELECT DISTINCT
	StaffSID
	,NetworkUsername
	,StaffSSN
INTO #StaffSID
FROM SStaff.SStaff WITH (NOLOCK)
; 

CREATE CLUSTERED INDEX StaffSID ON #StaffSID (StaffSID)

EXEC [Maintenance].[PublishTable] '[Present].[SStaffSID]', '#StaffSID'

END