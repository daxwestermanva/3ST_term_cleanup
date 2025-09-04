
/*
20200131	RAS	Changed from view to table because with REACH v02, joining to get the PatientICN is slower, which would slow down the report.
20201209	RAS	Added group by patient and taking MAX of percentage -- in case there are duplicate MVIPersonSIDs, which
				happens when the patient mapping is updated and 2 PatientSIDs in the reach data now have the same MVIPersonSID
				whereas they were different at the initial risk score run.
2025-05-06	LM	Updated references to point to REACH 2.0 objects
*/

/*
requested:Homeless Office
Server:vhacdwsql12
DB:VSSC_Homeless
POC:Todd Manning
Approved:Jodie Trafton
Date:05/11/18
*/

CREATE PROCEDURE [Code].[REACH_NationalTiers]
--VIEW [REACH].[NationalTiers]							  
AS 

BEGIN							   

DROP TABLE IF EXISTS #StageNationalTiers
SELECT mp.MVIPersonSID
	  ,mp.PatientICN 
	  ,CASE WHEN MAX(a.PercRanking)*100 <0.1 THEN 'Top 0.1% risk tier, 45x the baseline Veteran risk'
			WHEN MAX(a.PercRanking)*100 <1   THEN 'Top 1% risk tier, 10x the baseline Veteran risk'
			WHEN MAX(a.PercRanking)*100 <5   THEN 'Top 5% risk tier, 5x the baseline Veteran risk'
			WHEN MAX(a.PercRanking)*100 <20  THEN 'Top 20% risk tier, 3x the baseline Veteran risk'
		ELSE 'All VHA Veterans are at greater risk of death by suicide than the general population.'
		END RiskTierDescription
	  ,CASE WHEN MAX(a.PercRanking)*100 <0.1 THEN 'Highest'
			WHEN MAX(a.PercRanking)*100 <1   THEN 'Very High'
			WHEN MAX(a.PercRanking)*100 <5   THEN 'High'
			WHEN MAX(a.PercRanking)*100 <20  THEN 'Elevated'
		ELSE 'Baseline'
		END RiskTier
	  ,CASE WHEN MAX(b.MVIPersonSID) IS NOT NULL THEN 1 ELSE 0 end as ReachVET_Ever
INTO #StageNationalTiers
FROM [REACH].[RiskScore] a WITH (NOLOCK) --this table has 1 PatientSID and the RunDatePatientICN, but the current PatientICN could be different
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] s WITH(NOLOCK) ON a.PatientPersonSID=s.PatientPersonSID --join to get the current MVIPersonSID and PatientICN
INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK) ON s.MVIPersonSID=mp.MVIPersonSID
LEFT JOIN [REACH].[History] b WITH (NOLOCK) on b.MVIPersonSID=s.MVIPersonSID  --then use MVIPersonSID to check against displayed patients
WHERE mp.MVIPersonSID IS NOT NULL
GROUP BY mp.MVIPersonSID,mp.PatientICN

EXEC [Maintenance].[PublishTable] 'REACH.NationalTiers','#StageNationalTiers'

END

--DROP VIEW [REACH].[NationalTiers]
--CREATE TABLE [REACH].[NationalTiers] (
--PatientICN VARCHAR(50) NOT NULL
--,RiskTierDescription VARCHAR (85) NOT NULL
--,RiskTier VARCHAR(9) NOT NULL
--,ReachVET_Ever BIT NOT NULL
--)

--CREATE CLUSTERED COLUMNSTORE INDEX CCIX_Reach_NatlTiers ON  [REACH].[NationalTiers] 