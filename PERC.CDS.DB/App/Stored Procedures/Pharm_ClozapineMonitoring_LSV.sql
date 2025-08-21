
/********************************************************************************************************************
DESCRIPTION: Main report procedure for clozapine report
TEST:
	EXEC [App].[Pharm_ClozapineMonitoring_LSV] @checklistID='640', @user='vha21\vhapalmartins'
UPDATE:
	2019-08-19	RAS	Created procedure for clozapine report
	2019-09-03	SG	removed direct database references to OMHSP_PERC_CDSDev and changing drugnamewithdose to drugnamewithoutdose
	2019-12-16	SM	switched sta3n for ChecklistID to meet integrated VISN requirements
	2020-12-15	RAS	Removed join to StationAssignments.  Not needed because the display station is the ChecklistID in the source table.

********************************************************************************************************************/
CREATE PROCEDURE [App].[Pharm_ClozapineMonitoring_LSV]

  @ChecklistID varchar(max),
  @User varchar(100)

AS
BEGIN
SET NOCOUNT ON

-- create a table with the values from the parameter
  -- Declare the table variable with one column "Facility"
  DECLARE @FacilityList TABLE (Facility VARCHAR(5))
  -- Add values to the table
  INSERT @FacilityList SELECT value FROM string_split(@ChecklistID, ',')

/****** Script for SelectTopNRows command from SSMS  ******/
SELECT a.[ChecklistID]
      ,a.[MVIPersonSID]
	  ,a.[DrugNameWithoutDose]
	  ,CASE WHEN a.[Inpatient]=1 THEN 'Inpatient'
			WHEN a.[OutPat_Rx]=1 THEN 'OutPat_Rx'
			WHEN a.[CPRS_Order]=1 THEN 'CPRS_Order'
			ELSE NULL
			END as MedSource
      ,a.[max_ReleaseDateTime]
      ,a.[DaysSupply]
      ,a.[PillsOnHand]
      ,a.[DateSinceLastPillsHand]
      ,a.[MostRecentANC_D&T]
      ,a.[ANC_Value]
	  ,CASE WHEN a.[ANC_Value] <2.0 THEN 1 ELSE 0 END as [ANC_LowerLimit]
      ,a.[ANC_Units]
      ,a.[Calc_value_used]
	  ,a.[<30d_LowestPrev_LabChemSpecDateTime]
	  ,a.[<30d_LowestPrev_ANC_Value]
	  ,a.[Previous_ANC_Units]
	  ,a.[Prev_Calc_value_used]
      ,a.[MostRecentClozapine_D&T]
      ,a.[Clozapine_Lvl]
      ,a.[Cloz_Units]
      ,a.[MostRecentNorclozapine_D&T]
      ,a.[Norclozapine_Lvl]
      ,a.[Nor_Units]
      ,a.[VisitDateTime]
      ,a.[Prescriber]
	  ,a.[NPI]
      ,a.[Visit_Location]
	  ,a.[VisitStaff]
      ,mp.[PatientName]
      ,mp.[PatientSSN]
	  ,mp.[Age]
	  ,mp.[SourceEHR]
  FROM [Pharm].[ClozapineMonitoring] a
  INNER JOIN [Common].[MasterPatient] as mp on a.MVIPersonSID=mp.MVIPersonSID
  INNER JOIN (SELECT Sta3n from [App].[Access] (@User)) as f on f.sta3n = left(a.ChecklistID,3) 
  INNER JOIN @FacilityList sta on sta.Facility=a.ChecklistID


END