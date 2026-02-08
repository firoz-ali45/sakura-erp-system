# pgAdmin Configuration Fix

## Problem: Port 5432 Conflict

**Issue:** pgAdmin mein port 5432 set hai, lekin yeh **PostgreSQL ka port hai**, pgAdmin ka nahi!

pgAdmin ka apna port alag hota hai (usually 5050, 80, ya random).

## Solution: Port Fix Karein

### Step 1: pgAdmin Configuration Window Mein

1. **"Fixed port number?" checkbox UNCHECK karo** (uncheck karo)
2. Ya phir **Port Number ko 5050** ya **80** set karo (5432 nahi!)
3. **"Save"** button click karo
4. **"Yes"** click karo (restart confirmation par)

### Step 2: pgAdmin Restart Karein

1. pgAdmin completely band karo
2. Task Manager mein check karo ki pgAdmin process band ho gaya
3. Phir se pgAdmin kholo

## Alternative: Default Settings Use Karein

**Sabse easy tarika:**

1. **"Fixed port number?" checkbox UNCHECK karo**
2. pgAdmin automatically random port use karega
3. **"Save"** → **"Yes"** (restart)

## Fatal Error Ka Solution

Agar "Fatal Error" aa raha hai:

1. **pgAdmin completely close karo**
2. **Task Manager** kholo (Ctrl + Shift + Esc)
3. **"pgAdmin"** process dhundho
4. **End Task** karo (agar running hai)
5. **pgAdmin phir se kholo**

## Correct Configuration

**pgAdmin Configuration:**
- ✅ **Fixed port number?**: UNCHECKED (ya phir 5050/80)
- ✅ **Port Number**: 5050 ya 80 (5432 nahi!)
- ✅ **Connection Timeout**: 10 (theek hai)
- ✅ **Open Documentation in Default Browser?**: CHECKED (optional)

**PostgreSQL Configuration (alag):**
- Port: 5432 (yeh theek hai, PostgreSQL ka port hai)

## Quick Fix Steps

1. pgAdmin Configuration window mein:
   - "Fixed port number?" **UNCHECK** karo
   - Ya port **5050** set karo
   - **Save** karo

2. Confirmation par **Yes** click karo (restart)

3. pgAdmin restart hoga

4. Ab theek chalega!

## Agar Abhi Bhi Problem Hai

**Complete Reset:**

1. pgAdmin band karo
2. Ye folder delete karo:
   ```
   %APPDATA%\pgAdmin
   ```
3. pgAdmin phir se kholo
4. Fresh configuration hoga

---

**Main point:** Port 5432 PostgreSQL ke liye hai, pgAdmin ke liye nahi! pgAdmin ko random port ya 5050/80 use karna chahiye.

