-- =============================================
-- Author:		<Liam Mina>
-- Create date: <1/3/2024>
-- Description:	

--Updates

-- =============================================
CREATE PROCEDURE [App].[COMPACT_PatientInfo_PBI]

AS
BEGIN
	SET NOCOUNT ON;

SELECT DISTINCT mp.MVIPersonSID
		,mp.PatientName
		,mp.LastFour
		,mp.EDIPI
		,mp.Age
		,CASE WHEN mp.Age <25 THEN '<25'
			WHEN mp.Age between 25 and 34 THEN '25-34'
			WHEN mp.Age between 35 and 44 THEN '35-44'
			WHEN mp.Age between 45 and 54 THEN '45-54'
			WHEN mp.Age between 55 and 64 THEN '55-64'
			WHEN mp.Age between 65 and 74 THEN '65-74'
			WHEN mp.Age between 75 and 84 THEN '75-84'
			WHEN mp.Age>=85 THEN '85+'
			End AgeCategory
		,CASE WHEN DisplayGender='Man' THEN 'Male'
			  WHEN DisplayGender='Woman' THEN 'Female'
			  WHEN DisplayGender='Transgender Man' THEN 'Transgender Male'
			  WHEN DisplayGender='Transgender Woman' THEN 'Transgender Female'
			  ELSE DisplayGender
		 END AS DisplayGender
		,CAST(mp.DateOfBirth AS date) AS DateOfBirth
		,CASE WHEN mp.Race IS NULL or mp.race like '%null%' THEN 'Unknown'
			ELSE mp.Race END AS Race
		,CASE WHEN mp.Race like '%,%' THEN 'Multiple' 
			WHEN mp.Race IS NULL or mp.Race like '%null%' THEN 'Unknown'
			ELSE Race
			End RaceCategory
		,CASE WHEN mp.PriorityGroup=8 AND mp.PrioritySubGroup IN ('e','g') THEN CAST(CONCAT(mp.PriorityGroup,mp.PrioritySubGroup) AS varchar)
			WHEN mp.PriorityGroup=8 THEN '8a-d'
			WHEN mp.PriorityGroup=-1 THEN 'None'
			ELSE CAST(mp.PriorityGroup AS varchar)
			END AS PriorityGroup
		,CASE WHEN mp.PriorityGroup=8 THEN CAST(CONCAT(mp.PriorityGroup,mp.PrioritySubGroup) AS varchar)
			WHEN mp.PriorityGroup=-1 THEN 'None'
			ELSE CAST(mp.PriorityGroup AS varchar)
			END AS PriorityGroup_All
		--,CopayReq = 
		--	CASE WHEN PriorityGroup=1 THEN 'No' --No rx, outpat, inpat copays
		--	WHEN PriorityGroup=8 AND PrioritySubGroup IN ('e','g') THEN 'COMPACT Eligible Only - Income'
		--	WHEN PriorityGroup BETWEEN 2 AND 8 AND PercentServiceConnect >= 10 THEN 'Rx copays' --No outpat, inpat copays
		--	WHEN PriorityGroup BETWEEN 2 AND 8 THEN 'Rx and Tx copays'
		--	WHEN COMPACTEligible=1 THEN 'COMPACT Eligible Only'
		--	ELSE 'Not Eligible'
		--	END
		,CASE WHEN mp.PercentServiceConnect IS NULL THEN 'Unk/NA'
			ELSE mp.PercentServiceConnect END AS PercentServiceConnect
		,CASE WHEN mp.PercentServiceConnect IS NULL THEN -2
			WHEN mp.PercentServiceConnect='NSC' THEN -1
			ELSE TRY_CAST(REPLACE(PercentServiceConnect,'%','') as int) END AS PercentServiceConnectOrder
		,mp.PeriodOfService
		,CASE WHEN mp.BranchOfService IN ('COAST GUARD','ARMY','NAVY','AIR FORCE','SPACE FORCE','MARINE CORPS') THEN mp.BranchOfService
			ELSE 'OTHER OR NONE' END AS BranchOfService
		--,CASE WHEN mp.OEFOIFStatus IS NULL THEN 'N/A' ELSE mp.OEFOIFStatus END AS OEFOIFStatus
		,mp.ServiceSeparationDate
		,CASE WHEN mp.Homeless = 1 THEN 'Yes' ELSE 'No' END AS Homeless
		,CASE WHEN mp.TestPatient=1 THEN 'Demo Mode' ELSE 'All Data' END AS TestPatient
		,CASE WHEN (PriorityGroup = -1 OR PrioritySubGroup IN ('e','g')) AND COMPACTEligible=1 THEN 'COMPACT Eligible Only' 
			  WHEN (PriorityGroup > -1 AND PrioritySubGroup NOT IN ('e','g')) AND COMPACTEligible=1 THEN 'COMPACT and VHA Eligible'
			  ELSE 'Not Verified as COMPACT Eligible'
		 END AS COMPACTEligible
		,EpisodeCount = CASE WHEN e.MVIPersonSID IS NULL THEN 0
			ELSE MAX(e.EpisodeRankDesc) OVER (PARTITION BY a.MVIPersonSID) END
		,CASE WHEN mp.DateOfDeath_SVeteran IS NOT NULL THEN 'Deceased' ELSE 'Living' END AS Deceased
		,CASE WHEN p.CurrentActiveFlag=1 THEN 'Active'
			WHEN p.MVIPersonSID IS NOT NULL THEN 'Inactive'
			ELSE 'N/A' END AS PRF_HRS
		,CASE WHEN ISNULL(MAX(s.EventOrderDesc) OVER (PARTITION BY a.MVIPersonSID),0) = 0 THEN '0'
			WHEN MAX(s.EventOrderDesc) OVER (PARTITION BY a.MVIPersonSID) = 1 THEN '1'
			WHEN MAX(s.EventOrderDesc) OVER (PARTITION BY a.MVIPersonSID) = 2 THEN '2'
			WHEN MAX(s.EventOrderDesc) OVER (PARTITION BY a.MVIPersonSID) >2 THEN '3+'
			END AS SBORCount
		,ISNULL(MAX(s.EventOrderDesc) OVER (PARTITION BY a.MVIPersonSID),0) AS SBORCount_All
		,ISNULL(c.AcuteRisk,'None') AS AcuteRisk
		,ISNULL(c.ChronicRisk,'None') AS ChronicRisk
		,NextMHAppt = CASE WHEN ap.MVIPersonSID IS NOT NULL THEN CONCAT(CAST(ap.AppointmentDateTime AS date), ' (', ap.Sta6a, ')')
			ELSE NULL END
		,CountEpisode=CASE WHEN e.MVIPersonSID IS NULL THEN 0 ELSE 1 END
    FROM (SELECT MVIPersonSID FROM [COMPACT].[Episodes] WITH (NOLOCK)
			UNION 
		  SELECT MVIPersonSID FROM [COMPACT].[Template] WITH (NOLOCK)
		  )
		  AS a
	INNER JOIN [Common].[MasterPatient] AS mp WITH(NOLOCK) 
		ON a.MVIPersonSID = mp.MVIPersonSID
	LEFT JOIN [COMPACT].[Episodes] e WITH (NOLOCK)
		ON a.MVIPersonSID=e.MVIPersonSID
	LEFT JOIN [PRF_HRS].[EpisodeDates] AS p WITH (NOLOCK) 
		ON a.MVIPersonSID = p.MVIPersonSID AND p.FlagEpisode = p.TotalEpisodes
	LEFT JOIN [OMHSP_Standard].[SuicideOverdoseEvent] AS s WITH (NOLOCK)
		ON a.MVIPersonSID = s.MVIPersonSID AND s.EventType='Suicide Event'
	LEFT JOIN [OMHSP_Standard].[CSRE] AS c WITH (NOLOCK)
		ON a.MVIPersonSID=c.MVIPersonSID AND c.OrderDesc=1 AND CAST(c.EntryDateTime AS date) > CAST(DateAdd(day,-366,getdate()) AS date)
	LEFT JOIN [Present].[AppointmentsFuture] ap WITH (NOLOCK)
		ON a.MVIPersonSID=ap.MVIPersonSID AND ap.ApptCategory='MHFuture' AND NextAppt_ICN=1
	

END