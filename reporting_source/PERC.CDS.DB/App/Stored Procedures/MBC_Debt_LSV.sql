


-- =============================================
-- Author:		<Liam Mina>
-- Create date: <09/21/2021>
-- Description:	Dataset pulls data from Debt Management Center table to get detail on debt owed and recent letters sent
--
-- EXEC [App].[MBC_Debt_LSV] @User = 'VHAMASTER\VHAISBBACANJ'	, @Patient = '1014519156'
-- EXEC [App].[MBC_Debt_LSV] @User = 'vha21\vhapalminal'		, @Patient = '1044467850'
-- =============================================
CREATE PROCEDURE [App].[MBC_Debt_LSV]
(
	@User VARCHAR(MAX),
	@Patient VARCHAR(1000)
)  
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'	; SET @Patient = '1034545130'
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'vha21\vhapalminal'		; SET @Patient = '1016539698'


	SELECT DISTINCT a.MVIPersonSID 
		  ,Patient_Debt_Sum AS AllDebtAmount
		  ,Patient_Debt_Count
		  ,MAX(MostRecentContact_Date) OVER (PARTITION BY a.MVIPersonSID) AS AllMostRecentContactDate
		  ,Total_AR_Amount AS DetailDebtAmount
		  ,Deduction_Desc AS DetailDebtType
		  ,MostRecentContact_Date AS DetailMostRecentContactDate
		  ,MostRecentContact_Letter AS DetailMostrecentContactLetter
		  ,CASE WHEN CPDeduction=1 AND DateAdd(month,3,FirstDemandDate) >= getdate() THEN CONCAT('C&P benefit deduction beginning ', convert(varchar,DateAdd(day,90,FirstDemandDate),101))
			WHEN CPDeduction=1 AND DateAdd(month,6,FirstDemandDate) >= getdate() THEN CONCAT('C&P benefit deduction began ', convert(varchar,DateAdd(day,90,FirstDemandDate),101))
			END AS CPDeduction
		  ,CASE WHEN FirstDemandDate IS NOT NULL THEN CONCAT('First Demand Letter: ', convert(varchar,FirstDemandDate,101)) END AS FirstDemandDate
		  ,CASE WHEN TreasuryOffsetDate IS NOT NULL THEN CONCAT('Referred to Treasury Offset Program: ', convert(varchar,TreasuryOffsetDate,101)) END AS TreasuryOffsetDate
		  ,CASE WHEN ReferToCSDate IS NOT NULL THEN CONCAT('Referred to Treasury Cross-Servicing: ', convert(varchar,ReferToCSDate,101)) END AS ReferToCSDate
		  ,d.DisplayMessageText
		  ,d.Link
	FROM [VBA].[DebtManagementCenter] a WITH(NOLOCK) 
	INNER JOIN [Common].[MasterPatient] b WITH(NOLOCK) 
		ON a.MVIPersonSID=b.MVIPersonSID
	LEFT JOIN [Config].[DMC_DisplayMessage] d WITH (NOLOCK)
		ON a.DisplayMessage = d.DisplayMessage
	WHERE a.PatientICN =  @Patient
	AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)


END