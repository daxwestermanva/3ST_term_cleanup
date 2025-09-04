-- =============================================
-- Author:		Amy Robinson
-- Create date: 11/25/2016
-- Description:	Dataset for report parameters - Stations with National and VISN choices

-- MODIFICATIONS:
	-- 20180723 RAS: Added VISN to order by statement for reports that have multiple VISNs in parameter
	-- 20180912 JEB: Added alias to prefix VISN in order by statement to remove ambiguous column reference
	-- 20210401	RAS: Restructured to declare VISN list based on @VISN parameter value instead of 2 different queries.
				--   Removed Historic and IntegratedSta3n columns, added SortKey and added ORDER BY SortKey
				--	 Removed WHERE statement that limited to FacilityLevel=3 (this should be done in reports as needed)
	-- 20210406 RAS: Added @LSV parameter to allow for 1 SP for LSV and non-LSV usage of this dataset

/*
	EXEC [App].[p_Facility] @VISN = '-1',@User='VHA21\VHAPALSTEPHR6',@LSV=0
*/

-- =============================================
CREATE PROCEDURE [App].[p_Facility]
   @User VARCHAR(50)
  ,@VISN VARCHAR(500)  -- Datatype needs to be long enough to allow for multiple VISN selection where applicable
  ,@LSV BIT 		   -- Set to 0 to return all stations, set to 1 to limit to LSV-permissioned sites

AS
BEGIN
	SET NOCOUNT ON;

  -- For testing:
	-- DECLARE @VISN VARCHAR(500) = '-1'	,@LSV BIT =1, @User VARCHAR(50) = 'VHA21\VHAPALTolenE'
	-- DECLARE @VISN VARCHAR(500) = '21,22'	,@LSV BIT =1, @User VARCHAR(50) = 'VHA21\VHAPALTolenE'
	-- DECLARE @VISN VARCHAR(500) = '-1'	,@LSV BIT =0, @User	VARCHAR(50) = 'VHA21\VHAPALTolenE'

-- CREATE A LIST OF VISNs TO LIMIT THE SELECTION LIST IF REQUIRED
	DECLARE @VISNList TABLE (VISN VARCHAR(10))
	IF @VISN='-1'
		-- Allow -1 parameter to show all VISNs (or LSV-based list)
		BEGIN
			INSERT @VISNList  
			SELECT DISTINCT VISN FROM [LookUp].[ChecklistID] WITH (NOLOCK)
			WHERE ( -- Return the list of VISNs associated with patient-level permissions, plus national
					Sta3n IN (SELECT Sta3n FROM [App].[Access] (@User))
					--OR VISN = 0
					) 
				OR @LSV=0 --IF @LSV=0, then selects all VISNs	
		END	
		-- Or based on the selection from a VISN parameter
		ELSE
		BEGIN
		-- Otherwise, if @VISN<>'-1' then show the selected VISNs
			INSERT @VISNList  SELECT value FROM string_split(@VISN, ',')
		END

	 --SELECT * FROM @VISNList

-- CREATE A LIST OF STA3Ns TO LIMIT THE SELECTION LIST BASED ON LSV PERMISSIONS IF REQUIRED
	DECLARE @StaList TABLE (Sta3n SMALLINT) 
	IF @LSV = 1
		BEGIN
			INSERT @StaList SELECT Sta3n FROM [App].[Access] (@User)
			-- NOTE: This will NOT include a "National" or VISN level option.
			-- If the user should be able to view patient data at multiple facilities, in SSRS set the parameter to allow multiple values.
		END
		ELSE
		BEGIN
			INSERT @StaList 
				SELECT DISTINCT Sta3n FROM [LookUp].[ChecklistID] st WITH (NOLOCK)
				INNER JOIN @VISNList v ON v.VISN=st.VISN
				--NOTE: This will include National and VISN level rows.
		END
		
	--SELECT * FROM @StaList

-- PULL LIST OF STATIONS FROM LOOKUP TABLE JOINED TO VISN AND LSV LIMITATIONS
SELECT 
	cl.ChecklistID
	--,cl.StaPa
	,cl.VISN
	,cl.Sta3n
	,cl.STA6AID
	,cl.Facility
	,cl.Facility + ' | ' + cl.STA6AID  as FaciltySta
	,cl.ADMPARENT_FCDM
	,cl.FacilityLevelID
	,cl.ADMPSortKey
FROM [LookUp].[ChecklistID] as cl WITH (NOLOCK)
INNER JOIN @StaList st ON cl.STA3N = st.Sta3n
INNER JOIN @VISNList v ON v.VISN=cl.VISN
ORDER BY cl.ADMPSortKey

END
