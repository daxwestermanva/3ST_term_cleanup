
-- =============================================
-- Author: Elena Cherkasova
-- Create date: 10/27/2022
-- Description: Data Set for the PDE_PatientReport Provider parameter
-- =============================================
-- EXEC [App].[p_PDE_Provider] @Facility = '640', @FacilityType='1,2,3', @census='0,1', @ProviderType='1'
-- =============================================
CREATE PROCEDURE [App].[p_PDE_Provider]  

 @Facility NVARCHAR(15) 
,@FacilityType varchar(50)
,@census varchar(12)
,@ProviderType varchar(50)

AS
BEGIN	
SET NOCOUNT ON

SELECT DISTINCT a.label
	,a.ProviderValue AS value
	,a.ProviderType
	,a.ProviderTypeID
FROM (
	SELECT DISTINCT StaffName_MHTC as label
		,ProviderSID_MHTC as ProviderValue
		,ProviderType = 'MHTC'
		,ProviderTypeID = '1'
		,Census=CASE WHEN pde1.DischargeDateTime IS NULL OR pde1.DischargeDateTime>GETDATE() THEN 0
		WHEN DATEDIFF(DAY,pde1.DischargeDateTime,GETDATE()) > 60 THEN 3
		WHEN DATEDIFF(DAY,pde1.DischargeDateTime,GETDATE()) > 30 THEN 2
		WHEN pde1.DischargeDateTime<= GETDATE() THEN 1
		END
	FROM [PDE_Daily].[PDE_PatientLevel] as pde1
		WHERE Exclusion30=0
		AND ((@Facility=ChecklistID_Metric	AND '1' IN (SELECT value FROM string_split(@FacilityType ,',')))
			OR (@Facility=ChecklistID_Discharge AND '2' IN (SELECT value FROM string_split(@FacilityType ,',')))
			OR (@Facility=ChecklistID_Home		AND '3' IN (SELECT value FROM string_split(@FacilityType ,','))))

	UNION

	SELECT DISTINCT TeamName_BHIP as label
		,TeamSID_BHIP as ProviderValue
		,ProviderType = 'BHIP'
		,ProviderTypeID = '2'
		,Census=CASE WHEN pde.DischargeDateTime IS NULL OR pde.DischargeDateTime>GETDATE() THEN 0
		WHEN DATEDIFF(DAY,pde.DischargeDateTime,GETDATE()) > 60 THEN 3
		WHEN DATEDIFF(DAY,pde.DischargeDateTime,GETDATE()) > 30 THEN 2
		WHEN pde.DischargeDateTime<= GETDATE() THEN 1
		END
	FROM [PDE_Daily].[PDE_PatientLevel] as pde
		WHERE Exclusion30=0
		AND (
		(@Facility=ChecklistID_Metric	AND '1' IN (SELECT value FROM string_split(@FacilityType ,',')))
				OR (@Facility=ChecklistID_Discharge AND '2' IN (SELECT value FROM string_split(@FacilityType ,',')))
				OR (@Facility=ChecklistID_Home		AND '3' IN (SELECT value FROM string_split(@FacilityType ,',')))
				)
					) a
WHERE a.Census IN (SELECT value FROM string_split(@census ,','))
AND (ProviderTypeID = @ProviderType)
ORDER BY label

END

/*
	SELECT DISTINCT StaffName_MHTC as label
		,ProviderSID_MHTC as value
		,ProviderType = 'MHTC'
		,ProviderTypeID = '1'
		,Census=CASE WHEN pde1.DischargeDateTime IS NULL OR pde1.DischargeDateTime>GETDATE() THEN 0
		WHEN DATEDIFF(DAY,pde1.DischargeDateTime,GETDATE()) > 60 THEN 3
		WHEN DATEDIFF(DAY,pde1.DischargeDateTime,GETDATE()) > 30 THEN 2
		WHEN pde1.DischargeDateTime<= GETDATE() THEN 1
		END
	FROM [PDE_Daily].[PDE_PatientLevel] as pde1
		WHERE Exclusion30=0
		AND ((ChecklistID_Metric	like '640')
			OR (ChecklistID_Discharge like '640')
			OR (ChecklistID_Home like '640'))


			select * 	
			FROM [PDE_Daily].[PDE_PatientLevel] as pde1
		WHERE Exclusion30=0 and StaffName_MHTC like'ARMON,SHERMANIA DENISE'
		*/