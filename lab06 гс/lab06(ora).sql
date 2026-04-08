TRUNCATE TABLE Rentals DROP STORAGE;
TRUNCATE TABLE Vehicles DROP STORAGE;
TRUNCATE TABLE Users DROP STORAGE;
TRUNCATE TABLE Tariffs DROP STORAGE;
TRUNCATE TABLE VehicleModels DROP STORAGE;
TRUNCATE TABLE Roles DROP STORAGE;

DECLARE
    v_role_user_id   NUMBER;
    v_role_admin_id  NUMBER;
    v_user_id        NUMBER;
    v_veh_id         NUMBER;
BEGIN
    INSERT INTO Roles (RoleName) VALUES ('Администратор') RETURNING RoleID INTO v_role_admin_id;
    INSERT INTO Roles (RoleName) VALUES ('Пользователь') RETURNING RoleID INTO v_role_user_id;

    INSERT INTO VehicleModels (Brand, ModelName, MaxSpeedKMH, WeightLimitKG, VehicleType) 
    VALUES ('Ninebot', 'Max G30', 25, 100, 'самокат');
    INSERT INTO VehicleModels (Brand, ModelName, MaxSpeedKMH, WeightLimitKG, VehicleType) 
    VALUES ('Xiaomi', 'M365 Pro', 25, 100, 'самокат');
    INSERT INTO VehicleModels (Brand, ModelName, MaxSpeedKMH, WeightLimitKG, VehicleType) 
    VALUES ('Kugoo', 'Kirin M4', 45, 120, 'самокат');
    INSERT INTO VehicleModels (Brand, ModelName, MaxSpeedKMH, WeightLimitKG, VehicleType) 
    VALUES ('Giant', 'Escape 3', 35, 115, 'велосипед');
    INSERT INTO VehicleModels (Brand, ModelName, MaxSpeedKMH, WeightLimitKG, VehicleType) 
    VALUES ('Specialized', 'Sirrus', 40, 110, 'велосипед');

    INSERT INTO Tariffs (Name, UnlockPrice, MinutePrice) VALUES ('Стандарт', 2, 1);
    INSERT INTO Tariffs (Name, UnlockPrice, MinutePrice) VALUES ('Эконом', 1, 0.5);

    COMMIT;

    FOR i IN 1..250 LOOP
        INSERT INTO Users (FullName, Email, Phone, RoleID, Balance)
        VALUES (
            'Клиент ' || i, 
            'user' || i || '@mail.ru', 
            '+375' || (2900000 + i), 
            v_role_user_id,
            TRUNC(DBMS_RANDOM.VALUE(0, 500), 2)
        );
    END LOOP;

    FOR i IN 1..50 LOOP
        INSERT INTO Vehicles (QRCode, ModelID, TariffID, BatteryLevel, Status)
        VALUES (
            'QR-' || i || '-' || TRUNC(DBMS_RANDOM.VALUE(10, 99)),
            (SELECT ModelID FROM (SELECT ModelID FROM VehicleModels ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1),
            (SELECT TariffID FROM (SELECT TariffID FROM Tariffs ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1),
            TRUNC(DBMS_RANDOM.VALUE(20, 100)),
            'доступно'
        );
    END LOOP;
    COMMIT;

    FOR i IN 1..500 LOOP
        SELECT UserID INTO v_user_id FROM (SELECT UserID FROM Users ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;
        SELECT VehicleID INTO v_veh_id FROM (SELECT VehicleID FROM Vehicles ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;

        INSERT INTO Rentals (UserID, VehicleID, StartTime, EndTime, FixedMinutePrice, TotalCost, RentalStatus)
        VALUES (
            v_user_id, 
            v_veh_id, 
            TO_TIMESTAMP('2025-01-01', 'YYYY-MM-DD') + DBMS_RANDOM.VALUE(0, 365),
            NULL,
            5.00, 
            TRUNC(DBMS_RANDOM.VALUE(50, 600), 2), 
            'завершено'
        );
    END LOOP;

    UPDATE Rentals 
    SET EndTime = StartTime + (DBMS_RANDOM.VALUE(10, 120) / 1440)
    WHERE EndTime IS NULL;

    COMMIT;
END;
/

-- 2
SELECT 
    TO_CHAR(StartTime, 'YYYY') AS "год",
    'квартал ' || TO_CHAR(StartTime, 'Q') AS "квартал",
    TO_CHAR(StartTime, 'MM') AS "месяц",
    SUM(TotalCost) AS "выручка",
    CASE 
        WHEN GROUPING(TO_CHAR(StartTime, 'MM')) = 1 AND GROUPING(TO_CHAR(StartTime, 'Q')) = 0 
        THEN ' за квартал'
        WHEN GROUPING(TO_CHAR(StartTime, 'Q')) = 1 
        THEN ' за год'
    END AS "период"
FROM Rentals
WHERE RentalStatus = 'завершено'
GROUP BY ROLLUP (
    TO_CHAR(StartTime, 'YYYY'), 
    TO_CHAR(StartTime, 'Q'), 
    TO_CHAR(StartTime, 'MM')
)
ORDER BY 1, 2, 3;

-- 3
SELECT 
    vm.ModelName AS "модель",
    SUM(r.TotalCost) AS "выручка",
    ROUND(RATIO_TO_REPORT(SUM(r.TotalCost)) OVER() * 100, 2) || '%' AS "доля"
FROM Rentals r
JOIN Vehicles v ON r.VehicleID = v.VehicleID
JOIN VehicleModels vm ON v.ModelID = vm.ModelID
WHERE r.RentalStatus = 'завершено'
GROUP BY vm.ModelName
ORDER BY 2 DESC;

-- 6
SELECT 
    rol.RoleName AS "клиент",
    TO_CHAR(rent.StartTime, 'YYYY-MM') AS "месяц",
    SUM(rent.TotalCost) AS "сумма за месяц"
FROM Rentals rent
JOIN Users u ON rent.UserID = u.UserID
JOIN Roles rol ON u.RoleID = rol.RoleID
WHERE rent.RentalStatus = 'завершено'
  AND rent.StartTime >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -5)
GROUP BY rol.RoleName, TO_CHAR(rent.StartTime, 'YYYY-MM')
ORDER BY 2, 1;

-- 7
SELECT ModelName, QRCode, Total_Rents
FROM (
    SELECT 
        vm.ModelName,
        v.QRCode,
        COUNT(r.RentalID) AS Total_Rents,
        DENSE_RANK() OVER (
            PARTITION BY vm.ModelName 
            ORDER BY COUNT(r.RentalID) DESC
        ) AS Rnk
    FROM VehicleModels vm
    JOIN Vehicles v ON vm.ModelID = v.ModelID
    JOIN Rentals r ON v.VehicleID = r.VehicleID
    GROUP BY vm.ModelName, v.QRCode
) 
WHERE Rnk = 1;