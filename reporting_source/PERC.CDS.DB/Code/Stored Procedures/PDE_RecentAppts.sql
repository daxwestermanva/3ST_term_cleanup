
/*=============================================
-- Author:		Rebecca Stephens (RAS)
-- Create date: 2017-10-25
-- Description:	This code prepares visit data for the PDE subreport PatientAppts 
-- Updates:
--	2019-02-16	Jason Bacani - Refactored to use [Maintenance].[PublishTable]; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
  =============================================*/
CREATE PROCEDURE [Code].[PDE_RecentAppts]
AS
BEGIN

	EXEC [Log].[ExecutionBegin] @Name = 'Code.PDE_RecentAppts', @Description = 'Execution of Code.PDE_RecentAppts SP'

	DROP TABLE IF EXISTS #staging;
	SELECT * 
	INTO #staging
	FROM (
		SELECT DISTINCT MVIPersonSID,DisDay
			,Cl,Clc,ClName,ClcName
			,VisitDateTime,FollowUpDays,convert(date,VisitDateTime) as VisitDate
			,ProviderName,ProviderType
			,WorkloadLogicFlag
			,RN=DENSE_RANK() Over(Partition By MVIPersonSID,DisDay order by cast(VisitDateTime as date) desc)
		FROM [PDE_Daily].[PDE_FollowUpMHVisits]
		--where census=0 and Followup=1 
	  ) as a 
	WHERE RN<=5

	EXEC [Maintenance].[PublishTable] '[PDE_Daily].[RecentAppts]', '#staging'

	EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END
GO
