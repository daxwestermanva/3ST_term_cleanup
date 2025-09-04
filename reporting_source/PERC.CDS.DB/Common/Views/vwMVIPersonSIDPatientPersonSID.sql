
CREATE VIEW [Common].[vwMVIPersonSIDPatientPersonSID]
WITH SCHEMABINDING
AS
	SELECT
		MVIPersonSID, PatientPersonSID	
	FROM [Common].[MVIPersonSIDPatientPersonSID] WITH (NOLOCK)