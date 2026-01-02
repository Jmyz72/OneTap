# OneTap Build Guide

This guide will help you set up, build, and run the OneTap iOS financial tracking application.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Building the Project](#building-the-project)
- [Running the App](#running-the-app)
- [Troubleshooting](#troubleshooting)
- [Development Workflow](#development-workflow)

---

## Prerequisites

### Required Software

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| **macOS** | 13.0+ (Ventura) | Development environment |
| **Xcode** | 15.0+ | IDE and build tools |
| **iOS Simulator/Device** | iOS 16.0+ | Testing platform |
| **Git** | 2.0+ | Version control |

### Recommended Tools

- **SF Symbols App** - For browsing icons used in the app
- **Core Data Editor** - For inspecting Core Data database during development
- **Instruments** - For performance profiling (included with Xcode)

---

## Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd OneTap
```

### 2. Verify Project Structure

Ensure your directory structure looks like this:

```
OneTap/
├── OneTap/
│   ├── Core/
│   │   ├── Data/
│   │   │   └── Persistence.swift
│   │   ├── DI/
│   │   │   └── DependencyContainer.swift
│   │   ├── Extensions/
│   │   ├── Repositories/
│   │   ├── Services/
│   │   ├── Settings/
│   │   └── Theme/
│   ├── Models/
│   ├── ViewModels/
│   ├── Views/
│   ├── OneTapApp.swift
│   └── OneTap.xcdatamodeld/
├── OneTap.xcodeproj/
├── CLAUDE.md
├── BUILD_GUIDE.md
├── ARCHITECTURE_GUIDE.md
└── FEATURE_IMPLEMENTATION_GUIDE.md
```

### 3. Open the Project

```bash
open OneTap.xcodeproj
```

**Important:** Open `OneTap.xcodeproj`, NOT `OneTap.xcworkspace` (this project doesn't use CocoaPods or SPM).

---

## Building the Project

### Using Xcode GUI

1. **Select a Scheme**
   - Click the scheme selector in the toolbar (should show "OneTap")
   - Ensure "OneTap" scheme is selected

2. **Select a Destination**
   - Click the destination selector
   - Choose an iOS Simulator (e.g., "iPhone 15 Pro")
   - Or connect a physical device

3. **Build**
   - Press `⌘B` (Command + B)
   - Or select `Product > Build` from the menu
   - Wait for "Build Succeeded" message

### Using Command Line

#### Build for Simulator

```bash
xcodebuild \
  -project OneTap.xcodeproj \
  -scheme OneTap \
  -sdk iphonesimulator \
  -configuration Debug \
  build
```

#### Build for Device

```bash
xcodebuild \
  -project OneTap.xcodeproj \
  -scheme OneTap \
  -sdk iphoneos \
  -configuration Release \
  build
```

#### Clean Build

```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/OneTap-*

# Clean and rebuild
xcodebuild clean
xcodebuild build
```

---

## Running the App

### First Launch Setup

When you first run OneTap, the app will:

1. **Initialize Core Data Stack**
   - Creates persistent store at: `Application Support/OneTap.sqlite`
   - Runs automatic lightweight migration if needed

2. **Seed Default Categories**
   - Loads 10 expense categories (Food & Drinks, Transport, etc.)
   - Loads 2 income categories (Salary, Investment)
   - Each category includes subcategories with icons

3. **Display Empty State**
   - Shows empty account list
   - Prompts to add first account

### Using Xcode

1. Press `⌘R` (Command + R)
2. Or select `Product > Run`
3. App launches in selected simulator/device

### Using Command Line

```bash
# Launch in specific simulator
xcrun simctl boot "iPhone 15 Pro"
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/OneTap-*/Build/Products/Debug-iphonesimulator/OneTap.app
xcrun simctl launch booted com.yourcompany.OneTap
```

---

## Development Workflow

### Preview-Driven Development

OneTap uses SwiftUI Previews extensively. All views include `#Preview` blocks.

#### Using Previews

1. Open any View file (e.g., `AccountListView.swift`)
2. Press `⌘⌥P` (Command + Option + P) to show preview
3. Or click "Resume" in the preview canvas

#### Preview Data

The app provides preview-friendly Core Data context:

```swift
#Preview {
    AccountListView()
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
```

`PersistenceController.preview` creates an in-memory store with sample data.

### Live Previews

Enable live preview mode to interact with the UI:

1. Open preview canvas
2. Click the "Play" button in preview
3. Interact with the view as if running on simulator

---

## Troubleshooting

### Common Build Errors

#### Error: "No signing certificate found"

**Solution:**
```
1. Open Xcode preferences (⌘,)
2. Go to Accounts tab
3. Add your Apple ID
4. Download signing certificates
5. In project settings, select your team under "Signing & Capabilities"
```

#### Error: "Module not found: CoreData"

**Solution:**
```
1. Clean build folder (⌘⇧K)
2. Delete DerivedData: rm -rf ~/Library/Developer/Xcode/DerivedData/OneTap-*
3. Rebuild project (⌘B)
```

#### Error: "Persistent store migration failed"

**Solution:**
```
1. Delete app from simulator/device
2. Clean build folder
3. Run again (app will recreate database)

For development, you can also reset the simulator:
Device > Erase All Content and Settings
```

### Common Runtime Errors

#### App Crashes on Launch

**Symptom:** App crashes immediately with Core Data error

**Solution:**
```swift
// Check OneTapApp.swift - ensure DependencyContainer is initialized:
@StateObject private var container = DependencyContainer()

// In .environmentObject ensure container is passed to all views
```

#### "No ViewModel" Error

**Symptom:** Views show loading spinner indefinitely

**Solution:**
```swift
// Check that views properly initialize ViewModel in onAppear:
.onAppear {
    if viewModel == nil {
        viewModel = container.makeXViewModel()
    }
}
```

#### Balance Calculation Incorrect

**Symptom:** Account balances don't match transaction history

**Solution:**
```bash
# Reset and recalculate all balances
1. Delete and reinstall app
2. Or manually trigger: PersistenceController.shared.recalculateBalances(for:from:)
```

### Debugging Tips

#### Enable Core Data Debug Logging

Add launch argument in Xcode:
```
Edit Scheme > Run > Arguments > Arguments Passed On Launch
Add: -com.apple.CoreData.SQLDebug 1
```

#### View Database in Simulator

```bash
# Find the app container
xcrun simctl get_app_container booted com.yourcompany.OneTap data

# Open the directory
open $(xcrun simctl get_app_container booted com.yourcompany.OneTap data)

# Navigate to: Application Support/OneTap.sqlite
# Open with Core Data Editor or DB Browser for SQLite
```

#### Memory Debugging

```bash
# Run with Memory Graph debugger
1. Run app in Xcode
2. Tap "Debug Memory Graph" button in debug bar
3. Check for retain cycles in ViewModels/Views
```

---

## Build Configurations

### Debug (Development)

- **Optimizations:** None
- **Assertions:** Enabled
- **Logging:** Verbose
- **Code signing:** Automatic

```bash
xcodebuild -configuration Debug build
```

### Release (Production)

- **Optimizations:** Full (-O)
- **Assertions:** Disabled
- **Logging:** Minimal
- **Code signing:** Manual (requires distribution certificate)

```bash
xcodebuild -configuration Release build
```

---

## Performance Optimization

### Build Time Optimization

1. **Use Build Time Analyzer**
   ```bash
   xcodebuild -showBuildTimingSummary
   ```

2. **Enable Parallel Builds**
   - Xcode Preferences > Build Settings
   - Check "Enable parallel builds"

3. **Use Derived Data on SSD**
   - Xcode Preferences > Locations
   - Set Derived Data to SSD location

### Runtime Optimization

1. **Profile with Instruments**
   ```
   Product > Profile (⌘I)
   Select "Time Profiler" or "Allocations"
   ```

2. **Monitor Core Data Performance**
   - Add `-com.apple.CoreData.SQLDebug 1` launch argument
   - Watch for N+1 queries in console

---

## Continuous Integration

### GitHub Actions (Sample)

Create `.github/workflows/build.yml`:

```yaml
name: Build OneTap

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.0.app

      - name: Build
        run: |
          xcodebuild \
            -project OneTap.xcodeproj \
            -scheme OneTap \
            -sdk iphonesimulator \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
            build

      - name: Test
        run: |
          xcodebuild test \
            -project OneTap.xcodeproj \
            -scheme OneTap \
            -sdk iphonesimulator \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
```

---

## Testing

### Running Unit Tests

```bash
# Command line
xcodebuild test \
  -project OneTap.xcodeproj \
  -scheme OneTap \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Or in Xcode: ⌘U
```

### Creating Test Data

For testing, use the preview persistence controller:

```swift
let context = PersistenceController.preview.container.viewContext
let account = Account(context: context)
account.id = UUID()
account.name = "Test Account"
account.balance = 1000.0
try! context.save()
```

---

## Distribution

### TestFlight Build

1. **Archive the App**
   ```
   Product > Archive
   ```

2. **Upload to App Store Connect**
   ```
   - Select archive in Organizer
   - Click "Distribute App"
   - Choose "App Store Connect"
   - Follow prompts
   ```

3. **Submit for Review**
   - Go to App Store Connect
   - Add to TestFlight beta
   - Submit for external testing

### Ad-Hoc Distribution

```bash
# Create IPA
xcodebuild \
  -project OneTap.xcodeproj \
  -scheme OneTap \
  -configuration Release \
  -archivePath OneTap.xcarchive \
  archive

xcodebuild \
  -exportArchive \
  -archivePath OneTap.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```

---

## Additional Resources

- **Apple Documentation:** https://developer.apple.com/documentation/
- **SwiftUI Tutorials:** https://developer.apple.com/tutorials/swiftui
- **Core Data Guide:** https://developer.apple.com/documentation/coredata
- **Xcode Help:** Help > Xcode Help in menu

---

## Quick Reference

### Essential Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Build | ⌘B |
| Run | ⌘R |
| Test | ⌘U |
| Clean | ⌘⇧K |
| Open Quickly | ⌘⇧O |
| Find in Project | ⌘⇧F |
| Show Preview | ⌘⌥P |
| Jump to Definition | ⌘ Click |

### Common Commands

```bash
# Clean everything
rm -rf ~/Library/Developer/Xcode/DerivedData/OneTap-*
xcodebuild clean

# List simulators
xcrun simctl list devices

# Reset simulator
xcrun simctl erase all

# View app logs
log stream --predicate 'processImagePath contains "OneTap"'
```

---

**Last Updated:** 2026-01-02
**Xcode Version:** 15.0+
**iOS Target:** 16.0+
