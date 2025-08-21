-- =============================================
-- Description:	Prescriber parameter for Antidepressant report
-- =============================================
CREATE PROCEDURE [App].[p_MDD_Prescriber]
	@Facility as varchar(max),
	@NoPHI as varchar(10)

AS
BEGIN
	SET NOCOUNT ON;

	--select distinct cast(rtrim(ltrim(sta6aid)) as int) as sta6aid from datatable order by cast(rtrim(ltrim(sta6aid)) as int)
	--declare @station varchar (50)
	--declare @NoPHI int

	--set @station ='640'
	--set @NOPHI='0'

IF @NoPHI=1
BEGIN
	SELECT PrescriberSID = -5
		  ,Prescriber = 'Dr Zhivago'
		  ,PrescrberOrder = 0
		  ,PrescriberFake = 'Dr. Abc'
		  ,PrescriberTypeDropDown = 'Dr Zhivago'
END

ELSE

SELECT DISTINCT
	 ISNULL(PrescriberSID,-1) PrescriberSID
	,Prescriber
	,0 as PrescriberOrder
	,PrescriberFake = 'Dr. Abc'
	,Prescriber as PrescriberTypeDropDown
FROM [Pharm].[AntiDepressant_MPR_PatientReport] a
WHERE a.ChecklistID = @Facility
ORDER BY PrescriberOrder desc, Prescriber 



END