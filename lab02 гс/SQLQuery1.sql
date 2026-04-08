use blinova1;

INSERT INTO Roles (RoleName) VALUES ('Пользователь'), ('Админ');
INSERT INTO Tariffs (Name, UnlockPrice, MinutePrice) 
VALUES ('Базовый', 50.00, 5.00), ('Премиум', 0.00, 10.00);
INSERT INTO VehicleModels (Brand, ModelName, MaxSpeedKMH, WeightLimitKG, VehicleType)
VALUES ('Ninebot', 'Max G30', 25, 120, 'самокат'),
       ('Xiaomi', 'M365', 20, 100, 'самокат');
INSERT INTO Vehicles (QRCode, ModelID, TariffID, BatteryLevel, Status, Lat, Lon)
VALUES ('S-1001', 1, 1, 85, 'доступно', 55.75, 37.61),
       ('S-1002', 2, 1, 15, 'доступно', 55.76, 37.62);

BEGIN TRANSACTION;
    DELETE FROM Rentals;
    DELETE FROM Users;
COMMIT;

EXEC RegisterUser 'Кулешов Артем', 'artemych44@gmail.com', '+375445538895';
SELECT * FROM Users;

SELECT FullName, Balance, dbo.CanUserRent(UserID) as CanRent FROM Users WHERE Email = 'artemych44@gmail.com';
EXEC AddBalance 11, 500.00;
SELECT Balance FROM Users WHERE UserID = 11;
SELECT dbo.CanUserRent(11) as CanRentAfterTopUp;

SELECT * FROM AvailableVehicles;
EXEC StartRental @UserID = 11, @VehicleID = 1;
SELECT dbo.GetActiveRentalID(11) as ActiveRental;
SELECT Status FROM Vehicles WHERE VehicleID = 1;


SELECT * FROM Rentals;
EXEC sEndRental @RentalID = 5, @NewLat = 55.77, @NewLon = 37.63;
SELECT u.FullName, u.Balance, v.Status, r.TotalCost 
FROM Users u, Vehicles v, Rentals r 
WHERE u.UserID = 11 AND v.VehicleID = 1 AND r.RentalID = 5;


SELECT dbo.GetUserRentalCount(11) as TotalRentals;
SELECT dbo.EstimateCost(1, 20) as Estimated;
SELECT QRCode, BatteryLevel, dbo.BatteryLabel(BatteryLevel) as Label FROM Vehicles;


EXEC SetVehicleMaintenance @VehicleID = 2;
SELECT Status FROM Vehicles WHERE VehicleID = 2;