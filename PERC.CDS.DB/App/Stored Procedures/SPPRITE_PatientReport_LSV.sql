




-- =============================================
-- Author:		<Marcos Lau>
-- Create date: <8/4/18>
-- Description:	<App.SPPRITE_PatientReport_LSV>
-- Test in Sbx: EXEC  [App].[SPPRITE_PatientReport_LSV] 'VHA21\vhapalstephr6','402','1','-9','A,J', '0,1', '0,1', '0,1,2,3,4'
			 -- EXEC  [App].[SPPRITE_PatientReport_LSV] 'VHA21\vhapalstephr6','402', '3', '3401053,-1','A,J'
	--select count(distinct PatientICN) from Dflt.SPPRITE_Test
	--select * from Dflt.SPPRITE_Test
-- Test in Dev: EXEC  [App].[SPPRITE_PatientReport_LSV] 'VHA21\vhapalstephr6','640','5','-9','A,J', '1', '0,1,2,3,4'
-- Test in Dev: EXEC  [App].[SPPRITE_PatientReport_LSV] 'VHA21\vhapalhannec','528A6','2','-9','A,J'
-- Test in Dev: EXEC  [App].[SPPRITE_PatientReport_LSV] 'VHA21\vhapalstephr6','657A4','5','-9','A'
-- Test in Dev: EXEC  [App].[SPPRITE_PatientReport_LSV] 'VHA20\vhawcosullip','692','5','-9','A'
-- MODIFICATIONS:
	-- 20190226	RAS	Changed provider info to pull from Present PCP and MHTC views.  
	-- 20190226	RAS	Removed unioned query and included unassigned patients in first query
	-- 20190405 CB  Changed references from ProviderSID (& pp.) to MHTCSID (& pm); we want the parameter to encompass MHTCs instead of PCPs as it had done; future plans will be to create paramaters like STORM where users can choose multiple teams and multiple providers
	-- 20190719 RAS Added tables for provider and risk factor parameters to use inner join instead of previous where statements
	-- 20190910 CMH Changed references to pull in GroupAssignments parameter rather than MHTC - this will allow users to select from PCP, PACT, BHIP, MHTC, or opioid prescriber 
	-- 20191024 CMH Updated join for Appointments to be on ChecklistID rather than Sta3n since it was causing problems for the integrated facilities
	-- 20191230 CMH Pulled 'where ChecklistID=@Station' out of main SPPRITE table join and created temp table for GroupAssignments due to loading issues with some sites
	-- 20200318	RAS	Added temp tables for appt and added indexes to source tables to help with speed.
	-- 20200319	RAS	Added placeholder parameters for COVID-19 and MH non-engagement fields that are being added.
	-- 20200320	RAS	Removed appointment code and put fields into PatientBasetable.
	-- 20200623 CMH Added COVID-HRF outreach parameter to select patients specifically getting outreach at facility of interest
	-- 20230118	LM	Added preferred name
	-- 20240402 CMH Removing COVID data 
-- =============================================
CREATE PROCEDURE [App].[SPPRITE_PatientReport_LSV]
	
	 @UserID varchar(25)
	,@Station varchar(1000)
	,@GroupType varchar(100)
	,@Provider varchar(max)
	,@RiskFactors varchar(1000)
	,@COMPACT varchar(5)
	,@MHEngage varchar(25)
	--,@LocationSID int -- -2 = With or Without (default) 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


----TESTING
--	DECLARE @UserID varchar(25)			=	'VHA21\vhapalhannec'
--	DECLARE @Station varchar(1000)		=	'640'
--	DECLARE @GroupType varchar(100)		=	'2'
--	DECLARE @Provider varchar(1000)		=	'-9'
--	DECLARE @RiskFactors varchar(1000)	=	'A,B,C,D,F,G,H,I,J,K,L,M,N,O,P,Q,U,V,X,2,3,4'
--	DECLARE @MHEngage varchar(25)		=	'0,1,2,3,4'


---------------------------------------------------------------
-- Parameters
---------------------------------------------------------------
--Create Risk Factor parameter table
DECLARE @RiskList TABLE (RiskFactor VARCHAR(10))
INSERT @RiskList  SELECT value FROM string_split(@RiskFactors, ',')

DECLARE @COMPACT_List TABLE (COMPACT_ActiveEpisode BIT)
INSERT @COMPACT_List SELECT value FROM string_split(@COMPACT, ',')

DECLARE @MHNonEngage TABLE (MHEngage INT)
INSERT @MHNonEngage SELECT value FROM string_split(@MHEngage, ',')

--Create Provider parameter table (if applicable)
--IF len(@Provider) > 900
--	BEGIN
--		SET @Provider = '-9'
--	END
--ELSE
--BEGIN
	DECLARE @ProviderList TABLE ([Provider] VARCHAR(10))
	INSERT @ProviderList  SELECT value FROM string_split(@Provider, ',')	
--END

---------------------------------------------------------------
-- LSV Permissions
---------------------------------------------------------------
--First, create a table with all the patients (ICNs) that the user has permission to see
--Added filter for RiskFactors here to decrease number of patients carried forward (2020-03-18 RAS)
DROP TABLE IF EXISTS #PatientLSV;
--Subquery checks user's access to the patient and gets the PatientICN
		SELECT DISTINCT sr.MVIPersonSID
		INTO  #PatientLSV
		FROM [SPPRITE].[RiskIDandDisplay] sr WITH (NOLOCK) 
		INNER JOIN (
			--Use SPPRITE list to check access (all display stations must be included in RiskID table)
			SELECT DISTINCT MVIPersonSID
			FROM [SPPRITE].[RiskIDandDisplay] as pat WITH (NOLOCK)
			INNER JOIN (SELECT Sta3n FROM [App].[Access](@UserID)) as Access 
				on LEFT(pat.ChecklistID,3) = Access.Sta3n
			WHERE ChecklistID=@Station 
			) lsv on lsv.MVIPersonSID=sr.MVIPersonSID
		INNER JOIN @RiskList rl on rl.RiskFactor = sr.RiskFactorID

---------------------------------------------------------------
-- Pull in other parameters
---------------------------------------------------------------
DROP TABLE IF EXISTS #SPPRITE_PatientDetail
SELECT *
	,CASE WHEN COMPACT_ChecklistID=@Station THEN COMPACT_ActiveEpisode ELSE 0 END AS COMPACT_ActiveEpisode2
INTO #SPPRITE_PatientDetail
FROM [SPPRITE].[PatientDetail] WITH (NOLOCK) 

DROP TABLE IF EXISTS #Patient
SELECT DISTINCT p.MVIPersonSID
INTO #Patient
FROM #PatientLSV p 
INNER JOIN #SPPRITE_PatientDetail a on p.MVIPersonSID=a.MVIPersonSID
INNER JOIN @MHNonEngage e on e.MHEngage=a.MHengage
INNER JOIN @COMPACT_List f on f.COMPACT_ActiveEpisode=a.COMPACT_ActiveEpisode2
--WHERE COVID in (SELECT value FROM string_split(@COVID,','))
	--AND MHEngage IN (SELECT value FROM string_split(@MHEngage,','))

DROP TABLE #PatientLSV

---------------------------------------------------------------
-- Pull station of interest from Group Assignments 
---------------------------------------------------------------
DROP TABLE IF EXISTS #grp
SELECT g.MVIPersonSID
	,g.ChecklistID
	,g.GroupID
	,g.GroupType
	,g.ProviderSID
	,g.ProviderName
	,g.Sta3n
INTO #grp
FROM [Present].[GroupAssignments_STORM] g WITH (NOLOCK) 
INNER JOIN #Patient p on p.MVIPersonSID=g.MVIPersonSID
WHERE ChecklistID=@Station

--CREATE CLUSTERED INDEX CIX_GA_PatientICN

---------------------------------------------------------------
-- Main SPPRITE table
---------------------------------------------------------------
DROP TABLE IF EXISTS #SPPRITE;
SELECT a.*
      --,p.PatientSID
      --,p.PatientSSN
      ,concat(left(a.PatientName, 1), a.Last4) as LIL4                
      ,grp.GroupID
      ,grp.GroupType
      ,grp.ProviderSID
      ,grp.ProviderName
      ,grp.ChecklistID as ProviderChecklistID
      ,grp.Sta3n as ProviderSta3n
      ,isnull(mh.StaffName,'Unassigned') as Provider_MHTC
      ,isnull(pc.StaffName,'Unassigned') as Provider_PCP
	  ,mp.PreferredName
	  ,dm.DisplayMessageText as DMC_DisplayMessageText
	  ,dm.Link as DMC_Link
INTO #SPPRITE
FROM [SPPRITE].[PatientDetail] as a WITH (NOLOCK) 
INNER JOIN #Patient p on p.MVIPersonSID=a.MVIPersonSID
INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK) ON a.MVIPersonSID = mp.MVIPersonSID
LEFT JOIN #grp as grp on p.MVIPersonSID=grp.MVIPersonSID 
LEFT JOIN [Present].[Provider_MHTC] mh WITH (NOLOCK) on p.MVIPersonSID=mh.MVIPersonSID AND mh.ChecklistID=@Station
LEFT JOIN [Present].[Provider_PCP] pc WITH (NOLOCK) on p.MVIPersonSID=pc.MVIPersonSID AND pc.ChecklistID=@Station
LEFT JOIN [Config].[DMC_DisplayMessage] dm WITH (NOLOCK) on a.DMC_DisplayMessage=dm.DisplayMessage

---------------------------------------------------------------
-- Filter for provider 
---------------------------------------------------------------
IF @Provider= '-9' 
BEGIN
	SELECT * 
	FROM #SPPRITE a
	WHERE a.GroupID=@GroupType or @GroupType='-5'
	ORDER BY MVIPersonSID
END
ELSE
BEGIN
	SELECT * 
	FROM #SPPRITE a
	INNER JOIN @ProviderList p on p.Provider=a.ProviderSID 
	WHERE a.GroupID=@GroupType
END

END