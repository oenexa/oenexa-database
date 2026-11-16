# 🗄️ OENEXA Developer Database & Docker Access Manual

> **Developer & AI Agent Operational Runbook**  
> **Target:** Local Development, Docker Management, CLI & GUI Access  
> **Platform:** PostgreSQL 17 + pgvector, PgBouncer, Redis 7

---

## 🚀 1. Quickstart: Launching the Local Database Platform

Navigate to the `oenexa-database` directory in your terminal:

```bash
# 1. Create your local .env from template (if not already done)
cp .env.example .env

# 2. Launch PostgreSQL 17 and Redis in background
docker compose up -d

# 3. Verify services are healthy
docker compose ps
```

*On first boot, the initialization engine automatically provisions all 9 domain databases, configures least-privilege users, enables `pgvector`, and applies the relational schemas.*

---

## 🐳 2. Essential Docker Container Commands

| Operation | Command Line | Description |
| :--- | :--- | :--- |
| **Start Stack** | `docker compose up -d` | Boots PostgreSQL 17 and Redis containers. |
| **Stop Stack** | `docker compose down` | Stops containers while **preserving data volumes**. |
| **Restart Single Service** | `docker compose restart postgres` | Restarts only the PostgreSQL engine. |
| **View Live Logs** | `docker compose logs -f postgres` | Streams live PostgreSQL engine logs. |
| **Check Health Status** | `docker compose ps` | Displays container state, ports, and healthcheck status. |
| **Interactive Bash Shell**| `docker exec -it oenexa-postgres bash` | Opens a terminal shell inside the database container. |
| **Reset Data (Fresh Start)**| `docker compose down -v && docker compose up -d` | **Wipes all local data** and re-runs initial schemas. |

---

## 💻 3. Accessing Databases via CLI (`docker exec` & `psql`)

You do not need `psql` installed on your host machine; you can execute queries directly through Docker:

### Direct One-Liner Connection (Interactive psql)
```bash
# Connect to AI Intelligence & Vector Database
docker exec -it oenexa-postgres psql -U oenexa_ai_app -d oenexa_ai_db

# Connect to Quick-Commerce Database
docker exec -it oenexa-postgres psql -U oengo_app -d oengo_commerce_db

# Connect to Sovereign Identity Database
docker exec -it oenexa-postgres psql -U oenexa_identity_app -d oenexa_identity_db

# Connect to Master DBA Superuser (Admin only)
docker exec -it oenexa-postgres psql -U postgres -d oenexa_master
```

### Essential `psql` In-Terminal Commands:
* `\l` : List all 9 domain databases.
* `\dt` : List all relational tables in current database.
* `\d <table_name>` : Describe table columns, data types, constraints, and indexes.
* `\dn` : List schemas.
* `\q` : Quit and exit `psql`.

---

## 🌐 4. Connection Directory for All 9 Decoupled Databases

| Domain Database | Port | Default User | Default Dev Password | Connection String (URI) |
| :--- | :--- | :--- | :--- | :--- |
| **Identity & IAM** | `5432` | `oenexa_identity_app` | `identity_dev_password` | `postgresql://oenexa_identity_app:identity_dev_password@localhost:5432/oenexa_identity_db` |
| **Wallet & Custody** | `5432` | `oenexa_wallet_app` | `wallet_dev_password` | `postgresql://oenexa_wallet_app:wallet_dev_password@localhost:5432/oenexa_wallet_db` |
| **Tri-Rail Pay** | `5432` | `oenexa_pay_app` | `pay_dev_password` | `postgresql://oenexa_pay_app:pay_dev_password@localhost:5432/oenexa_pay_db` |
| **Exchange & Orders** | `5432` | `oenexa_exchange_app` | `exchange_dev_password` | `postgresql://oenexa_exchange_app:exchange_dev_password@localhost:5432/oenexa_exchange_db` |
| **AMM Liquidity** | `5432` | `oenexa_liquidity_app` | `liquidity_dev_password` | `postgresql://oenexa_liquidity_app:liquidity_dev_password@localhost:5432/oenexa_liquidity_db` |
| **AI & Swarm Vector** | `5432` | `oenexa_ai_app` | `ai_dev_password` | `postgresql://oenexa_ai_app:ai_dev_password@localhost:5432/oenexa_ai_db` |
| **Market Data** | `5432` | `oenexa_market_data_app` | `market_data_dev_password` | `postgresql://oenexa_market_data_app:market_data_dev_password@localhost:5432/oenexa_market_data_db` |
| **Validator PoS** | `5432` | `oenexa_validator_app` | `validator_dev_password` | `postgresql://oenexa_validator_app:validator_dev_password@localhost:5432/oenexa_validator_db` |
| **Commerce & Fleet** | `5432` | `oengo_app` | `commerce_dev_password` | `postgresql://oengo_app:commerce_dev_password@localhost:5432/oengo_commerce_db` |
| **Master Admin (DBA)**| `5432` | `postgres` | `postgres_local_dev_secret_2026` | `postgresql://postgres:postgres_local_dev_secret_2026@localhost:5432/oenexa_master` |

---

## 🖥️ 5. Connecting with GUI Tools (DBeaver, DataGrip, pgAdmin, TablePlus)

To connect any database GUI client to your local databases:

1. **Host:** `localhost` (or `127.0.0.1`)
2. **Port:** `5432` (Direct PostgreSQL) or `6432` (PgBouncer in production)
3. **Database:** Choose target DB (e.g. `oengo_commerce_db` or `oenexa_ai_db`)
4. **Username & Password:** Use the matching credentials from the table above.
5. **SSL Mode:** `disable` (or `allow`) for local development.
6. **Authentication Method:** `SCRAM-SHA-256` (handled automatically by modern GUI clients).

---

## ⚡ 6. Accessing & Managing Redis via Docker

### Interactive Redis CLI
```bash
# Open interactive Redis terminal
docker exec -it oenexa-redis redis-cli

# Test connectivity
127.0.0.1:6379> PING
PONG

# View all stored keys
127.0.0.1:6379> KEYS *

# Inspect key type and value
127.0.0.1:6379> TYPE session:usr_123
127.0.0.1:6379> GET session:usr_123

# Monitor real-time commands streaming into Redis
127.0.0.1:6379> MONITOR
```

---

## 🔍 7. Verification & Health Probes

Run the automated health probe script anytime to inspect active backend connections and database status:

```bash
# Linux / macOS / Git Bash
bash scripts/healthcheck.sh

# Windows PowerShell
& ".\scripts\healthcheck.sh"
```

---

## ⚠️ 8. Troubleshooting FAQ

### Q1: "Port 5432 is already in use"
* **Cause:** A local PostgreSQL service is already running on Windows/Linux host.
* **Fix:** Stop local service (`net stop postgresql-x64-16` on Windows or `sudo systemctl stop postgresql` on Linux), OR change host port in `docker-compose.yml` (e.g. `"5433:5432"`).

### Q2: "FATAL: password authentication failed for user"
* **Cause:** Volume retains old credentials from an earlier startup.
* **Fix:** Reset local container volumes:
  ```bash
  docker compose down -v
  docker compose up -d
  ```

### Q3: "Cannot connect to database from another container"
* **Rule:** Containers communicate using Docker service name (`postgres` or `oenexa-postgres`), **not** `localhost`.
* **Example URL:** `postgresql://oengo_app:commerce_dev_password@postgres:5432/oengo_commerce_db`
