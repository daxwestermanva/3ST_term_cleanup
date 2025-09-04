 
 
-- =============================================

-- Author:		Grace Chung

-- Create date: 2024-06-27

-- Description:	Format String.  

-- =============================================

CREATE FUNCTION [Dflt].[ufn_FormatName] 

(

	@aName varchar(max)

)

RETURNS varchar(max)

AS

BEGIN

	  SELECT @aName= rtrim(ltrim(Replace(Replace(Replace(Replace(@aName,' ',''),'-',''),'.',''),'''','')))

      RETURN @aName

END