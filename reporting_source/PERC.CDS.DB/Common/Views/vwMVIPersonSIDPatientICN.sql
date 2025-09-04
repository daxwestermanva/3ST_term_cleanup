



CREATE VIEW [Common].[vwMVIPersonSIDPatientICN]
WITH SCHEMABINDING
AS
	SELECT
		MVIPersonSID, PatientICN, COUNT_BIG(*) AS COUNT
	FROM [Common].[MVIPersonSIDPatientPersonSID] 
	WHERE MVIPersonSID > 0
	GROUP BY MVIPersonSID, PatientICN
GO
CREATE NONCLUSTERED INDEX [PK_vwMVIPersonSIDPatientICN_PatientICN]
    ON [Common].[vwMVIPersonSIDPatientICN]([PatientICN] ASC);


GO
CREATE UNIQUE CLUSTERED INDEX [PK_vwMVIPersonSIDPatientICN_MVIPersonSID]
    ON [Common].[vwMVIPersonSIDPatientICN]([MVIPersonSID] ASC);

