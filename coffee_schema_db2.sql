-- =====================================================================
-- Coffee Shop Chain - Central Database (3NF)
-- IBM Db2 on Cloud
--
-- Objects are created in the user's default schema (e.g. TMC83249),
-- so no schema prefix is required.
--
-- Translated from the PostgreSQL version:
--   numeric(10,2)           -> DECIMAL(10,2)
--   time without time zone  -> TIME
--   DROP ... CASCADE        -> DROP TABLE (no CASCADE in Db2)
-- =====================================================================


-- ---------------------------------------------------------------------
-- Drop existing objects, children first.
-- Db2 has no DROP TABLE IF EXISTS: on a first run these will report
-- SQLCODE -204 (object not found), which is safe to ignore.
-- ---------------------------------------------------------------------
DROP TABLE sales_detail;
DROP TABLE sales_transaction;
DROP TABLE product;
DROP TABLE product_type;
DROP TABLE customer;
DROP TABLE sales_outlet;
DROP TABLE staff;


-- =====================================================================
-- TABLES
-- Foreign keys are added after all tables exist, so creation order
-- does not matter.
-- =====================================================================

-- ---------------------------------------------------------------------
-- staff
-- ---------------------------------------------------------------------
CREATE TABLE staff
(
    staff_id    INTEGER      NOT NULL,
    first_name  VARCHAR(50)  NOT NULL,
    last_name   VARCHAR(50)  NOT NULL,
    "position"  VARCHAR(50),
    start_date  DATE,
    location    VARCHAR(20),

    CONSTRAINT pk_staff PRIMARY KEY (staff_id)
);


-- ---------------------------------------------------------------------
-- sales_outlet
-- manager holds a staff_id, but is not enforced as a foreign key:
-- staff and outlets are related through sales_transaction in this design.
-- ---------------------------------------------------------------------
CREATE TABLE sales_outlet
(
    sales_outlet_id    INTEGER      NOT NULL,
    sales_outlet_type  VARCHAR(20),
    address            VARCHAR(100),
    city               VARCHAR(50),
    telephone          VARCHAR(20),
    postal_code        VARCHAR(10),
    manager            INTEGER,

    CONSTRAINT pk_sales_outlet PRIMARY KEY (sales_outlet_id)
);


-- ---------------------------------------------------------------------
-- customer
-- customer_id 0 is reserved for walk-in (non-loyalty) sales.
-- ---------------------------------------------------------------------
CREATE TABLE customer
(
    customer_id    INTEGER      NOT NULL,
    customer_name  VARCHAR(80),
    email          VARCHAR(80),
    reg_date       DATE,
    card_number    VARCHAR(20),
    date_of_birth  DATE,
    gender         CHAR(1),

    CONSTRAINT pk_customer PRIMARY KEY (customer_id)
);


-- ---------------------------------------------------------------------
-- product_type
-- Each category/type pair is stored once rather than repeated
-- on every product row.
-- ---------------------------------------------------------------------
CREATE TABLE product_type
(
    product_type_id   INTEGER      NOT NULL,
    product_type      VARCHAR(50)  NOT NULL,
    product_category  VARCHAR(50)  NOT NULL,

    CONSTRAINT pk_product_type PRIMARY KEY (product_type_id)
);


-- ---------------------------------------------------------------------
-- product
-- ---------------------------------------------------------------------
CREATE TABLE product
(
    product_id       INTEGER       NOT NULL,
    product_name     VARCHAR(100)  NOT NULL,
    description      VARCHAR(250),
    product_price    DECIMAL(10,2),
    product_type_id  INTEGER,

    CONSTRAINT pk_product PRIMARY KEY (product_id)
);


-- ---------------------------------------------------------------------
-- sales_transaction   (RECEIPT HEADER)
-- One row per sale. transaction_id is unique here because the
-- product line items were moved to sales_detail.
-- ---------------------------------------------------------------------
CREATE TABLE sales_transaction
(
    transaction_id    INTEGER  NOT NULL,
    transaction_date  DATE,
    transaction_time  TIME,
    sales_outlet_id   INTEGER,
    staff_id          INTEGER,
    customer_id       INTEGER,

    CONSTRAINT pk_sales_transaction PRIMARY KEY (transaction_id)
);


-- ---------------------------------------------------------------------
-- sales_detail   (RECEIPT LINE ITEMS)
-- price is stored here rather than read from product, so the amount
-- actually charged survives later catalogue price changes.
-- ---------------------------------------------------------------------
CREATE TABLE sales_detail
(
    sales_detail_id  INTEGER        NOT NULL,
    transaction_id   INTEGER,
    product_id       INTEGER,
    quantity         INTEGER,
    price            DECIMAL(10,2),

    CONSTRAINT pk_sales_detail PRIMARY KEY (sales_detail_id)
);


-- =====================================================================
-- FOREIGN KEYS
-- Six relationships, matching the ERD.
-- =====================================================================

ALTER TABLE product
    ADD CONSTRAINT fk_product_type FOREIGN KEY (product_type_id)
    REFERENCES product_type (product_type_id);

ALTER TABLE sales_transaction
    ADD CONSTRAINT fk_txn_staff FOREIGN KEY (staff_id)
    REFERENCES staff (staff_id);

ALTER TABLE sales_transaction
    ADD CONSTRAINT fk_txn_outlet FOREIGN KEY (sales_outlet_id)
    REFERENCES sales_outlet (sales_outlet_id);

ALTER TABLE sales_transaction
    ADD CONSTRAINT fk_txn_customer FOREIGN KEY (customer_id)
    REFERENCES customer (customer_id);

ALTER TABLE sales_detail
    ADD CONSTRAINT fk_detail_transaction FOREIGN KEY (transaction_id)
    REFERENCES sales_transaction (transaction_id);

ALTER TABLE sales_detail
    ADD CONSTRAINT fk_detail_product FOREIGN KEY (product_id)
    REFERENCES product (product_id);


-- =====================================================================
-- INDEXES
-- Db2 indexes primary keys automatically but not foreign keys,
-- and these columns carry every join in the schema.
-- =====================================================================

CREATE INDEX idx_product_type    ON product (product_type_id);
CREATE INDEX idx_txn_staff       ON sales_transaction (staff_id);
CREATE INDEX idx_txn_outlet      ON sales_transaction (sales_outlet_id);
CREATE INDEX idx_txn_customer    ON sales_transaction (customer_id);
CREATE INDEX idx_detail_txn      ON sales_detail (transaction_id);
CREATE INDEX idx_detail_product  ON sales_detail (product_id);
