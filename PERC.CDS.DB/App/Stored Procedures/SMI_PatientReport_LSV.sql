

-- =============================================
-- Author:		Claire Hannemann
-- Create date: 8/10/2021
-- Description:	App.SMI_PatientReport_LSV
-- Test in Sbx: EXEC  [App].[SMI_PatientReport_LSV] 'VHA21\vhapalhannec','402','1','-9', '0,1', '0,1'

-- MODIFICATIONS:

-- =============================================
CREATE PROCEDURE [App].[SMI_PatientReport_LSV]
	
	 @UserID varchar(25)
	,@Station varchar(1000)
	,@GroupType varchar(100)
	,@Provider varchar(1000)
	,@MHEngage varchar(25)
	,@PCEngage varchar(25)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


----TESTING
--	DECLARE @UserID varchar(25)			=	'VHA21\vhapalhannec'
--	DECLARE @Station varchar(1000)		=	'402'
--	DECLARE @GroupType varchar(100)		=	'2'
--	DECLARE @Provider varchar(1000)		=	'-9'
--	DECLARE @MHEngage varchar(25)		=	'3,4,5'
--  DECLARE @PCEngage varchar(25)       =   '5'


---------------------------------------------------------------
-- Parameters
---------------------------------------------------------------
--Create parameter tables
DECLARE @MH_Engage TABLE (MH_Engagement INT)
INSERT @MH_Engage SELECT value FROM string_split(@MHEngage, ',')

DECLARE @PC_Engage TABLE (PC_Engagement INT)
INSERT @PC_Engage SELECT value FROM string_split(@PCEngage, ',')

--Create Provider parameter table (if applicable)
IF len(@Provider) > 900
	BEGIN
		SET @Provider = '-9'
	END
ELSE
BEGIN
	DECLARE @ProviderList TABLE ([Provider] VARCHAR(10))
	INSERT @ProviderList  SELECT value FROM string_split(@Provider, ',')	
END

---------------------------------------------------------------
-- LSV Permissions
---------------------------------------------------------------
--First, create a table with all the patients that the user has permission to see
DROP TABLE IF EXISTS #PatientLSV;
SELECT DISTINCT MVIPersonSID
INTO  #PatientLSV
FROM [SMI].[PatientReport] as pat WITH (NOLOCK)
INNER JOIN (SELECT Sta3n FROM [App].[Access](@UserID)) as Access 
	on LEFT(pat.Homestation_ChecklistID,3) = Access.Sta3n
WHERE Homestation_ChecklistID=@Station 
			

---------------------------------------------------------------
-- Pull in other parameters
---------------------------------------------------------------
DROP TABLE IF EXISTS #Patient
SELECT DISTINCT p.MVIPersonSID
INTO #Patient
FROM #PatientLSV p 
INNER JOIN [SMI].[PatientReport] a WITH (NOLOCK) on p.MVIPersonSID=a.MVIPersonSID
INNER JOIN @MH_Engage b on a.MH_Engagement=b.MH_Engagement
INNER JOIN @PC_Engage c on a.PC_Engagement=c.PC_Engagement

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
FROM [Present].[GroupAssignments_SMI] g WITH (NOLOCK)
INNER JOIN #Patient p on p.MVIPersonSID=g.MVIPersonSID
WHERE ChecklistID=@Station

--CREATE CLUSTERED INDEX CIX_GA_PatientICN

---------------------------------------------------------------
-- Main SMI Patient table
---------------------------------------------------------------
DROP TABLE IF EXISTS #SMI;
SELECT a.*
      ,concat(left(a.PatientName, 1), a.LastFour) as LIL4                
      ,grp.GroupID
      ,grp.GroupType
      ,grp.ProviderSID
      ,grp.ProviderName
      ,grp.ChecklistID as ProviderChecklistID
      ,grp.Sta3n as ProviderSta3n
	  ,w.UserID
	  ,w.PatientReviewed
	  ,w.ExecutionDate
	  ,w.Comments
	  ,w.LastReviewDate
INTO #SMI
FROM [SMI].[PatientReport] as a WITH (NOLOCK) 
INNER JOIN #Patient p on p.MVIPersonSID=a.MVIPersonSID
LEFT JOIN #grp as grp on p.MVIPersonSID=grp.MVIPersonSID 
LEFT OUTER JOIN 
	--Writeback
	(
		SELECT a1.*
		FROM
		(
			SELECT sta3n, MVIPersonSID, PatientReviewed, ExecutionDate, UserID, 
				Comments, MAX(ExecutionDate) OVER (PARTITION BY a2.MVIPersonSID) AS LastReviewDate
			FROM [SMI].[PatientReport_Writeback] AS a2
		) AS a1
		WHERE LastReviewDate = ExecutionDate
	) AS w ON a.MVIPersonSID= w.MVIPersonSID

---------------------------------------------------------------
-- Filter for provider 
---------------------------------------------------------------
IF @Provider= '-9' 
BEGIN
	SELECT * 
	FROM #SMI a
	WHERE a.GroupID=@GroupType or @GroupType='-5'
	ORDER BY MVIPersonSID
END
ELSE
BEGIN
	SELECT * 
	FROM #SMI a
	INNER JOIN @ProviderList p on p.Provider=a.ProviderSID 
	WHERE a.GroupID=@GroupType
END

END