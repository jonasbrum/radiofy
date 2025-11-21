# Building Windows App with GitHub Actions

Since Flutter requires Windows and Visual Studio to build Windows apps, the easiest way to build without a Windows PC is to use GitHub Actions (completely free for public repositories).

## Setup Steps

### 1. Create a GitHub Repository

```bash
cd /home/jonas/radiofy/radiofy_win
git init
git add .
git commit -m "Initial commit - Windows version of Radiofy"
```

Then create a new repository on GitHub and push:

```bash
git remote add origin https://github.com/YOUR_USERNAME/radiofy-windows.git
git branch -M main
git push -u origin main
```

### 2. Enable GitHub Actions

- Go to your repository on GitHub
- Click on the "Actions" tab
- GitHub will automatically detect the workflow file

### 3. Trigger a Build

**Automatic builds:**
- Builds trigger automatically on every push to the `main` branch

**Manual builds:**
1. Go to the "Actions" tab
2. Click "Build Windows App" on the left
3. Click "Run workflow" button on the right
4. Select the branch and click "Run workflow"

### 4. Download the Built App

1. Wait for the build to complete (usually 5-10 minutes)
2. Click on the completed workflow run
3. Scroll down to "Artifacts"
4. Download "windows-build" (it will be a ZIP file)
5. Extract the ZIP - inside you'll find `radiofy.exe` and all required files

## What the Workflow Does

The workflow (`.github/workflows/build-windows.yml`) automatically:
1. Checks out your code
2. Installs Flutter 3.24.5 on a Windows runner
3. Runs `flutter pub get` to install dependencies
4. Runs `flutter build windows --release` to create the executable
5. Uploads the built app as an artifact

## Cost

- **Public repositories:** Completely free, unlimited builds
- **Private repositories:** Free tier includes 2,000 minutes/month

## Modifying the Workflow

You can edit `.github/workflows/build-windows.yml` to:
- Change when builds trigger (on tags, specific branches, etc.)
- Use a different Flutter version
- Add automated testing before building
- Create releases automatically

## Alternative: Release on Tag

If you want to create a GitHub Release automatically when you tag a version, you can use this enhanced workflow instead.
