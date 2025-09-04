-- =============================================
-- Author:		Sohoni, Pooja
-- Create date: 2018-08-06
-- Description:	Stored Procedure to power the STORM Definitions report for Risk Mitigation strategies
-- EXEC [App].[ORM_Definitions_RiskMitigation] '7'
-- =============================================
CREATE PROCEDURE [App].[ORM_Definitions_RiskMitigation] 

	@VariableName NUMERIC

AS
BEGIN

SET NOCOUNT ON;

SELECT
   RiskMitigationStrategy
  ,MeasureName
  ,MeasureNameClean
  ,MeasureID
  ,Description
  ,Rationale
  ,CheckBoxRules
  ,DataSource
  ,Codes
  ,NumeratorCohort
  ,DenominatorCohort
  ,ActionableCohort
  ,Exclusion
  ,DiagnosisCohort
  ,MedicationCohort
  ,CPTCohort
  ,LabCohort
  ,StopcodeCohort
  ,ICD10ProcedureCohort
  ,ExclusionDiagnosisCohort
  ,ExclusionMedicationCohort
  ,ExclusionCPTCohort
  ,ExclusionStopcodeCohort
  ,UpdateFrequency
  ,TimePeriod
  ,ScoreDirection
  ,Notes
  ,Category
FROM [ORM].[MeasureDetails]
WHERE MeasureID in (@VariableName)

END