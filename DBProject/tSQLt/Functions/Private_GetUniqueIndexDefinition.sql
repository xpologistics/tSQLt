CREATE FUNCTION tSQLt.Private_GetUniqueIndexDefinition
(
    @ConstraintObjectId INT,
	@IndexId INT,
    @QuotedTableName NVARCHAR(MAX)
)
RETURNS TABLE
AS
RETURN
  SELECT 'CREATE UNIQUE ' + 
		 IX.type_desc +
		 ' INDEX '+
         QUOTENAME(tSQLt.Private::CreateUniqueObjectName() + '_' + IX.name) COLLATE SQL_Latin1_General_CP1_CI_AS+
         ' ON ' +
         @QuotedTableName +
         ' ' +
         '(' +
         STUFF((
                 SELECT ','+QUOTENAME(C.name)+CASE IC.is_descending_key WHEN 1 THEN ' DESC' ELSE ' ASC' END
                   FROM sys.index_columns AS IC
                   JOIN sys.columns AS C
                     ON IC.object_id = C.object_id
                    AND IC.column_id = C.column_id
                  WHERE IX.index_id = IC.index_id
                    AND IX.object_id = IC.object_id
					AND IX.index_id = @IndexId
					AND IC.is_included_column = 0
                    FOR XML PATH(''),TYPE
               ).value('.','NVARCHAR(MAX)'),
               1,
               1,
               ''
              ) +
         ') ' + 
		 ISNULL(NULLIF(
		 'INCLUDE (' +
         STUFF((
                 SELECT ','+QUOTENAME(C.name)
                   FROM sys.index_columns AS IC
                   JOIN sys.columns AS C
                     ON IC.object_id = C.object_id
                    AND IC.column_id = C.column_id
                  WHERE IX.index_id = IC.index_id
                    AND IX.object_id = IC.object_id
					AND IX.index_id = @IndexId
					AND IC.is_included_column = 1
                    FOR XML PATH(''),TYPE
               ).value('.','NVARCHAR(MAX)'),
               1,
               1,
               ''
              ) +
         ') ', 'INCLUDE () '),'') + 
		 ISNULL('WHERE ' + filter_definition,'') + ';' AS CreateConstraintCmd
    FROM sys.indexes AS IX
   WHERE IX.object_id = @ConstraintObjectId
   AND IX.index_id = @IndexId
   AND IX.is_unique = 1
   AND IX.is_unique_constraint = 0
   AND IX.is_primary_key = 0;
