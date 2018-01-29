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
            FROM sys.objects AS constraints
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
