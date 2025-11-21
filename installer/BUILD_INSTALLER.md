# Building the Radiofy Windows Installer

This directory contains the Inno Setup script to create a professional Windows installer for Radiofy.

## Prerequisites

1. **Inno Setup 6** - Download from https://jrsoftware.org/isdown.php
   - Install the standard edition (free)
   - Make sure to add Inno Setup to your PATH during installation

2. **Built Radiofy App** - You need to build the release version first:
   ```bash
   flutter build windows --release
   ```

## Creating the Installer

### Method 1: Using Inno Setup GUI

1. Open Inno Setup Compiler
2. Click "File" → "Open" and select `radiofy_setup.iss`
3. Click "Build" → "Compile" (or press Ctrl+F9)
4. The installer will be created in `build/installer/RadiofySetup_1.02.0.exe`

### Method 2: Command Line

```bash
# From the radiofy_win directory
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\radiofy_setup.iss
```

## Installer Features

✅ **Custom installation directory**
✅ **Desktop shortcut** (optional)
✅ **Start Menu shortcut**
✅ **Uninstaller**
✅ **Donation prompt** at the end of installation
✅ **Multi-language** support (English and Portuguese)

## Donation Screen

After installation completes, users will be prompted to support the project with a donation. This is entirely optional and can be declined.

The donation link is:
`https://www.paypal.com/donate/?business=6PNHFW2AUEJLE&no_recurring=0&item_name=Keep+Radiofy+alive%21&currency_code=BRL`

## Distributing the Installer

The created `RadiofySetup_1.02.0.exe` file is a standalone installer that includes:
- All required DLLs and dependencies
- The Flutter framework
- App resources and assets

Users just need to download and run this single .exe file.

## Code Signing (Optional but Recommended)

To avoid Windows Defender warnings, you should sign the installer with a code signing certificate:

1. Get a code signing certificate from a Certificate Authority (e.g., DigiCert, Sectigo)
2. Uncomment the `SignTool` line in radiofy_setup.iss
3. Configure the signing tool in Inno Setup

**Note:** Code signing certificates cost around $100-400/year but significantly improve user trust.

## Automated Build (GitHub Actions)

The GitHub Actions workflow can be configured to automatically build and sign the installer. See `.github/workflows/build-windows.yml` for details.
