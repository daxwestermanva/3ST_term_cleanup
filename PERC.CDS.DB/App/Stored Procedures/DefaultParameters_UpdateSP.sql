

-- =============================================
-- Author:		Tolessa Gurmessa
-- Create date: 2024-04-24
-- Description:	Adopted from Marcos Lau's App.DefaultParameters_UpdateSP for STORM default parameter updates
-- 2024-07-11  - TG - Adding a new report 
-- =============================================
CREATE PROCEDURE [App].[DefaultParameters_UpdateSP]
	@User varchar(100)
	, @ReportName varchar(100) 
	, @Parameter1 varchar(1000) = ''
	, @Parameter2 varchar(1000) = ''
	, @Parameter3 varchar(1000) = ''
	, @Parameter4 varchar(1000) = ''
	, @Parameter5 varchar(1000) = ''
	, @Parameter6 varchar(1000) = ''
	, @Parameter7 varchar(1000) = ''
	, @Parameter8 varchar(1000) = ''
	, @Parameter9 varchar(1000) = ''
	, @Parameter10 varchar(1000) = ''
	, @Parameter11 varchar(1000) = ''
	, @Parameter12 varchar(1000) = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	/*
	Description:
		This procedure updates the default parameters based on whatever was last ran
		It has been designed to accommodate up to 12 parameters
		Key point is to make sure the main default parameter dataset you created in SSRS
		matches the parameters below.

	*/

	set @Parameter1 = case when @Parameter1 like '%-9%' then '-9' else @Parameter1 end 
	set @Parameter2 = case when @Parameter2 like '%-9%' then '-9' else @Parameter2 end 
	set @Parameter3 = case when @Parameter3 like '%-9%' then '-9' else @Parameter3 end 
	set @Parameter4 = case when @Parameter4 like '%-9%' then '-9' else @Parameter4 end 
	set @Parameter5 = case when @Parameter5 like '%-9%' then '-9' else @Parameter5 end 
	set @Parameter6 = case when @Parameter6 like '%-9%' then '-9' else @Parameter6 end 
	set @Parameter7 = case when @Parameter7 like '%-9%' then '-9' else @Parameter7 end 
	set @Parameter8 = case when @Parameter8 like '%-9%' then '-9' else @Parameter8 end 
	set @Parameter9 = case when @Parameter9 like '%-9%' then '-9' else @Parameter9 end 
	set @Parameter10 = case when @Parameter10 like '%-9%' then '-9' else @Parameter10 end 
	set @Parameter11 = case when @Parameter11 like '%-9%' then '-9' else @Parameter11 end 
	set @Parameter12 = case when @Parameter12 like '%-9%' then '-9' else @Parameter12 end 
	
	-- restructure the parameters into a table for inserting 
	if object_id('tempdb..#temp') is not null
	drop table #temp 
	;
	

	select *
	into #Temp
	from (
		select case 
				when @ReportName = 'ORM_OPPEReport' then 'GroupType' 
				when @ReportName = 'ORM_OTRR' then 'GroupType' 
				when @ReportName = 'ORM_SummaryReport' then 'GroupType'
				when @ReportName = 'ORM_PatientQuickView' then 'GroupType'
				when @ReportName = 'ORM_PatientReport' then 'GroupType'
				when @ReportName = 'ORM_OPPEPatientReport' then 'GroupType'
				when @ReportName = 'ORM_OPPEDueNinetyDays' then 'GroupType'
				when @ReportName = 'ORM_TotalPatientReport' then 'GroupType'
				end as ParameterName
			, cast(value  as varchar(1000)) as ParameterValue
		from string_split(@Parameter1, ',') -- Parameters are numbered in order

		UNION ALL

		select case 
				when @ReportName = 'ORM_OPPEReport' then 'Prescriber'
				when @ReportName = 'ORM_OTRR' then 'Prescriber'
				when @ReportName = 'ORM_SummaryReport' then 'Prescriber'
				when @ReportName = 'ORM_PatientQuickView' then 'Prescriber'
				when @ReportName = 'ORM_PatientReport' then 'Prescriber'
				when @ReportName = 'ORM_OPPEPatientReport' then 'Prescriber'
				when @ReportName = 'ORM_OPPEDueNinetyDays' then 'Prescriber'
				when @ReportName = 'ORM_TotalPatientReport' then 'Prescriber'
				end as ParameterName
			, cast(value as varchar(1000)) as ParameterValue
		from string_split(@Parameter2, ',')

			UNION ALL

		select case 
				when @ReportName = 'ORM_OPPEReport' then 'Measure' 
				when @ReportName = 'ORM_OTRR' then 'Cohort'
                when @ReportName = 'ORM_SummaryReport' then 'RiskGroup'
				when @ReportName = 'ORM_PatientQuickView' then 'RiskGroup'
				when @ReportName = 'ORM_PatientReport' then 'RiskGroup'
				when @ReportName = 'ORM_OPPEPatientReport' then 'RiskGroup'
				when @ReportName = 'ORM_OPPEDueNinetyDays' then 'RiskGroup'
				when @ReportName = 'ORM_TotalPatientReport' then 'RiskGroup'
				end as ParameterName
			, cast(value as varchar(1000)) as ParameterValue
		from string_split(@Parameter3, ',')
		    UNION ALL

		select case 
				when @ReportName = 'ORM_SummaryReport' then 'Measure' 
				when @ReportName = 'ORM_PatientQuickView' then 'Measure'
				when @ReportName = 'ORM_PatientReport' then 'Measure'
				when @ReportName = 'ORM_OPPEPatientReport' then 'Measure'
				when @ReportName = 'ORM_OPPEDueNinetyDays' then 'Measure'
				when @ReportName = 'ORM_TotalPatientReport' then 'Measure'
				end as ParameterName
			, cast(value as varchar(1000)) as ParameterValue
		from string_split(@Parameter4, ',')
		UNION ALL

		select case 
				when @ReportName = 'ORM_PatientQuickView' then 'Cohort' 
				when @ReportName = 'ORM_PatientReport' then 'Cohort'
				when @ReportName = 'ORM_OPPEPatientReport' then 'Cohort'
				when @ReportName = 'ORM_OPPEDueNinetyDays' then 'Cohort'
				when @ReportName = 'ORM_TotalPatientReport' then 'Cohort'
				end as ParameterName
			, cast(value as varchar(1000)) as ParameterValue
		from string_split(@Parameter5, ',')
		UNION ALL

		select case 
				when @ReportName = 'ORM_OPPEDueNinetyDays' then 'DueNinetyDays'
				end as ParameterName
			, cast(value as varchar(1000)) as ParameterValue
		from string_split(@Parameter6, ',')
	
	) as a
	where ParameterName is not null 
;
-- remove the old parameter settings
delete from App.DefaultParameters 
where [User] = @User and ReportName = @ReportName 
;

-- insert the new parameter settings 
insert into App.DefaultParameters 
select @User, @ReportName, ParameterName, ParameterValue, GETDATE() AS LastUpdated
from #Temp

;

END