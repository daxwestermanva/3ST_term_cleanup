


/*******************************************************************************************************************************
Developer(s)	: Mina, Liam
Create Date		: 8/9/2024
Object Name		: [LookUp].[ZipState]

******************************************************************************************************************************/
CREATE   VIEW [LookUp].[ZipState]

AS 
 
	SELECT DISTINCT
		 StateCode
		,StateName
		,ZipCode
	FROM [NDim].[PyramidUSZipCode] WITH (NOLOCK)