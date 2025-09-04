
/********************************************************************************************************************
-- Author:		Liam Mina
-- Create date: 2023-11-15
-- Description:	Full reload of data in procedures where nightly run only updates recent records

-- Updates:
-- 
********************************************************************************************************************/

CREATE PROCEDURE [Code].[Maintenance_WeeklyFullReload] 
AS
BEGIN

	--Two years of data; nightly run updates past 3 months
	EXEC [Code].[OMHSP_Standard_MentalHealthAssistant_v02] @InitialBuild = 1
	;
	--Data since 2018; nightly run updates past year
	EXEC [Code].[OMHSP_Standard_HealthFactorSuicPrev] @InitialBuild = 1
	;
	--Data since 2019; nightly run updates past year
	EXEC [Code].[OMHSP_Standard_SBOR] @InitialBuild = 1
	;
	--Data since 2018; nightly run updates past year
	--EXEC [Code].[OMHSP_Standard_CSRE] @InitialBuild = 1


END;