

CREATE VIEW [App].[vwOutpatWorkload_StatusShowed]
AS  
SELECT 
--------------------------------------------------------------------------------------------------------------------------------------------
--2021/08/06	JB Enclave Work - Converted new view with vw naming convention, also using A01 naming convention from source objects
--------------------------------------------------------------------------------------------------------------------------------------------
	   wk.VisitSID
	  ,wk.MVIPersonSID
	  ,wk.PatientSID
	  ,wk.Sta3n
	  ,wk.VisitDateTime
	  ,wk.EncounterDateTime
	  ,wk.LastModifiedDateTime
	  ,wk.InstitutionSID
	  ,wk.DivisionSID
	  ,wk.EncounterDivisionSID
	  ,wk.LocationSID
	  ,wk.PrimaryStopCodeSID
	  ,wk.SecondaryStopCodeSID
	  ,wk.AppointmentStatusSID
	  ,wk.County
	  ,wk.ServiceConnectedFlag
	  ,ap.AppointmentStatusAbbreviation
FROM [App].[vwCDW_Outpat_Workload] wk WITH (NOLOCK)
INNER JOIN [Dim].[AppointmentStatus] ap WITH (NOLOCK)
	ON wk.AppointmentStatusSID = ap.AppointmentStatusSID
WHERE ap.AppointmentStatusAbbreviation IN ('CO','CI','PEND','X','I')