
CREATE PROCEDURE tSQLt.Private_ApplyUniqueIndex
   @ConstraintObjectId INT
  ,@ConstraintName NVARCHAR(MAX)
AS
BEGIN
  DECLARE @SchemaName NVARCHAR(MAX);
  DECLARE @OrgTableName NVARCHAR(MAX);
  DECLARE @TableName NVARCHAR(MAX);
  DECLARE @CreateConstraintCmd NVARCHAR(MAX);
  DECLARE @IndexId INT;

  SELECT @SchemaName = OBJECT_SCHEMA_NAME(OBJECT_ID(OriginalName)),
         @OrgTableName = OBJECT_ID(OriginalName),
         @TableName = OBJECT_NAME(OBJECT_ID(OriginalName))
    FROM tSQLt.Private_RenamedObjectLog
   WHERE ObjectId = @ConstraintObjectId;

  SELECT @IndexId = IX.index_id
    FROM sys.indexes AS IX
   WHERE IX.object_id = @ConstraintObjectId
   AND IX.name = @ConstraintName
   AND IX.is_unique = 1
   AND IX.is_unique_constraint = 0
   AND IX.is_primary_key = 0;

  SELECT @CreateConstraintCmd = CreateConstraintCmd
    FROM tSQLt.Private_GetUniqueIndexDefinition(@ConstraintObjectId, @IndexId, QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName));

  IF (	SELECT	CASE transaction_isolation_level 
				WHEN 0 THEN 'Unspecified' 
				WHEN 1 THEN 'ReadUncommitted' 
				WHEN 2 THEN 'ReadCommitted' 
				WHEN 3 THEN 'Repeatable' 
				WHEN 4 THEN 'Serializable' 
				WHEN 5 THEN 'Snapshot' END AS TRANSACTION_ISOLATION_LEVEL 
		FROM	sys.dm_exec_sessions 
		WHERE	session_id = @@SPID 
	  ) = 'Snapshot'
    PRINT 'Not created due to transaction_isolation_level = Snapshot: ' + @CreateConstraintCmd;
  ELSE
    EXEC (@CreateConstraintCmd);
END;
