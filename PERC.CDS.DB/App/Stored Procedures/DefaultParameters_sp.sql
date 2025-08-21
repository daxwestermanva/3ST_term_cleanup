

-- =============================================
-- Author:		Tolessa Gurmessa
-- Create date: <4/12/2024>
-- Description:	Adopted from Marcos Lau's <App.DefaultParameters_sp>
--2024-05-06  - TG finetuning the default parameters
-- 2024-07-11 - TG adding the new report parameters
-- =============================================
CREATE PROCEDURE [App].[DefaultParameters_sp]
	@User varchar(100)
	, @ReportName varchar(100)
	, @ParameterName varchar(100) 
	

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

/*
----====================================================================================================
----====== General Notes - This is all encompassing for default parameter use===========================
----====================================================================================================
1. Create the reference table to be updated which needs at a minimum user, report, parameter, value (see create table statement)
2. Create another procedure to perform the updates (delete + insert): App.DefaultParameters_UpdateSP
3. Datasets are loaded in parallel so the Default values must first be populated (see the insert into example)
4. In Report Builder, create as many datasets as you want for this default dataset
	1. Upon creation, go to the Parameters tab (NOT FOLDER) and assign the values you used in Step 3	 
	2. Repeat until all of your parameters have their own default setting 
5. Because we all have different naming conventions, using the ReportName, assign the proper Parameter Name and MultiSelect values
	1. Follow the example set by the Suicide Prevention Patient Report 
6. ENJOY!

create table App.DefaultParameters (
	[User] varchar(100)
	, ReportName varchar(100)
	, ParameterName varchar(100)
	, ParameterValue varchar(1000)
	, LastUpdated datetime2(0)
	) on DefFG
	
; 

create clustered columnstore index cci_App_DefaultParameters
	on App.DefaultParameters 
	with (data_compression = columnstore)
	on [DefFG]
;

-- set up your default parameters following the below example 
insert into App.DefaultParameters (ReportName, ParameterName, ParameterValue)
values 


-- OPPE Report 
insert into App.DefaultParameters (ReportName, ParameterName, ParameterValue)
values 
('ORM_OPPEReport', 'GroupType', '-5')
, ('ORM_OPPEReport', 'Prescriber', '-5')
, ('ORM_OPPEReport', 'Measure', '12')


-- OTRR
insert into App.DefaultParameters (ReportName, ParameterName, ParameterValue)
values 
('ORM_OTRR', 'GroupType', '-5')
, ('ORM_OTRR', 'Prescriber', '-5')
, ('ORM_OTRR', 'Cohort', '3')


-- STORM Summary Report 
insert into App.DefaultParameters (ReportName, ParameterName, ParameterValue)
values 
('ORM_SummaryReport', 'GroupType', '-5')
, ('ORM_SummaryReport', 'Prescriber', '-5')
, ('ORM_SummaryReport', 'RiskGroup', '4')
, ('ORM_SummaryReport', 'Measure', '12')

-- STORM Patient Quick View
insert into App.DefaultParameters (ReportName, ParameterName, ParameterValue)
values 
('ORM_PatientQuickView', 'GroupType', '-5')
, ('ORM_PatientQuickView', 'Prescriber', '-5')
, ('ORM_PatientQuickView', 'RiskGroup', '4')
, ('ORM_PatientQuickView', 'Measure', '12')
, ('ORM_PatientQuickView', 'Cohort', '3')


-- STORM Patient Report
insert into App.DefaultParameters (ReportName, ParameterName, ParameterValue)
values 
('ORM_PatientReport', 'GroupType', '-5')
, ('ORM_PatientReport', 'Prescriber', '-5')
, ('ORM_PatientReport', 'RiskGroup', '4')
, ('ORM_PatientReport', 'Measure', '12')
, ('ORM_PatientReport', 'Cohort', '3')

-- OPPE Patient Report
insert into App.DefaultParameters (ReportName, ParameterName, ParameterValue)
values 
('ORM_OPPEPatientReport', 'GroupType', '-5')
, ('ORM_OPPEPatientReport', 'Prescriber', '-5')
, ('ORM_OPPEPatientReport', 'RiskGroup', '4')
, ('ORM_OPPEPatientReport', 'Measure', '12')
, ('ORM_OPPEPatientReport', 'Cohort', '3')

-- OPPE Due in Ninety Days
insert into App.DefaultParameters (ReportName, ParameterName, ParameterValue)
values 
('ORM_OPPEDueNinetyDays', 'GroupType', '-5')
, ('ORM_OPPEDueNinetyDays', 'Prescriber', '-5')
, ('ORM_OPPEDueNinetyDays', 'RiskGroup', '4')
, ('ORM_OPPEDueNinetyDays', 'Measure', '12')
, ('ORM_OPPEDueNinetyDays', 'Cohort', '3')
,('ORM_OPPEDueNinetyDays', 'DueNinetyDays', '3')

-- STORM Total Patient Report
insert into App.DefaultParameters (ReportName, ParameterName, ParameterValue)
values 
('ORM_TotalPatientReport', 'GroupType', '-5')
, ('ORM_TotalPatientReport', 'Prescriber', '-5')
, ('ORM_TotalPatientReport', 'RiskGroup', '4')
, ('ORM_TotalPatientReport', 'Measure', '12')
, ('ORM_TotalPatientReport', 'Cohort', '3')

INSERT SNIPPET ABOVE THIS LINE
*/


if exists (select 1 from App.DefaultParameters where [User] = @User and ReportName = @ReportName)
begin
	select 
		ParameterValue
	from App.DefaultParameters 
	where [User] = @User and ReportName = @ReportName 
		and ParameterName = @ParameterName 
end
else
begin
	select ParameterValue 
	from App.DefaultParameters 
	where [User] is null and ReportName = @ReportName 
		and ParameterName = @ParameterName
end 


;

END