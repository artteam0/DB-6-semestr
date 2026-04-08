INSERT INTO Roles (RoleName) VALUES ('Клиент');
INSERT INTO Roles (RoleName) VALUES ('Админ');
INSERT INTO Tariffs (Name, UnlockPrice, MinutePrice) VALUES ('Стандарт', 50, 5);
INSERT INTO Tariffs (Name, UnlockPrice, MinutePrice) VALUES ('Бизнес', 0, 12);
INSERT INTO VehicleModels (Brand, ModelName, MaxSpeedKMH, WeightLimitKG, VehicleType) 
VALUES ('Ninebot', 'Max G30', 25, 120, 'самокат');
INSERT INTO Vehicles (QRCode, ModelID, TariffID, BatteryLevel, Status, Lat, Lon) 
VALUES ('QR-001', 1, 1, 90, 'доступно', 55.75, 37.61);
INSERT INTO Vehicles (QRCode, ModelID, TariffID, BatteryLevel, Status, Lat, Lon) 
VALUES ('QR-002', 1, 1, 15, 'доступно', 55.76, 37.62);
COMMIT;

DELETE FROM Rentals;
DELETE FROM Users WHERE Email = 'kuliashov200@mail.ru';
UPDATE Vehicles SET Status = 'доступно' WHERE VehicleID = 1;
COMMIT;

CALL RegisterUser('Кулешов Артем', 'kuliashov200@mail.ru', '+375445538895', 1);
SELECT UserID, FullName, Email, Balance FROM Users WHERE Email = 'kuliashov200@mail.ru';

SELECT CanUserRent(UserID) FROM Users WHERE Email = 'kuliashov200@mail.ru';
DECLARE
    v_uid NUMBER;
BEGIN
    SELECT UserID INTO v_uid FROM Users WHERE Email = 'kuliashov200@mail.ru';
    AddBalance(v_uid, 200);
END;
/
SELECT Balance FROM Users WHERE Email = 'kuliashov200@mail.ru';
SELECT Balance, CanUserRent(UserID) FROM Users WHERE Email = 'kuliashov200@mail.ru';

SELECT * FROM AvailableVehicles;
DECLARE
    v_uid NUMBER;
BEGIN
    SELECT UserID INTO v_uid FROM Users WHERE Email = 'kuliashov200@mail.ru';
    StartRental(v_uid, 1);
END;
/
SELECT * FROM Rentals WHERE RentalStatus = 'активно';
SELECT Status FROM Vehicles WHERE VehicleID = 1;
SELECT GetActiveRentalID((SELECT UserID FROM Users WHERE Email = 'kuliashov200@mail.ru')) FROM DUAL;
CALL EndRental(7, 55.75, 37.61);


SELECT RentalID, StartTime, EndTime, TotalCost, FixedMinutePrice 
FROM Rentals WHERE RentalStatus = 'завершено';
SELECT Balance FROM Users WHERE Email = 'kuliashov200@mail.ru';
SELECT Status, Lat, Lon FROM Vehicles WHERE VehicleID = 1;

SELECT BatteryLabel(15) FROM DUAL;
SELECT BatteryLabel(50) FROM DUAL;
SELECT BatteryLabel(80) FROM DUAL;

SELECT EstimateCost(1, 30) FROM DUAL;

CALL SetVehicleMaintenance(1);
SELECT Status FROM Vehicles WHERE VehicleID = 1;