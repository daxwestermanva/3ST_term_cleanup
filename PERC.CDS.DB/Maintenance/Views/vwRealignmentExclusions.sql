


CREATE VIEW [Maintenance].[vwRealignmentExclusions]
AS
SELECT t.object_id AS ObjectID
	,s.name as SchemaName
	,t.name as TableName 
	,t.schema_id as SchemaID
FROM sys.tables t
	LEFT JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.name LIKE 'Log%'
	OR t.name LIKE 'MVIPersonSIDPatientPersonSID%'
	OR t.name IN ('RiskScoreHistoric'
		,'DatabaseChangeLog'	-- RAS 2025-05-21 Added per ADO variables used in pipeline
		,'UserActivityLog'		-- RAS 2025-05-21 Added per ADO variables used in pipeline
		) 
	OR s.name IN ('Log','MillWork','DeltaView') -- RAS 2025-05-21 Added MillCDS and DeltaView per ADO variables used in pipeline
	OR t.[temporal_type] IN (1,2) -- RAS 2021-12-13 Added exclusion of system-versioned tables