
CREATE PROCEDURE tSQLt.Private_ApplyForeignKeyConstraint 
  @ConstraintObjectId INT,
  @NoCascade BIT
AS
BEGIN
  DECLARE @SchemaName NVARCHAR(MAX);
  DECLARE @OrgTableName NVARCHAR(MAX);
  DECLARE @TableName NVARCHAR(MAX);
  DECLARE @ConstraintName NVARCHAR(MAX);
  DECLARE @CreateFkCmd NVARCHAR(MAX);
  DECLARE @AlterTableCmd NVARCHAR(MAX);
  DECLARE @CreateIndexCmd NVARCHAR(MAX);
  DECLARE @FinalCmd NVARCHAR(MAX);
  
  SELECT @SchemaName = SchemaName,
         @OrgTableName = OrgTableName,
         @TableName = TableName,
         @ConstraintName = OBJECT_NAME(@ConstraintObjectId)
    FROM tSQLt.Private_GetQuotedTableNameForConstraint(@ConstraintObjectId);
      
  SELECT @CreateFkCmd = cmd, @CreateIndexCmd = CreIdxCmd
    FROM tSQLt.Private_GetForeignKeyDefinition(@SchemaName, @OrgTableName, @ConstraintName, @NoCascade);
  SELECT @AlterTableCmd = 'ALTER TABLE ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + 
                          ' ADD ' + @CreateFkCmd;
  SELECT @FinalCmd = @CreateIndexCmd + @AlterTableCmd;

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
    PRINT 'Not created due to transaction_isolation_level = Snapshot: ' + @FinalCmd;
  ELSE
    EXEC (@FinalCmd);
END;
