-- =============================================
-- Author: Elena Cherkasova
-- Create date: 2024-09-05
-- Description: Main Dataset for the VBA MST Claims Notifications Report

--MODIFICATIONS:
--
-- =============================================
--EXEC [App].[VBA_MSTClaims_LSV]	@User = 'VHA21\vhapalstephr6',@VISN='15',@Facility = '589A4'

-- =============================================
CREATE PROCEDURE [App].[VBA_MSTClaims_LSV] 
			@User varchar(MAX),
			@Facility varchar(12),
			@VISN int

AS
BEGIN	
SET NOCOUNT ON

SELECT DISTINCT c.[MVIPersonSID]
      ,mp.[PatientName]
      ,mp.[LastFour]
      ,mp.[EDIPI]
      ,mp.[DateOfBirth]

	  ,c.[StaPa_PCP]
      ,c.[StaPa_MHTC]
      ,c.[StaPa_Homestation]

	  ,c.[EventsCount]
      ,c.[FirstEventDate]
      ,c.[LatestEventDate] 
      ,c.[DropOffDate]

      ,c.[StaPa_Note]	
	  ,NoteCount = ISNULL(c.[NoteCount],0)
      ,c.[FirstNoteDate]
      ,c.[LatestNoteDate]
      ,c.[NoteNeededDate]
      ,NoteNeeded = CASE WHEN e.[NoteNeeded] = 1 THEN 'Yes' ELSE 'No' END

  FROM [VBA].[MSTClaimsCohort] AS c WITH(NOLOCK)
  LEFT JOIN (SELECT a.MVIPersonSID,a.StaPa_Note,a.NoteNeeded
			FROM [VBA].[MSTClaimsEvents] as a WITH(NOLOCK)
			INNER JOIN (SELECT MVIPersonSID,StaPa_Note,MaxEventDate=MAX(EventDate) FROM [VBA].[MSTClaimsEvents] GROUP BY MVIPersonSID,StaPa_Note) as b
			ON a.MVIPersonSID = b.MVIPersonSID AND a.EventDate = b.MaxEventDate
			) as e
	ON c.MVIPersonSID = e.MVIPersonSID and c.Stapa_Note = e.StaPa_Note
  LEFT JOIN [VBA].[MSTClaimsNotes] AS n WITH(NOLOCK)
	ON e.MVIPersonSID = n.MVIPersonSID
  LEFT JOIN [Common].[MasterPatient] AS mp WITH (NOLOCK)
    ON c.MVIPersonSID = mp.MVIPersonSID
  INNER JOIN [LookUp].[ChecklistID] as l WITH (NOLOCK)
	ON l.StaPa = c.StaPa_PCP
		OR l.StaPa = c.StaPa_MHTC
		OR l.StaPa = c.StaPa_Homestation
  INNER JOIN (SELECT Sta3n FROM [App].[Access] (@User)) as Access ON l.Sta3n = Access.Sta3n
  WHERE c.[Unassigned]=0
		AND (
			   (@Facility = c.StaPa_PCP)
			OR (@Facility = c.StaPa_MHTC)
			OR (@Facility = c.StaPa_Homestation)
			)
		AND (@Facility = c.StaPa_Note
			OR c.StaPa_Note IS NULL)
		AND c.DropOffDate >= CAST(getdate() AS DATE)
;

END