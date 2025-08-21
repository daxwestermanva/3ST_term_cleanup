﻿

CREATE View [Maintenance].[TableDetails] as

WITH DataPages AS (
	SELECT o.object_id, COALESCE(f.NAME, d.NAME) AS Storage, s.NAME AS SchemaName, o.NAME AS TableName, COUNT(DISTINCT p.partition_id) AS NumberOfPartitions, 
		CASE MAX(i.index_id) WHEN 1 THEN 'Cluster' ELSE 'Heap' END AS TableType, SUM(p.rows) AS [RowCount], SUM(a.total_pages) AS DataPages, p.data_compression_desc as TableCompression
	FROM sys.tables o
	INNER JOIN sys.indexes i ON i.object_id = o.object_id
	INNER JOIN sys.partitions p ON p.object_id = o.object_id AND p.index_id = i.index_id
	INNER JOIN sys.allocation_units a ON a.container_id = p.partition_id
	INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
	LEFT JOIN sys.filegroups f ON f.data_space_id = i.data_space_id
	LEFT JOIN sys.destination_data_spaces dds ON dds.partition_scheme_id = i.data_space_id AND dds.destination_id = p.partition_number
	LEFT JOIN sys.filegroups d ON d.data_space_id = dds.data_space_id
	WHERE o.type = 'U' AND i.index_id IN (0,1)
	GROUP BY s.NAME, COALESCE(f.NAME, d.NAME), o.NAME, o.object_id, p.data_compression_desc
), IndexPages AS (
	SELECT o.object_id, o.NAME AS TableName, COALESCE(f.NAME, d.NAME) AS Storage, COUNT(DISTINCT i.index_id) AS NumberOfIndexes, SUM(a.total_pages) AS IndexPages, p.data_compression_desc as IndexCompression
	FROM sys.objects o
	INNER JOIN sys.indexes i ON i.object_id = o.object_id
	INNER JOIN sys.partitions p ON p.object_id = o.object_id AND p.index_id = i.index_id
	INNER JOIN sys.allocation_units a ON a.container_id = p.partition_id
	LEFT JOIN sys.filegroups f ON f.data_space_id = i.data_space_id
	LEFT JOIN sys.destination_data_spaces dds ON dds.partition_scheme_id = i.data_space_id AND dds.destination_id = p.partition_number
	LEFT JOIN sys.filegroups d ON d.data_space_id = dds.data_space_id
	WHERE i.index_id <> 0
	GROUP BY o.NAME, o.object_id, COALESCE(f.NAME, d.NAME), p.data_compression_desc
)

SELECT DB_NAME() AS [DataBase], t.[SchemaName], t.[TableName], t.[SchemaName] + '.' + t.[TableName] as FullTableName,
	IIF(t.TableCompression <> 'PAGE','USE' + ' ' + DB_NAME() + ' ' + 'ALTER TABLE [' + t.[schemaName] + ']' + '.' + '[' + T.[tableName] + ']' + ' REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)','') AS 'EXECSQL',
	t.[TableType], t.[Storage] AS FileGroupName, t.[NumberOfPartitions], t.[RowCount], t.[DataPages], (t.[DataPages] * 8) AS SizeOfDataPagesKB, ISNULL(i.[NumberOfIndexes], 0) AS NumberOfIndexes,
	ISNULL(i.[IndexPages], 0) AS IndexPages, (ISNULL(i.[IndexPages], 0) * 8) AS SizeOfIndexPagesKB, i.IndexPages + t.DataPages AS TotalPages, ((i.IndexPages + t.DataPages) * 8) AS TotalKB,
	t.TableCompression, i.IndexCompression
FROM DataPages t
LEFT JOIN IndexPages i ON i.object_id = t.object_id AND i.Storage = t.Storage
Where TableCompression = 'NONE'