

-- =============================================
-- Author:		Shalini Gupta
-- Original Author:		Sara Tavakoli
-- Create date: <1/29/2017>
-- Description:	
-- Modification: To capture ORM Trends based on monthly snapshots
--               If SP runs more then once, delete previous records of that month.
-- =============================================
CREATE PROCEDURE [Code].[ORM_MetricTable_Trends] 
AS
BEGIN

DECLARE
	 @YR INT
	,@MONTH INT

SET @YR = DATEPART(YEAR,GETDATE())
SET @MONTH =  DATEPART(MONTH,GETDATE())
	-- print @MONTH
	-- print @YR

DECLARE @RowCount INT = (SELECT COUNT(*) FROM [ORM].[MetricTable])

IF @RowCount > 0 -- first make sure there is data to insert before continuing with deletion
	BEGIN

	-- delete previous records if this months data already exists
	DELETE FROM [ORM].[MetricTable_Trends] 
	WHERE YEAR(UpdateDate) = @YR 
		AND MONTH(UpdateDate) = @MONTH

	INSERT INTO [ORM].[MetricTable_Trends] (
		VISN,ChecklistID,GroupID,ProviderSID,Riskcategory
		,AllOpioidPatient,AllOpioidRXPatient,AllOUDPatient
		,Measureid,Numerator,Denominator
		,Score,NatScore,AllTxPatients,UpdateDate
		)
	SELECT VISN
		,ChecklistID
		,GroupID
		,ProviderSID
		,Riskcategory
		,AllOpioidPatient
		,AllOpioidRXPatient
		,AllOUDPatient
		,Measureid
		,Numerator
		,Denominator
		,Score
		,NatScore
		,AllTxPatients
		,UpdateDate = GETDATE() 
	FROM [ORM].[MetricTable]

	EXEC [Log].[PublishTable] 'ORM','MetricTable_Trends','ORM.MetricTable','Append',@RowCount

	END

END
GO
