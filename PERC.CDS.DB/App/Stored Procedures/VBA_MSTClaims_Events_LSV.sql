-- =============================================
-- Author: Elena Cherkasova
-- Create date: 2024-09-05
-- Description: List of events by patient for the VBA MST Claims Notifications Report

--MODIFICATIONS:
--
-- =============================================
--EXEC [App].[VBA_MSTClaims_Events_LSV]	@User = 'VHA21\vhapalstephr6',@MVIPersonSID=''

-- =============================================
CREATE PROCEDURE [App].[VBA_MSTClaims_Events_LSV] 
			@User varchar(MAX),
			@MVIPersonSID int

AS
BEGIN	
SET NOCOUNT ON

SELECT DISTINCT e.[MVIPersonSID]
      ,mp.[PatientName]
      ,mp.[LastFour]
	  ,c.[StaPa_PCP]
      ,c.[StaPa_MHTC]
      ,c.[StaPa_Homestation]

      ,e.[EventNumber]
      ,e.[EventType]
      ,e.[EventDate]
      ,e.[RecentEvent]

  FROM [VBA].[MSTClaimsEvents] as e WITH(NOLOCK)
  LEFT JOIN [VBA].[MSTClaimsCohort] AS c WITH(NOLOCK)
	ON e.MVIPersonSID = c.MVIPersonSID
  LEFT JOIN [VBA].[MSTClaimsNotes] AS n WITH(NOLOCK)
	ON e.MVIPersonSID = n.MVIPersonSID
  LEFT JOIN [Common].[MasterPatient] AS mp WITH (NOLOCK)
    ON e.MVIPersonSID = mp.MVIPersonSID
  INNER JOIN [LookUp].[ChecklistID] as l WITH (NOLOCK)
	ON l.StaPa = c.StaPa_PCP
		OR l.StaPa = c.StaPa_MHTC
		OR l.StaPa = c.StaPa_Homestation
  INNER JOIN (SELECT Sta3n FROM [App].[Access] (@User)) as Access ON l.Sta3n = Access.Sta3n
  WHERE e.MVIPersonSID = @MVIPersonSID
;

END