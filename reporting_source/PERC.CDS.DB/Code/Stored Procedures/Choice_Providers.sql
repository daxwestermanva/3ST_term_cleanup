/* =============================================================================
-- Author:           <Nirvesh Karki>
-- Create date: <11/19/2018>
-- Description: Identify all the prescriptions that has “CHOICE” description in the 
-- “FillRemarks” of RxOut.RxOutpatfill table. Determine if the provider is CHOICE 
-- provider based on our findings of what percentageof prescriptions indicate “CHOICE” 
-- of the total prescription they have prescribed.

-- 2019-06-05: Pooja Sohoni - migrated to Sbx, reformatted, validated, cleaned code
-- 2019-08-13: Pooja Sohoni - adding logic to capture new code for CHOICE
-- 2021-09-14: Bruk Woldesenbet - Enclave Refactoring - Counts Confirmed.
-- 2022-04-28: Rebecca Stephens - Added logic to get most recent FillRemark so that 
					CHOICE.Prescriptions has unique RxOutpatSID (which is better
					for current implementation in Present Medications). 
					Other changes for formatting and eliminating unneeded "distincts"
					and added logging.
-- ============================================================================== */

CREATE PROCEDURE [Code].[Choice_Providers]
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'Code.Choice_Providers','EXEC Code.Choice_Providers'

----------------------------------------------------------------------------
--************************** CHOICE PRESCRIPTIONS **************************
----------------------------------------------------------------------------

--Get all CHOICE remarks, including common typos 
DROP TABLE IF EXISTS #allchoicewithtypo
SELECT
	FillRemarks
	,RxOutpatSID
	,ProviderSID
	,ReleaseDateTime = MAX(ReleaseDateTime)
INTO #allchoicewithtypo
FROM [RxOut].[RxOutpatFill]
WHERE ReleaseDateTime > CAST(CAST(GETDATE() - 366 AS DATE) AS DATETIME2(0)) -- going back 1 year
	AND (FillRemarks   LIKE   '%choice%'
	OR   FillRemarks   LIKE   '%chioce%'
	OR   FillRemarks   LIKE   '%chioc%'
	OR   FillRemarks   LIKE   '%chice%'
	OR   FillRemarks   LIKE   '%chois%'
	OR   FillRemarks   LIKE   '%coice%'
	OR   FillRemarks   LIKE   '%choce%'
	OR   FillRemarks   LIKE   '%chiocerx%'
	OR   FillRemarks   LIKE   '%CCNRX%')
GROUP BY RxOutpatSID,ProviderSID,FillRemarks
;

--Filter out rows that mention CHOICE only because they are not CHOICE
DROP TABLE IF EXISTS #cleanchoice
SELECT TOP 1 WITH TIES
	FillRemarks
	,RxOutpatSID
	,ProviderSID 
	,ReleaseDateTime
INTO #cleanchoice
FROM #allchoicewithtypo
WHERE (
		FillRemarks NOT LIKE '% not choice %'	-- 11/07 Nirvesh screened & determined not relevant
	AND FillRemarks NOT LIKE '% no choice %'	-- 11/07 Nirvesh screened & determined not relevant
	AND FillRemarks NOT LIKE '% choice not %'	-- 11/07 Nirvesh screened & determined not relevant
	AND FillRemarks NOT LIKE '%non choice %'	-- 11/07 Nirvesh screened & determined not relevant
	AND FillRemarks NOT LIKE '%nochoice%'		-- 11/07 Nirvesh screened & determined not relevant
	AND FillRemarks NOT LIKE '%per provider:"informed, pt choice%'	-- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%awaiting CHOICE appt%'				-- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%until choice renews%'                -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%notified by choice%'                 -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%cannot be referred for CHOICE%'      -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%failed pantop choice%'               -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%new script from choice dr%'          -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%AWAITING CHOICE APPT%'               -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%ordered by CHOICE%'                  -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%CHOICE RENEWAL%'                     -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%establish care with CHOICE%'         -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%PT STATES CHOICE%'                   -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%working on choice approval%'         -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%UNTIL CHOICE%'                       -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%UNTIL NEW CHOICE APPT%'              -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%seeing choice doc%'                  -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%till choice straight%'               -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%TILL SEES CHOICE%'                   -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%verbal choice%'                      -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%waiting for choice %'                -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%waiting choice %'                    -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%inform choice%'                      -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%waiting for choice%'                 -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%choice expired%'                     -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%choice issue%'                       -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%working on choice update%'           -- Jodie decided on 11/07/2018
	AND FillRemarks NOT LIKE '%Choice MD gave samples%'             -- Jodie decided on 11/15/2018
	AND FillRemarks NOT LIKE '%other art tears choice%'             -- Jodie decided on 11/15/2018
	AND FillRemarks NOT LIKE '%ok%d Susan choice tw%'               -- Jodie decided on 11/15/2018
	AND FillRemarks NOT LIKE '%lidocaine is choice due to cost%'	-- Jodie decided on 11/15/2018
	AND FillRemarks NOT LIKE '%PT NOW WITH CHOICE MD%'              -- Jodie decided on 11/15/2018
	AND FillRemarks NOT LIKE '%pt ran out choice MD%'				-- Jodie decided on 11/15/2018
	)
ORDER BY ROW_NUMBER() OVER(PARTITION BY RxOutpatSID ORDER BY ReleaseDateTime DESC)
;                           

--Publish table of CHOICE prescriptions in the last year
EXEC [Maintenance].[PublishTable] 'CHOICE.Prescriptions', '#cleanchoice'


----------------------------------------------------------------------------
--*************************** CHOICE PROVIDERS *****************************
----------------------------------------------------------------------------

-- Numerator: All CHOICE fills by provider within the past year
DROP TABLE IF EXISTS #choicecount 
SELECT ProviderSID
	,CHOICECount = COUNT(RxOutpatSID) 
INTO #choicecount
FROM #cleanchoice
GROUP BY ProviderSID 

-- Denominator: All fills by provider within the past year
DROP TABLE IF EXISTS #allfills
SELECT ProviderSID
	,NonCHOICECount = COUNT(DISTINCT(RxOutpatSID)) 
INTO #allfills
FROM [RxOut].[RxOutpatFill]
WHERE ReleaseDateTime > CAST(CAST(GETDATE() - 366 AS DATE) AS DATETIME2(0))
GROUP BY ProviderSID

--Providers with at least one CHOICE prescription in the past year
DROP TABLE IF EXISTS #choicepercentage
SELECT non.ProviderSID
	,non.NonCHOICECount
	,choice.CHOICECount
	,CHOICEPercentage = FLOOR (CAST(choice.CHOICECount AS DECIMAL)/(non.NonCHOICECount) * 100)
INTO #choicepercentage
FROM #allfills as non
INNER JOIN #choicecount as choice ON non.ProviderSID = choice.ProviderSID

--Providers with over 25% or over 10 CHOICE prescriptions in the past year
DROP TABLE IF EXISTS #finalproviders
SELECT ProviderSID
	  ,NonCHOICECount
	  ,CHOICECount
	  ,CHOICEPercentage
INTO #finalproviders
FROM #choicepercentage
WHERE Choicepercentage >25
	OR CHOICECount > 10	-- Per Jodie on 11/14/2018

--Publish table of providers who are flagged as CHOICE in the last year
EXEC [Maintenance].[PublishTable] 'CHOICE.Providers', '#finalproviders'

EXEC [Log].[ExecutionEnd]

END