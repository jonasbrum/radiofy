# Building Radiofy for Windows

This directory contains the Windows-specific version of the Radiofy app.

## Prerequisites

- Flutter SDK (3.24.5 or later)
- Visual Studio 2022 with "Desktop development with C++" workload
- Windows 10 or later

## Building the App

### Debug Build

To run the app in debug mode:

```bash
flutter run -d windows
```

### Release Build

To create a release build:

```bash
flutter build windows --release
```

The built executable will be located at:
```
build/windows/x64/runner/Release/radiofy.exe
```

### Clean Build

If you encounter issues, clean the build and try again:

```bash
flutter clean
flutter pub get
flutter build windows --release
```

## Distribution

After building, you can distribute the entire `build/windows/x64/runner/Release/` folder, which contains:
- `radiofy.exe` - The main executable
- `data/` - Flutter assets and libraries
- DLL files required for the app to run

## Building Without a Windows PC

Flutter requires Windows and Visual Studio to build Windows apps. However, you have alternatives:

### Option 1: GitHub Actions (Recommended - Free)

I've included a workflow file at `.github/workflows/build-windows.yml`. To use it:

1. Push this repository to GitHub
2. Go to the "Actions" tab in your repository
3. Click "Build Windows App" and "Run workflow"
4. Download the built app from the "Artifacts" section

### Option 2: Cloud Windows VM

Use a cloud service with Windows instances:
- **AWS EC2** - Windows Server instances
- **Azure Virtual Machines** - Windows VMs
- **Google Cloud** - Windows Server instances
- **DigitalOcean** - Windows Droplets

Install Flutter and Visual Studio Build Tools on the VM, then build.

### Option 3: AppVeyor, CircleCI, or Azure Pipelines

These CI/CD services also provide Windows build environments.

## Notes

- This Windows version includes all the features from the original app
- The app requires an internet connection to stream radio stations
- All dependencies have been configured for Windows compatibility
- Cross-compilation from Linux to Windows is not supported by Flutter
