# Sakura ERP Migration - Deployment Guide

Complete setup and deployment instructions for the migrated ERP system.

---

## Prerequisites

- Node.js 18+ installed
- PostgreSQL 14+ installed and running
- npm or yarn package manager

---

## Project Structure

```
sakura-erp-migration/
├── frontend/          # Vue 3 + Vite frontend
├── backend/           # Express.js + Prisma backend
└── prisma/            # Database schema
```

---

## Step 1: Database Setup

### 1.1 Create PostgreSQL Database

```bash
# Connect to PostgreSQL
psql -U postgres

# Create database
CREATE DATABASE sakura_erp;

# Exit
\q
```

### 1.2 Configure Database Connection

Copy the example environment file:

```bash
cd sakura-erp-migration/backend
cp .env.example .env
```

Edit `.env` and set your database URL:

```env
DATABASE_URL="postgresql://username:password@localhost:5432/sakura_erp?schema=public"
JWT_SECRET="your-super-secret-jwt-key-change-this-in-production"
JWT_EXPIRES_IN="7d"
PORT=3000
NODE_ENV=development
CORS_ORIGIN="http://localhost:5173"
```

### 1.3 Run Prisma Migrations

```bash
cd sakura-erp-migration/backend

# Generate Prisma Client
npm run prisma:generate

# Run migrations (creates all tables)
npm run prisma:migrate

# (Optional) Open Prisma Studio to view database
npm run prisma:studio
```

---

## Step 2: Backend Setup

### 2.1 Install Dependencies

```bash
cd sakura-erp-migration/backend
npm install
```

### 2.2 Create Default Admin User

You can create an admin user using Prisma Studio or by running a seed script:

```bash
# Using Prisma Studio (recommended)
npm run prisma:studio
# Navigate to Users table and create a user manually
```

Or create a seed script at `backend/prisma/seed.js`:

```javascript
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const hashedPassword = await bcrypt.hash('admin123', 10);
  
  const admin = await prisma.user.upsert({
    where: { email: 'admin@sakura.com' },
    update: {},
    create: {
      email: 'admin@sakura.com',
      name: 'Admin User',
      passwordHash: hashedPassword,
      role: 'admin',
      status: 'active',
      permissions: {
        accountsPayable: true,
        forecasting: true,
        warehouse: true,
        userManagement: true,
        reports: true,
        settings: true
      }
    }
  });

  console.log('Admin user created:', admin);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
```

Then run:
```bash
npm run prisma:seed
```

### 2.3 Start Backend Server

```bash
# Development mode (with auto-reload)
npm run dev

# Production mode
npm start
```

Backend will run on `http://localhost:3000`

---

## Step 3: Frontend Setup

### 3.1 Install Dependencies

```bash
cd sakura-erp-migration/frontend
npm install
```

### 3.2 Configure API URL

Create `.env` file:

```bash
cd sakura-erp-migration/frontend
touch .env
```

Add:
```env
VITE_API_URL=http://localhost:3000/api
```

### 3.3 Start Development Server

```bash
npm run dev
```

Frontend will run on `http://localhost:5173`

---

## Step 4: Verify Installation

### 4.1 Test Backend

```bash
# Health check
curl http://localhost:3000/api/health

# Should return:
# {"status":"ok","timestamp":"2024-01-01T00:00:00.000Z"}
```

### 4.2 Test Frontend

1. Open browser to `http://localhost:5173`
2. You should see the login page
3. Login with admin credentials created in Step 2.2

### 4.3 Test API Authentication

```bash
# Login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sakura.com","password":"admin123"}'

# Save the token from response, then test protected endpoint:
curl http://localhost:3000/api/inventory/items \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

## Step 5: Production Build

### 5.1 Build Frontend

```bash
cd sakura-erp-migration/frontend
npm run build
```

This creates a `dist/` folder with production-ready files.

### 5.2 Serve Frontend (Production)

```bash
# Option 1: Using Vite preview
npm run preview

# Option 2: Using a static file server (e.g., nginx, Apache)
# Copy dist/ folder to your web server
```

### 5.3 Backend Production

For production, use a process manager like PM2:

```bash
# Install PM2 globally
npm install -g pm2

# Start backend with PM2
cd sakura-erp-migration/backend
pm2 start src/server.js --name sakura-erp-backend

# Save PM2 configuration
pm2 save

# Setup PM2 to start on system boot
pm2 startup
```

---

## Step 6: Environment Variables (Production)

### Backend `.env` (Production)

```env
DATABASE_URL="postgresql://user:password@host:5432/sakura_erp?schema=public"
JWT_SECRET="CHANGE-THIS-TO-A-RANDOM-SECRET-KEY"
JWT_EXPIRES_IN="7d"
PORT=3000
NODE_ENV=production
CORS_ORIGIN="https://your-frontend-domain.com"
```

### Frontend `.env.production`

```env
VITE_API_URL=https://your-backend-api.com/api
```

---

## Step 7: Database Migration from Existing System

If you have existing data in Supabase, you can migrate it:

### 7.1 Export from Supabase

1. Use Supabase dashboard to export data as SQL or CSV
2. Or use `pg_dump` if you have direct database access

### 7.2 Import to PostgreSQL

```bash
# Using psql
psql -U postgres -d sakura_erp < exported_data.sql

# Or using pg_restore
pg_restore -U postgres -d sakura_erp exported_data.dump
```

### 7.3 Verify Data

```bash
npm run prisma:studio
# Check tables have data
```

---

## Step 8: Deployment Options

### Option A: Traditional VPS/Server

1. **Backend**: Deploy to server (e.g., DigitalOcean, AWS EC2)
   - Install Node.js
   - Install PostgreSQL
   - Run backend with PM2
   - Setup reverse proxy (nginx) for API

2. **Frontend**: Deploy to same server or CDN
   - Build frontend
   - Serve with nginx or Apache
   - Or use CDN (Cloudflare, AWS CloudFront)

### Option B: Docker Deployment

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:14
    environment:
      POSTGRES_DB: sakura_erp
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  backend:
    build: ./backend
    environment:
      DATABASE_URL: postgresql://postgres:password@postgres:5432/sakura_erp
      JWT_SECRET: your-secret-key
    ports:
      - "3000:3000"
    depends_on:
      - postgres

  frontend:
    build: ./frontend
    ports:
      - "80:80"
    depends_on:
      - backend

volumes:
  postgres_data:
```

### Option C: Cloud Platforms

**Vercel/Netlify (Frontend) + Railway/Render (Backend)**

1. **Frontend**: Deploy to Vercel
   - Connect GitHub repo
   - Set build command: `npm run build`
   - Set output directory: `dist`

2. **Backend**: Deploy to Railway
   - Connect GitHub repo
   - Set start command: `npm start`
   - Add PostgreSQL database
   - Set environment variables

---

## Troubleshooting

### Database Connection Issues

```bash
# Test PostgreSQL connection
psql -U postgres -d sakura_erp -c "SELECT 1;"

# Check if PostgreSQL is running
sudo systemctl status postgresql
```

### Port Already in Use

```bash
# Find process using port 3000
lsof -i :3000

# Kill process
kill -9 <PID>
```

### CORS Errors

Ensure `CORS_ORIGIN` in backend `.env` matches your frontend URL exactly.

### Prisma Client Not Generated

```bash
cd backend
npm run prisma:generate
```

---

## Security Checklist

- [ ] Change `JWT_SECRET` to a strong random string
- [ ] Use HTTPS in production
- [ ] Set secure CORS origins
- [ ] Enable database SSL connections
- [ ] Use environment variables (never commit `.env`)
- [ ] Setup rate limiting on API
- [ ] Enable database backups
- [ ] Review and restrict API endpoints based on roles

---

## Support

For issues or questions:
1. Check Prisma logs: `npm run prisma:studio`
2. Check backend logs: `pm2 logs sakura-erp-backend`
3. Check browser console for frontend errors
4. Verify database connection and schema

---

## Next Steps

After deployment:
1. Create additional users via User Management
2. Import existing inventory data
3. Configure system settings
4. Setup automated backups
5. Monitor logs and performance

