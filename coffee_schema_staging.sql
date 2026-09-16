-- =====================================================================
-- Coffee Shop Chain - Central Database (3NF)
-- PostgreSQL / Neon
--
-- Column names follow the course script so the supplied CoffeeData.sql
-- inserts load without modification. Data types, constraint naming and
-- indexing have been revised.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- Drop existing objects so the script can be re-run safely.
-- CASCADE also removes dependent foreign keys and views.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS staging.sales_detail      CASCADE;
DROP TABLE IF EXISTS staging.sales_transaction CASCADE;
DROP TABLE IF EXISTS staging.product           CASCADE;
DROP TABLE IF EXISTS staging.product_type      CASCADE;
DROP TABLE IF EXISTS staging.customer          CASCADE;
DROP TABLE IF EXISTS staging.sales_outlet      CASCADE;
DROP TABLE IF EXISTS staging.staff             CASCADE;


-- =====================================================================
-- TABLES
-- Foreign keys are added after all tables exist, so creation order
-- does not matter.
-- =====================================================================

-- ---------------------------------------------------------------------
-- staff
-- ---------------------------------------------------------------------
CREATE TABLE staging.staff
(
    staff_id    integer                NOT NULL,
    first_name  character varying(50)  NOT NULL,
    last_name   character varying(50)  NOT NULL,
    "position"  character varying(50),
    start_date  date,
    location    character varying(20),

    CONSTRAINT pk_staff PRIMARY KEY (staff_id)
);


-- ---------------------------------------------------------------------
-- sales_outlet
-- manager holds a staff_id: the employee who runs the outlet.
-- Nullable, because the warehouse has no store manager.
-- ---------------------------------------------------------------------
CREATE TABLE staging.sales_outlet
(
    sales_outlet_id    integer                NOT NULL,
    sales_outlet_type  character varying(20),
    address            character varying(100),
    city               character varying(50),
    telephone          character varying(20),
    postal_code        character varying(10),
    manager            integer,

    CONSTRAINT pk_sales_outlet PRIMARY KEY (sales_outlet_id)
);


-- ---------------------------------------------------------------------
-- customer
-- customer_id 0 is reserved for walk-in (non-loyalty) sales.
-- ---------------------------------------------------------------------
CREATE TABLE staging.customer
(
    customer_id    integer                NOT NULL,
    customer_name  character varying(80),
    email          character varying(80),
    reg_date       date,
    card_number    character varying(20),
    date_of_birth  date,
    gender         character(1),

    CONSTRAINT pk_customer PRIMARY KEY (customer_id)
);


-- ---------------------------------------------------------------------
-- product_type
-- Each category/type pair is stored once rather than repeated
-- on every product row.
-- ---------------------------------------------------------------------
CREATE TABLE staging.product_type
(
    product_type_id   integer                NOT NULL,
    product_type      character varying(50)  NOT NULL,
    product_category  character varying(50)  NOT NULL,

    CONSTRAINT pk_product_type PRIMARY KEY (product_type_id)
);


-- ---------------------------------------------------------------------
-- product
-- ---------------------------------------------------------------------
CREATE TABLE staging.product
(
    product_id       integer                NOT NULL,
    product_name     character varying(100) NOT NULL,
    description      character varying(250),
    product_price    numeric(10,2),
    product_type_id  integer,

    CONSTRAINT pk_product PRIMARY KEY (product_id)
);


-- ---------------------------------------------------------------------
-- sales_transaction   (RECEIPT HEADER)
-- One row per sale. transaction_id is unique here because the
-- product line items were moved to sales_detail.
-- ---------------------------------------------------------------------
CREATE TABLE staging.sales_transaction
(
    transaction_id    integer  NOT NULL,
    transaction_date  date,
    transaction_time  time without time zone,
    sales_outlet_id   integer,
    staff_id          integer,
    customer_id       integer,

    CONSTRAINT pk_sales_transaction PRIMARY KEY (transaction_id)
);


-- ---------------------------------------------------------------------
-- sales_detail   (RECEIPT LINE ITEMS)
-- price is stored here rather than read from product, so the amount
-- actually charged survives later catalogue price changes.
-- ---------------------------------------------------------------------
CREATE TABLE staging.sales_detail
(
    sales_detail_id  integer        NOT NULL,
    transaction_id   integer,
    product_id       integer,
    quantity         integer,
    price            numeric(10,2),

    CONSTRAINT pk_sales_detail PRIMARY KEY (sales_detail_id)
);


-- =====================================================================
-- FOREIGN KEYS
-- =====================================================================

ALTER TABLE staging.sales_outlet
    ADD CONSTRAINT fk_outlet_manager FOREIGN KEY (manager)
    REFERENCES staging.staff (staff_id);

ALTER TABLE staging.product
    ADD CONSTRAINT fk_product_type FOREIGN KEY (product_type_id)
    REFERENCES staging.product_type (product_type_id);

ALTER TABLE staging.sales_transaction
    ADD CONSTRAINT fk_txn_staff FOREIGN KEY (staff_id)
    REFERENCES staging.staff (staff_id);

ALTER TABLE staging.sales_transaction
    ADD CONSTRAINT fk_txn_outlet FOREIGN KEY (sales_outlet_id)
    REFERENCES staging.sales_outlet (sales_outlet_id);

ALTER TABLE staging.sales_transaction
    ADD CONSTRAINT fk_txn_customer FOREIGN KEY (customer_id)
    REFERENCES staging.customer (customer_id);

ALTER TABLE staging.sales_detail
    ADD CONSTRAINT fk_detail_transaction FOREIGN KEY (transaction_id)
    REFERENCES staging.sales_transaction (transaction_id);

ALTER TABLE staging.sales_detail
    ADD CONSTRAINT fk_detail_product FOREIGN KEY (product_id)
    REFERENCES staging.product (product_id);


-- =====================================================================
-- INDEXES
-- PostgreSQL indexes primary keys automatically but not foreign keys,
-- and these columns carry every join in the schema.
-- =====================================================================

CREATE INDEX idx_outlet_manager  ON staging.sales_outlet (manager);
CREATE INDEX idx_product_type    ON staging.product (product_type_id);
CREATE INDEX idx_txn_staff       ON staging.sales_transaction (staff_id);
CREATE INDEX idx_txn_outlet      ON staging.sales_transaction (sales_outlet_id);
CREATE INDEX idx_txn_customer    ON staging.sales_transaction (customer_id);
CREATE INDEX idx_detail_txn      ON staging.sales_detail (transaction_id);
CREATE INDEX idx_detail_product  ON staging.sales_detail (product_id);

COMMIT;
