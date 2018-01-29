
CREATE FUNCTION tSQLt.Private_FindConstraint
(
  @TableObjectId INT,
  @ConstraintName NVARCHAR(MAX)
)
RETURNS TABLE
AS
RETURN
  SELECT TOP(1) constraints.object_id AS ConstraintObjectId, type_desc AS ConstraintType
    FROM sys.objects AS constraints
    CROSS JOIN tSQLt.Private_GetOriginalTableInfo(@TableObjectId) orgTbl
   WHERE @ConstraintName IN (constraints.name, QUOTENAME(constraints.name))
     AND constraints.parent_object_id = orgTbl.OrgTableObjectId
   UNION ALL
  SELECT TOP(1) indexes.object_id AS ConstraintObjectId, 'UNIQUE_INDEX' AS ConstraintType
    FROM sys.indexes AS indexes
    CROSS JOIN tSQLt.Private_GetOriginalTableInfo(@TableObjectId) orgTbl
   WHERE @ConstraintName IN (indexes.name, QUOTENAME(indexes.name))
     AND indexes.object_id = orgTbl.OrgTableObjectId
     AND indexes.is_unique = 1
     AND indexes.is_unique_constraint = 0
     AND indexes.is_primary_key = 0
   ORDER BY ConstraintType ASC;
