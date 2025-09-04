



-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	3/18/2025
-- Description:	To be used as Fact source in BHIP Care Coordination Power BI report.
--				Adapted from [App].[BHIP_Risk_PBI]
--
--
--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 3/27/2025 - CW - Removing unnecessary fields
-- 7/9/2025  - CW - Adding TestPatients from central table
--
-- =======================================================================================================

CREATE VIEW [App].[BHIPRisk_PBI] AS

	WITH RiskFactors AS (
		select distinct MVIPersonSID 
			,RiskFactor
			,ChecklistID
			,Facility
			,EventValue
			,EventDate
			,LastBHIPContact
			,Actionable
			,OverdueFlag
			,ActionExpected
			,ActionLabel
			,Code
			,TobaccoPositiveScreen
		from BHIP.RiskFactors WITH(NOLOCK)

		UNION

		SELECT MVIPersonSID
			,BHIPRiskFactor
			,CheckListID
			,Facility
			,BHIPEventValue
			,BHIPEventDate
			,LastBHIPContact
			,BHIPActionable
			,BHIPOverdueFlag
			,BHIPActionExpected
			,BHIPActionLabel
			,Code
			,BHIPTobaccoPositiveScreen
		FROM App.PBIReports_TestPatients WITH(NOLOCK)
	)
	SELECT distinct MVIPersonSID
		,Actionable
		,ActionExpected
		,EventDate
		,EventValue
		,RiskFactor
		,TobaccoPositiveScreen
		,ChecklistID
		,Code
		,Facility
		,ActionExpected_Sort=
			CASE WHEN ActionExpected='Assign to BHIP team' THEN 1
				 WHEN ActionExpected='MH Team' THEN 2
				 WHEN ActionExpected='Potential Screening Need' THEN 3
				 WHEN ActionExpected='Order lab' THEN 4
				 WHEN ActionExpected='Case Review' THEN 5
				 WHEN ActionExpected='Informational' THEN 6
				 WHEN ActionExpected='Consider scheduling MH appointment' THEN 7
				 WHEN ActionExpected='Assess/counsel on medication adherence' THEN 8
				 WHEN ActionExpected='No Action' THEN 9
				 END
		,QuickViewDisplay=
			CASE WHEN ActionExpected='Potential Screening Need' THEN 1
				 WHEN EventValue LIKE '%Low%' OR EventValue LIKE '%Negative%' THEN 0
				 WHEN Actionable = -5 THEN 0
				 ELSE 1 END
	FROM RiskFactors;