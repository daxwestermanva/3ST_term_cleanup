

CREATE VIEW [Present].[OutpatVisit_2Year]
AS
/************************************************************************************
UPDATES:
	2021-09-17	JEB	Enclave Refactoring
	2021-09-23	JEB Enclave Refactoring - Removed use of Partition ID
************************************************************************************/

	/*Outpatient encounter in past 2yrs*/
    SELECT 
		mvi.MVIPersonSID
		,pat.PatientICN
		,v.PatientSID
		,ISNULL	(
					sta.ChecklistID
					,CASE 
						WHEN v.STA3N IN (612) THEN CAST(v.Sta3n AS VARCHAR)+'A4' 
						ELSE CAST(v.Sta3n AS VARCHAR) 
					END
				) AS ChecklistID
		,v.VisitDateTime
		,v.VisitSID
	FROM [Outpat].[Visit] v WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON v.PatientSID = mvi.PatientPersonSID 
	INNER JOIN [Dim].[AppointmentStatus] sts WITH (NOLOCK) ON v.appointmentstatusSID = sts.appointmentstatusSID
	INNER JOIN [Patient].[Patient] pat WITH (NOLOCK) ON v.PatientSID = pat.PatientSID AND pat.Sta3n = v.Sta3n
	LEFT JOIN [Dim].[Division] div WITH (NOLOCK) ON div.DivisionSID = v.DivisionSID
	LEFT JOIN [LookUp].[Sta6a] sta WITH (NOLOCK) ON sta.Sta6a = div.Sta6a
	WHERE sts.AppointmentStatusAbbreviation IN ('CO','CI','PEND','X')
		AND v.VisitDateTime BETWEEN DATEADD(YY,-2,CAST(GETDATE() AS DATE)) AND CAST(GETDATE() AS DATE) 
		AND v.WorkloadLogicFlag = 'Y'