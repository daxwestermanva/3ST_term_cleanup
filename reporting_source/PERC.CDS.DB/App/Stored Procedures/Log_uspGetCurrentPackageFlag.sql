	
CREATE PROCEDURE [App].[Log_uspGetCurrentPackageFlag]
	(@PackageID VARCHAR(50)
	,@SourceID VARCHAR(50) 
	,@CurrentPackageFlag BIT OUTPUT)
AS

/**********************************************************************************************************
* SP Name:	App.Log_uspGetCurrentPackageFlag
*
* Parameters:
*		@PackageID			GUID for the SSIS Package
*		@SourceID			GUID for the task that is being logged.  This will be the same as the PackageID for the 1st time around
*		@CurrentPackageFlag	OUTPUT variable.  BIT indicating wether the SourceID belongs to the current package 
*
* Purpose:	This stored procedure checks to see if the task with ID @SourceID belongs to the pacakge @PackageID
*				@CurrentPackageFlag is returned
*					TRUE - if the task belongs to the package
*					FALSE - if the task does not belong to the package
*
* Revision Date/Time:
*
**********************************************************************************************************/

	--Check to see if the task belongs to the current pacakge
	SELECT @CurrentPackageFlag = CASE WHEN COUNT(*) = 0 THEN 0 ELSE 1 END
	FROM App.Log_ContainerList WITH (NOLOCK)
	WHERE TaskID = @SourceID
	AND PackageID = @PackageID	
	RETURN @CurrentPackageFlag