
-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	5/18/2023
-- Description:	Dataset for information related to screening, evaluation and care engagement 
--				in the Suicide Behavior and Overdose Summary Report. 
--				Data source: [Code].[SBOSR_ScreenEngage_PBI]
--
--				No row duplication expected in this dataset.		
--				
-- Modifications:
-- 5/17/24 - CW - Adding DBRR information into dataset (added into [Code].[SBOSR_ScreenEngage_PBI])
-- 1/15/25 - CW - Adding most recent ED to dataset
-- =======================================================================================================
CREATE PROCEDURE [App].[SBOSR_ScreenEngage_PBI]

AS
BEGIN
	
SET NOCOUNT ON;

	SELECT s.*, ed.EDRecentAppt
	FROM [SBOSR].[ScreenEngage_PBI] s
	LEFT JOIN ( SELECT MVIPersonSID, EDRecentAppt=VisitDateTime
				FROM Present.AppointmentsPast
				WHERE ApptCategory='EDRecent'
				AND MostRecent_ICN=1
			  ) ed
		ON s.MVIPersonSID=ed.MVIPersonSID

END