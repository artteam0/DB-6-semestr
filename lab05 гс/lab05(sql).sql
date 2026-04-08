use blinova1;

DELETE FROM Rentals;
DELETE FROM Vehicles;
DELETE FROM Users;
DELETE FROM Roles;
DELETE FROM Tariffs;
DELETE FROM VehicleModels;

DBCC CHECKIDENT ('Rentals', RESEED, 0);
DBCC CHECKIDENT ('Vehicles', RESEED, 0);
DBCC CHECKIDENT ('Users', RESEED, 0);
DBCC CHECKIDENT ('Roles', RESEED, 0);
DBCC CHECKIDENT ('Tariffs', RESEED, 0);
DBCC CHECKIDENT ('VehicleModels', RESEED, 0);



INSERT INTO Roles (RoleName) VALUES ('Пользователь'), ('Админ'), ('Техник');
INSERT INTO VehicleModels (Brand, ModelName, MaxSpeedKMH, WeightLimitKG, VehicleType) VALUES 
('Ninebot', 'Max G30', 25, 120, 'самокат'),
('Xiaomi', 'M365 Pro', 25, 100, 'самокат'),
('Giant', 'Escape 3', 35, 110, 'велосипед'),
('Specialized', 'Sirrus', 40, 115, 'велосипед');

INSERT INTO Tariffs (Name, UnlockPrice, MinutePrice, IsActive) VALUES 
('Стандарт', 5.00, 1.00, 1),
('Премиум', 10.00, 5.00, 1),
('Ночной', 5.00, 3.00, 1);

INSERT INTO Users (FullName, Email, Phone, Balance, RoleID) VALUES 
('Кулешов Артем', 'kuliashov200@mail.com', '+79001112233', 500.00, 1),
('Рауба Арсений', 'govba@mail.com', '+79004445566', 1200.00, 1),
('Старовойтов Илья', 'tolst@gmail.com', '+79007778899', 0.00, 1),
('Статько Герман', 'nemec@service.com', '+79990000000', 10000.00, 2);


DECLARE @i INT = 1;
DECLARE @RandomName NVARCHAR(50);
DECLARE @RandomEmail NVARCHAR(50);
WHILE @i <= 100
BEGIN
    SET @RandomName = 'User_' + CAST(@i AS NVARCHAR(10));
    SET @RandomEmail = 'user' + CAST(@i AS NVARCHAR(10)) + '@example.com';
    INSERT INTO Users (FullName, Email, Phone, Balance, RoleID, CreatedAt)
    VALUES (
        @RandomName, 
        @RandomEmail, 
        '+37529' + CAST(1000000 + ABS(CHECKSUM(NEWID())) % 9000000 AS NVARCHAR(20)),
        CAST(ABS(CHECKSUM(NEWID())) % 1000 AS DECIMAL(10,2)),
        1,
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE())
    );SET @i = @i + 1;
END;


INSERT INTO Vehicles (QRCode, ModelID, TariffID, BatteryLevel, Status, Lat, Lon) VALUES 
('SC-001', 1, 1, 85, 'доступно', 53.9000, 27.5500),
('SC-002', 1, 2, 15, 'зарядка', 53.9010, 27.5510),
('BK-001', 3, 1, 100, 'доступно', 53.9020, 27.5520),
('SC-003', 2, 3, 45, 'доступно', 53.9030, 27.5530);

DELETE FROM Rentals;
DECLARE @i INT = 1;
WHILE @i <= 300
BEGIN
    INSERT INTO Rentals (UserID, VehicleID, StartTime, EndTime, FixedMinutePrice, TotalCost, RentalStatus)
    VALUES (
        (SELECT TOP 1 UserID FROM Users ORDER BY NEWID()),
        (SELECT TOP 1 VehicleID FROM Vehicles ORDER BY NEWID()),
        DATEADD(MINUTE, -ABS(CHECKSUM(NEWID())) % 525600, '20251231'),
        NULL, 
        5.00, 
        CAST(ABS(CHECKSUM(NEWID())) % 500 AS DECIMAL(10,2)),
        'завершено'
    );
    SET @i = @i + 1;
END;
UPDATE Rentals SET EndTime = DATEADD(MINUTE, 30, StartTime) WHERE EndTime IS NULL;



-- 2
SELECT 
    YEAR(StartTime) AS [Год],
    CASE 
        WHEN GROUPING(CHOOSE(MONTH(StartTime), 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2)) = 1 THEN 'За год'
        ELSE CAST(CHOOSE(MONTH(StartTime), 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2) AS VARCHAR) + '-е полугодие'
    END AS [Полугодие],
    DATEPART(QUARTER, StartTime) AS [Квартал],
    MONTH(StartTime) AS [Месяц],
    SUM(TotalCost) AS [Итого выручка]
FROM Rentals
WHERE RentalStatus = 'завершено'
GROUP BY ROLLUP (
    YEAR(StartTime), 
    CHOOSE(MONTH(StartTime), 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2),
    DATEPART(QUARTER, StartTime), 
    MONTH(StartTime)
);

-- 3
SELECT 
    VehicleID,
    SUM(TotalCost) AS VehicleTotal,
    CAST(SUM(TotalCost) * 100.0 / SUM(SUM(TotalCost)) OVER() AS DECIMAL(10,2)) AS [Total],
    CAST(SUM(TotalCost) * 100.0 / MAX(SUM(TotalCost)) OVER() AS DECIMAL(10,2)) AS [Max]
FROM Rentals
WHERE StartTime BETWEEN '20250101' AND '20251231' 
  AND RentalStatus = 'завершено'
GROUP BY VehicleID;

-- 4
CREATE or alter PROCEDURE GetUsersByPage
    @PageNum INT = 1,
    @PageSize INT = 20
AS
BEGIN
    SELECT FullName, Email, Phone, Balance, RoleID
    FROM (
        SELECT *, 
               ROW_NUMBER() OVER (ORDER BY CreatedAt DESC) AS RowNum
        FROM Users
    ) AS PagedUsers
    WHERE RowNum BETWEEN (@PageNum - 1) * @PageSize + 1 
                     AND @PageNum * @PageSize
    ORDER BY RowNum;
END;

EXEC GetUsersByPage @PageNum = 1, @PageSize = 20;
EXEC GetUsersByPage @PageNum = 3, @PageSize = 20;
EXEC GetUsersByPage @PageNum = 4, @PageSize = 20;


-- 5
INSERT INTO Rentals (UserID, VehicleID, StartTime, EndTime, FixedMinutePrice, TotalCost, RentalStatus)
SELECT TOP 5 UserID, VehicleID, StartTime, EndTime, FixedMinutePrice, TotalCost, RentalStatus 
FROM Rentals;


WITH RentalDuplicates AS (
    SELECT 
        RentalID,
		UserID,
        VehicleID,
        StartTime,
        ROW_NUMBER() OVER (
            PARTITION BY UserID, VehicleID, StartTime 
            ORDER BY RentalID
        ) AS DuplicateRank
    FROM Rentals
)
SELECT * FROM RentalDuplicates WHERE DuplicateRank > 1;
DELETE FROM Rentals WHERE RentalID IN (SELECT RentalID FROM RentalDuplicates WHERE DuplicateRank > 1);

SELECT COUNT(*) FROM Rentals;
select * from Rentals;

-- 6
SELECT DISTINCT
    r_role.RoleName AS [клиент],
    FORMAT(rent.StartTime, 'yyyy-MM') AS [Месяц],
    SUM(rent.TotalCost) OVER (
        PARTITION BY r_role.RoleID, FORMAT(rent.StartTime, 'yyyy-MM')
    ) AS [Выручка]
FROM Rentals rent
JOIN Users u ON rent.UserID = u.UserID
JOIN Roles r_role ON u.RoleID = r_role.RoleID
WHERE rent.StartTime >= DATEADD(MONTH, -6, '20260101')
  AND rent.StartTime < '20260101'
  AND rent.RentalStatus = 'завершено'
ORDER BY [Месяц], [клиент];

-- 7
WITH VehicleUsage AS (
    SELECT 
        vm.ModelName,
        v.QRCode,
        COUNT(r.RentalID) AS TotalRents,
        DENSE_RANK() OVER (
            PARTITION BY vm.ModelName 
            ORDER BY COUNT(r.RentalID) DESC
        ) AS PopularityRank
    FROM VehicleModels vm
    JOIN Vehicles v ON vm.ModelID = v.ModelID
    JOIN Rentals r ON v.VehicleID = r.VehicleID
    GROUP BY vm.ModelName, v.QRCode
)
SELECT ModelName, QRCode, TotalRents
FROM VehicleUsage
WHERE PopularityRank = 1;