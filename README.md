# Coffee Shop Chain — Central Database Design

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat&logo=postgresql&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=flat&logo=mysql&logoColor=white)
![IBM Db2](https://img.shields.io/badge/IBM%20Db2-052FAD?style=flat&logo=ibm&logoColor=white)
![Neon](https://img.shields.io/badge/Neon-00E599?style=flat&logo=postgresql&logoColor=white)
![pgAdmin](https://img.shields.io/badge/pgAdmin-326690?style=flat&logo=postgresql&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-025E8C?style=flat&logo=amazondynamodb&logoColor=white)

Designing a normalized relational database for a coffee shop chain preparing to
franchise, then serving subsets of that data out to three different database engines.

---

## The problem

The business kept its data in five disconnected places:

| Source | Format |
|---|---|
| Staff records | Spreadsheet |
| Sales outlet records | Spreadsheet |
| Sales transactions | CSV export from the registers |
| Customer records | CSV export from a custom CRM |
| Product catalogue | Spreadsheet from their supplier |

Two things had to happen: consolidate all of it into one central database, and then
make defined subsets available to people outside the company.

---

## Design

### Entities identified
<img width="994" height="641" alt="Image1_ERD" src="https://github.com/user-attachments/assets/a1f12d0c-ad53-44c0-87a9-ae19aed07360" />

Five entities came directly from the source data: `staff`, `sales_outlet`,
`sales_transaction`, `customer`, and `product`.

Normalization added two more, bringing the final schema to seven tables.

### Normalization

**Problem 1 — the transaction table had a repeating group.**

A single receipt containing two products was stored as two rows. Both carried the same
`transaction_id`, and both repeated the date, time, outlet and employee. That meant
`transaction_id` was not unique and could not serve as a primary key, and any correction
to a shared value had to be applied consistently across rows or the data would
contradict itself.

The fix was a header/detail split:

- `sales_transaction` — one row per receipt: when, where, who served it, who bought
- `sales_detail` — one row per product on that receipt: what, how many, at what price

**Problem 2 — product category was a transitive dependency.**

`product_category` depended on `product_type`, which in turn depended on `product_id`.
A non-key column determining another non-key column violates third normal form, and in
practice it meant the same category text was repeated across every product sharing a
type.

Moving both columns into a `product_type` table stores each category/type pair once.

### Final schema

Seven tables, six one-to-many relationships:

| Child | Foreign key | Parent |
|---|---|---|
| `product` | `product_type_id` | `product_type` |
| `sales_transaction` | `staff_id` | `staff` |
| `sales_transaction` | `sales_outlet_id` | `sales_outlet` |
| `sales_transaction` | `customer_id` | `customer` |
| `sales_detail` | `transaction_id` | `sales_transaction` |
| `sales_detail` | `product_id` | `product` |

`sales_detail` sits between `sales_transaction` and `product` with a foreign key to
each. That resolves what is conceptually a many-to-many relationship — one transaction
contains many products, one product appears in many transactions — which a relational
database cannot express directly.

---

## Design decisions worth explaining

**Price is stored on the line item, not read from the product table.**
`sales_detail.price` records the amount actually charged. If the catalogue price changes
later, historical receipts still reflect what the customer paid.

**Walk-in sales use a sentinel customer rather than NULL.**
The POS extract sends `customer_id = 0` for non-loyalty sales. Inserting a customer 0
row keeps the foreign key strict instead of nullable, and makes counting walk-ins a
straightforward filter rather than a NULL check.

**`postal_code` is stored as text, not an integer.**
A New Jersey outlet at `07001` would silently lose its leading zero as a number. The
same reasoning applies to telephone numbers: no arithmetic is ever performed on them.

**Money uses `NUMERIC`/`DECIMAL`, never floating point.**
Floating point stores approximations. Summed across enough transactions, totals drift
and stop reconciling.

**Foreign keys are added after the bulk load, not before.**
The source data does not arrive in dependency order. Loading first and adding the
constraints afterwards avoids fighting the file's ordering — and because the database
validates every existing row when a constraint is added, a successful `ALTER TABLE`
proves the loaded data is consistent.

---

## Serving data to external consumers

Two external parties needed subsets of the data, which is where the three engines
diverge.

**A view** — `staff_locations_view` returns employees and their work locations for a
payroll vendor, excluding the CEO and CFO. A view stores the query rather than the
result, so it always reflects current staff with no maintenance step.

**A materialized view** — the product catalogue joined to its categories, exported for a
marketing consultant to load into their own MySQL database. Here the requirement is a
point-in-time snapshot rather than live data, so storing the result is correct.

The same requirement has three different answers depending on the engine:

| Engine | Implementation | Refresh |
|---|---|---|
| PostgreSQL | `CREATE MATERIALIZED VIEW` | `REFRESH MATERIALIZED VIEW` |
| IBM Db2 | Materialized Query Table (MQT) | `REFRESH TABLE` |
| MySQL | No equivalent exists | — |

Db2's MQT is declared with `DATA INITIALLY DEFERRED REFRESH DEFERRED`, and returns an
error rather than an empty result if you query it before the first refresh.

---

## Other differences encountered across engines

| | PostgreSQL | MySQL | Db2 |
|---|---|---|---|
| Object hierarchy | server → database → schema → table | server → database → table | server → database → schema → table |
| `CREATE SCHEMA` | namespace inside a database | synonym for `CREATE DATABASE` | requires elevated privileges |
| `DROP TABLE IF EXISTS` | supported | supported | not supported |
| Row limiting | `LIMIT 100` | `LIMIT 100` | `FETCH FIRST 100 ROWS ONLY` |
| Decimal type | `NUMERIC(10,2)` | `DECIMAL(10,2)` | `DECIMAL(10,2)` |

MySQL treats schema and database as the same object, so the two-level
`database → schema` structure used in PostgreSQL cannot be reproduced there.

---

## Repository contents

```
sql/
  01_schema_postgres.sql     DDL for PostgreSQL (Neon)
  02_views_postgres.sql      View and materialized view
  03_schema_db2.sql          DDL translated for IBM Db2
  04_mqt_db2.sql             Materialized Query Table and view
  05_analysis_queries.sql    Analytical queries run against MySQL
images/
  erd-initial.png            Un-normalized ERD, five entities
  erd-normalized.png         Final ERD, seven tables and six relationships
  pgadmin-objects.png        Tables, view and materialized view in pgAdmin
  neon-sql-editor.png        Schema creation in the Neon console
  mysql-workbench.png        Analytical queries in MySQL Workbench
  db2-mqt.png                MQT and view in the Db2 web console
```

---

## Tooling

| Engine | Hosting | Client |
|---|---|---|
| PostgreSQL | Neon (cloud) | pgAdmin 4 |
| MySQL | Local, via XAMPP | MySQL Workbench, phpMyAdmin |
| IBM Db2 | IBM Cloud | Db2 web console |

The ERD was designed in the pgAdmin ERD tool, which generates the DDL script directly
from the diagram.

---

## Notes

Built as the capstone project for the IBM Data Engineering Professional Certificate.
The scenario and source data are from the course; the schema design, normalization
decisions, multi-engine implementation and queries here are my own.
