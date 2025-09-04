
-- =============================================
-- Author: Elena Cherkasova
-- Create date: 2024-09-05
-- Description: List of notes by patient by facility for the VBA MST Claims Notifications Report

--MODIFICATIONS:
--
-- =============================================
--EXEC [App].[VBA_MSTClaims_Notes_LSV]	@User = 'VHA21\vhapalstephr6',@MVIPersonSID='',@Facility = ''

-- =============================================
CREATE PROCEDURE [App].[VBA_MSTClaims_Notes_LSV] 
			@User varchar(MAX),
			@MVIPersonSID INT,
			@Facility VARCHAR(12)


AS
BEGIN	
SET NOCOUNT ON

SELECT DISTINCT c.[MVIPersonSID]
	  ,c.[StaPa_PCP]
      ,c.[StaPa_MHTC]
      ,c.[StaPa_Homestation]
	  ,n.[NoteNumber]
	  ,n.[HealthFactorDateTime]	  
	  ,n.StaPa
  FROM [VBA].[MSTClaimsCohort] AS c WITH(NOLOCK) 
  LEFT JOIN [VBA].[MSTClaimsNotes] AS n WITH(NOLOCK)
	ON n.MVIPersonSID = c.MVIPersonSID
  INNER JOIN [LookUp].[ChecklistID] as l WITH (NOLOCK)
	ON l.StaPa = c.StaPa_PCP
		OR l.StaPa = c.StaPa_MHTC
		OR l.StaPa = c.StaPa_Homestation
  INNER JOIN (SELECT Sta3n FROM [App].[Access] (@User)) as Access ON l.Sta3n = Access.Sta3n
  WHERE n.MVIPersonSID=@MVIPersonSID
		AND n.StaPa=@Facility
;

END