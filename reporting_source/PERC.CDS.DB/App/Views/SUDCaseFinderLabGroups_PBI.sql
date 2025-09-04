
-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	6/9/2025
-- Description:	Will be used in Power BI visuals (mainly decomposition tree) and pertains
--				to lab groups re: positive drug screen results:
--					- Amphetamine
--					- Barbiturate
--					- Benzodiazepine
--					- Buprenorphine
--					- Cannabinoid
--					- Cocaine
--					- Codeine
--					- Dihydrocodeine
--					- Drug Screen
--					- Ethanol
--					- Fentanyl
--					- Heroin
--					- Hydrocodone
--					- Hydromorphone
--					- Ketamine
--					- Meprobamate
--					- Methadone
--					- Morphine
--					- Other Opiate
--					- Oxycodone
--					- Oxymorphone
--					- Phencyclidine (PCP)
--					- Tramadol
--
--				Code adapted from [App].[SUD_CaseFinderPosDrugScreen_PBI].
--				
--				Row duplication is expected in this dataset.
--
-- Modifications:
--
--
-- =======================================================================================================
CREATE VIEW [App].[SUDCaseFinderLabGroups_PBI] AS 

	SELECT DISTINCT c.MVIPersonSID
		,LabGroup=
			CASE WHEN u.LabGroup='Amphetamine' THEN 'Amphetamine'
				 WHEN u.LabGroup='Barbiturate' THEN 'Barbiturate'
				 WHEN u.LabGroup='Benzodiazepine' THEN 'Benzodiazepine'
				 WHEN u.LabGroup='Buprenorphine' THEN 'Buprenorphine'
				 WHEN u.LabGroup='Cannabinoid' THEN 'Cannabinoid'
				 WHEN u.LabGroup='Cocaine' THEN 'Cocaine'
				 WHEN u.LabGroup='Codeine' THEN 'Codeine'
				 WHEN u.LabGroup='Dihydrocodeine' THEN 'Dihydrocodeine'
				 WHEN u.LabGroup='Drug Screen' THEN 'Drug Screen'
				 WHEN u.LabGroup='Ethanol' THEN 'Ethanol'
				 WHEN u.LabGroup='Fentanyl' THEN 'Fentanyl'
				 WHEN u.LabGroup='Heroin' THEN 'Heroin'
				 WHEN u.LabGroup='Hydrocodone' THEN 'Hydrocodone'
				 WHEN u.LabGroup='Hydromorphone' THEN 'Hydromorphone'
				 WHEN u.LabGroup='Ketamine' THEN 'Ketamine'
				 WHEN u.LabGroup='Meprobamate' THEN 'Meprobamate'
				 WHEN u.LabGroup='Methadone' THEN 'Methadone'
				 WHEN u.LabGroup='Morphine' THEN 'Morphine'
				 WHEN u.LabGroup='Other Opiate' THEN 'Other Opiate'
				 WHEN u.LabGroup='Oxycodone' THEN 'Oxycodone'
				 WHEN u.LabGroup='Oxymorphone' THEN 'Oxymorphone'
				 WHEN u.LabGroup='Phencyclidine (PCP)' THEN 'Phencyclidine (PCP)'
				 WHEN u.LabGroup='Tramadol' THEN 'Tramadol' END
	FROM SUD.CaseFinderCohort c WITH (NOLOCK) 
	INNER JOIN Present.UDSLabResults as u WITH (NOLOCK)
		ON u.MVIPersonSID=c.MVIPersonSID
	WHERE LabScore=1 AND (LabDate >= DATEADD(YEAR, -1, CAST(GETDATE() AS DATE)))

	UNION

	--test patient data
	SELECT MVIPersonSID
		,LabGroup
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)