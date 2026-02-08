# pgAdmin Se Database Setup (Step-by-Step)

## Step 1: PostgreSQL Server Connect Karein

pgAdmin welcome screen mein:

1. **"Add New Server"** button click karo (Quick Links section mein)
   
   Ya phir:
   - Left side **"Servers"** par right-click karo
   - **"Create" → "Server"** select karo

2. **"General" tab:**
   - **Name**: `Local PostgreSQL` (ya kuch bhi naam)
   - **Server group**: `Servers` (default)

3. **"Connection" tab:**
   - **Host name/address**: `localhost`
   - **Port**: `5432`
   - **Maintenance database**: `postgres`
   - **Username**: `postgres`
   - **Password**: (apna PostgreSQL password - jo install ke time set kiya tha)
   - **"Save password"** checkbox tick karo (optional)

4. **"Save"** button click karo

5. Agar password correct hai, to server connect ho jayega ✅

## Step 2: Database Create Karein

1. Left side **"Servers"** expand karo
2. **"PostgreSQL 18"** (ya jo version hai) expand karo
3. **"Databases"** par right-click karo
4. **"Create" → "Database"** click karo

5. **"General" tab:**
   - **Database**: `sakura_erp` (name type karo)
   - **Owner**: `postgres` (default)
   - **Comment**: (optional) "Sakura ERP Database"

6. **"Save"** button click karo

**Bas! Database `sakura_erp` create ho gaya! ✅**

## Step 3: Verify Database

1. Left side **"Databases"** expand karo
2. **"sakura_erp"** database dikhna chahiye
3. Click karo - empty hai (abhi tables nahi hain)

---

**Next:** Backend migrations run karein (tables create honge)

