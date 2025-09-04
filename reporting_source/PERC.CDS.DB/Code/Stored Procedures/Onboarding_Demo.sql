
-- =============================================
-- Author:		Elena Cherkasova
-- Create date: 1/26/20
-- Description:	Code to demo cworking in TFS
-- Updates
--	
-- =============================================

CREATE PROCEDURE [Code].[Onboarding_Demo]
AS
BEGIN
	SET NOCOUNT ON; 
--TESTING 1-2 TESTING 1-2 DOES EDITING THIS CODE IN THE DEVOPS REPO SAVE IT TO TFVC????

DROP TABLE IF EXISTS #TEMP;
SELECT [DateSID]
      ,[Date]
      ,[DateText]
      ,[DayName]
      ,[MonthName]
	  ,[DayofMonth]
      ,[MonthOfYear]
      ,[CalendarYear]
      ,[FiscalYear]
      ,[FederalHoliday]
	  ,[DaysLeftInFiscalYear]
	  ,[IsWeekend]
  INTO #TEMP
  FROM [Dim].[Date]
  WHERE CalendarYear='2023' and FederalHolidayFlag like 'Y'
  ORDER BY DaysLeftInYear DESC

  EXEC [Maintenance].[PublishTable] 'CDS.Onboarding_Demo','#TEMP'

  END