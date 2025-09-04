SELECT TOP 1 WITH TIES MVIPersonSID
	,ChecklistID
	,TargetClass
	,SubclassLabel
	,Term
	,EntryDateTime
	,ReferenceDateTime
	,TIUDocumentDefinition
	,Snippet
	,StaffName
FROM #AddTIU  -- pipeline_source\Code\Stored Procedures\tmp_table_AddTIU.sql
ORDER BY ROW_NUMBER() OVER (PARTITION BY TIUDocumentSID, TargetClass ORDER BY NoteAndSnipOffset)
