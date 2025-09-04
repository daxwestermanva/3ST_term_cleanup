-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <2/13/23>
-- Description:	SUD PowerBI - Hep C Lab history

-- =============================================
CREATE   PROCEDURE [App].[SUD_HepCLabs_PBI]

AS
BEGIN
	SET NOCOUNT ON;
 
 
select MVIPersonSID
	,CheckListID
	,LabType
	,LabChemResultValue
	,Interpretation
	,LabChemSpecimenDateSID
	,Date
	,case when LastRowID = RowID then 1 else 0 end MostRecent
from (
	select a.* 
		,Max(RowID) over (partition by a.PatientICN,LabType) as LastRowID
		,b.[Date]
	from PDW.SCS_HLIRC_DOEx_HepCLabAllPtAllTime as a  WITH (NOLOCK)
	inner join dim.date as b WITH (NOLOCK) on a.LabChemSpecimenDateSID = b.DateSID
	where date > getdate()-1825
	) as a 
inner join common.masterpatient as b WITH (NOLOCK) on a.patienticn = b.patienticn
inner join lookup.stationcolors as s WITH (NOLOCK) on cast( a.sta3n as varchar(5)) = s.CheckListID

 
 
END