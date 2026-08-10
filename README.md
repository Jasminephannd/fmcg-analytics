# Retail Analytics Pipeline (dunnhumby)

A small end-to-end data pipeline that turns raw grocery data into a clean, modelled database and a Power BI dashboard.

It follows the **Medallion** pattern in PostgreSQL:

- **bronze** – the raw CSVs
- **silver** – cleaned tables
- **gold** – a galaxy model (facts + dimensions) that feeds the dashboard

Data source: dunnhumby "The Complete Journey" on Kaggle (`frtgnn/dunnhumby-the-complete-journey`).

---

## Pre-requisites

Install these once:

1. **Python 3.14** – https://www.python.org/downloads/
2. **Docker Desktop** – https://www.docker.com/products/docker-desktop/ (this runs the database, so you don't have to install PostgreSQL)
3. **A free Kaggle account** – to download the dataset **with the API** (Step 1). This is optional: you can instead download the CSVs manually from the [dataset page](https://www.kaggle.com/datasets/frtgnn/dunnhumby-the-complete-journey), unzip them into `data/bronze/`, and skip Step 1.
4. **Power BI Desktop** (Windows) – dashboard

Make sure Docker Desktop is open and running before you start.

---

## Project layout

```
fmcg-analytics/
├── src/                 # the pipeline code (run in order)
│   ├── config.py        # database connection
│   ├── ingest.py        # 1. download the data from Kaggle
│   ├── bronze.py        # 2. load raw CSVs into the bronze schema
│   ├── inspect_data.py  #    (optional) profile the raw data
│   ├── silver.py        # 3. clean the data into the silver schema
│   └── gold.py          # 4. build the gold model
├── sql/
│   ├── schema.sql       # gold table definitions (run automatically by gold.py)
│   └── challenges.sql   # the PostgreSQL challenge answers
├── docker-compose.yml   # starts PostgreSQL
├── requirements.txt     # Python packages
├── .env.example         # template for your secrets
├── dashboard.pbix       # the Power BI dashboard
└── README.md
```

---

## Setup

All commands are for **Windows PowerShell**, run from inside the `fmcg-analytics` folder.
(Mac/Linux equivalents are noted where they differ.)

### 1. Create your `.env` file

Copy the template and open it:

```bash
copy .env.example .env
```

Fill in a database password and your Kaggle token. Your `.env` should look like this:

```
POSTGRES_USER=fmcg
POSTGRES_PASSWORD=fmcg_local_pw
POSTGRES_DB=fmcg
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
KAGGLE_API_TOKEN=your_kaggle_api_token   # only needed for Step 1; remove this line if you download the CSVs manually
```

**To get your Kaggle token:** go to Kaggle → your profile → **Settings** → **Create New Token**.
Copy the token value into `KAGGLE_API_TOKEN`.

> If you are downloading the CSVs manually (see Step 1), you can leave out `KAGGLE_API_TOKEN` entirely, only the `POSTGRES_*` lines are required.

### 2. Create a virtual environment and install the packages

```bash
python -m venv .venv
```
```bash
.venv\Scripts\Activate.ps1
```
```bash
pip install -r requirements.txt
```

### 3. Start the database

```bash
docker compose up -d
```

This starts PostgreSQL in the background. The data is saved between restarts, so you only need to do this once.

---

## Run the pipeline

Run these one at a time, from the project folder, with the virtual environment active.

### Step 1 – Download the data

```bash
python -m src.ingest
```
Downloads the dataset from Kaggle into `data/bronze/`.

> **No Kaggle API?** Skip this step. Download the dataset manually from the [Kaggle dataset page](https://www.kaggle.com/datasets/frtgnn/dunnhumby-the-complete-journey), unzip it, and put the CSV files directly inside `data/bronze/`. Then continue from Step 2.

### Step 2 – Load raw data into bronze

```bash
python -m src.bronze
```
Loads every CSV into the `bronze` schema exactly as-is (all text).

### Step 3 (optional) – Look at the raw data

```bash
python -m src.inspect_data
```
Prints a profile of each table (missing values, ranges, duplicates). This is to have a quick view of data for further inspection.

### Step 4 – Clean the data into silver

```bash
python -m src.silver
```
Cleans each table: fixes column names, sets the correct data types, turns the relative `DAY` number into a real date, fills blank categories with `UNKNOWN`, removes duplicate and non-sale rows, change positive to negative `RETAIL_DISC` in transaction table.

### Step 5 – Build the gold model

```bash
python -m src.gold
```
Builds the star/galaxy model (facts and dimensions) that the dashboard uses. This runs `sql/schema.sql` automatically, then fills the tables from silver.

---

## Run the SQL challenges

Open `sql/challenges.sql` in a database tool (for example DBeaver, connecting to `localhost:5432`, database `fmcg`, user `fmcg`) and run the queries.

Or run the whole file from the command line:

```bash
Get-Content sql\challenges.sql | docker exec -i fmcg_postgres psql -U fmcg -d fmcg
```

---

## Open the dashboard

1. Open `dashboard.pbix` in Power BI Desktop.
2. If it asks, sign in / allow the connection to PostgreSQL, then click **Refresh** so it pulls the latest gold data.

The connection is `localhost` / port `5432` / database `fmcg`.

---
