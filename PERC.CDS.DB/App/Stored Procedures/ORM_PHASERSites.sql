 
-- =============================================
-- Author:		Amy Robinson 
-- Create date: 10/3/2022
-- Description:	Sites which have rolled out PHASER and those randomized to a STORM PGX trial
-- =============================================
CREATE   PROCEDURE [App].[ORM_PHASERSites] 
 
    @User VARCHAR(MAX)
 

 
AS
BEGIN
 
SET NOCOUNT ON;
 --	declare @user varchar(max)
	--set @user='vha21\vhapalsohonp' 
 
	SELECT 
		a.LCustomerID
		,a.ADDomain
		,a.ADLogin
		,ISNULL(b.InferredVISN ,a.InferredVISN) as InferredVISN 
		,ISNULL(b.Sta6aID,a.InferredSta3n) as InferredSta3n
		,ISNULL(b.ChecklistID,a.InferredSta3n) as InferredChecklistID
		,[PHASER_status]
      ,[Randomization]
	  ,SUBSTRING(a.ADLogin,4,3)
	FROM [LCustomer].[LCustomer] a WITH (NOLOCK)
	LEFT JOIN  [Config].[InferredSta6AID] b WITH (NOLOCK) ON SUBSTRING(a.ADLogin,4,3) = b.LocationIndicator
	left join [Config].[ORM_PgX_Randomization] as c on c.Sta3n = InferredSta3n 
	WHERE a.ADDomain = SUBSTRING(@User,1,PATINDEX('%\%',@User)-1)
		AND a.ADLogin = SUBSTRING(@User,PATINDEX('%\%',@User)+1,99)
	;

	--select * from [OMHSP_PERC_CDSDev].[Config].[ORM_PgX_Randomization] 

END