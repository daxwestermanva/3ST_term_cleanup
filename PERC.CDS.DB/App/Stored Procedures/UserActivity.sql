
-- [App].[UserActivity] 'Last 30 days', 0, NULL,NULL,'Reports', '*All*', '*All*'

CREATE PROCEDURE [App].[UserActivity] (@TimeFrame varchar(20), @Top integer = 0, @StartDt date='1/1/1900', @EndDt date='1/1/1900', @View varchar(50) = 'Reports', @ReportName varchar(300) = '*All*', @UserName varchar(100) = '*All*') as

Declare @SQLQuery AS NVarchar(4000)
Declare @ParamDefinition AS NVarchar(2000) 
Declare @CountBy varchar(50)
Declare @Join varchar(500) = ''

Set @ParamDefinition = '@StartDt date,@EndDt date'

Set NoCount ON;

If @TimeFrame = 'Last 30 days' 
Begin
	set @EndDt = Cast(Getdate() as date)
	set @StartDt =  DateAdd(d, -30, GETDATE())
End

If @TimeFrame = 'Last full month' 
Begin
	set @EndDt = Cast(DATEADD(DAY, -(DAY(GETDATE())), GETDATE()) + 1 as date)
	set @StartDt = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0) 
End

If @TimeFrame = 'Last 6 months' 
Begin
	set @EndDt = Cast(DATEADD(DAY, -(DAY(GETDATE())), GETDATE()) + 1 as date)
	set @StartDt = DATEADD(MONTH, DATEDIFF(MONTH, 0, DateAdd(m, -6, GETDATE())), 0) 
End

If @TimeFrame = 'Last 12 months' 
Begin
	set @EndDt = Cast(DATEADD(DAY, -(DAY(GETDATE())), GETDATE()) + 1 as date)
	set @StartDt = DATEADD(MONTH, DATEDIFF(MONTH, 0, DateAdd(m, -12, GETDATE())), 0) 
End

If @TimeFrame = 'Last 24 months' 
Begin
	set @EndDt = Cast(DATEADD(DAY, -(DAY(GETDATE())), GETDATE()) + 1 as date)
	set @StartDt = DATEADD(MONTH, DATEDIFF(MONTH, 0, DateAdd(m, -24, GETDATE())), 0) 
End

If @TimeFrame = 'Last FY' 
Begin
	set @EndDt = Maintenance.[GetFY_Start](getdate())
	set @StartDt = Maintenance.[GetFY_Start](getdate()-365)
End

If @TimeFrame = 'Current FY' 
Begin
	set @EndDt = cast(DateAdd(d, -1,(getdate())) as date)
	set @StartDt = Maintenance.[GetFY_Start](getdate())
End

Set @CountBy = 
	Case
		When @View = 'Reports' Then ' a.[ReportName] '
		When @View = 'Users' Then ' a.[UserName] '
	End

Set @SQLQuery = 'select'
If @Top > 0 
	Set @SQLQuery = @SQLQuery + ' top ' + cast(@Top as varchar(2))

Set @SQLQuery = @SQLQuery + @CountBy + ' As CountBy, Count(*) as RecCount '
Set @SQLQuery = @SQLQuery + ' from App.[UserActivityLog] a ' + 
				' where a.[TimeStart] between @StartDt and @EndDt'
If @ReportName <> '*All*'
	Set @SQLQuery = @SQLQuery + ' AND a.ReportName = ''' + @ReportName + ''''
If @UserName <> '*All*'
	Set @SQLQuery = @SQLQuery + ' AND a.UserName = ''' + @UserName + ''''

Set @SQLQuery = @SQLQuery + ' Group By ' + @CountBy
Set @SQLQuery = @SQLQuery + ' order by Count(*) desc'

Print @StartDt
Print @EndDt
Print @SQLQuery

create table #detail (CountBy varchar(100), RecCount int)
insert into #detail (CountBy, RecCount)
Execute sp_Executesql @SQLQuery, @ParamDefinition, @StartDt, @EndDt

Select *
from #detail
order by RecCount desc