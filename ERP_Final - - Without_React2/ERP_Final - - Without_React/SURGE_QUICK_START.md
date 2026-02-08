# ⚡ Surge.sh Quick Start - 2 Minutes

## 🚀 Fastest Way to Deploy

### Step 1: Install Surge (1 minute)

**Windows (Command Prompt)**:
```bash
npm install -g surge
```

**Mac/Linux (Terminal)**:
```bash
npm install -g surge
```

**Note**: Agar `npm` nahi hai, pehle Node.js install karein: https://nodejs.org

---

### Step 2: Deploy (1 minute)

**Option A: Use Script (Easiest)**

**Windows**:
```bash
deploy-surge.bat
```

**Mac/Linux**:
```bash
chmod +x deploy-surge.sh
./deploy-surge.sh
```

**Option B: Manual**

1. **Create 200.html**:
   ```bash
   # Windows
   copy index.html 200.html
   
   # Mac/Linux
   cp index.html 200.html
   ```

2. **Deploy**:
   ```bash
   surge
   ```

3. **Follow prompts**:
   - Email enter karein (pehli baar)
   - Password create karein (pehli baar)
   - Domain name: `sakura-erp.surge.sh` (ya kuch aur)
   - Enter press karein

4. **Done!** 🎉

---

## ✅ Your Site is Live!

Visit: `https://sakura-erp.surge.sh` (ya jo domain aapne diya)

---

## 🔄 Update Karne Ke Liye

Jab bhi changes karein, simply:

```bash
surge
```

Ye automatically update ho jayega!

---

## 🌐 Custom Domain (Optional)

```bash
surge --domain sakurafactory.com
```

Phir DNS records update karein (instructions Surge.sh dashboard mein milenge).

---

## 🆘 Problems?

### "surge: command not found"
→ `npm install -g surge` run karein

### Router not working (404 errors)
→ `200.html` file create karein: `copy index.html 200.html`

### Need help?
→ Check `SURGE_DEPLOYMENT.md` for detailed guide

---

**🎉 Surge.sh par deploy karna bahut simple hai!**
