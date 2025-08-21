


/*******************************************************************************************************************************
Developer(s)	: Mina, Liam
Create Date		: 8/9/2024
Object Name		: [LookUp].[StateCountry]

******************************************************************************************************************************/
CREATE   VIEW [LookUp].[StateCountry]

AS 
 
	SELECT DISTINCT b.StateCode
		,b.StateName
		,CASE WHEN b.StateCode IS NOT NULL THEN 'UNITED STATES' ELSE a.State END AS Country
		,CASE WHEN b.StateCode IS NOT NULL THEN 'US' ELSE a.StateAbbrev END AS CountryCode
	FROM [Dim].[State] a WITH (NOLOCK)
	LEFT JOIN [NDim].[PyramidUSZipCode] b WITH (NOLOCK)
		ON a.StateAbbrev=b.StateCode
	WHERE State NOT LIKE 'Z%' 
	AND StateAbbrev NOT LIKE 'Z%' 
	AND StateAbbrev NOT LIKE 'X%'
	AND State NOT IN ('COUNTRY NOT SPECIFIED','*Missing*')