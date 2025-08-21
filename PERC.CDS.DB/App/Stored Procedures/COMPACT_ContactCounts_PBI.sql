-- =============================================
-- Author:		<Liam Mina>
-- Create date: <7/11/2024>
-- Description:	

--Updates

-- =============================================
CREATE PROCEDURE [App].[COMPACT_ContactCounts_PBI]

AS
BEGIN
	SET NOCOUNT ON;

DROP TABLE IF EXISTS #EpisodeID
SELECT a.MVIPersonSID
	,UniqueEpisodeID=CONCAT(a.MVIPersonSID,'-',a.EpisodeRankDesc)
INTO #EpisodeID 
FROM [COMPACT].[Episodes] a WITH (NOLOCK)
INNER JOIN [Common].[MasterPatient] m WITH (NOLOCK)
	ON a.MVIPersonSID=m.MVIPersonSID

DROP TABLE IF EXISTS #Counts
SELECT DISTINCT
	e.UniqueEpisodeID
	,a.ContactSID
	,CASE WHEN a.ContactType = 'Outpatient Encounter' THEN 1 ELSE 0 END AS DirectOutpat
	,CASE WHEN a.ContactType = 'Inpatient Stay' THEN 1 ELSE 0 END AS DirectInpat
	,CASE WHEN a.ContactType IN ('CC Emergency Encounter','CC Outpatient Encounter') THEN 1 ELSE 0 END AS CCOutpat
	,CASE WHEN a.ContactType = 'CC Inpatient Encounter' THEN 1 ELSE 0 END AS CCInpat
	,CASE WHEN a.ContactType = 'Medication Fill' THEN 1 ELSE 0 END AS MedFill
	,a.Template
	,CASE WHEN a.EncounterCodes IS NOT NULL THEN 1 ELSE 0 END AS EncounterCodes
INTO #Counts
FROM #EpisodeID AS e WITH(NOLOCK)
LEFT JOIN [COMPACT].[ContactHistory] AS a WITH (NOLOCK)
	ON CONCAT(a.MVIPersonSID,'-',a.EpisodeRankDesc) = e.UniqueEpisodeID
LEFT JOIN [Lookup].[Sta6a] AS c WITH (NOLOCK)
	ON a.Sta6a = c.Sta6a
LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK) 
	ON c.ChecklistID = ch.ChecklistID

DROP TABLE IF EXISTS #Categories
SELECT c.UniqueEpisodeID
	,Category='All'
	,ISNULL(SUM(c.DirectOutpat),0) AS DirectOutpatCount
	,CASE WHEN SUM(c.DirectOutpat) = 0 THEN '0'
		WHEN SUM(c.DirectOutpat) BETWEEN 1 AND 2 THEN '1-2'
		WHEN SUM(c.DirectOutpat) BETWEEN 3 AND 5 THEN '3-5'
		WHEN SUM(c.DirectOutpat) BETWEEN 6 AND 10 THEN '6-10'
		WHEN SUM(c.DirectOutpat) BETWEEN 11 AND 20 THEN '11-20'
		WHEN SUM(c.DirectOutpat) > 20 THEN '21+'
		ELSE '0'
		END AS DirectOutpatCat
	,CASE WHEN SUM(c.DirectOutpat) = 0 THEN 0
		WHEN SUM(c.DirectOutpat) BETWEEN 1 AND 2 THEN 1
		WHEN SUM(c.DirectOutpat) BETWEEN 3 AND 5 THEN 2
		WHEN SUM(c.DirectOutpat) BETWEEN 6 AND 10 THEN 3
		WHEN SUM(c.DirectOutpat) BETWEEN 11 AND 20 THEN 4
		WHEN SUM(c.DirectOutpat) > 20 THEN 5
		ELSE 0
		END AS DirectOutpatSort
	,ISNULL(SUM(c.DirectInpat),0) AS DirectInpatCount
	,CASE WHEN SUM(c.DirectInpat) = 0 THEN '0'
		WHEN SUM(c.DirectInpat) = 1 THEN '1'
		WHEN SUM(c.DirectInpat) = 2 THEN '2'
		WHEN SUM(c.DirectInpat) = 3 THEN '3'
		WHEN SUM(c.DirectInpat) = 4 THEN '4'
		WHEN SUM(c.DirectInpat) > 4 THEN '5+'
		ELSE '0'
		END AS DirectInpatCat
	,CASE WHEN SUM(c.DirectInpat) = 0 THEN 0
		WHEN SUM(c.DirectInpat) = 1 THEN 1
		WHEN SUM(c.DirectInpat) = 2 THEN 2
		WHEN SUM(c.DirectInpat) = 3 THEN 3
		WHEN SUM(c.DirectInpat) = 4 THEN 4
		WHEN SUM(c.DirectInpat) > 4 THEN 5
		ELSE 0
		END AS DirectInpatSort
	,ISNULL(SUM(c.CCOutpat),0) AS CCOutpatCount
	,CASE WHEN SUM(c.CCOutpat) = 0 THEN '0'
		WHEN SUM(c.CCOutpat) = 1 THEN '1'
		WHEN SUM(c.CCOutpat) = 2 THEN '2'
		WHEN SUM(c.CCOutpat) = 3 THEN '3'
		WHEN SUM(c.CCOutpat) = 4 THEN '4'
		WHEN SUM(c.CCOutpat) > 4 THEN '5+'
		ELSE '0'
		END AS CCOutpatCat
	,CASE WHEN SUM(c.CCOutpat) = 0 THEN 0
		WHEN SUM(c.CCOutpat) = 1 THEN 1
		WHEN SUM(c.CCOutpat) = 2 THEN 2
		WHEN SUM(c.CCOutpat) = 3 THEN 3
		WHEN SUM(c.CCOutpat) = 4 THEN 4
		WHEN SUM(c.CCOutpat) > 4 THEN 5
		ELSE 0
		END AS CCOutpatSort
	,ISNULL(SUM(c.CCInpat),0) AS CCInpatCount
	,CASE WHEN SUM(c.CCInpat) = 0 THEN '0'
		WHEN SUM(c.CCInpat) = 1 THEN '1'
		WHEN SUM(c.CCInpat) = 2 THEN '2'
		WHEN SUM(c.CCInpat) = 3 THEN '3'
		WHEN SUM(c.CCInpat) = 4 THEN '4'
		WHEN SUM(c.CCInpat) > 4 THEN '5+'
		ELSE '0'
		END AS CCInpatCat
	,CASE WHEN SUM(c.CCInpat) = 0 THEN 0
		WHEN SUM(c.CCInpat) = 1 THEN 1
		WHEN SUM(c.CCInpat) = 2 THEN 2
		WHEN SUM(c.CCInpat) = 3 THEN 3
		WHEN SUM(c.CCInpat) = 4 THEN 4
		WHEN SUM(c.CCInpat) > 4 THEN 5
		ELSE 0
		END AS CCInpatSort
	,ISNULL(SUM(c.MedFill),0) AS MedFillCount
	,CASE WHEN SUM(c.MedFill) = 0 THEN '0'
		WHEN SUM(c.MedFill) BETWEEN 1 AND 5 THEN '1-5'
		WHEN SUM(c.MedFill) BETWEEN 6 AND 10 THEN '6-10'
		WHEN SUM(c.MedFill) BETWEEN 11 AND 20 THEN '11-20'
		WHEN SUM(c.MedFill) > 20 THEN '21+'
		ELSE '0'
		END AS MedFillCat
	,CASE WHEN SUM(c.MedFill) = 0 THEN 0
		WHEN SUM(c.MedFill) BETWEEN 1 AND 5 THEN 1
		WHEN SUM(c.MedFill) BETWEEN 6 AND 10 THEN 2
		WHEN SUM(c.MedFill) BETWEEN 11 AND 20 THEN 3
		WHEN SUM(c.MedFill) > 20 THEN 4
		ELSE 0
		END AS MedFillSort
INTO #Categories
FROM #Counts AS c
GROUP BY c.UniqueEpisodeID
UNION ALL
SELECT e.UniqueEpisodeID
	,Category='Template'
	,ISNULL(SUM(c.DirectOutpat),0) AS DirectOutpatCount
	,CASE WHEN SUM(c.DirectOutpat) = 0 THEN '0'
		WHEN SUM(c.DirectOutpat) BETWEEN 1 AND 2 THEN '1-2'
		WHEN SUM(c.DirectOutpat) BETWEEN 3 AND 5 THEN '3-5'
		WHEN SUM(c.DirectOutpat) BETWEEN 6 AND 10 THEN '6-10'
		WHEN SUM(c.DirectOutpat) BETWEEN 11 AND 20 THEN '11-20'
		WHEN SUM(c.DirectOutpat) > 20 THEN '21+'
		ELSE '0'
		END AS DirectOutpatCat
	,CASE WHEN SUM(c.DirectOutpat) = 0 THEN 0
		WHEN SUM(c.DirectOutpat) BETWEEN 1 AND 2 THEN 1
		WHEN SUM(c.DirectOutpat) BETWEEN 3 AND 5 THEN 2
		WHEN SUM(c.DirectOutpat) BETWEEN 6 AND 10 THEN 3
		WHEN SUM(c.DirectOutpat) BETWEEN 11 AND 20 THEN 4
		WHEN SUM(c.DirectOutpat) > 20 THEN 5
		ELSE 0
		END AS DirectOutpatSort
	,ISNULL(SUM(c.DirectInpat),0) AS DirectInpatCount
	,CASE WHEN SUM(c.DirectInpat) = 0 THEN '0'
		WHEN SUM(c.DirectInpat) = 1 THEN '1'
		WHEN SUM(c.DirectInpat) = 2 THEN '2'
		WHEN SUM(c.DirectInpat) = 3 THEN '3'
		WHEN SUM(c.DirectInpat) = 4 THEN '4'
		WHEN SUM(c.DirectInpat) > 4 THEN '5+'
		ELSE '0'
		END AS DirectInpatCat
	,CASE WHEN SUM(c.DirectInpat) = 0 THEN 0
		WHEN SUM(c.DirectInpat) = 1 THEN 1
		WHEN SUM(c.DirectInpat) = 2 THEN 2
		WHEN SUM(c.DirectInpat) = 3 THEN 3
		WHEN SUM(c.DirectInpat) = 4 THEN 4
		WHEN SUM(c.DirectInpat) > 4 THEN 5
		ELSE 0
		END AS DirectInpatSort
	,CCOutpatCount=NULL
	,CCOutpatCat=NULL
	,CCOutpatSort=NULL
	,CCInpatCount=NULL
	,CCInpatCat=NULL
	,CCInpatSort=NULL
	,MedFillCount=NULL
	,MedFillCat=NULL
	,MedFillSort=NULL
FROM #EpisodeID AS e
LEFT JOIN #Counts c
	ON c.UniqueEpisodeID = e.UniqueEpisodeID
	AND c.Template=1 
GROUP BY e.UniqueEpisodeID
UNION ALL
SELECT e.UniqueEpisodeID
	,Category='Dx or Procedure Code, No Template'
	,ISNULL(SUM(c.DirectOutpat),0) AS DirectOutpatCount
	,CASE WHEN SUM(c.DirectOutpat) = 0 THEN '0'
		WHEN SUM(c.DirectOutpat) BETWEEN 1 AND 2 THEN '1-2'
		WHEN SUM(c.DirectOutpat) BETWEEN 3 AND 5 THEN '3-5'
		WHEN SUM(c.DirectOutpat) BETWEEN 6 AND 10 THEN '6-10'
		WHEN SUM(c.DirectOutpat) BETWEEN 11 AND 20 THEN '11-20'
		WHEN SUM(c.DirectOutpat) > 20 THEN '21+'
		ELSE '0'
		END AS DirectOutpatCat
	,CASE WHEN SUM(c.DirectOutpat) = 0 THEN 0
		WHEN SUM(c.DirectOutpat) BETWEEN 1 AND 2 THEN 1
		WHEN SUM(c.DirectOutpat) BETWEEN 3 AND 5 THEN 2
		WHEN SUM(c.DirectOutpat) BETWEEN 6 AND 10 THEN 3
		WHEN SUM(c.DirectOutpat) BETWEEN 11 AND 20 THEN 4
		WHEN SUM(c.DirectOutpat) > 20 THEN 5
		ELSE 0
		END AS DirectOutpatSort
	,ISNULL(SUM(c.DirectInpat),0) AS DirectInpatCount
	,CASE WHEN SUM(c.DirectInpat) = 0 THEN '0'
		WHEN SUM(c.DirectInpat) = 1 THEN '1'
		WHEN SUM(c.DirectInpat) = 2 THEN '2'
		WHEN SUM(c.DirectInpat) = 3 THEN '3'
		WHEN SUM(c.DirectInpat) = 4 THEN '4'
		WHEN SUM(c.DirectInpat) > 4 THEN '5+'
		ELSE '0'
		END AS DirectInpatCat
	,CASE WHEN SUM(c.DirectInpat) = 0 THEN 0
		WHEN SUM(c.DirectInpat) = 1 THEN 1
		WHEN SUM(c.DirectInpat) = 2 THEN 2
		WHEN SUM(c.DirectInpat) = 3 THEN 3
		WHEN SUM(c.DirectInpat) = 4 THEN 4
		WHEN SUM(c.DirectInpat) > 4 THEN 5
		ELSE 0
		END AS DirectInpatSort
	,CCOutpatCount=NULL
	,CCOutpatCat=NULL
	,CCOutpatSort=NULL
	,CCInpatCount=NULL
	,CCInpatCat=NULL
	,CCInpatSort=NULL
	,MedFillCount=NULL
	,MedFillCat=NULL
	,MedFillSort=NULL
FROM #EpisodeID AS e
LEFT JOIN #Counts c
	ON c.UniqueEpisodeID = e.UniqueEpisodeID
	AND c.EncounterCodes=1 AND c.Template=0 
GROUP BY e.UniqueEpisodeID


SELECT a.UniqueEpisodeID
	,a.Category
	,a.DirectOutpatCount
	,a.DirectOutpatCat
	,a.DirectOutpatSort
	,a.DirectInpatCount
	,a.DirectInpatCat
	,a.DirectInpatSort
	,ISNULL(a.CCOutpatCount,b.CCOutpatCount) AS CCOutpatCount
	,ISNULL(a.CCOutpatCat,b.CCOutpatCat) AS CCOutpatCat
	,ISNULL(a.CCOutpatSort,b.CCOutpatSort) AS CCOutpatSort
	,ISNULL(a.CCInpatCount,b.CCInpatCount) AS CCInpatCount
	,ISNULL(a.CCInpatCat,b.CCInpatCat) AS CCInpatCat
	,ISNULL(a.CCInpatSort,b.CCInpatSort) AS CCInpatSort
	,ISNULL(a.MedFillCount,b.MedFillCount) AS MedFillCount
	,ISNULL(a.MedFillCat,b.MedFillCat) MedFillCat
	,ISNULL(a.MedFillSort,b.MedFillSort) AS MedFillSort
	,CASE WHEN (a.DirectOutpatCount + a.DirectInpatCount)>0 AND (a.CCOutpatCount + a.CCInpatCount)>0 THEN 'Both'
		WHEN (a.DirectOutpatCount + a.DirectInpatCount)>0 THEN 'Direct Care Only'
		WHEN (a.CCOutpatCount + a.CCInpatCount)>0 THEN 'Community Care Only'
		ELSE 'None'
		END AS CareSetting
FROM #Categories a
LEFT JOIN (SELECT * FROM #Categories WHERE Category='All') b
	ON a.UniqueEpisodeID = b.UniqueEpisodeID

END