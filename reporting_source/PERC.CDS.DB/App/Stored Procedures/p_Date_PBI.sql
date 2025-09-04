CREATE   PROCEDURE [App].[p_Date_PBI]

/*******************************************************************************************************************************
Developer(s)	: Amy Robinson
Create Date		: 9/20/2022
Description  	: Date Dim for PBI reports

REVISON LOG		:

*******************************************************************************************************************************/

@DomainFltr VARCHAR(MAX) = NULL --Parameter for filtering Domain; one or many

AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON; 

select * from Dim.Date
END
;