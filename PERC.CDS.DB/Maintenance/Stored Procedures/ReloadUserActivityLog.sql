

CREATE PROCEDURE [Maintenance].[ReloadUserActivityLog] as

DECLARE @FirstDayOfMonth datetime = '2014-01-01 00:00:00.000'

DELETE FROM [App].[UserActivityLog]

INSERT INTO [App].[UserActivityLog] (UserName, ReportID, ReportName, TimeStart, VISN, [YEAR], ReportFileName, [MONTH], MMM, Count_Displays, RecType, ReportAction)
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

INSERT INTO [App].[UserActivityLog] (ReportID, ReportName, VISN, [YEAR], ReportFileName, [MONTH], MMM, ReportAction, Count_Displays, CountUniqueUsers, RecType)
SELECT ReportID, ReportName, VISN, [YEAR], ReportFileName, [MONTH], MMM, ReportAction, Sum(Count_Displays) as Count_Displays, Count(*) as CountUniqueUsers, 'M' as RecType
FROM (
	Select UserName, ReportID, ReportName, VISN, [YEAR], ReportFileName, [MONTH], MMM, ReportAction, Sum(Count_Displays) as Count_Displays
	from [App].[UserActivityLog] 
	Where TimeStart > @FirstDayOfMonth
	Group by UserName, ReportID, ReportName, VISN, [YEAR], ReportFileName, [MONTH], MMM, ReportAction
) a
GROUP BY ReportID, ReportName, VISN, [YEAR], ReportFileName, [MONTH], MMM, ReportAction

INSERT INTO [App].[UserActivityLog] (ReportID, ReportName, [YEAR], ReportFileName, [MONTH], MMM, ReportAction, Count_Displays, CountUniqueUsers, RecType, VISN)
SELECT ReportID, ReportName, [YEAR], ReportFileName, [MONTH], MMM, ReportAction, Sum(Count_Displays) as Count_Displays, Sum(CountUniqueUsers) as CountUniqueUsers, 'M' as RecType, 'NTNL' as VISN
FROM [App].[UserActivityLog]
WHERE RecType = 'M' 
GROUP BY ReportID, ReportName, [YEAR], ReportFileName, [MONTH], MMM, ReportAction

INSERT INTO [App].[UserActivityLog] (ReportID, ReportName, VISN, [YEAR], ReportFileName, ReportAction, Count_Displays, CountUniqueUsers, [MONTH], MMM, RecType)
SELECT ReportID, ReportName, VISN, [YEAR], ReportFileName, ReportAction, Sum(Count_Displays) as Count_Displays, Sum(CountUniqueUsers) as CountUniqueUsers, 0 as [MONTH], 'YTD' as MMM, 'Y' as RecType
FROM [App].[UserActivityLog] 
WHERE RecType = 'M' and VISN <> 'NTNL'
GROUP BY ReportID, ReportName, VISN, [YEAR], ReportFileName, ReportAction

INSERT INTO App.[UserActivityLog] (ReportID, ReportName, [YEAR], ReportFileName, ReportAction, Count_Displays, CountUniqueUsers, [MONTH], MMM, RecType, VISN)
SELECT ReportID, ReportName, [YEAR], ReportFileName, ReportAction, Sum(Count_Displays) as Count_Displays, Sum(CountUniqueUsers) as CountUniqueUsers, 0 as [MONTH], 'YTD' as MMM, 'Y' as RecType, 'NTNL' as VISN
FROM [App].[UserActivityLog] 
WHERE RecType = 'Y' 
GROUP BY ReportID, ReportName, [YEAR], ReportFileName, ReportAction