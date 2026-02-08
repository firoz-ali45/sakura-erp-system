# Deploy Accounts Payable Dashboard to Surge

## Prerequisites
1. Install Surge CLI: `npm install -g surge`
2. Create Surge account (if not exists): `surge` (will prompt for email/password)

## Deployment Steps

### Option 1: Using deploy.sh (Linux/Mac/Git Bash)
```bash
cd sakura-accounts-payable-dashboard
chmod +x deploy.sh
./deploy.sh
```

### Option 2: Manual Deployment
```bash
cd sakura-accounts-payable-dashboard
surge . sakura-accounts-payable-dashboard.surge.sh
```

## Expected Result
- Dashboard available at: https://sakura-accounts-payable-dashboard.surge.sh/
- All HTML files accessible
- CSS and assets load correctly
- Mobile-responsive

## Troubleshooting
- If domain already taken, Surge will suggest alternative
- Ensure all files are in the directory before deploying
- Check `_headers` file for CORS/security headers
