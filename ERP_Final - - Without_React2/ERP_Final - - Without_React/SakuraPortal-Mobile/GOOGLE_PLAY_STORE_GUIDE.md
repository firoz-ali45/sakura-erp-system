# 📱 Google Play Store Upload Guide - Sakura Portal

This guide will help you upload your Sakura Portal app to the Google Play Store.

## 🎯 Prerequisites

### 1. Google Play Console Account
- **Cost:** $25 one-time registration fee
- **Sign up at:** [Google Play Console](https://play.google.com/console)
- **Requirements:** Google account, payment method

### 2. Development Tools
- Android Studio (latest version)
- Java Development Kit (JDK 11+)
- Android SDK

## 📋 Step-by-Step Upload Process

### Step 1: Create Google Play Console Account

1. **Visit Google Play Console:**
   ```
   https://play.google.com/console
   ```

2. **Sign up with Google account**
3. **Pay $25 registration fee**
4. **Complete developer profile**
5. **Accept Google Play Developer Distribution Agreement**

### Step 2: Create New App

1. **Click "Create app"**
2. **Fill in app details:**
   ```
   App name: Sakura Portal
   Default language: English
   App or game: App
   Free or paid: Free
   ```

3. **Declarations:**
   - Check "App content" - No ads
   - Check "Target audience" - General audience
   - Check "Content rating" - Everyone

### Step 3: Prepare App for Upload

#### 3.1 Build Production APK/AAB

```bash
# Navigate to your project
cd SakuraPortal-Mobile

# Install dependencies
npm install

# Build the app
npm run build

# Sync with Capacitor
npx cap sync android

# Open Android Studio
npx cap open android
```

#### 3.2 In Android Studio:

1. **Configure signing:**
   - Go to `Build` → `Generate Signed Bundle/APK`
   - Choose `Android App Bundle`
   - Create new keystore or use existing
   - Fill in keystore details:
     ```
     Key store path: [Choose location]
     Key store password: [Your password]
     Key alias: [Your alias]
     Key password: [Your password]
     ```

2. **Build release version:**
   - Select `release` build variant
   - Click `Build`
   - Wait for build completion

3. **Locate the AAB file:**
   ```
   android/app/build/outputs/bundle/release/app-release.aab
   ```

### Step 4: Upload to Google Play Console

#### 4.1 Upload App Bundle

1. **Go to Production tab**
2. **Click "Create new release"**
3. **Upload the AAB file:**
   - Drag and drop `app-release.aab`
   - Or click "Browse files"

4. **Release name:** `1.0.0 (100)`
5. **Release notes:**
   ```
   🎉 Initial release of Sakura Portal!
   
   Features:
   • Complete ERP Management System
   • Accounts Payable Management
   • Raw Materials Forecasting
   • Warehouse Management
   • Real-time Data Sync
   • Offline Support
   ```

#### 4.2 Complete Store Listing

**App Details:**
```
App name: Sakura Portal
Short description: ERP Management System for Sakura Cafe
Full description: [Use the description from store-assets/android/play-store-listing.json]
```

**Graphics:**
- **App icon:** 512x512 PNG (from store-assets/icons/)
- **Feature graphic:** 1024x500 PNG
- **Screenshots:** 
  - Phone: 1080x1920 PNG (minimum 2, maximum 8)
  - Tablet: 1080x1920 PNG (optional)

**Categorization:**
```
App category: Business
Content rating: Everyone
Target audience: General audience
```

**Contact details:**
```
Website: https://sakuraportal.com
Email: support@sakuraportal.com
Phone: [Your phone number]
```

### Step 5: Complete App Content

#### 5.1 Content Rating

1. **Go to "App content"**
2. **Answer questionnaire:**
   - Violence: No
   - Sexual content: No
   - Profanity: No
   - Controlled substances: No
   - Simulated gambling: No
   - Real money gambling: No
   - User-generated content: No
   - Location sharing: No

3. **Submit for rating**

#### 5.2 Privacy Policy

1. **Upload privacy policy:**
   - Use the template from `store-assets/shared/privacy-policy.md`
   - Host it on your website
   - Add URL in app content section

#### 5.3 Data Safety

1. **Complete data safety form:**
   ```
   Does your app collect or share any of the required user data types?
   Answer based on your app's functionality
   
   Data types collected:
   - Financial info (for ERP data)
   - App activity (for analytics)
   ```

### Step 6: Pricing and Distribution

#### 6.1 Pricing

1. **Select "Free"**
2. **Set up in-app purchases (if any):** None for basic version

#### 6.2 Distribution

1. **Countries/regions:** Select all or specific countries
2. **Device categories:** Phone and tablet
3. **User programs:** None selected

### Step 7: Review and Publish

#### 7.1 Final Review

1. **Check all sections are complete:**
   - ✅ Production releases
   - ✅ Store listing
   - ✅ App content
   - ✅ Pricing & distribution

2. **Review app details**
3. **Check for any warnings or errors**

#### 7.2 Submit for Review

1. **Click "Send for review"**
2. **Confirm submission**
3. **Wait for Google review (1-3 days)**

## 📊 Post-Upload Monitoring

### Track Review Status

1. **Check Google Play Console dashboard**
2. **Monitor review status**
3. **Respond to any feedback from Google**

### Common Review Issues

**Policy Violations:**
- Update app description if needed
- Fix any misleading claims
- Ensure privacy policy is accessible

**Technical Issues:**
- Fix crashes or bugs
- Update app if requested
- Test on different devices

## 🎉 Publishing Success

Once approved:

1. **App goes live automatically**
2. **Users can download from Google Play Store**
3. **Monitor downloads and ratings**
4. **Respond to user reviews**
5. **Plan future updates**

## 📈 Post-Launch Tasks

### Analytics Setup

1. **Google Play Console Analytics**
2. **Firebase Analytics integration**
3. **Track user engagement**

### User Feedback

1. **Monitor user reviews**
2. **Respond to feedback**
3. **Plan improvements**

### Updates

1. **Regular bug fixes**
2. **Feature updates**
3. **Security patches**

## 🔧 Troubleshooting

### Common Issues

**Upload Failed:**
- Check AAB file size (max 150MB)
- Verify signing certificate
- Ensure all required fields are filled

**Review Rejected:**
- Read Google's feedback
- Fix policy violations
- Update app description
- Resubmit for review

**App Not Found:**
- Wait 2-24 hours after approval
- Check if app is available in your region
- Verify app is not restricted

## 📞 Support Resources

- **Google Play Console Help:** https://support.google.com/googleplay/android-developer
- **Developer Policy:** https://play.google.com/about/developer-content-policy/
- **Technical Support:** https://support.google.com/googleplay/android-developer/contact/developer

---

**🎊 Congratulations!** Your Sakura Portal app is now live on Google Play Store!







