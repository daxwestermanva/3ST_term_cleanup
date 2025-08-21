Create function [Maintenance].[GetFY_Start](@DateVal as date)
RETURNS date
 AS
BEGIN

	Declare @Year int
	
	if Month(@DateVal) > 9
		set @Year = Year(@DateVal) 
	else
		set @Year = Year(@DateVal) - 1
		
	Return	Cast('10/1/' + Cast(@Year as varchar(4)) as date)

End