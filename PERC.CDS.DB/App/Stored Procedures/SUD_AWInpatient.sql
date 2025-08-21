
-- =============================================
-- Author: Elena Cherkasova
-- Create date: 12/5/24
-- Description: Main Data Set for SUD AW Inpatient report
-- Updates
-- =============================================
/*  
	EXEC [App].[SUD_AWInpatient]
	@FYQ = 'FY24Q4',
	@Facility = '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,358,402,405,518,523,640,21,358,459,570,593,612A4,603,614,621,626,640,654,662'

*/
-- =============================================
CREATE PROCEDURE [App].[SUD_AWInpatient] 
	@Facility VARCHAR(MAX),
	@FYQ VARCHAR(MAX)	

AS
BEGIN	
SET NOCOUNT ON

DECLARE @FYQList TABLE (FYQ VARCHAR(MAX))
DECLARE @FacilityList TABLE (Facility VARCHAR(MAX))

INSERT @FYQList	SELECT value FROM string_split(@FYQ, ',')
INSERT @FacilityList	SELECT value FROM string_split(@Facility, ',')

	--TO TEST FOR ALL STATIONS:
	-- RUN STARTING WITH THE DECLARE STATEMENTS BELOW (IGNORE THE ONES ABOVE)
	/*

	DECLARE @FYQList TABLE (FYQ VARCHAR(MAX))
	DECLARE @FacilityList TABLE (Facility VARCHAR(MAX))

	INSERT @FYQList	
		SELECT MAX(FYQ) FROM [SUD].[AW_Inpatient_Metrics]

	INSERT @FacilityList	
		SELECT DISTINCT Facility FROM [SUD].[AW_Inpatient_Metrics]

--	*/

SELECT a.[VISN]
      ,a.[Facility]
      ,a.[FacilityName]
      ,a.[IOCDate]
	  ,a.[MCGName]
	  ,a.[FYQ]
      ,[FYQlabel] = CASE WHEN a.FYQ LIKE 'YTD%' THEN CONCAT('YTD-',RIGHT(a.FYQ,6))
						ELSE CONCAT(a.FYQ,' ONLY') END
      ,a.[Inpatients]
      ,a.[InpDischarges]
      ,a.[AWinpatients]
      ,a.[AWdischarges]
      ,a.[AWdischarges_percent]
      ,a.[AverageLOS]
      ,a.[InpatientDeaths]
      ,a.[AMAdischarges]
      ,a.[AMADisch_percent]
      ,a.[Readmissions]
      ,a.[Readmission_Denominator]
      ,a.[Readmission_Denominator_AMA]
      ,a.[ReadmissionRate]
      ,a.[ReadmissionRate_AMA]
      ,a.[Delirium]
      ,a.[Delirium_percent]
      ,a.[Seizure]
      ,a.[Seizure_percent]
      ,a.[AUDITC]
      ,a.[AUDITC_percent]
      ,a.[AUD_RX]
      ,a.[AUDrx_percent]
      ,a.[Clonidine]
      ,a.[Clonidine_percent]
      ,a.[Chlordiazepoxide]
      ,a.[Chlordiazepoxide_percent]
      ,a.[Diazepam]
      ,a.[Diazepam_percent]
      ,a.[Gabapentin]
      ,a.[Gabapentin_percent]
      ,a.[Lorazepam]
      ,a.[Lorazepam_percent]
      ,a.[Phenobarbital]
      ,a.[Phenobarbital_percent]
      ,a.[ICUadmissions]
      ,a.[ICUadmissions_percent]
      ,a.[ICUtransfer]
      ,a.[ICUtransfer_percent]
      ,a.[SUD_RRTP7]
      ,a.[SUD_RRTP7_percent]
  FROM [SUD].[AW_Inpatient_Metrics] as a WITH (NOLOCK)
		INNER JOIN [LookUp].[ChecklistID] as cl WITH (NOLOCK) ON a.Facility = cl.STA6AID
		INNER JOIN @FYQList AS q ON q.FYQ = a.FYQ
		INNER JOIN @FacilityList AS f ON f.Facility = a.Facility
			-- The above join works and is easier for the testing that was added for all stations
			-- but if the report is ever changed to a multi-value parameter, then the data type will
			-- need to be changed in multiple places
	ORDER BY  cl.ADMPSortKey, a.FYQ DESC

END