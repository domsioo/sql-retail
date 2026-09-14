/* ============================================================
   PortfolioRetailLab - SQL Practice Database (SQL Server / SSMS)
   ============================================================ */
USE master;
GO

IF DB_ID(N'PortfolioRetailLab') IS NOT NULL
BEGIN
    ALTER DATABASE PortfolioRetailLab SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PortfolioRetailLab;
END;
GO

CREATE DATABASE PortfolioRetailLab;
GO

USE PortfolioRetailLab;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* -----------------------
   Schemas
----------------------- */
CREATE SCHEMA util AUTHORIZATION dbo;
GO
CREATE SCHEMA ref AUTHORIZATION dbo;
GO
CREATE SCHEMA crm AUTHORIZATION dbo;
GO
CREATE SCHEMA ops AUTHORIZATION dbo;
GO
CREATE SCHEMA sales AUTHORIZATION dbo;
GO
CREATE SCHEMA logistics AUTHORIZATION dbo;
GO
CREATE SCHEMA web AUTHORIZATION dbo;
GO
CREATE SCHEMA reporting AUTHORIZATION dbo;
GO

/* -----------------------
   Calendar
----------------------- */
CREATE TABLE util.CalendarDate
(
    DateKey         INT          NOT NULL CONSTRAINT PK_CalendarDate PRIMARY KEY,
    [Date]          DATE         NOT NULL CONSTRAINT UQ_CalendarDate_Date UNIQUE,
    [Year]          SMALLINT     NOT NULL,
    [Quarter]       TINYINT      NOT NULL,
    [Month]         TINYINT      NOT NULL,
    [MonthName]     VARCHAR(9)   NOT NULL,
    [DayOfMonth]    TINYINT      NOT NULL,
    [DayOfWeek]     TINYINT      NOT NULL, -- DATEFIRST dependent (we populate with DATEFIRST = 1)
    [DayName]       VARCHAR(9)   NOT NULL,
    [ISOWeek]       TINYINT      NOT NULL,
    [WeekStartDate] DATE         NOT NULL,
    [MonthStartDate] DATE        NOT NULL,
    [IsWeekend]     BIT          NOT NULL
);
GO

/* -----------------------
   Reference tables
----------------------- */
CREATE TABLE ref.Channel
(
    ChannelCode VARCHAR(10)  NOT NULL CONSTRAINT PK_Channel PRIMARY KEY,
    ChannelName VARCHAR(50)  NOT NULL,
    IsOnline    BIT          NOT NULL CONSTRAINT DF_Channel_IsOnline DEFAULT (0)
);
GO

CREATE TABLE ref.OrderStatus
(
    OrderStatusCode VARCHAR(15) NOT NULL CONSTRAINT PK_OrderStatus PRIMARY KEY,
    StatusName      VARCHAR(50) NOT NULL,
    IsFinal         BIT         NOT NULL,
    IsDelivered     BIT         NOT NULL,
    IsCancelled     BIT         NOT NULL
);
GO

CREATE TABLE ref.ShipmentStatus
(
    ShipmentStatusCode VARCHAR(20) NOT NULL CONSTRAINT PK_ShipmentStatus PRIMARY KEY,
    StatusName         VARCHAR(100) NOT NULL,
    IsFinal            BIT NOT NULL
);
GO

CREATE TABLE ref.Carrier
(
    CarrierID   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Carrier PRIMARY KEY,
    CarrierCode VARCHAR(10) NOT NULL CONSTRAINT UQ_Carrier_CarrierCode UNIQUE,
    CarrierName VARCHAR(100) NOT NULL
);
GO

CREATE TABLE ref.ReturnReason
(
    ReturnReasonCode VARCHAR(30) NOT NULL CONSTRAINT PK_ReturnReason PRIMARY KEY,
    ReasonName       VARCHAR(200) NOT NULL
);
GO

CREATE TABLE ref.Category
(
    CategoryID       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Category PRIMARY KEY,
    CategoryName     VARCHAR(100) NOT NULL,
    ParentCategoryID INT NULL,
    IsActive         BIT NOT NULL CONSTRAINT DF_Category_IsActive DEFAULT (1),
    CONSTRAINT FK_Category_Parent FOREIGN KEY (ParentCategoryID) REFERENCES ref.Category(CategoryID)
);
GO

CREATE TABLE ref.Product
(
    ProductID   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Product PRIMARY KEY,
    SKU         VARCHAR(30) NOT NULL CONSTRAINT UQ_Product_SKU UNIQUE,
    ProductName VARCHAR(200) NOT NULL,
    Brand       VARCHAR(100) NULL,
    CategoryID  INT NOT NULL,
    IsActive    BIT NOT NULL CONSTRAINT DF_Product_IsActive DEFAULT (1),
    CreatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_Product_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT FK_Product_Category FOREIGN KEY (CategoryID) REFERENCES ref.Category(CategoryID)
);
GO

CREATE TABLE ref.ProductListPriceHistory
(
    ProductID     INT NOT NULL,
    EffectiveFrom DATE NOT NULL,
    EffectiveTo   DATE NULL,
    ListPrice     DECIMAL(10,2) NOT NULL,
    CONSTRAINT PK_ProductListPriceHistory PRIMARY KEY (ProductID, EffectiveFrom),
    CONSTRAINT FK_PLPH_Product FOREIGN KEY (ProductID) REFERENCES ref.Product(ProductID),
    CONSTRAINT CK_PLPH_DateRange CHECK (EffectiveTo IS NULL OR EffectiveTo > EffectiveFrom),
    CONSTRAINT CK_PLPH_ListPrice CHECK (ListPrice >= 0)
);
GO

CREATE INDEX IX_PLPH_Product_Effective
ON ref.ProductListPriceHistory(ProductID, EffectiveFrom, EffectiveTo)
INCLUDE (ListPrice);
GO

/* -----------------------
   Operational tables
----------------------- */
CREATE TABLE ops.Store
(
    StoreID    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Store PRIMARY KEY,
    StoreCode  VARCHAR(20) NOT NULL CONSTRAINT UQ_Store_StoreCode UNIQUE,
    StoreName  VARCHAR(200) NOT NULL,
    RegionCode VARCHAR(10) NOT NULL,
    OpenDate   DATE NOT NULL,
    CloseDate  DATE NULL,
    IsActive   AS (CONVERT(bit, CASE WHEN CloseDate IS NULL THEN 1 ELSE 0 END)) PERSISTED
);
GO

CREATE INDEX IX_Store_RegionCode ON ops.Store(RegionCode);
GO

/* -----------------------
   CRM tables
----------------------- */
CREATE TABLE crm.Customer
(
    CustomerID  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Customer PRIMARY KEY,
    CustomerNK  VARCHAR(20) NOT NULL CONSTRAINT UQ_Customer_CustomerNK UNIQUE,
    FirstName   VARCHAR(100) NOT NULL,
    LastName    VARCHAR(100) NOT NULL,
    CreatedAt   DATETIME2(0) NOT NULL,
    IsActive    BIT NOT NULL CONSTRAINT DF_Customer_IsActive DEFAULT (1)
);
GO

CREATE TABLE crm.CustomerEmail
(
    CustomerEmailID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CustomerEmail PRIMARY KEY,
    CustomerID      INT NOT NULL,
    EmailAddress    VARCHAR(320) NOT NULL,
    IsPrimary       BIT NOT NULL CONSTRAINT DF_CustomerEmail_IsPrimary DEFAULT (0),
    IsVerified      BIT NOT NULL CONSTRAINT DF_CustomerEmail_IsVerified DEFAULT (0),
    VerifiedAt      DATETIME2(0) NULL,
    CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_CustomerEmail_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT FK_CustomerEmail_Customer FOREIGN KEY (CustomerID) REFERENCES crm.Customer(CustomerID),
    CONSTRAINT CK_CustomerEmail_Email CHECK (EmailAddress LIKE '%_@_%._%')
);
GO

CREATE INDEX IX_CustomerEmail_Customer_Primary ON crm.CustomerEmail(CustomerID, IsPrimary) INCLUDE (EmailAddress, IsVerified, VerifiedAt);
GO

CREATE TABLE crm.CustomerAttributeHistory
(
    CustomerID     INT NOT NULL,
    EffectiveFrom  DATE NOT NULL,
    EffectiveTo    DATE NULL,
    RegionCode     VARCHAR(10) NOT NULL,
    LoyaltyTier    VARCHAR(20) NOT NULL,
    Segment        VARCHAR(30) NULL,
    CONSTRAINT PK_CustomerAttributeHistory PRIMARY KEY (CustomerID, EffectiveFrom),
    CONSTRAINT FK_CustomerAttributeHistory_Customer FOREIGN KEY (CustomerID) REFERENCES crm.Customer(CustomerID),
    CONSTRAINT CK_CustomerAttributeHistory_DateRange CHECK (EffectiveTo IS NULL OR EffectiveTo > EffectiveFrom)
);
GO

CREATE INDEX IX_CustomerAttributeHistory_Customer_Effective
ON crm.CustomerAttributeHistory(CustomerID, EffectiveFrom, EffectiveTo)
INCLUDE (RegionCode, LoyaltyTier, Segment);
GO

/* -----------------------
   Web analytics tables
----------------------- */
CREATE TABLE web.Session
(
    SessionSeq   INT IDENTITY(1,1) NOT NULL,
    WebSessionID UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Session_WebSessionID DEFAULT (NEWID()),
    CustomerID   INT NULL,
    StartedAt    DATETIME2(0) NOT NULL,
    EndedAt      DATETIME2(0) NOT NULL,
    TrafficSource VARCHAR(50) NOT NULL,
    DeviceType    VARCHAR(20) NOT NULL,
    UserAgent     VARCHAR(200) NULL,
    CONSTRAINT PK_Session PRIMARY KEY (WebSessionID),
    CONSTRAINT UQ_Session_SessionSeq UNIQUE (SessionSeq),
    CONSTRAINT FK_Session_Customer FOREIGN KEY (CustomerID) REFERENCES crm.Customer(CustomerID),
    CONSTRAINT CK_Session_Time CHECK (EndedAt > StartedAt)
);
GO

CREATE INDEX IX_Session_StartedAt ON web.Session(StartedAt) INCLUDE (CustomerID, TrafficSource, DeviceType);
GO

/* -----------------------
   Sales tables
----------------------- */
CREATE TABLE sales.SalesOrder
(
    SalesOrderID     BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SalesOrder PRIMARY KEY,
    OrderNumber      VARCHAR(20) NOT NULL CONSTRAINT UQ_SalesOrder_OrderNumber UNIQUE,
    CustomerID       INT NOT NULL,
    StoreID          INT NULL,
    ChannelCode      VARCHAR(10) NOT NULL,
    WebSessionID     UNIQUEIDENTIFIER NULL,
    OrderStatusCode  VARCHAR(15) NOT NULL,
    OrderDate        DATETIME2(0) NOT NULL,
    PaidAt           DATETIME2(0) NULL,
    CancelledAt      DATETIME2(0) NULL,
    ShippingAmount   DECIMAL(10,2) NOT NULL CONSTRAINT DF_SalesOrder_ShippingAmount DEFAULT (0),
    CurrencyCode     CHAR(3) NOT NULL CONSTRAINT DF_SalesOrder_CurrencyCode DEFAULT ('USD'),
    HeaderGrossAmount     DECIMAL(12,2) NULL,
    HeaderDiscountAmount  DECIMAL(12,2) NULL,
    HeaderTaxAmount       DECIMAL(12,2) NULL,
    HeaderNetAmount       DECIMAL(12,2) NULL,
    CONSTRAINT FK_SalesOrder_Customer FOREIGN KEY (CustomerID) REFERENCES crm.Customer(CustomerID),
    CONSTRAINT FK_SalesOrder_Store FOREIGN KEY (StoreID) REFERENCES ops.Store(StoreID),
    CONSTRAINT FK_SalesOrder_Channel FOREIGN KEY (ChannelCode) REFERENCES ref.Channel(ChannelCode),
    CONSTRAINT FK_SalesOrder_WebSession FOREIGN KEY (WebSessionID) REFERENCES web.Session(WebSessionID),
    CONSTRAINT FK_SalesOrder_Status FOREIGN KEY (OrderStatusCode) REFERENCES ref.OrderStatus(OrderStatusCode),
    CONSTRAINT CK_SalesOrder_Store_Channel CHECK
    (
        (ChannelCode = 'STORE' AND StoreID IS NOT NULL) OR
        (ChannelCode <> 'STORE' AND StoreID IS NULL)
    ),
    CONSTRAINT CK_SalesOrder_CancelledAt CHECK
    (
        (OrderStatusCode = 'CANCELLED' AND CancelledAt IS NOT NULL) OR
        (OrderStatusCode <> 'CANCELLED')
    )
);
GO

CREATE INDEX IX_SalesOrder_OrderDate ON sales.SalesOrder(OrderDate) INCLUDE (OrderStatusCode, ChannelCode, StoreID, CustomerID, HeaderNetAmount);
GO
CREATE INDEX IX_SalesOrder_Customer ON sales.SalesOrder(CustomerID, OrderDate) INCLUDE (OrderStatusCode, HeaderNetAmount);
GO

CREATE TABLE sales.SalesOrderLine
(
    SalesOrderLineID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SalesOrderLine PRIMARY KEY,
    SalesOrderID     BIGINT NOT NULL,
    LineNumber       INT NOT NULL,
    ProductID        INT NOT NULL,
    Quantity         INT NOT NULL,
    UnitPrice        DECIMAL(10,2) NOT NULL, -- price before discount
    DiscountAmount   DECIMAL(10,2) NOT NULL CONSTRAINT DF_SalesOrderLine_DiscountAmount DEFAULT (0),
    TaxAmount        DECIMAL(10,2) NOT NULL CONSTRAINT DF_SalesOrderLine_TaxAmount DEFAULT (0),
    GrossAmount      AS (CONVERT(DECIMAL(12,2), Quantity * UnitPrice)) PERSISTED,
    NetAmount        AS (CONVERT(DECIMAL(12,2), (Quantity * UnitPrice) - DiscountAmount + TaxAmount)) PERSISTED,
    CONSTRAINT FK_SalesOrderLine_Order FOREIGN KEY (SalesOrderID) REFERENCES sales.SalesOrder(SalesOrderID),
    CONSTRAINT FK_SalesOrderLine_Product FOREIGN KEY (ProductID) REFERENCES ref.Product(ProductID),
    CONSTRAINT UQ_SalesOrderLine_Order_Line UNIQUE (SalesOrderID, LineNumber),
    CONSTRAINT CK_SalesOrderLine_Qty CHECK (Quantity > 0),
    CONSTRAINT CK_SalesOrderLine_Price CHECK (UnitPrice >= 0),
    CONSTRAINT CK_SalesOrderLine_Discount CHECK (DiscountAmount >= 0),
    CONSTRAINT CK_SalesOrderLine_Tax CHECK (TaxAmount >= 0)
);
GO

CREATE INDEX IX_SalesOrderLine_Order ON sales.SalesOrderLine(SalesOrderID) INCLUDE (ProductID, Quantity, NetAmount, GrossAmount);
GO
CREATE INDEX IX_SalesOrderLine_Product ON sales.SalesOrderLine(ProductID) INCLUDE (Quantity, NetAmount, GrossAmount);
GO

/* -----------------------
   Logistics tables
----------------------- */
CREATE TABLE logistics.Shipment
(
    ShipmentID          BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Shipment PRIMARY KEY,
    SalesOrderID        BIGINT NOT NULL,
    CarrierID           INT NOT NULL,
    ShipmentStatusCode  VARCHAR(20) NOT NULL,
    ShippedAt           DATETIME2(0) NOT NULL,
    DeliveredAt         DATETIME2(0) NULL,
    TrackingNumber      VARCHAR(30) NOT NULL,
    CONSTRAINT FK_Shipment_Order FOREIGN KEY (SalesOrderID) REFERENCES sales.SalesOrder(SalesOrderID),
    CONSTRAINT FK_Shipment_Carrier FOREIGN KEY (CarrierID) REFERENCES ref.Carrier(CarrierID),
    CONSTRAINT FK_Shipment_Status FOREIGN KEY (ShipmentStatusCode) REFERENCES ref.ShipmentStatus(ShipmentStatusCode),
    CONSTRAINT UQ_Shipment_Order UNIQUE (SalesOrderID),
    CONSTRAINT CK_Shipment_Dates CHECK (DeliveredAt IS NULL OR DeliveredAt >= ShippedAt)
);
GO

CREATE INDEX IX_Shipment_Carrier_ShippedAt ON logistics.Shipment(CarrierID, ShippedAt) INCLUDE (DeliveredAt, ShipmentStatusCode, SalesOrderID);
GO

/* -----------------------
   Returns tables
----------------------- */
CREATE TABLE sales.ReturnHeader
(
    ReturnID          BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ReturnHeader PRIMARY KEY,
    ReturnNumber      VARCHAR(20) NOT NULL CONSTRAINT UQ_ReturnHeader_ReturnNumber UNIQUE,
    SalesOrderID      BIGINT NOT NULL,
    CustomerID        INT NOT NULL,
    ReturnReasonCode  VARCHAR(30) NOT NULL,
    ReturnStatusCode  VARCHAR(20) NOT NULL,
    CreatedAt         DATETIME2(0) NOT NULL,
    ReceivedAt        DATETIME2(0) NULL,
    CONSTRAINT FK_ReturnHeader_Order FOREIGN KEY (SalesOrderID) REFERENCES sales.SalesOrder(SalesOrderID),
    CONSTRAINT FK_ReturnHeader_Customer FOREIGN KEY (CustomerID) REFERENCES crm.Customer(CustomerID),
    CONSTRAINT FK_ReturnHeader_Reason FOREIGN KEY (ReturnReasonCode) REFERENCES ref.ReturnReason(ReturnReasonCode),
    CONSTRAINT CK_ReturnHeader_Status CHECK (ReturnStatusCode IN ('REQUESTED','RECEIVED','REFUNDED','REJECTED')),
    CONSTRAINT CK_ReturnHeader_ReceivedAt CHECK (ReceivedAt IS NULL OR ReceivedAt >= CreatedAt)
);
GO

CREATE INDEX IX_ReturnHeader_CreatedAt ON sales.ReturnHeader(CreatedAt) INCLUDE (SalesOrderID, CustomerID, ReturnStatusCode, ReturnReasonCode);
GO

CREATE TABLE sales.ReturnLine
(
    ReturnLineID      BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ReturnLine PRIMARY KEY,
    ReturnID          BIGINT NOT NULL,
    SalesOrderLineID  BIGINT NOT NULL,
    Quantity          INT NOT NULL,
    RefundAmount      DECIMAL(10,2) NOT NULL,
    RefundedAt        DATETIME2(0) NULL,
    RefundStatusCode  VARCHAR(20) NOT NULL,
    CONSTRAINT FK_ReturnLine_Return FOREIGN KEY (ReturnID) REFERENCES sales.ReturnHeader(ReturnID),
    CONSTRAINT FK_ReturnLine_OrderLine FOREIGN KEY (SalesOrderLineID) REFERENCES sales.SalesOrderLine(SalesOrderLineID),
    CONSTRAINT CK_ReturnLine_Qty CHECK (Quantity > 0),
    CONSTRAINT CK_ReturnLine_RefundAmount CHECK (RefundAmount >= 0),
    CONSTRAINT CK_ReturnLine_RefundStatus CHECK (RefundStatusCode IN ('PENDING','REFUNDED','DECLINED'))
);
GO

CREATE INDEX IX_ReturnLine_ReturnID ON sales.ReturnLine(ReturnID) INCLUDE (SalesOrderLineID, Quantity, RefundAmount, RefundedAt, RefundStatusCode);
GO

/* -----------------------
   Web events (created after SalesOrder so we can FK to SalesOrder)
----------------------- */
CREATE TABLE web.Event
(
    WebEventID     BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_WebEvent PRIMARY KEY,
    WebSessionID   UNIQUEIDENTIFIER NOT NULL,
    EventTime      DATETIME2(0) NOT NULL,
    EventType      VARCHAR(30) NOT NULL,
    ProductID      INT NULL,
    SalesOrderID   BIGINT NULL,
    Properties     NVARCHAR(MAX) NOT NULL CONSTRAINT DF_WebEvent_Properties DEFAULT (N'{}'),
    CONSTRAINT FK_WebEvent_Session FOREIGN KEY (WebSessionID) REFERENCES web.Session(WebSessionID),
    CONSTRAINT FK_WebEvent_Product FOREIGN KEY (ProductID) REFERENCES ref.Product(ProductID),
    CONSTRAINT FK_WebEvent_SalesOrder FOREIGN KEY (SalesOrderID) REFERENCES sales.SalesOrder(SalesOrderID),
    CONSTRAINT CK_WebEvent_EventType CHECK (EventType IN ('PAGEVIEW','SEARCH','ADD_TO_CART','REMOVE_FROM_CART','CHECKOUT','PURCHASE','LOGIN','SIGNUP','ERROR')),
    CONSTRAINT CK_WebEvent_Properties_IsJson CHECK (ISJSON(Properties)=1)
);
GO

ALTER TABLE web.Event
ADD AbVariant AS CONVERT(VARCHAR(10), JSON_VALUE(Properties, '$.ab_variant'));
GO

CREATE INDEX IX_WebEvent_Session_Time ON web.Event(WebSessionID, EventTime) INCLUDE (EventType, ProductID, SalesOrderID);
GO

/* ============================================================
   Seed Data
   ============================================================ */
BEGIN TRAN;

/* Calendar population */
DECLARE @CalStart DATE = '2023-01-01';
DECLARE @CalEnd   DATE = '2025-12-31';

SET DATEFIRST 1; -- Monday

;WITH n AS
(
    SELECT TOP (DATEDIFF(DAY, @CalStart, @CalEnd) + 1)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
INSERT util.CalendarDate
(
    DateKey, [Date], [Year], [Quarter], [Month], [MonthName],
    [DayOfMonth], [DayOfWeek], [DayName], [ISOWeek],
    [WeekStartDate], [MonthStartDate], [IsWeekend]
)
SELECT
    (YEAR(d.d) * 10000) + (MONTH(d.d) * 100) + DAY(d.d) AS DateKey,
    d.d AS [Date],
    YEAR(d.d) AS [Year],
    DATEPART(QUARTER, d.d) AS [Quarter],
    MONTH(d.d) AS [Month],
    CONVERT(VARCHAR(9), DATENAME(MONTH, d.d)) AS [MonthName],
    DAY(d.d) AS [DayOfMonth],
    DATEPART(WEEKDAY, d.d) AS [DayOfWeek],
    CONVERT(VARCHAR(9), DATENAME(WEEKDAY, d.d)) AS [DayName],
    DATEPART(ISO_WEEK, d.d) AS [ISOWeek],
    DATEADD(DAY, 1 - DATEPART(WEEKDAY, d.d), d.d) AS [WeekStartDate],
    DATEFROMPARTS(YEAR(d.d), MONTH(d.d), 1) AS [MonthStartDate],
    CONVERT(bit, CASE WHEN DATEPART(WEEKDAY, d.d) IN (6,7) THEN 1 ELSE 0 END) AS [IsWeekend]
FROM
(
    SELECT DATEADD(DAY, n.n, @CalStart) AS d
    FROM n
) d;
GO

/* Reference data */
INSERT ref.Channel(ChannelCode, ChannelName, IsOnline)
VALUES
('ONLINE','Online Web', 1),
('STORE','Retail Store', 0),
('PHONE','Phone Order', 0);

INSERT ref.OrderStatus(OrderStatusCode, StatusName, IsFinal, IsDelivered, IsCancelled)
VALUES
('PAID','Paid', 0, 0, 0),
('SHIPPED','Shipped', 0, 0, 0),
('DELIVERED','Delivered', 1, 1, 0),
('CANCELLED','Cancelled', 1, 0, 1);

INSERT ref.ShipmentStatus(ShipmentStatusCode, StatusName, IsFinal)
VALUES
('IN_TRANSIT','In Transit', 0),
('DELIVERED','Delivered', 1),
('LOST','Lost', 1);

INSERT ref.Carrier(CarrierCode, CarrierName)
VALUES
('UPS','UPS'),
('FDX','FedEx'),
('DHL','DHL'),
('USPS','US Postal Service');

INSERT ref.ReturnReason(ReturnReasonCode, ReasonName)
VALUES
('DAMAGED','Damaged item'),
('NOT_AS_DESCRIBED','Not as described'),
('SIZE_ISSUE','Size/fit issue'),
('LATE_DELIVERY','Late delivery'),
('OTHER','Other');

/* Categories (with hierarchy) */
DECLARE
    @Electronics INT, @Computers INT, @Phones INT, @Audio INT,
    @Laptops INT, @ElecAccessories INT, @Smartphones INT, @PhoneAccessories INT, @Headphones INT, @Speakers INT,
    @Home INT, @Kitchen INT, @Furniture INT, @Decor INT,
    @Apparel INT, @Mens INT, @Womens INT, @Kids INT,
    @Beauty INT, @Skincare INT, @Makeup INT,
    @Sports INT, @Outdoor INT, @Fitness INT;

INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Electronics', NULL); SET @Electronics = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Computers', @Electronics); SET @Computers = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Phones', @Electronics); SET @Phones = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Audio', @Electronics); SET @Audio = SCOPE_IDENTITY();

INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Laptops', @Computers); SET @Laptops = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Accessories', @Computers); SET @ElecAccessories = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Smartphones', @Phones); SET @Smartphones = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Phone Accessories', @Phones); SET @PhoneAccessories = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Headphones', @Audio); SET @Headphones = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Speakers', @Audio); SET @Speakers = SCOPE_IDENTITY();

INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Home', NULL); SET @Home = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Kitchen', @Home); SET @Kitchen = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Furniture', @Home); SET @Furniture = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Decor', @Home); SET @Decor = SCOPE_IDENTITY();

INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Apparel', NULL); SET @Apparel = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Mens', @Apparel); SET @Mens = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Womens', @Apparel); SET @Womens = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Kids', @Apparel); SET @Kids = SCOPE_IDENTITY();

INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Beauty', NULL); SET @Beauty = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Skincare', @Beauty); SET @Skincare = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Makeup', @Beauty); SET @Makeup = SCOPE_IDENTITY();

INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Sports', NULL); SET @Sports = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Outdoor', @Sports); SET @Outdoor = SCOPE_IDENTITY();
INSERT ref.Category(CategoryName, ParentCategoryID) VALUES ('Fitness', @Sports); SET @Fitness = SCOPE_IDENTITY();

/* Stores */
INSERT ops.Store(StoreCode, StoreName, RegionCode, OpenDate, CloseDate)
VALUES
('ST-001','Downtown Store','NORTH','2020-01-01',NULL),
('ST-002','Mall Store','NORTH','2020-06-01',NULL),
('ST-003','Airport Store','EAST','2021-03-15',NULL),
('ST-004','Outlet Store','SOUTH','2021-09-01',NULL),
('ST-005','Suburb Store','WEST','2022-02-01',NULL),
('ST-006','City Center Store','EAST','2022-05-01',NULL),
('ST-007','Campus Store','SOUTH','2023-01-01',NULL),
('ST-008','Harbor Store','WEST','2023-07-01',NULL);

/* Products (generated) */
DECLARE @LeafCategories TABLE (Seq INT PRIMARY KEY, CategoryID INT NOT NULL);
INSERT @LeafCategories(Seq, CategoryID)
VALUES
(1,@Laptops),
(2,@ElecAccessories),
(3,@Smartphones),
(4,@PhoneAccessories),
(5,@Headphones),
(6,@Speakers),
(7,@Kitchen),
(8,@Furniture),
(9,@Decor),
(10,@Mens),
(11,@Womens),
(12,@Kids),
(13,@Skincare),
(14,@Makeup),
(15,@Outdoor),
(16,@Fitness);

DECLARE @LeafCount INT = (SELECT COUNT(*) FROM @LeafCategories);
DECLARE @TotalProducts INT = 64;

;WITH n AS
(
    SELECT TOP (@TotalProducts) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
)
INSERT ref.Product(SKU, ProductName, Brand, CategoryID)
SELECT
    CONCAT('SKU-', RIGHT('0000' + CONVERT(VARCHAR(4), n.n), 4)) AS SKU,
    CONCAT('Product ', RIGHT('0000' + CONVERT(VARCHAR(4), n.n), 4)) AS ProductName,
    CHOOSE((n.n % 8) + 1, 'Contoso','Fabrikam','Northwind','Adventure','Woodgrove','Litware','Proseware','Tailspin') AS Brand,
    lc.CategoryID
FROM n
JOIN @LeafCategories lc
  ON lc.Seq = ((n.n - 1) % @LeafCount) + 1;

/* Product list price history */
INSERT ref.ProductListPriceHistory(ProductID, EffectiveFrom, EffectiveTo, ListPrice)
SELECT
    p.ProductID,
    '2023-01-01',
    '2024-06-30',
    CAST(ROUND(((p.ProductID % 25) + 5) * 2.75 + ((p.ProductID % 10) * 0.39), 2) AS DECIMAL(10,2))
FROM ref.Product p;

INSERT ref.ProductListPriceHistory(ProductID, EffectiveFrom, EffectiveTo, ListPrice)
SELECT
    ph.ProductID,
    '2024-07-01',
    NULL,
    CAST(ROUND(ph.ListPrice * CASE WHEN ph.ProductID % 8 IN (0,1,2,3) THEN 1.10 ELSE 0.90 END, 2) AS DECIMAL(10,2))
FROM ref.ProductListPriceHistory ph
WHERE ph.EffectiveFrom = '2023-01-01'
  AND ph.ProductID % 4 = 0;

UPDATE ph
SET EffectiveTo = '2025-01-31'
FROM ref.ProductListPriceHistory ph
WHERE ph.EffectiveFrom = '2024-07-01'
  AND ph.ProductID % 12 = 0;

INSERT ref.ProductListPriceHistory(ProductID, EffectiveFrom, EffectiveTo, ListPrice)
SELECT
    ph.ProductID,
    '2025-02-01',
    NULL,
    CAST(ROUND(ph.ListPrice * 1.05, 2) AS DECIMAL(10,2))
FROM ref.ProductListPriceHistory ph
WHERE ph.EffectiveFrom = '2024-07-01'
  AND ph.ProductID % 12 = 0;

/* Customers (generated) */
DECLARE @CustomerCount INT = 200;

;WITH n AS
(
    SELECT TOP (@CustomerCount) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
INSERT crm.Customer(CustomerNK, FirstName, LastName, CreatedAt, IsActive)
SELECT
    CONCAT('C', RIGHT('000000' + CONVERT(VARCHAR(6), n.n), 6)) AS CustomerNK,
    CHOOSE((n.n % 12) + 1, 'Alex','Sam','Taylor','Casey','Riley','Morgan','Jamie','Avery','Cameron','Drew','Jordan','Peyton') AS FirstName,
    CHOOSE((n.n % 12) + 1, 'Smith','Johnson','Brown','Davis','Miller','Wilson','Moore','Taylor','Anderson','Thomas','Jackson','White') AS LastName,
    DATEADD(MINUTE, (n.n * 19) % 1440, DATEADD(DAY, (n.n - 1) * 3, CAST('2023-01-01' AS DATETIME2(0)))) AS CreatedAt,
    CONVERT(bit, CASE WHEN n.n % 55 = 0 THEN 0 ELSE 1 END) AS IsActive
FROM n;

/* Customer emails (with a few intentional anomalies: some customers get 2 "primary" emails) */
INSERT crm.CustomerEmail(CustomerID, EmailAddress, IsPrimary, IsVerified, VerifiedAt, CreatedAt)
SELECT
    c.CustomerID,
    CONCAT('customer', RIGHT('000000' + CONVERT(VARCHAR(6), c.CustomerID), 6), '@example.com') AS EmailAddress,
    1 AS IsPrimary,
    CONVERT(bit, CASE WHEN c.CustomerID % 10 = 0 THEN 0 ELSE 1 END) AS IsVerified,
    CASE WHEN c.CustomerID % 10 = 0 THEN NULL ELSE DATEADD(DAY, 1, c.CreatedAt) END AS VerifiedAt,
    c.CreatedAt
FROM crm.Customer c;

INSERT crm.CustomerEmail(CustomerID, EmailAddress, IsPrimary, IsVerified, VerifiedAt, CreatedAt)
SELECT
    c.CustomerID,
    CONCAT('alt', RIGHT('000000' + CONVERT(VARCHAR(6), c.CustomerID), 6), '@example.com') AS EmailAddress,
    CONVERT(bit, CASE WHEN c.CustomerID % 50 = 0 THEN 1 ELSE 0 END) AS IsPrimary, -- creates some duplicate primaries
    1 AS IsVerified,
    DATEADD(DAY, 2, c.CreatedAt) AS VerifiedAt,
    DATEADD(DAY, 2, c.CreatedAt) AS CreatedAt
FROM crm.Customer c
WHERE c.CustomerID % 8 = 0;

/* Customer attribute history (SCD-ish) */
INSERT crm.CustomerAttributeHistory(CustomerID, EffectiveFrom, EffectiveTo, RegionCode, LoyaltyTier, Segment)
SELECT
    c.CustomerID,
    CONVERT(DATE, c.CreatedAt) AS EffectiveFrom,
    NULL AS EffectiveTo,
    CHOOSE((c.CustomerID % 4) + 1, 'NORTH','SOUTH','EAST','WEST') AS RegionCode,
    CHOOSE((c.CustomerID % 4) + 1, 'BRONZE','SILVER','GOLD','PLATINUM') AS LoyaltyTier,
    CHOOSE((c.CustomerID % 5) + 1, 'B2C','B2C','B2C','SMB','VIP') AS Segment
FROM crm.Customer c;

UPDATE cah
SET EffectiveTo = '2024-06-30'
FROM crm.CustomerAttributeHistory cah
WHERE cah.EffectiveTo IS NULL
  AND cah.CustomerID % 15 = 0
  AND cah.EffectiveFrom < '2024-07-01';

INSERT crm.CustomerAttributeHistory(CustomerID, EffectiveFrom, EffectiveTo, RegionCode, LoyaltyTier, Segment)
SELECT
    c.CustomerID,
    '2024-07-01',
    NULL,
    CHOOSE(((c.CustomerID + 1) % 4) + 1, 'NORTH','SOUTH','EAST','WEST') AS RegionCode,
    CHOOSE(((c.CustomerID + 2) % 4) + 1, 'BRONZE','SILVER','GOLD','PLATINUM') AS LoyaltyTier,
    'VIP' AS Segment
FROM crm.Customer c
WHERE c.CustomerID % 15 = 0;

/* Web sessions (generated) */
DECLARE @SessionCount INT = 1500;

;WITH n AS
(
    SELECT TOP (@SessionCount) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
INSERT web.Session(CustomerID, StartedAt, EndedAt, TrafficSource, DeviceType, UserAgent)
SELECT
    CASE
        WHEN n.n <= 1200 THEN ((n.n - 1) % @CustomerCount) + 1
        WHEN n.n % 5 = 0 THEN NULL
        ELSE ((n.n - 1) % @CustomerCount) + 1
    END AS CustomerID,
    s.StartedAt,
    DATEADD(MINUTE, s.DurationMinutes, s.StartedAt) AS EndedAt,
    CHOOSE((n.n % 6) + 1, 'google','facebook','email','direct','affiliate','tiktok') AS TrafficSource,
    CHOOSE((n.n % 3) + 1, 'DESKTOP','MOBILE','TABLET') AS DeviceType,
    CONCAT('UA/', (n.n % 9) + 1, ' (PortfolioRetailLab)') AS UserAgent
FROM n
CROSS APPLY
(
    SELECT
        StartedAt =
            DATEADD
            (
                MINUTE,
                (n.n * 13) % 1440,
                DATEADD(DAY, (n.n - 1) % 546, CAST('2024-01-01' AS DATETIME2(0)))
            ),
        DurationMinutes =
            CASE
                WHEN n.n % 77 = 0 THEN 1
                WHEN n.n % 12 = 0 THEN 60
                ELSE (n.n % 25) + 5
            END
) s;

/* Sales orders (generated) */
DECLARE @OrderCount INT = 1200;

;WITH n AS
(
    SELECT TOP (@OrderCount) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
INSERT sales.SalesOrder
(
    OrderNumber, CustomerID, StoreID, ChannelCode, WebSessionID,
    OrderStatusCode, OrderDate, PaidAt, CancelledAt, ShippingAmount
)
SELECT
    CONCAT('SO', RIGHT('000000' + CONVERT(VARCHAR(6), n.n), 6)) AS OrderNumber,
    ((n.n - 1) % @CustomerCount) + 1 AS CustomerID,
    CASE WHEN ch.ChannelCode = 'STORE' THEN ((n.n - 1) % 8) + 1 ELSE NULL END AS StoreID,
    ch.ChannelCode,
    CASE WHEN ch.ChannelCode = 'ONLINE' THEN s.WebSessionID ELSE NULL END AS WebSessionID,
    st.OrderStatusCode,
    od.OrderDate,
    CASE WHEN st.OrderStatusCode IN ('PAID','SHIPPED','DELIVERED') THEN DATEADD(MINUTE, 5, od.OrderDate) ELSE NULL END AS PaidAt,
    CASE WHEN st.OrderStatusCode = 'CANCELLED' THEN DATEADD(HOUR, 2, od.OrderDate) ELSE NULL END AS CancelledAt,
    CASE WHEN ch.ChannelCode = 'STORE' THEN CAST(0.00 AS DECIMAL(10,2))
         ELSE CAST(3.99 + (n.n % 3) AS DECIMAL(10,2))
    END AS ShippingAmount
FROM n
CROSS APPLY
(
    SELECT
        ChannelCode =
            CASE
                WHEN n.n % 3 = 1 THEN 'ONLINE'
                WHEN n.n % 3 = 2 THEN 'STORE'
                ELSE 'PHONE'
            END
) ch
LEFT JOIN web.Session s
    ON s.SessionSeq = n.n
CROSS APPLY
(
    SELECT
        OrderStatusCode =
            CASE
                WHEN n.n % 25 = 0 THEN 'CANCELLED'
                WHEN n.n % 13 = 0 THEN 'PAID'
                WHEN n.n % 7  = 0 THEN 'SHIPPED'
                ELSE 'DELIVERED'
            END
) st
CROSS APPLY
(
    SELECT
        OrderDate =
            DATEADD
            (
                MINUTE,
                (n.n * 17) % 1440,
                DATEADD(DAY, (n.n - 1) % 546, CAST('2024-01-01' AS DATETIME2(0)))
            )
) od;

/* Sales order lines (generated, with effective-dated list price lookup and some intentional unit price discrepancies) */
DECLARE @ProductCount INT = (SELECT COUNT(*) FROM ref.Product);

;WITH LineNums AS
(
    SELECT 1 AS LineNumber UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
)
INSERT sales.SalesOrderLine
(
    SalesOrderID, LineNumber, ProductID, Quantity, UnitPrice, DiscountAmount, TaxAmount
)
SELECT
    o.SalesOrderID,
    ln.LineNumber,
    p.ProductID,
    x.Qty AS Quantity,
    CAST(pl.ListPrice + x.PriceAdj AS DECIMAL(10,2)) AS UnitPrice,
    CAST(ROUND(x.Qty * (pl.ListPrice + x.PriceAdj) * x.DiscountRate, 2) AS DECIMAL(10,2)) AS DiscountAmount,
    CAST
    (
        ROUND
        (
            (x.Qty * (pl.ListPrice + x.PriceAdj) - ROUND(x.Qty * (pl.ListPrice + x.PriceAdj) * x.DiscountRate, 2)) * 0.08,
            2
        )
        AS DECIMAL(10,2)
    ) AS TaxAmount
FROM sales.SalesOrder o
JOIN LineNums ln
  ON ln.LineNumber <= ((o.SalesOrderID % 4) + 1)
CROSS APPLY
(
    SELECT ProductID = ((o.SalesOrderID * 13 + ln.LineNumber * 7) % @ProductCount) + 1
) p
CROSS APPLY
(
    SELECT
        Qty = ((o.SalesOrderID + ln.LineNumber) % 3) + 1,
        PriceAdj = CASE WHEN (o.SalesOrderID + ln.LineNumber) % 23 = 0 THEN 2.00 ELSE 0.00 END,
        DiscountRate =
            CAST
            (
                CASE
                    WHEN (o.SalesOrderID + ln.LineNumber) % 13 = 0 THEN 0.15
                    WHEN (o.SalesOrderID + ln.LineNumber) % 9  = 0 THEN 0.10
                    WHEN (o.SalesOrderID + ln.LineNumber) % 5  = 0 THEN 0.05
                    ELSE 0.00
                END
                AS DECIMAL(5,2)
            )
) x
CROSS APPLY
(
    SELECT TOP (1) ph.ListPrice
    FROM ref.ProductListPriceHistory ph
    WHERE ph.ProductID = p.ProductID
      AND ph.EffectiveFrom <= CONVERT(DATE, o.OrderDate)
      AND (ph.EffectiveTo IS NULL OR ph.EffectiveTo > CONVERT(DATE, o.OrderDate))
    ORDER BY ph.EffectiveFrom DESC
) pl;

/* Update order header totals from lines (+ shipping) */
;WITH s AS
(
    SELECT
        SalesOrderID,
        SUM(GrossAmount) AS GrossAmount,
        SUM(DiscountAmount) AS DiscountAmount,
        SUM(TaxAmount) AS TaxAmount,
        SUM(NetAmount) AS NetLinesAmount
    FROM sales.SalesOrderLine
    GROUP BY SalesOrderID
)
UPDATE o
SET
    HeaderGrossAmount = s.GrossAmount,
    HeaderDiscountAmount = s.DiscountAmount,
    HeaderTaxAmount = s.TaxAmount,
    HeaderNetAmount = s.NetLinesAmount + o.ShippingAmount
FROM sales.SalesOrder o
JOIN s
  ON s.SalesOrderID = o.SalesOrderID;

/* Introduce a few header-vs-lines mismatches for reconciliation practice */
UPDATE o
SET HeaderNetAmount = HeaderNetAmount + 0.50
FROM sales.SalesOrder o
WHERE o.SalesOrderID % 37 = 0;

UPDATE o
SET HeaderNetAmount = HeaderNetAmount - 0.25
FROM sales.SalesOrder o
WHERE o.SalesOrderID % 53 = 0
  AND o.HeaderNetAmount IS NOT NULL;

/* Shipments (some shipped/delivered orders intentionally missing a shipment record) */
INSERT logistics.Shipment
(
    SalesOrderID, CarrierID, ShipmentStatusCode, ShippedAt, DeliveredAt, TrackingNumber
)
SELECT
    o.SalesOrderID,
    ((o.SalesOrderID - 1) % 4) + 1 AS CarrierID,
    CASE
        WHEN o.SalesOrderID % 41 = 0 THEN 'LOST'
        WHEN o.OrderStatusCode = 'DELIVERED' THEN 'DELIVERED'
        ELSE 'IN_TRANSIT'
    END AS ShipmentStatusCode,
    sh.ShippedAt,
    CASE
        WHEN o.OrderStatusCode = 'DELIVERED' AND o.SalesOrderID % 41 <> 0
            THEN DATEADD(DAY, (o.SalesOrderID % 5) + 1, sh.ShippedAt)
        ELSE NULL
    END AS DeliveredAt,
    CONCAT('TRK', RIGHT('0000000000' + CONVERT(VARCHAR(10), o.SalesOrderID), 10)) AS TrackingNumber
FROM sales.SalesOrder o
CROSS APPLY
(
    SELECT ShippedAt = DATEADD(DAY, (o.SalesOrderID % 3) + 1, o.OrderDate)
) sh
WHERE o.OrderStatusCode IN ('SHIPPED','DELIVERED')
  AND o.SalesOrderID % 17 <> 0; -- missing shipments anomaly

/* Create a few delivered shipments with DeliveredAt NULL (inconsistent) */
UPDATE s
SET DeliveredAt = NULL
FROM logistics.Shipment s
WHERE s.ShipmentStatusCode = 'DELIVERED'
  AND s.ShipmentID % 101 = 0;

/* Returns (some delivered orders have returns + refunds) */
INSERT sales.ReturnHeader
(
    ReturnNumber, SalesOrderID, CustomerID, ReturnReasonCode, ReturnStatusCode, CreatedAt, ReceivedAt
)
SELECT
    CONCAT('R', RIGHT('000000' + CONVERT(VARCHAR(6), o.SalesOrderID), 6)) AS ReturnNumber,
    o.SalesOrderID,
    o.CustomerID,
    CHOOSE((o.SalesOrderID % 5) + 1, 'DAMAGED','NOT_AS_DESCRIBED','SIZE_ISSUE','LATE_DELIVERY','OTHER') AS ReturnReasonCode,
    CASE
        WHEN o.SalesOrderID % 4 = 0 THEN 'REFUNDED'
        WHEN o.SalesOrderID % 3 = 0 THEN 'RECEIVED'
        ELSE 'REQUESTED'
    END AS ReturnStatusCode,
    DATEADD(DAY, (o.SalesOrderID % 20) + 1, s.DeliveredAt) AS CreatedAt,
    CASE
        WHEN o.SalesOrderID % 4 = 0 THEN DATEADD(DAY, (o.SalesOrderID % 20) + 2, s.DeliveredAt)
        WHEN o.SalesOrderID % 3 = 0 THEN DATEADD(DAY, (o.SalesOrderID % 20) + 2, s.DeliveredAt)
        ELSE NULL
    END AS ReceivedAt
FROM sales.SalesOrder o
JOIN logistics.Shipment s
  ON s.SalesOrderID = o.SalesOrderID
WHERE o.OrderStatusCode = 'DELIVERED'
  AND s.ShipmentStatusCode = 'DELIVERED'
  AND o.SalesOrderID % 11 = 0;

/* Return lines: one line per return, refund one unit of the first order line */
INSERT sales.ReturnLine
(
    ReturnID, SalesOrderLineID, Quantity, RefundAmount, RefundedAt, RefundStatusCode
)
SELECT
    rh.ReturnID,
    sol.SalesOrderLineID,
    1 AS Quantity,
    CAST(ROUND(sol.NetAmount / NULLIF(sol.Quantity, 0), 2) AS DECIMAL(10,2)) AS RefundAmount,
    CASE WHEN rh.ReturnStatusCode = 'REFUNDED' THEN DATEADD(DAY, (rh.ReturnID % 10) + 1, rh.CreatedAt) ELSE NULL END AS RefundedAt,
    CASE WHEN rh.ReturnStatusCode = 'REFUNDED' THEN 'REFUNDED' ELSE 'PENDING' END AS RefundStatusCode
FROM sales.ReturnHeader rh
JOIN sales.SalesOrderLine sol
  ON sol.SalesOrderID = rh.SalesOrderID
 AND sol.LineNumber = 1;

/* Create a few inconsistent refund records (REFUNDED but RefundedAt NULL) */
UPDATE rl
SET RefundedAt = NULL
FROM sales.ReturnLine rl
WHERE rl.RefundStatusCode = 'REFUNDED'
  AND rl.ReturnLineID % 55 = 0;

/* Web events: baseline PAGEVIEW for all sessions */
INSERT web.Event(WebSessionID, EventTime, EventType, ProductID, SalesOrderID, Properties)
SELECT
    s.WebSessionID,
    s.StartedAt AS EventTime,
    'PAGEVIEW' AS EventType,
    NULL AS ProductID,
    NULL AS SalesOrderID,
    CONVERT(NVARCHAR(MAX),
        N'{"ab_variant":"' + CASE WHEN s.SessionSeq % 2 = 0 THEN 'A' ELSE 'B' END + N'","page":"home"}'
    ) AS Properties
FROM web.Session s;

/* SEARCH events for some sessions */
INSERT web.Event(WebSessionID, EventTime, EventType, ProductID, SalesOrderID, Properties)
SELECT
    s.WebSessionID,
    DATEADD(MINUTE, 1, s.StartedAt),
    'SEARCH',
    NULL,
    NULL,
    CONVERT(NVARCHAR(MAX),
        N'{"ab_variant":"' + CASE WHEN s.SessionSeq % 2 = 0 THEN 'A' ELSE 'B' END + N'","query":"wireless"}'
    )
FROM web.Session s
WHERE s.SessionSeq % 6 = 0
  AND s.SessionSeq % 77 <> 0;

/* ADD_TO_CART for sessions that progress (exclude bot sessions) */
INSERT web.Event(WebSessionID, EventTime, EventType, ProductID, SalesOrderID, Properties)
SELECT
    s.WebSessionID,
    DATEADD(MINUTE, 2, s.StartedAt),
    'ADD_TO_CART',
    ((s.SessionSeq * 9) % @ProductCount) + 1 AS ProductID,
    NULL,
    CONVERT(NVARCHAR(MAX),
        N'{"ab_variant":"' + CASE WHEN s.SessionSeq % 2 = 0 THEN 'A' ELSE 'B' END + N'","qty":1}'
    )
FROM web.Session s
WHERE s.SessionSeq % 10 >= 5
  AND s.SessionSeq % 77 <> 0;

/* CHECKOUT for sessions that progress further (exclude bot sessions) */
INSERT web.Event(WebSessionID, EventTime, EventType, ProductID, SalesOrderID, Properties)
SELECT
    s.WebSessionID,
    DATEADD(MINUTE, 5, s.StartedAt),
    'CHECKOUT',
    NULL,
    NULL,
    CONVERT(NVARCHAR(MAX),
        N'{"ab_variant":"' + CASE WHEN s.SessionSeq % 2 = 0 THEN 'A' ELSE 'B' END + N'","step":"payment"}'
    )
FROM web.Session s
WHERE s.SessionSeq % 10 >= 7
  AND s.SessionSeq % 77 <> 0;

/* PURCHASE events for a subset of ONLINE delivered orders (exclude bot sessions) */
INSERT web.Event(WebSessionID, EventTime, EventType, ProductID, SalesOrderID, Properties)
SELECT
    s.WebSessionID,
    DATEADD(MINUTE, 8, s.StartedAt),
    'PURCHASE',
    NULL,
    o.SalesOrderID,
    CONVERT(NVARCHAR(MAX),
        N'{"ab_variant":"' + CASE WHEN s.SessionSeq % 2 = 0 THEN 'A' ELSE 'B' END
        + N'","order_number":"' + o.OrderNumber
        + N'","payment":"card"}'
    )
FROM web.Session s
JOIN sales.SalesOrder o
  ON o.WebSessionID = s.WebSessionID
WHERE o.ChannelCode = 'ONLINE'
  AND o.OrderStatusCode = 'DELIVERED'
  AND s.SessionSeq % 10 = 9
  AND s.SessionSeq % 77 <> 0;

/* Bot-like sessions: generate many rapid events */
;WITH BotSessions AS
(
    SELECT WebSessionID, StartedAt, SessionSeq
    FROM web.Session
    WHERE SessionSeq % 77 = 0
),
Nums AS
(
    SELECT TOP (200) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
)
INSERT web.Event(WebSessionID, EventTime, EventType, ProductID, SalesOrderID, Properties)
SELECT
    b.WebSessionID,
    DATEADD(SECOND, n.n, b.StartedAt),
    CASE WHEN n.n % 20 = 0 THEN 'ERROR' ELSE 'PAGEVIEW' END,
    NULL,
    NULL,
    CONVERT(NVARCHAR(MAX),
        N'{"ab_variant":"' + CASE WHEN b.SessionSeq % 2 = 0 THEN 'A' ELSE 'B' END
        + N'","bot_noise":true,"seq":' + CONVERT(NVARCHAR(10), n.n) + N'}'
    )
FROM BotSessions b
CROSS JOIN Nums n;

COMMIT;
GO