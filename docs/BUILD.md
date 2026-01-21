# Building FlowRead

This guide covers building FlowRead from source for development and release.

## Prerequisites

- **macOS 13.0** (Ventura) or later
- **Xcode 15.0** or later
- **Command Line Tools**: `xcode-select --install`

## Development Build

### Using Xcode

1. Open the project:
   ```bash
   open FlowRead.xcodeproj
   ```

2. Select "FlowRead" scheme in the toolbar

3. Press `⌘R` to build and run

### Using Command Line

Quick debug build:
```bash
chmod +x run-debug.sh
./run-debug.sh
```

This builds and launches the app in debug mode.

## Release Build

### Creating a DMG

Run the build script:
```bash
chmod +x build.sh
./build.sh
```

This will:
1. Clean previous builds
2. Build the Release configuration
3. Archive the app
4. Export the app bundle
5. Create a DMG installer

Output files:
- `build/FlowRead.app` - The app bundle
- `build/FlowRead.dmg` - DMG installer

### Manual Build Steps

If you prefer manual control:

```bash
# 1. Build archive
xcodebuild -project FlowRead.xcodeproj \
    -scheme FlowRead \
    -configuration Release \
    archive \
    -archivePath build/FlowRead.xcarchive

# 2. Export app (create ExportOptions.plist first)
xcodebuild -exportArchive \
    -archivePath build/FlowRead.xcarchive \
    -exportPath build \
    -exportOptionsPlist ExportOptions.plist

# 3. Create DMG
hdiutil create -volname "FlowRead" \
    -srcfolder build/FlowRead.app \
    -ov -format UDZO \
    build/FlowRead.dmg
```

## Code Signing

### Development (No Signing)

For local development, Xcode handles signing automatically with your Apple ID.

### Distribution

For distribution outside the App Store:

1. **Developer ID Certificate**: Obtain from Apple Developer Program
2. **Update Build Settings**:
   ```
   CODE_SIGN_IDENTITY = "Developer ID Application: Your Name (TEAM_ID)"
   CODE_SIGN_STYLE = Manual
   ```

3. **Notarization** (required for Gatekeeper):
   ```bash
   xcrun notarytool submit build/FlowRead.dmg \
       --apple-id "your@email.com" \
       --team-id "TEAM_ID" \
       --password "app-specific-password" \
       --wait
   
   xcrun stapler staple build/FlowRead.dmg
   ```

## Project Structure

```
FlowRead.xcodeproj/      Xcode project file
├── project.pbxproj      Project configuration
└── xcshareddata/
    └── xcschemes/       Build schemes

FlowRead/                Source code
├── FlowReadApp.swift    App entry (@main)
├── Models/              Data models
├── Services/            Business logic
├── Views/               SwiftUI views
├── Theme/               Design tokens
├── Assets.xcassets/     Assets (colors, icons)
├── Info.plist           App configuration
└── FlowRead.entitlements  Permissions
```

## Build Configuration

### Debug
- Optimization: None (`-Onone`)
- Debug information: Full
- Assertions: Enabled

### Release
- Optimization: Full (`-O`)
- Debug info: dSYM
- Assertions: Disabled
- Hardened Runtime: Enabled

## Entitlements

The app requires these entitlements:

```xml
<!-- App Sandbox -->
<key>com.apple.security.app-sandbox</key>
<true/>

<!-- File Access (for PDFs) -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<!-- Network (for Groq API) -->
<key>com.apple.security.network.client</key>
<true/>
```

## Troubleshooting

### "Code signing failed"

1. Check Xcode signing settings
2. Refresh your certificates in Keychain Access
3. Try: Xcode → Preferences → Accounts → Download Certificates

### "Asset catalog not found"

Ensure `Assets.xcassets` is added to the target:
1. Select the asset catalog in Project Navigator
2. Check target membership in File Inspector

### Build warnings

Common warnings and fixes:
- **Sendable conformance**: Add `@Sendable` or `@MainActor`
- **Deprecated APIs**: Update to newer alternatives
- **Unused variables**: Remove or prefix with `_`

## Clean Build

If you encounter strange build issues:

```bash
# Clean build folder
rm -rf build/

# Clean Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/FlowRead-*

# Rebuild
./build.sh
```

## Package.swift (Alternative)

A `Package.swift` is included for Swift Package Manager compatibility:

```bash
swift build
swift run
```

Note: The SPM build is for development convenience. Use xcodebuild for releases.

---

For issues, please open a GitHub issue with:
- macOS version
- Xcode version  
- Build logs
- Steps to reproduce
