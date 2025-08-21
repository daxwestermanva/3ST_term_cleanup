
-- =============================================
-- Author:		Amy Furman 
-- Create date: 4/15/2014
-- Description:	DataSet for Diagnosis Crosswalk
-- =============================================
CREATE PROCEDURE [App].[Definitions_StopCodes]
	-- Add the parameters for the stored procedure here
	@AppointmentType varchar(max)
 -- @Column varchar(1000)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
 

	--	DECLARE @AppointmentType VARCHAR(1000) =  'ClinRelevant_Stop,MHOC_MentalHealth_Stop'

SELECT DISTINCT 
	Stopcode
	,StopCodeName
	,AppointmentType
	,PrintName
FROM (
	SELECT *
	FROM [LookUp].[StopCode]
	-- where ClinRelevantRecent_Stop=1 or PCRecent_Stop=1 or MHOC_MentalHealth_Stop=1 
   ) p
UNPIVOT (Flag FOR AppointmentType IN (
	SUDTx_NoDxReq_Stop,
	SUDTx_DxReq_Stop,
	RM_PhysicalTherapy_Stop,
	RM_ChiropracticCare_Stop,
	RM_ActiveTherapies_Stop,
	RM_OccupationalTherapy_Stop,
	RM_SpecialtyTherapy_Stop,
	RM_OtherTherapy_Stop,
	RM_PainClinic_Stop,
	Rx_MedManagement_Stop,
	OUDTx_DxReq_Stop,
	ORM_TimelyAppt_Stop,
	Hospice_Stop,
	MHOC_Homeless_Stop,
	EmergencyRoom_Stop,
	Reach_EmergencyRoom_Stop,
	Reach_MH_Stop,
	Incarcerated_Stop,
	Justice_Outreach_Stop,
	Any_Stop,
	ClinRelevant_Stop,
	PC_Stop,
	Pain_Stop,
	MHOC_MentalHealth_Stop,
	Other_Stop,
	Reach_Homeless_Stop,
	ORM_CIH_Stop,
	ORM_OS_Education_Stop,
	GeneralMentalHealth_Stop,
	PrimaryCare_PDSI_Stop,
	PeerSupport_Stop)
	) AS unpvt
INNER JOIN [LookUp].[ColumnDescriptions] cd on unpvt.AppointmentType = cd.ColumnName
WHERE Flag= 1 
	AND AppointmentType IN (SELECT value FROM string_split(@AppointmentType ,','))

END