
CREATE PROCEDURE tSQLt.Private_ApplyUniqueConstraint 
  @ConstraintObjectId INT
AS
BEGIN
  DECLARE @SchemaName NVARCHAR(MAX);
  DECLARE @OrgTableName NVARCHAR(MAX);
  DECLARE @TableName NVARCHAR(MAX);
  DECLARE @ConstraintName NVARCHAR(MAX);
  DECLARE @CreateConstraintCmd NVARCHAR(MAX);
  DECLARE @AlterColumnsCmd NVARCHAR(MAX);
  
  SELECT @SchemaName = SchemaName,
         @OrgTableName = OrgTableName,
         @TableName = TableName,
         @ConstraintName = OBJECT_NAME(@ConstraintObjectId)
    FROM tSQLt.Private_GetQuotedTableNameForConstraint(@ConstraintObjectId);
      
  SELECT @AlterColumnsCmd = NotNullColumnCmd,
         @CreateConstraintCmd = CreateConstraintCmd
    FROM tSQLt.Private_GetUniqueConstraintDefinition(@ConstraintObjectId, QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName));

  EXEC tSQLt.Private_RenameObjectToUniqueName @SchemaName, @ConstraintName;
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
    PRINT 'Not created due to transaction_isolation_level = Snapshot: ' + @AlterColumnsCmd;
  ELSE
    EXEC (@AlterColumnsCmd);

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
