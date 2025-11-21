# Windows Defender SmartScreen Warnings

When users download and run Radiofy for the first time, they may see a Windows Defender SmartScreen warning:

> "Windows protected your PC - Microsoft Defender SmartScreen prevented an unrecognized app from starting"

This is **normal** for new applications and **does NOT mean the app is malicious**.

## Why This Happens

1. **App Reputation**: Windows SmartScreen uses reputation-based protection. New apps without established download history trigger warnings.
2. **No Code Signing**: The app isn't signed with a paid code signing certificate ($100-400/year).
3. **Small User Base**: As more users safely download and run the app, Windows builds reputation and warnings decrease.

## Solutions (in order of effectiveness)

### 1. Code Signing Certificate (Most Effective - Paid)

**Cost:** $100-400/year
**Effect:** Eliminates warnings immediately

**Steps:**
1. Purchase a code signing certificate from a trusted CA:
   - [DigiCert](https://www.digicert.com/signing/code-signing-certificates)
   - [Sectigo](https://sectigo.com/ssl-certificates-tls/code-signing)
   - [SSL.com](https://www.ssl.com/certificates/code-signing/)

2. Sign the installer and .exe:
   ```powershell
   signtool sign /f "certificate.pfx" /p "password" /t http://timestamp.digicert.com RadiofySetup.exe
   ```

3. Users will see "Published by: Radiofy" instead of "Unknown publisher"

### 2. Build Reputation (Free - Takes Time)

**Cost:** Free
**Effect:** Warnings decrease over 2-4 weeks as more users download

**How it works:**
- Windows telemetry tracks safe downloads
- After ~100-1000 downloads without incidents, SmartScreen warnings reduce
- GitHub releases and consistent URLs help build reputation faster

**Actions:**
- Keep the download URL consistent (don't change hosting)
- Encourage users to report the file as safe if prompted
- Use GitHub Releases (more trusted than direct download links)

### 3. Inno Setup Installer (Partially Effective - Free)

**Cost:** Free
**Effect:** Reduces warnings slightly (already implemented)

Using a professional installer like Inno Setup helps because:
- Well-known installer framework recognized by Windows
- Includes proper uninstaller and registry entries
- More "legitimate" appearance than a bare .exe

**Status:** ✅ Already implemented in this project

### 4. Submit to Microsoft (Free - No Guarantee)

**Cost:** Free
**Effect:** May or may not help

You can submit the file to Microsoft for analysis:
1. Go to https://www.microsoft.com/en-us/wdsi/filesubmission
2. Upload RadiofySetup.exe
3. Microsoft will analyze and may whitelist it

**Note:** This doesn't guarantee approval, and the process can take weeks.

### 5. Extended Validation (EV) Certificate (Most Trusted - Expensive)

**Cost:** $300-600/year
**Effect:** Best reputation, instant trust

EV certificates provide:
- Highest level of trust
- No SmartScreen warnings
- Immediate reputation even for new apps
- Hardware token for security

## What To Tell Users

Include this in your README or website:

---

### Windows SmartScreen Warning?

When you first download Radiofy, Windows may show a warning. This is normal for new apps.

**To install anyway:**
1. Click "More info"
2. Click "Run anyway"

This happens because Radiofy is a new, free app without expensive code signing. As more people safely use it, this warning will go away.

**Is it safe?** Yes! Radiofy is open source - you can review the code on GitHub.

---

## Current Status for Radiofy

✅ **Using Inno Setup installer**
✅ **Open source code** (users can verify safety)
❌ **No code signing certificate** (would require $100-400/year)
❌ **Limited download reputation** (will improve over time)

## Recommendations

### Short Term (Free):
1. ✅ Use the Inno Setup installer (already done)
2. Publish releases on GitHub Releases (more trusted)
3. Add a notice in your README about the warning
4. Build reputation through organic downloads

### Long Term (If Budget Allows):
1. Purchase a code signing certificate once you have regular users
2. Consider EV certificate if the app becomes popular
3. Set up automated signing in GitHub Actions

## Automated Signing (Future Enhancement)

If you get a certificate, you can add automated signing to GitHub Actions:

```yaml
- name: Sign installer
  run: |
    signtool sign /f certificate.pfx /p ${{ secrets.CERT_PASSWORD }} /t http://timestamp.digicert.com build\installer\RadiofySetup.exe
```

Store the certificate password in GitHub Secrets for security.

## Bottom Line

For a free, open-source project, the current approach is reasonable:
- Users can work around the warning
- Cost of certificate may not be justified initially
- Reputation will build over time
- The app is genuinely safe (open source, verifiable)

Once you have a stable user base and some revenue (donations), investing in a code signing certificate makes sense for better UX.
