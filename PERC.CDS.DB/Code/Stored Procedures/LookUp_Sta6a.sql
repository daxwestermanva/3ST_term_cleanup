
-- =============================================
-- Author:		<Author,Shalini Gupta>
-- Create date: <Create Date, 2/27/2018 >
-- Description:	<Description, This code creates the Lookup Sta6a level tables  >
-- Creates Table Lookup.Sta6a
-- Updated by SG on 11/14/19 to reflect merger of '528A5'(Canandaigua) to '528A6'(Bath)
-- Updated by SG on 12/08/19, fixed sta3n and CurSta3n column to have count of 130
-- Updated by SG on 2/19/20, fixed for Null ADMParent_FCDM in the final table 
--	2020-11-16 SG - Fixing temp SHRED issue with 589A5, need to revert when it is fixed in SHRED -revert back
--  2021-04-19 SG - Added StaPa and created new table [LookUp].[Sta6aCumulative]
--	2021-10-18 RAS	Added PublishedTable logging to Sta6aCumulative
--	2022-07-11 JEB - Updated Synonym references to point to Synonyms from Core
--  2024-06-11 SG - Correcting Sta3n wrt sta6a and removing reference of the discontinued SHRED_dbo_DimFacility6A table                  
--  2024-08-13 SG - changing checklistID from 596A4 to 596 from FYID 2025 onwards, same as stapa and sta6aid 
 -- =============================================

CREATE PROCEDURE [Code].[LookUp_Sta6a] 
AS
BEGIN
/**********************************************************************************************************
THIS QUERY CREATES TABLE 
Lookup.Sta6a from [PDW].[SHRED_dbo_DimSHREDFacility] which is a copy of [App].[SHRED_dbo_dbo].[DimSHREDFacility]

COLUMNS:  VISN, STA3N, Sta6a, ChecklistID, Nepec3n, ADMParent_Key,FacilityLevel
***********************************************************************************************************/

-- TimeFrame 
DECLARE @FYID INT = (select FYID=max(FYID) from [PDW].[SHRED_dbo_DimSHREDFacility])
--print @FYID 

/*********************************************************************************************************/
/* STEP 1: Getting AdmParent/ChecklistID                                                                 */
/*********************************************************************************************************/
DROP TABLE IF EXISTS #c1
 SELECT ADMParent_Key, ADMPARENT_FCDM, DIVISION_FCDM, VISN, STA3N, CurSTA3N, ChecklistID, STA6AID, FacilityLevel,FYID, uniq
 INTO #c1
 FROM(
   SELECT  ADMParent_Key
           ,ADMPARENT_FCDM 
	       ,DIVISION_FCDM 
           ,VISN 
	       ,STA3N 
	       ,CurSTA3N = STA3N
	       ,ChecklistID = STA6AID		 
	       ,STA6AID
	      ,FacilityLevel
	      ,FYID
	      ,uniq=row_number() over(PARTITION BY FYID,ADMParent_Key ORDER BY FYID,ADMParent_Key,sta6aid desc )
FROM [PDW].[SHRED_dbo_DimSHREDFacility]
WHERE FacilityLevelid in (3) and (sta3n not between '470' and '499' )
	  and FYID = @FYID
) as a
WHERE uniq=1
-- 140 rows,  select * from #c1  where checklistid='596' order by VISN, STA6AID

-- Getting distinct ADMParent_Key with ChecklistID and adding Nepec3n
DROP TABLE IF EXISTS #c2
SELECT DISTINCT 
     a.ADMParent_Key
	,a.ADMPARENT_FCDM 
	,a.DIVISION_FCDM 
	,a.VISN
	,b.STA3N
	,b.CurSTA3N
	,Sta6a = a.STA6AID
	,a.ChecklistID
	,a.STA6AID
	,b.Nepec3n
	,c.stapa
	,FacilityLevel
	,FYID
INTO #c2
FROM #c1 AS a
INNER JOIN  ( Select distinct ChecklistID, Nepec3n, CurSTA3N, STA3N from LookUp.ChecklistidCumulative)  AS b
       ON a.ChecklistID = b.ChecklistID
LEFT JOIN  ( Select distinct StaPa from Dim.Institution)  AS c 
	   ON a.STA6AID = c.StaPa

-- 140 rows --  select * from #c2 where checklistid='596'  order by VISN, Sta6a
-- select * from [PDW].[SHRED_dbo_DimSHREDFacility]
/**************************************************************************************************************/
/* STEP 2: Getting Sta6a/Division/CBOC/ from [PDW].[SHRED_dbo_DimSHREDFacility]                                 */
/* and adding same ChecklistID, Nepec3n  as their admparent                                                   */
/**************************************************************************************************************/
DROP TABLE IF EXISTS #c3
SELECT distinct x.ADMParent_Key
       ,y.ADMPARENT_FCDM
	   ,DIVISION_FCDM 
	   ,VISN 
	   ,x.STA3N
	   ,CurSTA3N=x.STA3N
	   ,Sta6a = x.STA6AID
   	   ,y.ChecklistID
	   ,y.STA6AID
	   ,y.Nepec3n
	   ,y.StaPa
	   ,x.FacilityLevel
	   ,x.FYID
INTO #c3
FROM [PDW].[SHRED_dbo_DimSHREDFacility] AS x
LEFT JOIN ( SELECT ChecklistID, Nepec3n,STA6AID, ADMParent_Key, ADMPARENT_FCDM, STA3N, CurSTA3N, StaPa FROM #c2) AS y
   ON x.ADMParent_Key = y.ADMParent_Key
WHERE x.FacilityLevelid IN (5) 
AND FacilityLevel = 'Division'
AND FYID = @FYID
and x.ADMPARENT_FCDM NOT LIKE ('%OLD%') and y.sta3n is not null 
-- select * from #c3 order by VISN, Sta6a
--3775

/**************************************************************************************************************/
/* STEP 3: COMBIN both ADMParent level and Division level                                                     */
/**************************************************************************************************************/
DROP TABLE IF EXISTS #sta6a
SELECT 
     VISN
	,STA3N
    ,CurSTA3N
	,Sta6a
	,ChecklistID
	,STA6AID
	,Nepec3n
	,StaPa
	,ADMParent_Key
	,ADMPARENT_FCDM
	,DIVISION_FCDM
	,FacilityLevel 
	,uniq=row_number() over(PARTITION BY Sta6a ORDER BY Sta6a,FacilityLevel )
INTO #sta6a
FROM (  SELECT VISN, STA3N, CurSTA3N, Sta6a, ChecklistID, STA6AID, Nepec3n, StaPa, ADMParent_Key, ADMPARENT_FCDM, DIVISION_FCDM,FacilityLevel FROM #c2
		UNION ALL
        SELECT VISN, STA3N, CurSTA3N, Sta6a, ChecklistID, STA6AID, Nepec3n, StaPa, ADMParent_Key, ADMPARENT_FCDM, DIVISION_FCDM,FacilityLevel FROM #c3
	 ) AS s

--3915
-- select * from #Sta6a where FacilityLevel ='Division'
-- select count(*) from Lookup.Sta6a -- 3833

/************************************************************************************************************/
/* Final Sta6a table                                                                                         */
/************************************************************************************************************/
DROP TABLE IF EXISTS #StageSta6a;
SELECT VISN
	  ,STA3N
      ,CurSTA3N
	  ,Sta6a
	  ,ChecklistID
	  ,STA6AID
	  ,Nepec3n
	  ,StaPa
	  ,ADMParent_Key
	  ,ADMPARENT_FCDM
	  ,DIVISION_FCDM
	  ,FacilityLevel 
	  ,FYID = @FYID
INTO #StageSta6a
FROM #sta6a
WHERE uniq=1
--3775
-- select * from #StageSta6a where checklistid='589A5' order by DIVISION_FCDM  -- 26
-- select * from #StageSta6a where checklistid='528A6' order by DIVISION_FCDM  -- 18
-- select * from [Lookup].[Sta6a] where checklistid in ('528A6','528A5') order by DIVISION_FCDM -- 43

---- check for checklistID change from 596A to 596 
--select * from [Lookup].[Sta6a] where sta3n='596' 

---- check for left(sta6a,3) <> sta3n , should be 0 
--select * from [Lookup].[Sta6a] where  left(sta6a,3) <> sta3n --441
--select * from #StageSta6a where left(sta6a,3) <> sta3n -- 0 rows
--select * from #StageSta6a   where sta6a='668GC'
--select * from #StageSta6a  where stapa='596' 

EXEC [Maintenance].[PublishTable] '[Lookup].[Sta6a]','#StageSta6a' 

/*************CHECK ******************************************** 
select distinct ADMPARENT_FCDM FROM LookUp.Sta6a  -- should return 140 rows
****************************************************************/

/************************************************************************************************************/
/* Sta6a Cumulative table                                                                                   */
/************************************************************************************************************/
DECLARE @RowCount INT = (SELECT COUNT(*) FROM #StageSta6a )
-- Delete FYID data if already exists 
IF @RowCount > 0

 BEGIN 
  DELETE FROM [LookUp].[Sta6aCumulative] 
  WHERE FYID = @FYID 

  INSERT INTO [LookUp].[Sta6aCumulative]
  SELECT  
     FYID = @FYID
    ,VISN
    ,STA3N
    ,CurSTA3N
    ,Sta6a
    ,ChecklistID
    ,STA6AID
    ,Nepec3n
    ,StaPa
    ,ADMParent_Key
    ,ADMPARENT_FCDM
    ,DIVISION_FCDM
    ,FacilityLevel 
  FROM #StageSta6a
 
 EXEC [Log].[PublishTable] 'LookUp','Sta6aCumulative','#StageSta6a','Append',@RowCount
 END 


END

GO
