create database blinova1;

use blinova1;

CREATE TABLE Roles (
    RoleID INT PRIMARY KEY IDENTITY(1,1),
    RoleName NVARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Users (
    UserID INT PRIMARY KEY IDENTITY(1,1),
    FullName NVARCHAR(255) NOT NULL,
    Email NVARCHAR(100) NOT NULL UNIQUE,
    Phone NVARCHAR(20) NOT NULL UNIQUE,
    Balance DECIMAL(10, 2) DEFAULT 0.00 CHECK (Balance >= 0),
    RoleID INT NOT NULL,
    CreatedAt DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT FK_User_Role FOREIGN KEY (RoleID) REFERENCES Roles(RoleID)
);

CREATE TABLE VehicleModels (
    ModelID INT PRIMARY KEY IDENTITY(1,1),
    Brand NVARCHAR(100),
    ModelName NVARCHAR(100) NOT NULL,
    MaxSpeedKMH INT,
    WeightLimitKG INT,
    VehicleType NVARCHAR(20) CHECK (VehicleType IN ('самокат', 'велосипед'))
);

CREATE TABLE Tariffs (
    TariffID INT PRIMARY KEY IDENTITY(1,1),
    Name NVARCHAR(50) NOT NULL,
    UnlockPrice DECIMAL(10, 2) NOT NULL,
    MinutePrice DECIMAL(10, 2) NOT NULL,
    IsActive BIT DEFAULT 1
);

CREATE TABLE Vehicles (
    VehicleID INT PRIMARY KEY IDENTITY(1,1),
    QRCode NVARCHAR(50) NOT NULL UNIQUE,
    ModelID INT NOT NULL,
    TariffID INT NOT NULL,
    BatteryLevel INT DEFAULT 100 CHECK (BatteryLevel BETWEEN 0 AND 100),
    Status NVARCHAR(20) DEFAULT 'доступно' 
        CHECK (Status IN ('доступно', 'забронировано', 'ремонт', 'зарядка', 'сломано')),
    Lat DECIMAL(9, 6),
    Lon DECIMAL(9, 6),
    LastServiceDate DATETIME,

    CONSTRAINT FK_Vehicle_Model FOREIGN KEY (ModelID) REFERENCES VehicleModels(ModelID),
    CONSTRAINT FK_Vehicle_Tariff FOREIGN KEY (TariffID) REFERENCES Tariffs(TariffID)
);

CREATE TABLE Rentals (
    RentalID INT PRIMARY KEY IDENTITY(1,1),
    UserID INT NOT NULL,
    VehicleID INT NOT NULL,
    StartTime DATETIME DEFAULT GETDATE(),
    EndTime DATETIME,
    FixedMinutePrice DECIMAL(10, 2) NOT NULL,
    
    TotalCost DECIMAL(10, 2),
    RentalStatus NVARCHAR(20) DEFAULT 'активно' 
        CHECK (RentalStatus IN ('активно', 'завершено', 'отменено')),

    CONSTRAINT FK_Rental_User FOREIGN KEY (UserID) REFERENCES Users(UserID),
    CONSTRAINT FK_Rental_Vehicle FOREIGN KEY (VehicleID) REFERENCES Vehicles(VehicleID)
);


-- индекс
CREATE INDEX IX_Users_Email ON Users(Email);


-- триггер
CREATE TRIGGER AfterRentalEnd
ON Rentals
AFTER UPDATE
AS
BEGIN
    IF UPDATE(TotalCost)
    BEGIN
        DECLARE @Cost DECIMAL(10,2), @UID INT
        SELECT @Cost = i.TotalCost, @UID = i.UserID FROM inserted i
        WHERE i.RentalStatus = 'завершено'
        
        UPDATE Users SET Balance = Balance - @Cost WHERE UserID = @UID;
    END
END;

-- Пересоздать представление с понятной логикой
CREATE OR ALTER VIEW AvailableVehicles AS
SELECT 
    v.VehicleID,
    v.QRCode,
    vm.Brand,
    vm.ModelName,
    v.BatteryLevel,
    v.Lat,
    v.Lon,
    t.Name as TariffName,
    t.UnlockPrice,
    t.MinutePrice,
    v.Status,
    CASE 
        WHEN v.BatteryLevel <= 20 THEN 'Низкий заряд'
        WHEN v.Status != 'доступно' THEN v.Status
        ELSE 'Доступен'
    END as AvailabilityStatus
FROM Vehicles v
JOIN VehicleModels vm ON v.ModelID = vm.ModelID
JOIN Tariffs t ON v.TariffID = t.TariffID;


CREATE SEQUENCE Seq_ContractNumber
    START WITH 1000
    INCREMENT BY 1;


-- процедуры
-- 1
CREATE PROCEDURE StartRental @UserID INT, @VehicleID INT AS
BEGIN
    UPDATE Vehicles SET Status = 'забронировано' WHERE VehicleID = @VehicleID;
    INSERT INTO Rentals (UserID, VehicleID, FixedMinutePrice, RentalStatus)
    SELECT @UserID, @VehicleID, t.MinutePrice, 'активно'
    FROM Vehicles v JOIN Tariffs t ON v.TariffID = t.TariffID WHERE v.VehicleID = @VehicleID;
END;

-- 2
CREATE PROCEDURE sEndRental @RentalID INT, @NewLat DECIMAL(9,6), @NewLon DECIMAL(9,6) AS
BEGIN
    DECLARE @StartTime DATETIME, @Price DECIMAL(10,2), @VID INT
    SELECT @StartTime = StartTime, @Price = FixedMinutePrice, @VID = VehicleID FROM Rentals WHERE RentalID = @RentalID

    DECLARE @Minutes INT = DATEDIFF(MINUTE, @StartTime, GETDATE())
    IF @Minutes = 0 SET @Minutes = 1

    UPDATE Rentals SET EndTime = GETDATE(), TotalCost = @Minutes * @Price, RentalStatus = 'завершено' WHERE RentalID = @RentalID
    UPDATE Vehicles SET Status = 'доступно', Lat = @NewLat, Lon = @NewLon WHERE VehicleID = @VID
END;

-- 3
CREATE PROCEDURE AddBalance @UserID INT, @Amount DECIMAL(10,2) AS
BEGIN
    UPDATE Users SET Balance = Balance + @Amount WHERE UserID = @UserID;
END;

-- 4   |1(роль) - пользователь
CREATE PROCEDURE RegisterUser @Name NVARCHAR(255), @Email NVARCHAR(100), @Phone NVARCHAR(20) AS
BEGIN
    INSERT INTO Users (FullName, Email, Phone, RoleID) VALUES (@Name, @Email, @Phone, 1);
END;

-- 5
CREATE PROCEDURE SetVehicleMaintenance @VehicleID INT AS
BEGIN
    UPDATE Vehicles SET Status = 'ремонт' WHERE VehicleID = @VehicleID;
END;


-- функции
-- 1
CREATE FUNCTION dbo.GetUserRentalCount (@UserID INT) RETURNS INT AS
BEGIN
    RETURN (SELECT COUNT(*) FROM Rentals WHERE UserID = @UserID)
END;

-- 2
CREATE FUNCTION dbo.EstimateCost (@TariffID INT, @Minutes INT) RETURNS DECIMAL(10,2) AS
BEGIN
    RETURN (SELECT UnlockPrice + (MinutePrice * @Minutes) FROM Tariffs WHERE TariffID = @TariffID)
END;

-- 3
CREATE FUNCTION dbo.BatteryLabel (@Level INT) RETURNS NVARCHAR(20) AS
BEGIN
    IF @Level < 20 RETURN 'Низкий'
    IF @Level < 60 RETURN 'Средний'
    RETURN 'Высокий'
END;

-- 4
CREATE FUNCTION dbo.CanUserRent (@UserID INT) RETURNS BIT AS
BEGIN
    DECLARE @Balance DECIMAL(10,2) = (SELECT Balance FROM Users WHERE UserID = @UserID)
    RETURN CASE WHEN @Balance > 0 THEN 1 ELSE 0 END
END;

-- 5
CREATE FUNCTION dbo.GetActiveRentalID (@UserID INT) RETURNS INT AS
BEGIN
    RETURN (SELECT TOP 1 RentalID FROM Rentals WHERE UserID = @UserID AND RentalStatus = 'активно')
END;