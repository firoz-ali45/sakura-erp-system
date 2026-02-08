# Quick Start Guide

Get the migrated Sakura ERP system running in 5 minutes.

## Prerequisites Check

```bash
node --version  # Should be 18+
psql --version  # Should be 14+
```

## 1. Database Setup (2 minutes)

```bash
# Create database
createdb sakura_erp

# Or using psql
psql -U postgres
CREATE DATABASE sakura_erp;
\q
```

## 2. Backend Setup (1 minute)

```bash
cd sakura-erp-migration/backend

# Install dependencies
npm install

# Configure database (edit .env)
# DATABASE_URL="postgresql://user:password@localhost:5432/sakura_erp"

# Setup database
npm run prisma:generate
npm run prisma:migrate

# Start server
npm run dev
```

Backend runs on: `http://localhost:3000`

## 3. Frontend Setup (1 minute)

```bash
cd sakura-erp-migration/frontend

# Install dependencies
npm install

# Start dev server
npm run dev
```

Frontend runs on: `http://localhost:5173`

## 4. Create Admin User (1 minute)

```bash
# Option 1: Using Prisma Studio (GUI)
cd sakura-erp-migration/backend
npm run prisma:studio
# Navigate to Users table → Create new user

# Option 2: Using SQL
psql -U postgres -d sakura_erp
INSERT INTO users (email, name, password_hash, role, status) 
VALUES ('admin@example.com', 'Admin', '$2a$10$...', 'admin', 'active');
# (Generate password hash using: node -e "console.log(require('bcryptjs').hashSync('password123', 10))")
```

## 5. Login

1. Open `http://localhost:5173`
2. Login with admin credentials
3. Navigate to Inventory Items

## That's It! 🎉

You now have:
- ✅ Backend API running
- ✅ Frontend app running
- ✅ Database configured
- ✅ Admin user created

## Next Steps

- Explore the Inventory Items module (fully migrated)
- Review API documentation: `API_MAP.md`
- Check module mapping: `MODULE_MAPPING.md`
- Read deployment guide: `DEPLOYMENT.md`

## Troubleshooting

**Database connection error?**
```bash
# Test connection
psql -U postgres -d sakura_erp -c "SELECT 1;"
```

**Port already in use?**
```bash
# Find process
lsof -i :3000  # Backend
lsof -i :5173  # Frontend

# Kill process
kill -9 <PID>
```

**Prisma errors?**
```bash
cd backend
npm run prisma:generate
npm run prisma:migrate
```

## File Locations

- **API Endpoints**: `backend/src/routes/`
- **Vue Components**: `frontend/src/views/`
- **Database Schema**: `prisma/schema.prisma`
- **API Client**: `frontend/src/services/api.js`
- **Auth Store**: `frontend/src/stores/auth.js`

---

**Need help?** Check `DEPLOYMENT.md` for detailed instructions.

