
-- =============================================
-- Author:		Claire Hannemann
-- Create date: 11/8/2023
-- Description:	App.SUD_TobaccoUD_LSV
-- Test in Dev: EXEC  [App].[SUD_TobaccoUD_LSV] 'VHA21\vhapalhannec','618','2','-9','0,1', '9530888', '1,2','1,2,3'

-- MODIFICATIONS:
--  04052024   CMH  Added in GroupType parameter
--  04112024   CMH  Added in outreach staff parameter, removed active treatment
--  02102025   CMH  Added Case Open/Closed parameter
--  05092025   CMH  Added Outreach Needed parameter

-- =============================================
CREATE PROCEDURE [App].[SUD_TobaccoUD_LSV]
	
	 @UserID varchar(25)
	,@Station varchar(100)
	,@GroupType varchar(100)
	,@Provider varchar(max)
	,@TobaccoScreen_Past60Days varchar(10)
	,@OutreachStaff varchar(max)
	,@CaseStatus varchar(25)
	,@OutreachNeeded varchar(10)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

---------------------------------------------------------------
-- Parameters
---------------------------------------------------------------
--Create parameter tables
DECLARE @TobaccoScreen TABLE (TobaccoScreen_Past60Days INT)
INSERT @TobaccoScreen SELECT value FROM string_split(@TobaccoScreen_Past60Days, ',')

DECLARE @Staff TABLE (OutreachStaff VARCHAR(MAX))
INSERT @Staff SELECT value FROM string_split(@OutreachStaff, ',')

DECLARE @CaseStatus1 TABLE (CaseStatus VARCHAR(MAX))
INSERT @CaseStatus1 SELECT value FROM string_split(@CaseStatus, ',')

DECLARE @OutreachNeeded1 TABLE (OutreachNeeded VARCHAR(MAX))
INSERT @OutreachNeeded1 SELECT value FROM string_split(@OutreachNeeded, ',')


--Create Provider parameter table 
IF len(@Provider) > 900
	BEGIN
		SET @Provider = '-9'
	END
ELSE
BEGIN
	DECLARE @ProviderList TABLE ([Provider] VARCHAR(10))
	INSERT @ProviderList  SELECT value FROM string_split(@Provider, ',')	
END

-- LSV Permissions
DROP TABLE IF EXISTS #PatientLSV;
SELECT DISTINCT MVIPersonSID
INTO  #PatientLSV
FROM [SUD].[TobaccoUD] as pat WITH (NOLOCK)
INNER JOIN (SELECT Sta3n FROM [App].[Access](@UserID)) as Access 
	on LEFT(pat.Homestation_ChecklistID,3) = Access.Sta3n
WHERE Homestation_ChecklistID=@Station 

-- Pull station of interest from Group Assignments 
DROP TABLE IF EXISTS #grp
SELECT g.MVIPersonSID
	,g.ChecklistID
	,g.GroupID
	,g.GroupType
	,g.ProviderSID
	,g.ProviderName
	,g.Sta3n
INTO #grp
FROM [Present].[GroupAssignments] g WITH (NOLOCK) 
INNER JOIN [SUD].[TobaccoUD] p WITH (NOLOCK) on p.MVIPersonSID=g.MVIPersonSID
WHERE ChecklistID=@Station

-- Pull in other parameters
DROP TABLE IF EXISTS #tobacco
SELECT a.*
	,d.GroupID
	,d.GroupType
	,d.ProviderSID
	,d.ProviderName
into #tobacco
FROM [SUD].[TobaccoUD] as a WITH (NOLOCK) 
INNER JOIN #PatientLSV p on p.MVIPersonSID=a.MVIPersonSID
INNER JOIN @TobaccoScreen b on a.TobaccoScreen_Past60Days=b.TobaccoScreen_Past60Days
LEFT JOIN #grp d on p.MVIPersonSID=d.MVIPersonSID
INNER JOIN @Staff s on ISNULL(a.HF_staffSID2,a.HF_staffSID1)=s.OutreachStaff
INNER JOIN @CaseStatus1 c on a.CaseStatus=c.CaseStatus
INNER JOIN @OutreachNeeded1 o on a.OutreachNeeded=o.OutreachNeeded

-- Filter for provider 
IF @Provider= '-9' 
BEGIN
	SELECT * 
	FROM #tobacco a
	WHERE a.GroupID=@GroupType or @GroupType='-5'
	ORDER BY MVIPersonSID
END
ELSE
BEGIN
	SELECT * 
	FROM #tobacco a
	INNER JOIN @ProviderList p on p.Provider=a.ProviderSID 
	WHERE a.GroupID=@GroupType
END

END