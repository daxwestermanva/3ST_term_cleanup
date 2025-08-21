



/*Replacing table with view*/
CREATE VIEW [PRF_HRS].[ActivePRF]
AS
SELECT a.MVIPersonSID
	  ,a.PatientICN
	  ,a.OwnerChecklistID
	  ,a.OwnerFacility
	  ,a.InitialActivation
	  ,a.MostRecentActivation
	  ,a.ActionDateTime
	  ,a.ActionType
	  ,a.ActionTypeDescription
FROM [OMHSP_Standard].[PRF_HRS_CompleteHistory] as a
WHERE ActiveFlag='Y' --only active flags
	AND EntryCountDesc=1 --only most recent action 