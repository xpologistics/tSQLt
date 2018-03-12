IF OBJECT_ID('tSQLt.Private_GetQuotedTableNameForConstraint') IS NOT NULL DROP FUNCTION tSQLt.Private_GetQuotedTableNameForConstraint;
IF OBJECT_ID('tSQLt.Private_FindConstraint') IS NOT NULL DROP FUNCTION tSQLt.Private_FindConstraint;
IF OBJECT_ID('tSQLt.Private_FindAllConstraints') IS NOT NULL DROP FUNCTION tSQLt.Private_FindAllConstraints;
IF OBJECT_ID('tSQLt.Private_GetUniqueIndexDefinition') IS NOT NULL DROP FUNCTION tSQLt.Private_GetUniqueIndexDefinition;
IF OBJECT_ID('tSQLt.Private_ResolveApplyConstraintParameters') IS NOT NULL DROP FUNCTION tSQLt.Private_ResolveApplyConstraintParameters;
IF OBJECT_ID('tSQLt.Private_ApplyCheckConstraint') IS NOT NULL DROP PROCEDURE tSQLt.Private_ApplyCheckConstraint;
IF OBJECT_ID('tSQLt.Private_ApplyForeignKeyConstraint') IS NOT NULL DROP PROCEDURE tSQLt.Private_ApplyForeignKeyConstraint;
IF OBJECT_ID('tSQLt.Private_ApplyUniqueConstraint') IS NOT NULL DROP PROCEDURE tSQLt.Private_ApplyUniqueConstraint;
IF OBJECT_ID('tSQLt.Private_ApplyUniqueIndex') IS NOT NULL DROP PROCEDURE tSQLt.Private_ApplyUniqueIndex;
IF OBJECT_ID('tSQLt.Private_GetConstraintType') IS NOT NULL DROP FUNCTION tSQLt.Private_GetConstraintType;
IF OBJECT_ID('tSQLt.ApplyConstraint') IS NOT NULL DROP PROCEDURE tSQLt.ApplyConstraint;
GO
---Build+
GO
CREATE FUNCTION tSQLt.Private_GetQuotedTableNameForConstraint(@ConstraintObjectId INT)
RETURNS TABLE
AS
RETURN
  SELECT QUOTENAME(SCHEMA_NAME(newtbl.schema_id)) + '.' + QUOTENAME(OBJECT_NAME(newtbl.object_id)) QuotedTableName,
         SCHEMA_NAME(newtbl.schema_id) SchemaName,
         OBJECT_NAME(newtbl.object_id) TableName,
         OBJECT_NAME(constraints.parent_object_id) OrgTableName
      FROM sys.objects AS constraints
      JOIN sys.extended_properties AS p
      JOIN sys.objects AS newtbl
        ON newtbl.object_id = p.major_id
       AND p.minor_id = 0
       AND p.class_desc = 'OBJECT_OR_COLUMN'
       AND p.name = 'tSQLt.FakeTable_OrgTableName'
        ON OBJECT_NAME(constraints.parent_object_id) = CAST(p.value AS NVARCHAR(4000))
       AND constraints.schema_id = newtbl.schema_id
       AND constraints.object_id = @ConstraintObjectId;
GO

CREATE FUNCTION tSQLt.Private_FindConstraint
(
  @TableObjectId INT,
  @ConstraintName NVARCHAR(MAX)
)
RETURNS TABLE
AS
RETURN
  SELECT TOP(1) constraints.object_id AS ConstraintObjectId, type_desc AS ConstraintType
    FROM sys.objects constraints
    CROSS JOIN tSQLt.Private_GetOriginalTableInfo(@TableObjectId) orgTbl
   WHERE @ConstraintName IN (constraints.name, QUOTENAME(constraints.name))
     AND constraints.parent_object_id = orgTbl.OrgTableObjectId
   ORDER BY LEN(constraints.name) ASC;
GO

CREATE FUNCTION tSQLt.Private_FindAllConstraints
(
  @TableObjectId INT
)
RETURNS TABLE
AS
RETURN
  SELECT TOP 100 PERCENT
         ConstraintObjectId, ConstraintType, name, index_id
    FROM (
          SELECT constraints.object_id AS ConstraintObjectId, type_desc AS ConstraintType, constraints.name, 0 as index_id
            FROM sys.objects constraints
           WHERE constraints.parent_object_id = @TableObjectId
           UNION ALL
          SELECT indexes.object_id AS ConstraintObjectId, CASE WHEN indexes.is_unique = 1 THEN 'UNIQUE_' ELSE '' END + 'INDEX' AS ConstraintType, indexes.name, indexes.index_id
            FROM sys.indexes AS indexes
           WHERE indexes.object_id = @TableObjectId
             AND indexes.is_unique_constraint = 0
             AND indexes.is_primary_key = 0
        ) constraints
   ORDER BY CASE ConstraintType 
                 WHEN 'PRIMARY_KEY_CONSTRAINT' THEN '1'
                 WHEN 'UNIQUE_CONSTRAINT' THEN '2'
                 WHEN 'CHECK_CONSTRAINT' THEN '3'
                 WHEN 'UNIQUE_INDEX' THEN '4'
                 WHEN 'INDEX' THEN '5'
                 WHEN 'DEFAULT_CONSTRAINT' THEN '6'
                 WHEN 'FOREIGN_KEY_CONSTRAINT' THEN '7'
                 ELSE ConstraintType 
            END
   ASC;
GO

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
GO

CREATE FUNCTION tSQLt.Private_ResolveApplyConstraintParameters
(
  @A NVARCHAR(MAX),
  @B NVARCHAR(MAX),
  @C NVARCHAR(MAX)
)
RETURNS TABLE
AS 
RETURN
  SELECT ConstraintObjectId, ConstraintType
    FROM tSQLt.Private_FindConstraint(OBJECT_ID(@A), @B)
   WHERE @C IS NULL
   UNION ALL
  SELECT *
    FROM tSQLt.Private_FindConstraint(OBJECT_ID(@A + '.' + @B), @C)
   UNION ALL
  SELECT *
    FROM tSQLt.Private_FindConstraint(OBJECT_ID(@C + '.' + @A), @B);
GO

CREATE PROCEDURE tSQLt.Private_ApplyCheckConstraint
  @ConstraintObjectId INT
AS
BEGIN
  DECLARE @Cmd NVARCHAR(MAX);
  SELECT @Cmd = 'CONSTRAINT ' + QUOTENAME(name) + ' CHECK' + definition 
    FROM sys.check_constraints
   WHERE object_id = @ConstraintObjectId;
  
  DECLARE @QuotedTableName NVARCHAR(MAX);
  
  SELECT @QuotedTableName = QuotedTableName FROM tSQLt.Private_GetQuotedTableNameForConstraint(@ConstraintObjectId);

  EXEC tSQLt.Private_RenameObjectToUniqueNameUsingObjectId @ConstraintObjectId;
  SELECT @Cmd = 'ALTER TABLE ' + @QuotedTableName + ' ADD ' + @Cmd
    FROM sys.objects 
   WHERE object_id = @ConstraintObjectId;

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
    PRINT 'Not created due to transaction_isolation_level = Snapshot: ' + @Cmd;
  ELSE
    EXEC (@Cmd);

END; 
GO

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
GO

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
GO

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
GO

CREATE FUNCTION tSQLt.Private_GetConstraintType(@TableObjectId INT, @ConstraintName NVARCHAR(MAX))
RETURNS TABLE
AS
RETURN
  SELECT object_id,type,type_desc
    FROM sys.objects 
   WHERE object_id = OBJECT_ID(SCHEMA_NAME(schema_id)+'.'+@ConstraintName)
     AND parent_object_id = @TableObjectId;
GO

CREATE PROCEDURE tSQLt.ApplyConstraint
       @TableName NVARCHAR(MAX),
       @ConstraintName NVARCHAR(MAX),
       @SchemaName NVARCHAR(MAX) = NULL, --parameter preserved for backward compatibility. Do not use. Will be removed soon.
       @NoCascade BIT = 0
AS
BEGIN
  DECLARE @ConstraintType NVARCHAR(MAX);
  DECLARE @ConstraintObjectId INT;
  
  SELECT @ConstraintType = ConstraintType, @ConstraintObjectId = ConstraintObjectId
    FROM tSQLt.Private_ResolveApplyConstraintParameters (@TableName, @ConstraintName, @SchemaName);

  IF @ConstraintType = 'CHECK_CONSTRAINT'
  BEGIN
    EXEC tSQLt.Private_ApplyCheckConstraint @ConstraintObjectId;
    RETURN 0;
  END

  IF @ConstraintType = 'FOREIGN_KEY_CONSTRAINT'
  BEGIN
    EXEC tSQLt.Private_ApplyForeignKeyConstraint @ConstraintObjectId, @NoCascade;
    RETURN 0;
  END;  
   
  IF @ConstraintType IN('UNIQUE_CONSTRAINT', 'PRIMARY_KEY_CONSTRAINT')
  BEGIN
    EXEC tSQLt.Private_ApplyUniqueConstraint @ConstraintObjectId;
    RETURN 0;
  END;  

  IF @ConstraintType = 'UNIQUE_INDEX'
  BEGIN
    EXEC tSQLt.Private_ApplyUniqueIndex @ConstraintObjectId, @ConstraintName;
    RETURN 0;
  END;  
  
   
  RAISERROR ('ApplyConstraint could not resolve the object names, ''%s'', ''%s''. Be sure to call ApplyConstraint and pass in two parameters, such as: EXEC tSQLt.ApplyConstraint ''MySchema.MyTable'', ''MyConstraint''', 
             16, 10, @TableName, @ConstraintName);
  RETURN 0;
END;
GO
---Build-
