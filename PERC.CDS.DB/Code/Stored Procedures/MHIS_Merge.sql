
-- =============================================
-- Author:		<Sara Tavakoli>
-- Create date: 12/24/2014
-- Description: Code for merging MHIS data
--Modifications: 
	-- 2.5.15	  ST	created case statements for pulling in checklistid for 596A4 and 612A4 (should be 596 abd 612 respectively)
	-- 6.10.15			updated code to pull ALC_top from MHIS rather than ALC.
	-- 7.23.15			Switched to depot new
	-- 8/12/15			pulling in each PEC dataset separately in first query, bringing in new ap_schiz
	-- 9/4/15	  ST	excluded 5120 and 5121 from second to last query and updated table name [App].[OMHO_PEC_mh_Sta6aid_DimFacility6A_]  to include underscore
	-- 11/20	  ST	removed case statments to adjust measureid 5134/5135; corrected data for smitrec; may need to add back in	
	-- 2/15/2017  GS	added App.Tool_DoBackup
	-- 3/14/2017  GS	Repointed Present objects to PERC
	-- 2018/06/07 JB	Removed hard coded database references
	-- 20190206	  RAS	Added maintenance publish table, removed DISTINCTS, added UNION ALL. Cleaned formatting and removed deprecated code that was commented
	-- 20190218   SG    Added Missing #StageMHISChecklistid in publish tables
-- =============================================
CREATE PROCEDURE [Code].[MHIS_Merge]
	-- Add the parameters for the stored procedure here

AS
BEGIN

----------------------------PUlling in MHIS data, keeping only pdsi measures (use this table for trends) ------------------------------
DROP TABLE IF EXISTS #mhis_all_pecs_data;

SELECT 'PERC' as pec
	  ,cast([program_id] as int) as program_id
	  ,cast([measureid] as int) as measureid
	  ,cast([yearid] as int) as yearid
	  ,cast([timeframeid] as int) as timeframeid
	  ,cast([reportingperiodid] as int) as reportingperiodid
	  ,cast([loaddate] as varchar(10)) as loaddate
	  ,cast([passfail] as varchar(10)) as passfail
	  ,sta6aid
	  ,checklistid
	  --The sta6aid in the this table from Shalini is really a NEPEC3n will work to change the name at the source 
	  ,cast([Nepec3n] as int) as Nepec3n
	  ,cast([visn] as int) as visn
	  ,cast([admparent_key] as int) as admparent_key
	  ,cast([cursta3n] as int) as cursta3n
	  ,cast([admparent_fcdm] as nvarchar(255)) as admparent_fcdm
	  ,cast([best_met_notmet] as varchar(10)) as best_met_notmet
	  ,cast([low_met_notmet] as varchar(10)) as low_met_notmet
	  --,score
	  ,case when [score] like '.' then 'NULL' else cast([score] as varchar(15)) end as score
	  ,cast([numerator] as varchar(15)) as numerator
	  ,cast([denominator] as varchar(15)) as denominator
INTO #mhis_all_pecs_data
FROM [PDW].[OMHO_PEC_DOEx_PERC_PDSI_Data_AllQuarters] AS a
WHERE measureid BETWEEN 5101 AND 5999 
	OR measureid = 1116

UNION ALL

SELECT 'SMITREC' as pec
	  ,cast([program_id] as int) as program_id
	  ,cast([measureid] as int) as measureid
	  ,cast([yearid] as int) as yearid
	  ,cast([timeframeid] as int) as timeframeid
	  ,cast([reportingperiodid] as int) as reportingperiodid
	  ,cast([loaddate] as varchar(10)) as loaddate
	  ,cast([passfail] as varchar(10)) as passfail
	  ,sta6aid
	  ,Checklistid
      --sta6aid and nepec3n from Shalini's table now correctly named
	  ,cast(Nepec3n as int) as Nepec3n
	  ,cast([visn] as int) as visn
	  ,cast([admparent_key] as int) as admparent_key
	  ,cast([cursta3n] as int) as cursta3n
	  ,cast([admparent_fcdm] as nvarchar(255)) as admparent_fcdm
	  ,cast([best_met_notmet] as varchar(10)) as best_met_notmet
	  ,cast([low_met_notmet] as varchar(10)) as low_met_notmet
	  --,score
	  ,case when [score] like '.' then 'NULL' else cast([score] as varchar(15)) end as score
	  ,cast([numerator] as varchar(15)) as numerator
	  ,cast([denominator] as varchar(15)) as denominator
FROM [PDW].[OMHO_PEC_DOEx_smitrec_pdsi_data_allquarters] AS a
WHERE measureid BETWEEN 5101 AND 5999 
	OR a.measureid = 1116

EXEC [Maintenance].[PublishTable] 'PDSI.mhis_all_pecs_data','#mhis_all_pecs_data'

-----------------------------Pulling in MHIS MeasureID (don't need to do each time we run the code - only if definitions change)----------------
--IF OBJECT_ID('dflt.mhis_measureid') IS NOT NULL
--	DROP TABLE dflt.mhis_measureid


--SELECT *
--INTO dflt.mhis_measureid
--FROM [App].[OMHO_PEC_mh_mhis_measureid]
--WHERE measureid BETWEEN 5101
--		AND 5999 AND (measureid not in ('5120','5121')) --old DEPOT and AP_Schiz  --8/11 ST also excluded old AP_SCHIZ
		
--***********************************************************PULLING MOST RECENT MHIS Data*****************************************

--------------------------------create temp table with all most recent MHIS PDSI measures, all facilities/visns, no national--------------------
DROP TABLE IF EXISTS #TempMHISdata
SELECT DISTINCT a.[pec]
	  ,a.[program_id]
	  ,a.[measureid]
	  ,a.[yearid]
	  ,a.[timeframeid]
	  ,a.[reportingperiodid]
	  ,a.[loaddate]
	  ,a.[passfail]
	  ,a.sta6aid
	  ,a.ChecklistID
	  ,a.[NEPEC3n]
	  ,a.[visn]
	  ,a.[admparent_key]
	  ,a.[cursta3n]
	  ,a.[admparent_fcdm]
	  ,a.[best_met_notmet]
	  ,a.[low_met_notmet]
	  --,[score]
	  ,a.[numerator]
	  ,a.[denominator]
	  ,VariableName as Measuremnemonic 
	  ,SCORE
INTO #TempMHISdata
FROM [PDSI].[mhis_all_pecs_data] AS a
LEFT JOIN [PDSI].[Definitions] AS b ON a.measureid = b.measureid
INNER JOIN (
	SELECT measureid
		  ,max(yearid) AS recentyear   
		  ,max(reportingperiodid) AS recentqtr
	FROM PDSI.mhis_all_pecs_data as a
	INNER JOIN (
		SELECT max(yearid) as recentyear 
		FROM [PDSI].[mhis_all_pecs_data]
		) as b on a.yearid=b.recentyear
	WHERE (measureid BETWEEN 5101 AND 5999 or a.measureid = 1116) 
		AND (measureid not in ('5120','5121')) 
	GROUP BY measureid

	UNION ALL

	SELECT measureid
		  ,max(yearid) AS recentyear   
		  ,max(reportingperiodid) AS recentqtr
	FROM PDSI.mhis_all_pecs_data as a 
	INNER JOIN (
		SELECT max(yearid) as recentyear
		FROM [PDSI].[mhis_all_pecs_data]
		WHERE measureid like '5110'
		) as b on a.yearid=b.recentyear
	WHERE measureid like '5110'
	GROUP BY measureid
	) AS c ON a.measureid = c.measureid
		AND a.yearid = c.recentyear
		AND a.reportingperiodid = c.recentqtr
WHERE VISN <> 0

--------------------------------create temp table with all most recent MHIS PDSI measures, just national--------------------
DROP TABLE IF EXISTS #TempMHISdatantnl;

SELECT [pec]
	  ,a.[program_id]
	  ,a.[measureid]
	  ,a.[yearid]
	  ,a.[timeframeid]
	  ,a.[reportingperiodid]
	  ,a.[loaddate]
	  ,a.[passfail]
	  ,a.sta6aid
	  ,a.ChecklistID
	  ,a.[NEPEC3n]
	  ,a.[visn]
	  ,a.[admparent_key]
	  ,a.[cursta3n]
	  ,a.[admparent_fcdm]
	  ,a.[best_met_notmet]
	  ,a.[low_met_notmet]
	  --,[score] as NatScore
	  ,a.[numerator]
	  ,a.[denominator]
	  ,VariableName as [MEASUREMNEMONIC]
	  ,Score as NatScore 
INTO #TempMHISdatantnl
FROM [PDSI].[mhis_all_pecs_data] AS a
LEFT JOIN [PDSI].[Definitions] AS b ON a.measureid = b.measureid
INNER JOIN (
	SELECT measureid
			,max(yearid) AS recentyear   
			,max(reportingperiodid) AS recentqtr
	FROM [PDSI].[mhis_all_pecs_data] as a 
	INNER JOIN (
		SELECT max(yearid) as recentyear 
		FROM [PDSI].[mhis_all_pecs_data]
		) as b on a.yearid=b.recentyear
	WHERE (measureid BETWEEN 5101 AND 5999 or measureid = 1116 ) 
		AND (measureid not in ('5120','5121')) 
	GROUP BY measureid

	UNION ALL

	SELECT measureid
		  ,max(yearid) AS recentyear   
		  ,max(reportingperiodid) AS recentqtr
	FROM PDSI.mhis_all_pecs_data as a 
	INNER JOIN (
		SELECT max(yearid) as recentyear 
		FROM [PDSI].[mhis_all_pecs_data]
		WHERE measureid like '5110'
		) as b on a.yearid=b.recentyear
	WHERE measureid like '5110'
	GROUP BY measureid	
	) AS c ON a.measureid = c.measureid
		AND a.yearid = c.recentyear
		AND a.reportingperiodid = c.recentqtr
WHERE VISN = 0

--------------------------------------------------------Join Facility and national MHIS data-----------------
DROP TABLE IF EXISTS #StageMHISChecklistid

SELECT a.pec
	  ,a.program_id
	  ,a.measureid
	  ,a.yearid
	  ,a.timeframeid
	  ,a.reportingperiodid
	  ,a.loaddate
	  ,a.passfail
	  ,a.sta6aid
	  ,a.ChecklistID
	  ,a.NEPEC3n
	  ,a.visn
	  ,a.admparent_key
	  ,a.cursta3n
	  ,a.admparent_fcdm
	  ,a.best_met_notmet
	  ,a.low_met_notmet
	  ,a.numerator
	  ,a.denominator
	  ,a.Measuremnemonic
	  ,a.SCORE
	  ,b.NatScore
INTO #StageMHISChecklistid
FROM #TempMHISdata AS a
INNER JOIN #TempMHISdatantnl AS b ON a.measuremnemonic = b.measuremnemonic

EXEC [Maintenance].[PublishTable] 'PDSI.ALLMHISChecklistid','#StageMHISChecklistid'
--select distinct  measuremnemonic from #TempAllMHIS
--select distinct nepec3n, checklistid from #tempallmhis

--************************************************PULLING MHIS DATA FOR TRENDS*************************************************************

--------------------------------create temp table with all most recent MHIS PDSI measures, all facilities/visns, no national--------------------
DROP TABLE IF EXISTS #StageMHISTrends ;

SELECT [pec]
	,a.[program_id]
	,a.[measureid]
	,a.[yearid]
	,a.[timeframeid]
	,a.[reportingperiodid]
	,a.[loaddate]
	,a.[passfail]
	,a.sta6aid
	,a.ChecklistID
	,a.[NEPEC3n]
	,a.[visn]
	,a.[admparent_key]
	,a.[cursta3n]
	,a.[admparent_fcdm]
	,a.[best_met_notmet]
	,a.[low_met_notmet]
	--,[score]
	,a.[numerator]
	,a.[denominator]
	,Variablename as Measuremnemonic
	,Score 
INTO #StageMHISTrends
FROM [PDSI].[mhis_all_pecs_data] AS a
LEFT JOIN [PDSI].[Definitions] AS b ON a.measureid = b.measureid
WHERE VISN <> 0  
	AND (a.measureid not in ('5120','5121')) 

EXEC [Maintenance].[PublishTable] 'App.ALLMHISChecklistid_Trends','#StageMHISTrends'


END
GO
