
CREATE PROCEDURE [App].[Log_uspSetContainerListOnPreExecute]
	(@PackageID VARCHAR(50)
	,@SourceID VARCHAR(50) 
	,@ParentSourceID VARCHAR(50)
	,@PackageName VARCHAR(50)
	,@SourceName VARCHAR(50)
	,@SourceDesc VARCHAR(50))
AS

/**********************************************************************************************************
* SP Name:	App.Log_uspSetContainerListOnPreExecute
*
* Parameters:
*		@PackageID			GUID for the SSIS Package
*		@SourceID			GUID for the task that is being logged.  This will be the same as the PackageID for the 1st time around
*		@ParentSourceID		GUID for the parent task that is calling the task
*
* Purpose:	This stored procedure logs each SSIS package that gets called and the tasks that are executed within that package.
*				When a child package is executed, the child tasks will not be added to the table

* Revision Date/Time:
*	
**********************************************************************************************************/

	--The 1st time the Pre Execute gets called the PackageID will = the SourceID
	IF @PackageID = @SourceID
		AND NOT EXISTS 
		(   SELECT  1
			FROM    App.Log_ContainerList 
			WHERE   PackageID = @PackageID )
	BEGIN
		INSERT INTO App.Log_ContainerList([PackageID],[TaskID],[PackageName],[TaskName],[TaskDesc]) 
		VALUES(@PackageID,@SourceID,@PackageName,@SourceName, 'Package Begin')
		
	END 
	
	--Only Add a record if the ParentSourceID belongs to that package.
	--	Otherwise the ParentSoureID is comming from a child package
	INSERT INTO App.Log_ContainerList([PackageID],[TaskID],[PackageName],[TaskName],[TaskDesc]) 
	SELECT TOP 1 @PackageID, @SourceID, @PackageName, @SourceName, @SourceDesc
	FROM App.Log_ContainerList
	WHERE TaskID = @ParentSourceID
	AND PackageID = @PackageID
	AND NOT EXISTS(SELECT * FROM App.Log_ContainerList WHERE PackageID = @SourceID)
	AND NOT EXISTS(SELECT * FROM App.Log_ContainerList 
					WHERE PackageID = @PackageID 
					AND TaskID = @SourceID)