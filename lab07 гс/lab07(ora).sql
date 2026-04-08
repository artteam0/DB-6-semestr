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

    FOR i IN 1..10 LOOP
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

    FOR i IN 1..250 LOOP
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

select * from Rentals;

-- model
SELECT UserID, Month, Predicted_Cost
FROM (
    SELECT 
        UserID, 
        TRUNC(StartTime, 'MM') as Month, 
        SUM(TotalCost) as Monthly_Sum
    FROM Rentals
    GROUP BY UserID, TRUNC(StartTime, 'MM')
)
MODEL 
    PARTITION BY (UserID)
    DIMENSION BY (Month)
    MEASURES (Monthly_Sum AS Predicted_Cost)
    RULES (
        Predicted_Cost[FOR Month FROM TO_DATE('2026-01-01', 'YYYY-MM-DD') 
                       TO TO_DATE('2026-12-01', 'YYYY-MM-DD') INCREMENT INTERVAL '1' MONTH] = 
            Predicted_Cost[ADD_MONTHS(CV(), -12)] * 1.10 )
ORDER BY UserID, Month;




-- match recognize
SELECT *
FROM (
    SELECT 
        vm.ModelName, 
        TRUNC(r.StartTime, 'MM') as R_Month, 
        AVG(r.TotalCost) as Avg_Cost
    FROM Rentals r
    JOIN Vehicles v ON r.VehicleID = v.VehicleID
    JOIN VehicleModels vm ON v.ModelID = vm.ModelID
    GROUP BY vm.ModelName, TRUNC(r.StartTime, 'MM')
)
MATCH_RECOGNIZE (
    PARTITION BY ModelName
    ORDER BY R_Month
    MEASURES 
        FIRST(UP.R_Month) AS Start_Trend,
        LAST(UP2.R_Month) AS End_Trend,
        STRT.Avg_Cost AS Base_Price,
        UP.Avg_Cost AS Peak_Price,
        DOWN.Avg_Cost AS Low_Price,
        UP2.Avg_Cost AS Recovery_Price
    ONE ROW PER MATCH
    PATTERN (STRT UP+ DOWN+ UP2+)
    DEFINE 
        UP AS Avg_Cost > PREV(Avg_Cost),
        DOWN AS Avg_Cost < PREV(Avg_Cost),
        UP2 AS Avg_Cost > PREV(Avg_Cost));