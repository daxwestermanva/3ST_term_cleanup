
/********************************************************************************************************************
DESCRIPTION: View gets distinct MVIPersonSID for all patients for whom variables 
			 should be computed and added to RiskScore.PatientVariable
TEST:
	SELECT MVIPersonSID FROM [RiskScore].[PatientPopulation]
UPDATE:
	2020-02-12	RAS	Created view - set population to Present.SPatient and Reach.ActivePatient
********************************************************************************************************************/

CREATE VIEW [RiskScore].[PatientPopulation]
AS

SELECT MVIPersonSID FROM [Present].[SPatient]
--UNION 
--SELECT p.MVIPersonSID FROM [REACH].[ActivePatient] as a 
--INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] as p on a.PatientSID=p.PatientPersonSID