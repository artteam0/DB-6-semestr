USE blinova1;

-- 6
SELECT DISTINCT 
    geom.STGeometryType() as geom_type,
    geom.STSrid as srid
FROM ne_10m_land;

-- 8
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'ne_10m_land'
  AND data_type NOT IN ('geometry', 'geography');

-- 9
SELECT TOP 10 
    qgs_fid as id, 
    geom.STAsText() AS wkt_geometry 
FROM ne_10m_land;

-- 10.1
SELECT TOP 10
    t1.qgs_fid, 
    t2.qgs_fid, 
    t1.geom.STIntersection(t2.geom).STAsText() as intersection_wkt
FROM ne_10m_land t1
CROSS JOIN ne_10m_land t2
WHERE t1.qgs_fid <> t2.qgs_fid 
  AND t1.geom.STIntersects(t2.geom) = 1;

-- 10.2
SELECT TOP 10
    qgs_fid, 
    geom.STPointN(1).STAsText() AS first_vertex,
    geom.STNumPoints() AS total_vertices
FROM ne_10m_land;

-- 10.3 
SELECT 
    qgs_fid, 
    geom.STArea() AS area_units 
FROM ne_10m_land;

-- 11
DECLARE @g_point geometry = geometry::STGeomFromText('POINT(27.56 53.90)', 4326); 
DECLARE @g_line  geometry = geometry::STGeomFromText('LINESTRING(-1.0 50.0, 1.0 51.0)', 4326);
DECLARE @g_poly  geometry = geometry::STGeomFromText('POLYGON((120 -20, 130 -20, 130 -30, 120 -30, 120 -20))', 4326);

-- 12
SELECT 
    'Point' AS [Тип тестового объекта],
    qgs_fid, 
    featurecla,
    NULL AS relation_type,
    CAST(NULL AS FLOAT) AS overlap_value
FROM ne_10m_land 
WHERE geom.STContains(@g_point) = 1

UNION ALL

SELECT 
    'Line' AS [Тип тестового объекта],
    qgs_fid, 
    featurecla,
    'Intersects' AS relation_type,
    ROUND(geom.STIntersection(@g_line).STLength(), 4) AS overlap_value
FROM ne_10m_land 
WHERE geom.STIntersects(@g_line) = 1

UNION ALL

SELECT 
    'Polygon' AS [Тип тестового объекта],
    qgs_fid, 
    featurecla,
    'Contains' AS relation_type,
    ROUND(geom.STIntersection(@g_poly).STArea(), 4) AS overlap_value
FROM ne_10m_land 
WHERE geom.STContains(@g_poly) = 1
ORDER BY [Тип тестового объекта], qgs_fid;


SELECT qgs_fid 
FROM ne_10m_land
WHERE geom.STContains(@g_point) = 1;

-- 13
IF EXISTS (SELECT * FROM sys.spatial_indexes WHERE name = 'idx_spatial_land')
    DROP INDEX idx_spatial_land ON ne_10m_land;

CREATE SPATIAL INDEX idx_spatial_land ON ne_10m_land(geom)
USING GEOMETRY_GRID
WITH (BOUNDING_BOX = (XMIN=-180, YMIN=-90, XMAX=180, YMAX=90));

-- 14
CREATE OR ALTER PROCEDURE find_object_by_coords
    @lon FLOAT,
    @lat FLOAT
AS
BEGIN
    DECLARE @p geometry = geometry::STGeomFromText('POINT(' + CAST(@lon AS VARCHAR) + ' ' + CAST(@lat AS VARCHAR) + ')', 4326);
    SELECT TOP 1
        qgs_fid, 
        featurecla
    FROM ne_10m_land
    WHERE geom.STIntersects(@p) = 1;
END;

EXEC find_object_by_coords @lon = 27.56, @lat = 53.90;