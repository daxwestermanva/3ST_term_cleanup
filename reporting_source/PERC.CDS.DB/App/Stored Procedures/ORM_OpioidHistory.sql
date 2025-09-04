 
-- =============================================
-- Author:		Pooja Sohoni
-- Create date: 2018-07-30
-- Description:	Pulls opioid Rx history in past year for all patients, this App procedure feeds the Opioid History part of the STORM SSN Lookup report
-- 2025-03-04  - TG - Fixing a permission issue affecting providers at non-homestation
-- =============================================
CREATE   PROCEDURE [App].[ORM_OpioidHistory] 
 
    @User VARCHAR(MAX),
    @Patient VARCHAR(1000)
 
	--declare @user varchar(max)
	--declare @patient varchar(1000)
	--set @user='vha21\vhapalsohonp'
	--set @patient= '1003722988' 
 
AS
BEGIN
 
SET NOCOUNT ON;
 
--First, create a table with all the patients (ICNs) that the user has permission to see
	DROP TABLE IF EXISTS #Patient;
	SELECT 
		 MVIPersonSID
		,PatientICN
	INTO #Patient
	FROM [Common].[MasterPatient] AS b WITH (NOLOCK) 
	WHERE b.PatientICN =  @Patient
	AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0);

 
--Then, using that table, select the relevant opioid Rx records
SELECT DISTINCT 
		p.PatientICN
       ,oh.ChecklistID
       ,oh.DrugNameWithDose
       ,oh.IssueDate 
       ,oh.ReleaseDateTime
       ,oh.DaysSupply 
       ,oh.Qty AS Quantity
	   ,oh.StaffName
	   ,oh.RxStatus
	   ,oh.Active
	   ,oh.OpioidOnHand
FROM [ORM].[OpioidHistory] AS oh  WITH (NOLOCK)
INNER JOIN #Patient p on p.MVIPersonSID=oh.MVIPersonSID
 
END