
/* =============================================
-- Author:		<Author,,Shalini Gupta>
-- Create date: <Create Date,2/27/2018>
-- Description:	<Description, This code creates the Lookup ChecklistID >
-- Creates Table LookUp.ChecklistID
-- UPDATE:	
	--	2019-02-13	Jason Bacani - Refactored to use [Maintenance].[PublishTable]
	--	2020-11-16 Shalini Gupta - Fixing temp SHRED issue with 589A5, need to revert when it is fixed in SHRED - revert back
	--  2021-04-19 Shalini Gupta - Adding Stapa - used in Cerner data. 
	--  2021-04-19 Shalini Gupta - updating CDW synonym to Dim.Institution
	--	2022-04-28 Rebecca Stephens - Added Sta3nFlag to LookUp.ChecklistID for implementation of joins going from Sta3n
									to ChecklistID (usually we would go from Sta6a or similar up to ChecklistID, but sometimes
									that granularity is not available, so we need the "default" ChecklistID for the Sta3n)
    --  2022-06-16 Shalini Gupta - Adding IOCDate to the table for cerner implemented sites
	--	2022-07-11 Jason Bacani - Updated Synonym references to point to Synonyms from Core

	--  2022-08-12 Alston, Steven -Updated source of facility location from [MillCDS].[DimVALocation] to [MillCDS].[DimLocations]
									New table includes DoD location data
									Changed logic for DoD flag to utilize identifier in [MillCDS].[DimVALocation]
   --  2024-08-13 Shalini Gupta - changing checklistID from 596A4 to 596 from FYID 2025 onwards, same as stapa and sta6aid
-- ============================================= */

CREATE   PROCEDURE [Code].[LookUp_ChecklistID]
AS
BEGIN

	/*************************************************************************************************************
	FY17: 160 rows : 1 National, 18 VISN and 141 ChecklistID/AdmParent from the following SHRED tables

	[App].[SHRED_dbo_dbo].[DimSHREDFacility] --> [PDW].[SHRED_dbo_DimSHREDFacility]
	[App].[SHRED_dbo_dbo].[DimFacility6A]   --> [PDW].[SHRED_dbo_DimFacility6A]
	
	**************************************************************************************************************/

	/************************************************************************************************************/
	/* Getting 159 rows : 1 National, 18 VISN and 140 ChecklistID/AdmParent from [PDW].[SHRED_dbo_DimSHREDFacility] **/
	/* Adding ChecklistID. Note: STA6AID in DimSHREDFacility is similar to ChecklistID except 2 fac */
	
	DROP TABLE IF EXISTS #t1;
	SELECT FYID
		,ChecklistID
		,STA6AID
		,VISN_FCDM
		,VISN
		,ADMPARENT_FCDM
		,ADMParent_Key
		,CurSTA3N
		,District
		,STA3N
		,FacilityID
		,FacilityLevel
		,FacilityLevelID
		,MCGKey
		,MCGName
	INTO #t1
	FROM (
		SELECT FYID
		    ,ChecklistID = STA6AID			
			,STA6AID
			,VISN_FCDM
			,VISN 
			,ADMPARENT_FCDM 
			,ADMParent_Key 
			,CurSTA3N = STA3N
			,District 
			,STA3N
			,FacilityID 
			,FacilityLevel 
			,FacilityLevelID
			,MCGKey
			,MCGName
			,uniq = ROW_NUMBER() OVER(PARTITION BY FYID,ADMParent_Key ORDER BY ADMParent_Key,STA6AID DESC)
		FROM [PDW].[SHRED_dbo_DimSHREDFacility]
		WHERE FacilityLevelID IN (1,2,3) 
			AND (STA3N NOT BETWEEN '470' AND '499' )  
			-- AND FYID in (select FYID=max(FYID) from [PDW].[SHRED_dbo_DimSHREDFacility] )
		) as a
	WHERE uniq=1
--2249
	/****************************************************************************************************************/
	/* Adding Nepec3n amd StaPa                                                                                     */
    /* Adding StaPa from DimInstitution table, it is same as STA6AID. difference in ChecklistID=596A4 and Stapa =596*/
	/****************************************************************************************************************/
	DROP TABLE IF EXISTS #t2
	SELECT t.*
		,cc.Nepec3n
		,StaPa = CASE WHEN FYID >= 2020 AND LEN(t.ChecklistID) < 3 THEN t.ChecklistID 
			          WHEN FYID >= 2020 THEN stp.StaPA
					ELSE NULL END 
		,Facility = CASE WHEN t.ADMPARENT_FCDM LIKE 'National' THEN 'National' 
						WHEN t.ADMPARENT_FCDM LIKE 'V%' 
						AND cc.Nepec3n < 100 
						AND t.FYID < 2016 
						THEN LTRIM(RIGHT(t.ADMPARENT_FCDM,LEN(t.ADMPARENT_FCDM)))
						WHEN t.ADMPARENT_FCDM LIKE '(%' THEN LTRIM(RTRIM(SUBSTRING(t.ADMPARENT_FCDM, CAST(PATINDEX('%) [a-z]%', t.ADMPARENT_FCDM) AS INT) + 1 , LEN(t.ADMPARENT_FCDM)))) 
						ELSE LTRIM(RIGHT(t.ADMPARENT_FCDM,  Len(t.ADMPARENT_FCDM) - 1))
						END 			   
	INTO #t2
	FROM  #t1 AS t
	INNER JOIN  (
		SELECT DISTINCT 
			Sta6aid,Nepec3n 
			FROM [LookUp].[ChecklistidCumulative]
		) AS cc ON t.ChecklistID = cc.Sta6aid
    LEFT JOIN  (
		SELECT DISTINCT 
			StaPa 
		FROM [Dim].[Institution]
		) AS stp 
	   ON t.STA6AID = stp.StaPa
--2249
	DROP TABLE IF EXISTS #t3;
	SELECT FYID
		,ChecklistID
		,STA6AID 
		,VISN_FCDM 
		,VISN 
		,ADMPARENT_FCDM
		,ADMParent_Key
		,CurSTA3N
		,District
		,STA3N
		,FacilityID
		,FacilityLevel
		,FacilityLevelID
		,Nepec3n
		,Facility
		,MCGKey
		,MCGName
		,a.StaPa
		,ADMPSortKey = ROW_NUMBER() OVER(PARTITION BY FYID ORDER BY VISN,ADMPARENT_KEY)
		,Sta3nFlag = CASE 
			WHEN FacilityLevelID = 3 
				AND FacilityID = MIN(FacilityID) OVER(PARTITION BY Sta3n ORDER BY FacilityID) 
			THEN 1 ELSE 0 END
		,IOCDate
	INTO #t3
	FROM #t2 as a
	-- Facility date of cerner implemention 
	LEFT JOIN (
		SELECT DISTINCT StaPa,IOCDate 
		FROM [Cerner].[DimLocations] 
	    WHERE 1=1
		   AND OrganizationTypeValueID IN (1)
		   AND IOCDate != '8000-03-01' 
		   AND STAPA NOT IN ('459') -- exception, this facility is not fully Cerner implemented
		   ) b ON a.StaPa=b.StaPa
	WHERE FYID IN (SELECT MAX(FYID) FROM #t2)
-- 159
	--	select * from #t3 where stapa <> checklistID
	--	select * from #t3 WHERE Sta3nFlag = 1
	/************************************************************************************************************/
	/* Final table LookUp.ChecklistID with Latest FYID                                                */
	/************************************************************************************************************/
	EXEC [Maintenance].[PublishTable] 'LookUp.ChecklistID', '#t3'

	/************************************************************************************************************/
	/* Final Cumulative table                                                                                   */
	/************************************************************************************************************/
	DROP TABLE IF EXISTS #t2_Stage
	SELECT FYID, 
	       -- Keeping ChecklistID =596A from 2012 to 2024
		   ChecklistID = CASE 
						  WHEN FYID <2025 and ChecklistID = '596' THEN '596A4' -- visn 9
						  ELSE ChecklistID
						 END,
		   STA6AID, 
		   VISN_FCDM, 
		   VISN, 
		   ADMPARENT_FCDM,
		   ADMParent_Key,
		   CurSTA3N,
		   District,
		   STA3N,
		   FacilityID,
		   FacilityLevel,
		   FacilityLevelID,
		   Nepec3n,
		   Facility,
		   MCGKey,
		   MCGName,
		   StaPa,
		   ADMPSortKey = ROW_NUMBER() OVER(PARTITION BY FYID ORDER BY VISN,ADMPARENT_KEY) 
	INTO #t2_Stage
	FROM #t2

	EXEC [Maintenance].[PublishTable] 'LookUp.ChecklistIDCumulative', '#t2_Stage'

	--select * from LookUp.ChecklistIDCumulative where checklistid like '%612%' or checklistID like '%596%' order by FYID, ChecklistID
	--select * from LookUp.ChecklistID where checklistid like '%612%' or checklistID like '%596%' order by FYID, ChecklistID 
END
;

GO
