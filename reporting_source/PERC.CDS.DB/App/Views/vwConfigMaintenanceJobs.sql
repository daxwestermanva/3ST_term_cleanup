
CREATE VIEW [App].[vwConfigMaintenanceJobs]
AS  
--2022/06/29 - JEB	- Explicit defined view 
SELECT mj.[Schedule]
      ,mj.[Project]
      ,mj.[SpName]
      ,mj.[Sequence]
      ,mj.[StopOnFailure]
      ,mj.[Comments]
FROM [Config].[Maintenance_Jobs] mj WITH (NOLOCK)