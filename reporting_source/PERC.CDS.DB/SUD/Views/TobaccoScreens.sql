





CREATE VIEW [SUD].[TobaccoScreens]
AS

-- ==========================================================================================
-- Author: Claire Hannemann
-- Create date: 2024-07-03
-- Description: Pulling all tobacco use screens in past 5 years and creating positive screen indicator for some day or every day use

-- Vista HealthFactorType: 
-- VA-TOBACCO NEVER USED
-- VA-TOBACCO FORMER USER
-- VA-TOBACCO USER SOME DAYS 
-- VA-TOBACCO USER EVERY DAY 
-- VA-TOBACCO USE DECLINED TO ANSWER
-- VA-TOBACCO USE EVERY DAY CIGARETTES
-- VA-TOBACCO USE EVERY DAY CIGARS/PIPES
-- VA-TOBACCO USE EVERY DAY ENDS
-- VA-TOBACCO USE EVERY DAY OTHER PRODUCT
-- VA-TOBACCO USE EVERY DAY OTHER TYPE
-- VA-TOBACCO USE EVERY DAY SMOKELESS
-- VA-TOBACCO USE SOME DAYS CIGARETTES
-- VA-TOBACCO USE SOME DAYS CIGARS/PIPES
-- VA-TOBACCO USE SOME DAYS ENDS
-- VA-TOBACCO USE SOME DAYS OTHER PRODUCT
-- VA-TOBACCO USE SOME DAYS OTHER TYPE
-- VA-TOBACCO USE SOME DAYS SMOKELESS

-- Cerner FactPowerForm DerivedDtaEventResult (where DerivedDtaEvent='Tobacco Use Status' ):
-- Former - tobacco user
-- Former-other tobacco user (not cigarettes)
-- N/A
-- Never - tobacco user
-- Never-other tobacco user (not cigarettes)
-- Not obtained due to cognitive impairment
-- Patient declines to answer
-- Yes - Current everyday tobacco user
-- Yes - Current some day tobacco user
-- Yes-current some day other tobacco user (not cigarettes)

-- 10 or more cigs(1/2 pack or more)/day in last 30 days
-- 4 or less cigs(less than 1/4 pack)/day in last 30 days
-- 5-9 cigs(between 1/4 to 1/2 pack)/day in last 30 days
-- Cigars or pipes but not daily within last 30 days
-- Cigars or pipes daily within last 30 days
-- Former - E-Cigarette/Vaping user
-- Former smokeless tob user, quit over 30 days ago
-- Former smoker, quit more than 30 days ago
-- Former-cigarette user
-- Former-other tobacco user (not cigarettes)
-- Never
-- Never (less than 100 in lifetime)
-- Never - E-Cigarette/Vaping user
-- Never-cigarette user
-- Never-other tobacco user (not cigarettes)
-- Not obtained due to cognitive impairment
-- Other
-- Patient declines to answer
-- Refused tobacco status screen
-- Smokeless tobacco user within last 30 days
-- Smoker, current status unknown
-- Yes - current everyday user
-- Yes - current some day user
-- Yes-current everyday cigarette user
-- Yes-current everyday other tobacco user (not cigarettes)
-- Yes-current some day cigarette user
-- Yes-current some day other tobacco user (not cigarettes)

-- ===========================================================================================

	SELECT MVIPersonSID
		,HealthFactorDateTime
		,HealthFactorType
		,ChecklistID
		,CASE WHEN HealthFactorType in ('VA-TOBACCO USER EVERY DAY','VA-TOBACCO USER SOME DAYS',
					'Yes - Current everyday tobacco user','Yes - Current some day tobacco user',
					'Yes - current everyday user', 'Yes - current some day user',
					'Yes-current everyday cigarette user', 'Yes-current some day cigarette user',
					'Yes-current everyday other tobacco user (not cigarettes)', 
					'Yes-current some day other tobacco user (not cigarettes)') 
					or HealthFactorType like 'VA-TOBACCO USE SOME DAYS%'
					or HealthFactorType like 'VA-TOBACCO USE EVERY DAY%' THEN 1 ELSE 0 END AS PositiveScreen
		,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID 
							ORDER BY HealthFactorDateTime DESC, 
									CASE WHEN HealthFactorType='VA-TOBACCO USER EVERY DAY' or (HealthFactorType like 'Yes%' and HealthFactorType like '%everyday%') THEN 12
										 WHEN HealthFactorType like 'VA-TOBACCO USE EVERY DAY%' and HealthFactorType like '%CIGARETTES%' THEN 11
										 WHEN HealthFactorType like 'VA-TOBACCO USE EVERY DAY%' and HealthFactorType like '%ENDS%' THEN 10
										 WHEN HealthFactorType like 'VA-TOBACCO USE EVERY DAY%' and HealthFactorType like '%CIGARS/PIPES%' THEN 9
										 WHEN HealthFactorType like 'VA-TOBACCO USE EVERY DAY%' and HealthFactorType like '%OTHER%' THEN 8
										 WHEN HealthFactorType='VA-TOBACCO USER SOME DAYS' or (HealthFactorType like 'Yes%' and HealthFactorType like '%some day%') THEN 7
										 WHEN HealthFactorType like 'VA-TOBACCO USE SOME DAYS%' and HealthFactorType like '%CIGARETTES%' THEN 6
										 WHEN HealthFactorType like 'VA-TOBACCO USE SOME DAYS%' and HealthFactorType like '%ENDS%' THEN 5
										 WHEN HealthFactorType like 'VA-TOBACCO USE SOME DAYS%' and HealthFactorType like '%CIGARS/PIPES%' THEN 4
										 WHEN HealthFactorType like 'VA-TOBACCO USE SOME DAYS%' and HealthFactorType like '%OTHER%' THEN 3
										 WHEN HealthFactorType='VA-TOBACCO FORMER USER' or HealthFactorType like 'Former%' THEN 2 
										 WHEN HealthFactorType='VA-TOBACCO NEVER USED' or HealthFactorType like 'Never%' THEN 1 
										 ELSE 0 END DESC
							) 
							AS OrderDesc
		,CASE WHEN HealthFactorDateTime > DATEADD(year,-1,cast(getdate() as date)) THEN 1 ELSE 0 END AS PastYear
	FROM (	
		--Vista 
			SELECT c.MVIPersonSID
				,a.HealthFactorDateTime
				,b.HealthFactorType
				,d.ChecklistID
			FROM HF.HealthFactor a
			INNER JOIN Dim.HealthFactorType b WITH (NOLOCK) on a.HealthFactorTypeSID=b.HealthFactorTypeSID
			INNER JOIN Common.MVIPersonSIDPatientPersonSID c WITH (NOLOCK) on a.patientsid=c.PatientPersonSID
			LEFT JOIN Outpat.Visit v WITH (NOLOCK) on a.VisitSID=v.VisitSID
			LEFT JOIN LookUp.DivisionFacility d WITH (NOLOCK) on d.DivisionSID=v.DivisionSID
			WHERE (b.HealthFactorType in ('VA-TOBACCO NEVER USED',
										 'VA-TOBACCO FORMER USER',
										 'VA-TOBACCO USER SOME DAYS',
										 'VA-TOBACCO USER EVERY DAY',
										 'VA-TOBACCO USE DECLINED TO ANSWER')
					or b.HealthFactorType like 'VA-TOBACCO USE SOME DAYS%'
					or b.HealthFactorType like 'VA-TOBACCO USE EVERY DAY%')
				and a.HealthFactorDateTime > DATEADD(year,-5,cast(getdate() as date))

			UNION
		--Cerner/Oracle Health
			SELECT a.MVIPersonSID
				,a.TZFormUTCDateTime
				,a.DerivedDtaEventResult
				,b.ChecklistID
			FROM Cerner.FactPowerForm a
			LEFT JOIN Lookup.ChecklistID b WITH (NOLOCK) on a.STAPA=b.StaPa
			WHERE DerivedDtaEvent='Tobacco Use Status' 
				and TZFormUTCDateTime > DATEADD(year,-5,cast(getdate() as date))
			UNION
			SELECT a.MVIPersonSID
				,a.TZPerformDateTime
				,a.DerivedSourceString
				,b.ChecklistID
			FROM Cerner.FactSocialHistory a
			LEFT JOIN Lookup.ChecklistID b WITH (NOLOCK) on a.STAPA=b.StaPa
			WHERE TaskAssay IN 
                                (
                                 'SHX E-Cigarette use'
                                ,'SHX Cigarette use'
                                ,'SHX Other Tobacco use'
                                ,'SHX Smokeless Tobacco use'
                                )
				and TZPerformDateTime > DATEADD(year,-5,cast(getdate() as date))
			) a
	WHERE MVIPersonSID > 0