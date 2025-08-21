

CREATE VIEW [LookUp].[DivisionFacility]
AS
	--2020/11/09 - Jason E Bacani - Updated view to use WITH (NOLOCK)
	SELECT 
		s.Sta6a
		, d.DivisionSID
		, d.DivisionName
		, s.ChecklistID
		, S.StaPa
		, c.Facility
	FROM [LookUp].[Sta6a] AS s WITH (NOLOCK)
	LEFT OUTER JOIN [LookUp].[ChecklistID] AS c WITH (NOLOCK)
		ON c.ChecklistID = s.ChecklistID 
	LEFT OUTER JOIN [Dim].[Division] AS d WITH (NOLOCK)
		ON d.Sta6a = s.Sta6a

