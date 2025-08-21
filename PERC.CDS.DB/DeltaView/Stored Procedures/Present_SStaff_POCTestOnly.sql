






-- =============================================
-- Author:		Liam Mina
-- Create date: 2021-10-08
-- Description:	Get SSN and network username for all staff, to get permissions for CRISTAL and STORM SSN lookup reports

-- UPDATE:	

-- =============================================

CREATE PROCEDURE [DeltaView].[Present_SStaff_POCTestOnly]
AS
BEGIN

	DROP TABLE IF EXISTS #Staff
	SELECT DISTINCT
		a.NetworkUsername
		,a.StaffSSN
	INTO #Staff
	FROM 
		SStaff.SStaff a WITH (NOLOCK)
		/*<Vista>INNER JOIN $DeltaKeyTable VDK WITH (NOLOCK) ON VDK.StaffSID = a.StaffSID</Vista>*/; 

	CREATE CLUSTERED INDEX UserName ON #Staff (NetworkUsername);


	DROP TABLE IF EXISTS #StaffSID
	SELECT DISTINCT
		a.StaffSID
		,a.NetworkUsername
		,a.StaffSSN
	INTO #StaffSID
	FROM 
		SStaff.SStaff a WITH (NOLOCK)
		/*<Vista>INNER JOIN $DeltaKeyTable VDK WITH (NOLOCK) ON VDK.StaffSID = a.StaffSID</Vista>*/;
		
	CREATE CLUSTERED INDEX StaffSID ON #StaffSID (StaffSID);


	BEGIN TRY

		BEGIN TRAN;

		IF( SELECT COUNT([NetworkUsername]) FROM DeltaView.SStaff_POCTestOnly) > 0
			BEGIN
				DELETE T
				FROM 
					DeltaView.SStaff_POCTestOnly T
					INNER JOIN #Staff S
						ON ISNULL(S.[NetworkUsername], '') = ISNULL(T.[NetworkUsername], '')
						AND ISNULL(S.[StaffSSN], '') = ISNULL(T.[StaffSSN], '');			
			END


		INSERT INTO DeltaView.SStaff_POCTestOnly
		([StaffSSN]
		,[NetworkUsername])
		SELECT
			[StaffSSN]
			,[NetworkUsername]
		FROM
			#Staff;
		

		IF( SELECT COUNT([NetworkUsername]) FROM DeltaView.SStaffSID_POCTestOnly) > 0
			BEGIN
				DELETE T
				FROM 
					DeltaView.SStaffSID_POCTestOnly T
					INNER JOIN #StaffSID S
						ON S.[StaffSID] = T.[StaffSID];
					
			END


		INSERT INTO [DeltaView].[SStaffSID_POCTestOnly]
		([StaffSID]
		,[StaffSSN]
		,[NetworkUsername])
		SELECT
			[StaffSID]
			,[StaffSSN]
			,[NetworkUsername]
		FROM
			#StaffSID;


		COMMIT;

	END TRY
	BEGIN CATCH

		ROLLBACK

	END CATCH

END