-- =============================================
-- Author:		Amy Robinson
-- Create date: 11/25/2016
-- Description:	VISN 21 Stations with National and VISN21 choices
/*
	EXEC [App].[p_Sta6aID]  	
	@VISN = '-1'
*/
-- 20180723 RAS: Added VISN to order by statement for reports that have multiple VISNs in parameter
-- 20180912 JEB: Added alias to prefix VISN in order by statement to remove ambiguous column reference
-- 20240815	LM:	 Updated ChecklistID value for Lexington 596
-- =============================================
CREATE PROCEDURE [App].[p_Sta6aID]
  --@FiscalYear varchar(50)
  @User varchar(50),
  @VISN varchar(500)
AS
BEGIN
	SET NOCOUNT ON;
	
DECLARE @VISNList TABLE (VISN VARCHAR(10))
INSERT @VISNList  SELECT value FROM string_split(@VISN, ',')

IF @VISN = '' OR @VISN='-1'
	BEGIN
		SELECT DISTINCT a.Sta3n,
			CASE WHEN  a.STA6AID LIKE '612%' THEN '612' 
				WHEN a.ChecklistID = '596A4' THEN '596'
				ELSE  a.STA6AID end AS Historic
			,a.ChecklistID AS IntegratedSta3n
			,a.STA6AID
			,a.Facility
			,a.Facility + ' | ' + a.Sta6aid  as FaciltySta
			,a.ADMPARENT_FCDM
			,LTRIM(RTRIM(REPLACE(a.ADMPARENT_FCDM,',','|'))) AS Value
			,a.ChecklistID 
			,a.FacilityLevelID
			,a.VISN
			,a.StaPa
			,CASE WHEN a.IOCDate < getdate() THEN 1 ELSE 0 END AS Active_OracleH
		FROM LookUp.ChecklistID AS a WITH (NOLOCK)
		WHERE FacilityLevelID = 3 -- need to remove and use filter in the  first 3 EBP reports to support ORM trend report
		ORDER BY a.VISN,STA6AID  --VISN  
	END

ELSE

	BEGIN
		SELECT DISTINCT a.Sta3n,
			CASE WHEN  a.STA6AID LIKE '612%' THEN '612' 
				WHEN a.ChecklistID = '596A4' THEN '596'
				ELSE  a.STA6AID end AS Historic
			,a.ChecklistID AS IntegratedSta3n
			,a.STA6AID
			,a.Facility
			,a.Facility + ' | ' + a.Sta6aid  as FaciltySta
			,a.ADMPARENT_FCDM
			,LTRIM(RTRIM(REPLACE(a.ADMPARENT_FCDM,',','|'))) AS Value
			,a.ChecklistID 
			,a.FacilityLevelID
			,a.VISN
			,a.StaPa
			,CASE WHEN a.IOCDate < getdate() THEN 1 ELSE 0 END AS Active_OracleH
		FROM LookUp.ChecklistID as a WITH (NOLOCK)
		INNER JOIN @VISNList v ON v.VISN = a.VISN
		--where VISN = @VISN 
		--and facilitylevelid = 3 
		ORDER BY a.VISN, STA6AID 
	END





















/*

case when  a.STA6AID like '612%' then '612' else  a.STA6AID end Historic
,STA6AID
,a.Facility
,a.Facility + ' | ' + Sta6aid  as FaciltySta
, ADMPARENT_FCDM
,VISN
,FacilityLevelID
,LTRIM(RTRIM(REPLACE(admparent_fcdm,',','|'))) AS Value
		,case when  a.ChecklistID like '612%' then '612' else  a.ChecklistID end ChecklistID
		
FROM LookUp.ChecklistID as a
where VISN in  (SELECT value FROM string_split(@VISN ,',')) --and facilitylevelid in 
or facilitylevelid = 1
order by visn,facilitylevelid desc,STA6AID
*/

END