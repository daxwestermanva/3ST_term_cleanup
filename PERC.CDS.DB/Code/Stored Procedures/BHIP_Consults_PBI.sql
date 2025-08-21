-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	3/18/2025
-- Description:	To be used as Fact source in BHIP Care Coordination Power BI report.
--				Adapted from [App].[BHIP_Consults_PBI]

--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 7/29/2025  CW  Ensuring there are no TestPatients in dataset
--
--
-- =======================================================================================================

CREATE PROCEDURE [Code].[BHIP_Consults_PBI]

AS
BEGIN
	SET NOCOUNT ON;


	drop table if exists #consult
	select *
	into #consult
	from (
		select distinct a.* 
			,max(RequestDateTime) over (partition by a.patientsid) as MaxConsultDate
			,MVIPersonSID
		,ServiceName as ToRequestServiceName
		,OrderStatus as CPRSStatus  
		from Con.Consult a WITH (NOLOCK)
		inner join Common.MVIPersonSIDPatientPersonSID as b WITH (NOLOCK) on a.Patientsid = b.PatientPersonSID
	  inner join Dim.RequestService as r WITH (NOLOCK) on r.RequestServiceSID = a.ToRequestServiceSID
	 inner join  Dim.OrderStatus as o WITH (NOLOCK) on a.OrderStatusSID = o.OrderStatusSID
	  where (ServiceName like '%BHIP%' or ServiceName like '%BEHAVIORAL HEALTH INTERDISCIPLINARY PROGRAM%')
				and requestdatetime > DATEADD(month,-6,getdate())
		) as a
	where MaxConsultdate = RequestDateTime


	drop table if exists #consult2
	select distinct b.* 
		,ConsultActivityComment
		,ActivityDateTime
	into #consult2
	from Con.consultfactor as c 
	inner join #consult as b on c.consultSID = b.consultSID
	inner join SPatient.SConsultActivityComment_Recent as a WITH (NOLOCK) on c.SConsultActivityCommentSID = a.SConsultActivityCommentSID 


	--Get MH or PC appointments (PCMHI falls within PC) in relation to consults to figure out who needs f/u appt (ActionFollowUp)
	drop table if exists #Final
	select distinct a.MVIPersonSID
		,ToRequestServiceName
		,RequestDateTime=cast(RequestDateTime as date)
		,CPRSStatus
		,l.Facility
		,ProvisionalDiagnosis
		,ConsultActivityComment
		,ActivityDateTime=cast(ActivityDateTime as date)
		,case when MHP.patientsid is null and MHF.patientsid is null and PCP.patientsid is null and PCF.patientsid is null then 'Follow Up Appointment' --F/U appt is needed
			end as ActionFollowUp
		,b.Team
		,l.ChecklistID
		,mp.PatientName
		,DateofBirth=cast(mp.DateofBirth as date)
		,mp.LastFour
	into #Final
	from #consult2 as a
	inner join Lookup.Checklistid as l WITH (NOLOCK) on a.sta3n = l.sta3n 
	inner join common.masterpatient as mp WITH (NOLOCK) on a.mvipersonsid = mp.MVIPersonSID and TestPatient=0
	left outer join BHIP.PatientDetails as b WITH (NOLOCK) on a.MVIPersonSID = b.MVIPersonSID 
	left outer join Present.appointmentsfuture as MHF WITH (NOLOCK) on a.MVIPersonSID = MHF.MVIPersonSID and MHF.apptcategory = 'MHFuture' 
	left outer join Present.appointmentsfuture as PCF WITH (NOLOCK) on a.MVIPersonSID = PCF.MVIPersonSID and PCF.apptcategory = 'PCFuture'
	left outer join Present.appointmentspast as PCP WITH (NOLOCK) on a.MVIPersonSID = PCP.MVIPersonSID and PCP.apptcategory in ('PCRecent') and PCP.VisitDateTime > a.RequestDateTime
	left outer join Present.appointmentspast as MHP WITH (NOLOCK) on a.MVIPersonSID = MHP.MVIPersonSID and MHP.apptcategory in ('MHRecent') and MHP.VisitDateTime > RequestDateTime
	

EXEC [Maintenance].[PublishTable] 'BHIP.Consults_PBI', '#Final';
END