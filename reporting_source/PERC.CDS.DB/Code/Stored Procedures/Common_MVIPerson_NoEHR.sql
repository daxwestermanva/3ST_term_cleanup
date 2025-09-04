
-- =======================================================================================================
-- Author:		Liam Mina
-- Create date:	7/15/2025
-- Description:	
--
-- Modifications:

-- =======================================================================================================
CREATE PROCEDURE [Code].[Common_MVIPerson_NoEHR]
AS
BEGIN

DROP TABLE IF EXISTS #MissingRecords
SELECT TOP 1 WITH TIES
		mvi.MVIPersonSID
		,mvi.MVIPersonICN AS PatientICN
		,mvi.PersonSSN AS PatientSSN
		,e.EDIPI
		,PatientName=CONCAT(mvi.LastName,', ',mvi.FirstName,' ',mvi.MiddleName)	
		,NameFour=CONCAT(LEFT(mvi.LastName,1),RIGHT(mvi.PersonSSN,4))
		,PatientSSN_Hyphen=SUBSTRING(mvi.PersonSSN,0,4) +'-' + SUBSTRING(mvi.PersonSSN,4,2)+'-'+SUBSTRING(mvi.PersonSSN,6,4)	
		,mvi.BirthDateTime AS DateOfBirth
		,mvi.PhoneNumber
		,mvi.CellularPhoneNumber AS CellPhoneNumber
		,CASE WHEN mvi.StreetAddress3 IS NOT NULL THEN CONCAT(mvi.StreetAddress1,', ',mvi.StreetAddress2,', ',mvi.StreetAddress3)
			WHEN mvi.StreetAddress2 IS NOT NULL THEN CONCAT(mvi.StreetAddress1,', ',mvi.StreetAddress2)
			ELSE mvi.StreetAddress1 END AS StreetAddress
		,mvi.City
		,s.StateAbbrev AS State
		,LEFT(mvi.Zip4,5) AS Zip
INTO #MissingRecords
FROM [SVeteran].[SMVIPerson] mvi WITH (NOLOCK)
INNER JOIN [SVeteran].[SMVIPersonSiteAssociation] e  WITH (NOLOCK)
	ON mvi.MVIPersonSID=e.MVIPersonSID
LEFT JOIN Common.MVIPersoNSIDPatientPersoNSID a WITH (NOLOCK)
	ON mvi.MVIPersonICN=a.PatientICN
LEFT JOIN Common.MVIPersonSIDPatientPersonSID b WITH (NOLOCK)
	ON LEFT(mvi.PrimaryPersonFullICN,10)=b.PatientICN
LEFT JOIN Common.MasterPatient m WITH (NOLOCK)
	ON a.MVIPersonSID=m.MVIPersonSID
LEFT JOIN NDim.MVIState s WITH (NOLOCK) 
	ON mvi.MVIStateSID=s.MVIStateSID AND mvi.MVIStateSID>0
WHERE mvi.ICNStatusCode <> 'D'
	AND (e.EDIPI IS NOT NULL OR mvi.PersonSSN IS NOT NULL)
	AND (a.MVIPersonSID IS NULL AND b.MVIPersonSID IS NULL AND m.MVIPersonSID IS NULL)
	AND mvi.TestRecordIndicator IS NULL
	AND e.ActiveMergedIdentifierCode = 'A'
	AND mvi.DeathDateTime IS NULL AND mvi.BirthDateTime >DATEADD(year,-100,getdate())
ORDER BY ROW_NUMBER() OVER (PARTITION BY mvi.MVIPersonSID ORDER BY CASE WHEN mvi.PersonSSN IS NOT NULL THEN 1 ELSE 2 END
																  ,CASE WHEN e.EDIPI IS NOT NULL THEN 1 ELSE 2 END
																  ,CASE WHEN mvi.PhoneNumber IS NOT NULL THEN 1 ELSE 2 END
																  ,mvi.BirthDateTime DESC
																  )

DELETE FROM #MissingRecords
WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM Common.MasterPatient WITH (NOLOCK))

EXEC [Maintenance].[PublishTable] 'Common.MVIPerson_NoEHR', '#MissingRecords';



END