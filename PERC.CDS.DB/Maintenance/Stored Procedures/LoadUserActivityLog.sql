
CREATE PROCEDURE [Maintenance].[LoadUserActivityLog] as
-- Modifications:
--	2022/07/08	JEB Updated Synonym references to point to Synonyms from Core
--	2022/07/11	JEB Updated more Synonym references to point to Synonyms from Core (missed some)

declare @FirstDayOfMonth datetime = DATEADD(mm, DATEDIFF(mm,0,GetDate()), 0)

DELETE FROM [App].[UserActivityLog]
WHERE TimeStart > @FirstDayOfMonth

INSERT INTO [App].[UserActivityLog] (
	 UserName
	,ReportID
	,ReportName
	,TimeStart
	,VISN
	,[YEAR]
	,ReportFileName
	,[MONTH]
	,MMM,Count_Displays
	,RecType
	,ReportAction	)
SELECT el.[UserName]
	  ,rl.ReportKey AS ReportID
	  ,CASE WHEN rl.ReportFileName like '%HRF%' THEN 'HRF'
		WHEN rl.ReportFileName like '%SPPRITE%' THEN 'SPPRITE'
		WHEN rl.ReportPath like '%RV' THEN 'REACH VET'
		ELSE SubString(rl.ReportPath,36,15)
		END AS ReportName
	  ,el.TimeStart
	  ,CAST(LEFT(el.UserName, CHARINDEX('\', el.UserName) - 1) AS VARCHAR) AS VISN
	  ,Year(el.TimeStart) as [YEAR]
	  ,rl.ReportFileName
	  ,Month(el.TimeStart) as [MONTH]
	  ,FORMAT(el.TimeStart,'MMM') as MMM
	  ,1 as [Count_Displays]
	  ,'U' as RecType
	  ,el.ReportAction
FROM [PDW].[BISL_SSRSLog_DOEx_ExecutionLog] el
INNER JOIN [PDW].[BISL_SSRSLog_DOEx_Reports] rl ON el.ReportKey = rl.ReportKey
WHERE el.TimeStart > @FirstDayOfMonth
	AND el.ReportAction in ('Render','DrillThrough','Execute')
	AND el.VISN NOT IN ('DVA','VHAMASTER')
	AND [UserName] not like 'DVA\%'
	AND [UserName] not like 'VHAMASTER\%'
	AND rl.[ReportPath] IN ('RVS/OMHSP_PERC/SSRS/Production/CDS/CRISTAL'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/Definitions'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/EBP'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/PDE'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/PDSI'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/Pharm' 
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/RV'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/SMI'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/SP'
	,'RVS/OMHSP_PERC/SSRS/Production/CDS/STORM'
	)

DELETE FROM [App].[UserActivityLog]
WHERE RecType = 'M'
	AND [YEAR] = Year(GetDate()) 
	AND [Month] = Month(GetDate())

INSERT INTO [App].[UserActivityLog] (
	 ReportID
	,ReportName
	,VISN
	,[YEAR]
	,ReportFileName
	,[MONTH]
	,MMM
	,ReportAction
	,Count_Displays
	,CountUniqueUsers
	,RecType	)
SELECT ReportID
	  ,ReportName
	  ,VISN
	  ,[YEAR]
	  ,ReportFileName
	  ,[MONTH]
	  ,MMM
	  ,ReportAction
	  ,Sum(Count_Displays) as Count_Displays
	  ,Count(*) as CountUniqueUsers, 'M' as RecType
FROM (
	SELECT UserName, ReportID, ReportName, VISN, [YEAR], ReportFileName, [MONTH], MMM, ReportAction
		  ,Sum(Count_Displays) as Count_Displays
	FROM [App].[UserActivityLog] 
	WHERE TimeStart > @FirstDayOfMonth
	GROUP BY UserName, ReportID, ReportName, VISN, [YEAR], ReportFileName, [MONTH], MMM, ReportAction
	) a
GROUP BY ReportID, ReportName, VISN, [YEAR], ReportFileName, [MONTH], MMM, ReportAction

INSERT INTO [App].[UserActivityLog] (ReportID, ReportName, [YEAR], ReportFileName, [MONTH], MMM, ReportAction, Count_Displays, CountUniqueUsers, RecType, VISN)
SELECT ReportID
	  ,ReportName
	  ,[YEAR]
	  ,ReportFileName
	  ,[MONTH]
	  ,MMM
	  ,ReportAction
	  ,Sum(Count_Displays) as Count_Displays
	  ,Sum(CountUniqueUsers) as CountUniqueUsers
	  ,'M' as RecType
	  ,'NTNL' as VISN
FROM [App].[UserActivityLog] 
WHERE RecType = 'M' 
	AND [YEAR] = Year(GetDate()) 
	AND [Month] = Month(GetDate())
GROUP BY ReportID, ReportName, [YEAR], ReportFileName, [MONTH], MMM, ReportAction

DELETE FROM [App].[UserActivityLog]
WHERE RecType = 'Y'
	AND [YEAR] = Year(GetDate()) 

INSERT INTO [App].[UserActivityLog] (ReportID, ReportName, VISN, [YEAR], ReportFileName, ReportAction, Count_Displays, CountUniqueUsers, [MONTH], MMM, RecType)
SELECT ReportID
	  ,ReportName
	  ,VISN
	  ,[YEAR]
	  ,ReportFileName
	  ,ReportAction
	  ,Sum(Count_Displays) as Count_Displays
	  ,Sum(CountUniqueUsers) as CountUniqueUsers, 0 as [MONTH]
	  ,'YTD' as MMM
	  ,'Y' as RecType
FROM [App].[UserActivityLog] 
WHERE RecType = 'M' and VISN <> 'NTNL'
GROUP BY ReportID, ReportName, VISN, [YEAR], ReportFileName, ReportAction

INSERT INTO App.[UserActivityLog] (ReportID, ReportName, [YEAR], ReportFileName, ReportAction, Count_Displays, CountUniqueUsers, [MONTH], MMM, RecType, VISN)
SELECT ReportID, ReportName, [YEAR], ReportFileName, ReportAction, Sum(Count_Displays) as Count_Displays, Sum(CountUniqueUsers) as CountUniqueUsers, 0 as [MONTH], 'YTD' as MMM, 'Y' as RecType, 'NTNL' as VISN
FROM [App].[UserActivityLog] 
WHERE RecType = 'Y' 
	AND [YEAR] = Year(GetDate()) 
GROUP BY ReportID, ReportName, [YEAR], ReportFileName, ReportAction