-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	
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
--				Row duplication is expected in this dataset.
--
-- Modifications:
--
--
-- =======================================================================================================
CREATE PROCEDURE [App].[SUD_CaseFinderPosDrugScreen_PBI]
AS
BEGIN

	DROP TABLE IF EXISTS #Cohort
	SELECT DISTINCT MVIPersonSID
	INTO #Cohort
	FROM SUD.CaseFinderCohort WITH (NOLOCK);

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
	FROM #Cohort c
	INNER JOIN Present.UDSLabResults as u WITH (NOLOCK)
		ON u.MVIPersonSID=c.MVIPersonSID
	WHERE LabScore=1 AND (LabDate >= DATEADD(YEAR, -1, CAST(GETDATE() AS DATE)))

	UNION

	--test patient data
	SELECT MVIPersonSID
		,LabGroup=
			CASE WHEN MVIPersonSID=15258421	THEN 'Buprenorphine'
				 WHEN MVIPersonSID=9382966	THEN 'Amphetamine'
				 WHEN MVIPersonSID=36728031	THEN 'Methadone'
				 WHEN MVIPersonSID=13066049	THEN 'Dihydrocodeine'
				 WHEN MVIPersonSID=14920678	THEN 'Oxycodone'
				 WHEN MVIPersonSID=9160057	THEN 'Tramadol'
				 WHEN MVIPersonSID=9097259	THEN 'Codeine'
				 WHEN MVIPersonSID=40746866	THEN 'Phencyclidine (PCP)'
				 WHEN MVIPersonSID=43587294	THEN 'Cannabinoid'
				 WHEN MVIPersonSID=42958478	THEN 'Barbiturate' 
				 WHEN MVIPersonSID=46455441	THEN 'Hydromorphone'
				 WHEN MVIPersonSID=36668998	THEN 'Ketamine'
				 WHEN MVIPersonSID=49627276	THEN 'Fentanyl'
				 WHEN MVIPersonSID=13426804	THEN 'Benzodiazepine'
				 WHEN MVIPersonSID=16063576	THEN 'Heroin'
				 WHEN MVIPersonSID=9415243	THEN 'Morphine'
				 WHEN MVIPersonSID=9144260	THEN 'Oxymorphone'
				 WHEN MVIPersonSID=46028037	THEN 'Hydrocodone'
				 WHEN MVIPersonSID=49605020	THEN 'Meprobamate' 				 
				 WHEN MVIPersonSID=9279280	THEN 'Cocaine'
				 WHEN MVIPersonSID=46113976	THEN 'Ethanol' END
	FROM Common.MasterPatient WITH (NOLOCK)
	WHERE MVIPersonSID IN (15258421, 9382966, 36728031, 13066049, 14920678, 9160057, 9097259, 40746866, 43587294, 42958478, 46455441, 36668998, 49627276, 13426804, 16063576, 9415243, 9144260, 46028037, 49605020, 9279280, 46113976); --TestPatient=1

END