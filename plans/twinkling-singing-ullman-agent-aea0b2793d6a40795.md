# Kotlin Multiplatform (KMP) State of the Art -- March 2026

Comprehensive research on KMP/CMP for mobile development, covering stability, libraries, and tooling.

---

## 1. Compose Multiplatform -- iOS Stability & Latest Version

### Status: STABLE for iOS (since May 2025)

**Latest stable version**: Compose Multiplatform **1.10.1** (with 1.10.0 released January 2026).

**Key milestone**: Compose Multiplatform for iOS reached **stable** status with version **1.8.0** (May 6, 2025). This was the first release where JetBrains declared iOS production-ready, with a finalized core API surface.

**Can you use Compose UI for both Android AND iOS?** YES. You can now write a single Compose UI codebase that runs on both Android and iOS. SwiftUI is no longer "recommended" for iOS -- Compose Multiplatform is the official shared UI approach. However, you CAN still use SwiftUI for iOS-specific screens via `expect`/`actual` if needed (e.g., deep platform integrations).

**Version history (key releases)**:
| Version | Date | Highlights |
|---------|------|------------|
| 1.8.0 | May 2025 | iOS reaches **stable**. K2 compiler required. Accessibility improvements. |
| 1.9.3 | ~Oct 2025 | Bug fixes, performance improvements |
| 1.10.0 | Jan 2026 | Common `@Preview` annotation, **Navigation 3** on all targets, bundled stable **Compose Hot Reload** |
| 1.10.1 | ~Feb 2026 | Bug fixes, incremental improvements |

**Requirements**:
- Kotlin **2.1.20** minimum (for Compose Hot Reload); recommended **2.3.0** for latest features
- For native/web targets: Kotlin **2.2.20** recommended

**Verdict**: Production-ready. Ship to App Store with confidence. Compose UI shared across Android + iOS is the recommended approach.

---

## 2. Camera & Barcode Scanning in KMP

### Cross-platform camera/barcode libraries DO exist, but maturity varies.

**Best options (ranked by maturity/features)**:

#### a) CameraK (by Kashif-E)
- **Repository**: [github.com/Kashif-E/CameraK](https://github.com/Kashif-E/CameraK)
- **Platforms**: Android, iOS, JVM
- **Status**: **Experimental**
- **Features**: Compose-first native API, flexible configuration (aspect ratio, zoom, flash), **plugin system** for:
  - QR/barcode scanning plugin
  - OCR plugin
  - Image saving plugin
- **Under the hood**: Uses CameraX on Android, AVFoundation on iOS
- **Verdict**: Most promising unified camera library, but still experimental. Good for prototypes; evaluate carefully for production.

#### b) QRKit (by Chaintech-Network)
- **Repository**: [github.com/Chaintech-Network/QRKitComposeMultiplatform](https://github.com/Chaintech-Network/QRKitComposeMultiplatform)
- **Platforms**: Android, iOS, Desktop
- **Features**: Both **scanning** AND **generation** of QR codes and barcodes
- **Supported formats**: QR, EAN-13, Code 39, Code 128, UPC-A, UPC-E, ITF, Codabar
- **QRKit 2.0**: Customizable QR code generation (shapes, patterns, branding)
- **Verdict**: Good for QR-focused use cases. More mature than CameraK for barcode-specific needs.

#### c) KScan (by ismai117)
- **Repository**: [github.com/ismai117/KScan](https://github.com/ismai117/KScan)
- **Compose Multiplatform barcode scanning**
- **Less documented** than the above options

#### d) Scanbot Barcode Scanner SDK
- **Commercial** SDK with KMP support
- 0.04 second scan time, offline operation
- **Not open-source** -- licensing required

#### e) Platform-specific approach (still viable)
- **Android**: CameraX + ML Kit (most mature, Google-supported)
- **iOS**: AVFoundation + Vision framework
- Use `expect`/`actual` declarations to wrap platform-specific implementations
- **Verdict**: Still the most reliable approach for production apps requiring advanced camera features.

**Recommendation**: For simple QR/barcode scanning, **QRKit** is the easiest path. For full camera control + barcode scanning, use **CameraK** if you can tolerate experimental status, otherwise go platform-specific with `expect`/`actual`.

---

## 3. Local Storage in KMP

### SQLDelight vs Room KMP

#### Room KMP -- NOW STABLE
- **First stable KMP version**: Room **2.7.0** (2025)
- **Latest version**: Room **2.8.3** (October 2025)
- **Platforms**: Android, iOS, JVM (Desktop)
- **Approach**: Annotation-based (`@Entity`, `@Dao`, `@Database`), generates implementations from Kotlin code
- **Pros**: Familiar to Android developers, Google-backed, integrates with LiveData/ViewModel/Flow
- **Cons**: KMP support is newer (stable since mid-2025), less battle-tested cross-platform than SQLDelight

#### SQLDelight -- MATURE & ESTABLISHED
- **Latest version**: SQLDelight 2.x (stable)
- **Platforms**: Android, iOS, JVM, JS, Native
- **Approach**: SQL-first -- you write `.sq` SQL files, it generates type-safe Kotlin APIs
- **Pros**: More platforms, more battle-tested for KMP, explicit SQL gives you fine-grained control
- **Cons**: SQL-first approach has steeper learning curve for ORM-accustomed developers

#### Other Options
- **Realm**: Was popular but **MongoDB deprecated Realm** (announced 2024). Migrating away is recommended.
- **DataStore**: Google's DataStore now supports KMP (stable since 2025) -- good for key-value or typed preferences, not for relational data.

#### Recommendation

| Scenario | Choice |
|----------|--------|
| New KMP project, team knows Android/Room | **Room KMP** (2.8.x) |
| New KMP project, team values SQL control | **SQLDelight** |
| Need JS/Web target | **SQLDelight** (Room doesn't support JS) |
| Migrating existing Android app with Room | **Room KMP** (easiest migration) |
| Simple preferences/settings | **DataStore KMP** |

---

## 4. Navigation in Compose Multiplatform

### Recommended: Navigation 3 (as of CMP 1.10.0)

**Navigation 3** is the new official navigation library from Google/JetBrains, supported in Compose Multiplatform starting with version **1.10.0** (January 2026).

**Key features**:
- **User-owned back stack**: You create and manage a `SnapshotStateList` of states; the UI observes it directly
- **Compose-native**: Deeper integration with Compose compared to Navigation 2.x
- **Multiplatform**: Works on Android, iOS, Desktop, Web
- **ViewModel integration**: Works with KMP ViewModel

**Alternatives (still maintained)**:
| Library | Status | Notes |
|---------|--------|-------|
| **Navigation 3** | Official, recommended | Bundled with CMP 1.10+ |
| **Voyager** | Community, mature | Widely used before Nav 3, still maintained |
| **Decompose** | Community, mature | Lifecycle-aware, supports deep links, more control |
| **Appyx** | Community | Node-based navigation with transitions |
| **Precompose** | Community | Lightweight, simple API |

**Recommendation**: Use **Navigation 3** for new projects. If you need more advanced features (complex deep linking, custom animations), consider **Decompose** as the most mature community alternative.

---

## 5. Dependency Injection -- Koin Multiplatform

### Status: STABLE and MATURE

**Latest version**: Koin **4.1.1** (stable, 2025)

**Key features of Koin 4.x for KMP**:
- **ViewModel DSL**: Mutualizes the Google/JetBrains KMP ViewModel API (`koin-core-viewmodel`)
- **UUID generation**: Uses `kotlin.uuid.Uuid` API for cross-platform unique IDs
- **WASM support**: Stable WebAssembly integration
- **Compose 1.8+ / MPP support**: First-class Compose Multiplatform integration
- **Ktor 3.2 integration**: Out-of-the-box
- **Koin Annotations**: Compile-time DI with KSP (`koin-annotations` 2.x for KMP)
- **Graph verification**: Module/lazy-module DSL with compile-time verification

**LTS version**: Koin **3.5.6** (for projects still on Kotlin 1.x)

**Alternatives**:
- **Kodein-DI**: Also supports KMP, less popular
- **Manual DI**: Some teams prefer simple factories for KMP shared code

**Recommendation**: Koin 4.1.x is the de facto standard for DI in KMP projects. Production-ready.

---

## 6. Barcode Rendering (Generating Barcode Images)

### ZXing alternatives that work cross-platform

#### QRCode-Kotlin (pure Kotlin, KMP)
- **Website**: [qrcodekotlin.com](https://qrcodekotlin.com/)
- **Repository**: [github.com/g0dkar/qrcode-kotlin](https://github.com/g0dkar/qrcode-kotlin)
- **Platforms**: JVM, JS, Android, iOS, tvOS
- **Features**: QR code generation in pure Kotlin, no platform dependencies
- **Limitation**: QR codes only (not EAN-13, Code 128, etc.)

#### QRKit (generation + scanning)
- **Repository**: [github.com/Chaintech-Network/QRKitComposeMultiplatform](https://github.com/Chaintech-Network/QRKitComposeMultiplatform)
- **Features**: Both **generation AND scanning**, supports multiple barcode formats (EAN-13, Code 39, Code 128, UPC-A, UPC-E, ITF, Codabar, QR)
- **Generation API**: `rememberBarcodePainter()` Compose function
- **Customization**: Custom shapes, patterns, colors for QR codes (QRKit 2.0)
- **Platforms**: Android, iOS, Desktop

#### ZXing (JVM/Android only)
- Still works fine for Android-only barcode generation
- NOT multiplatform -- Java/JVM library
- Use via `expect`/`actual` if needed

#### Recommendation

| Need | Library |
|------|---------|
| QR code generation only, pure KMP | **QRCode-Kotlin** |
| Multiple barcode formats + QR, Compose UI | **QRKit** |
| Android-only or via `expect`/`actual` | **ZXing** |

---

## 7. File System Access in KMP

### File picking

**FileKit** (by vinceglb) -- the best option:
- **Repository**: [github.com/vinceglb/FileKit](https://github.com/vinceglb/FileKit)
- **Platforms**: Android, iOS, macOS, JVM (Windows/macOS/Linux), JS, WASM
- **Features**:
  - Native file/media/folder pickers
  - File saving to user-selected locations
  - Camera capture (photo) on Android/iOS
  - Save to native gallery
  - `PlatformFile` abstraction with read/write/stream via `kotlinx-io`
  - Access to `filesDir` and `cacheDir` cross-platform
  - Coil 3 integration for image display
  - Compose Multiplatform dialogs
- **Version**: v0.10+ (full rewrite, significantly improved)
- **Verdict**: Most comprehensive file operations library for KMP. Actively maintained.

### File I/O libraries

| Library | Status | Zip Support | Notes |
|---------|--------|-------------|-------|
| **Okio** (Square) | Stable, KMP | JVM/Android ONLY | Mature, good for byte streams |
| **kotlinx-io** | Experimental | None | Official Kotlin lib, file system API under `kotlinx.io.files` but experimental and "not well designed" per maintainers |
| **KmpIO** | Community | YES (cross-platform) | Text files, binary files, zip/archive support |

### Zip file handling

**No mature cross-platform zip library exists**. Options:
1. **KmpIO**: Has zip/archive support, but smaller community
2. **Okio zip**: Only works on JVM/Android
3. **`expect`/`actual`** wrapping: Use `java.util.zip` on Android/JVM, `NSData`+Foundation on iOS
4. **kotlinx-io**: No zip support

**Recommendation**: For file picking, use **FileKit**. For zip operations, use `expect`/`actual` with platform-native APIs (most reliable) or evaluate **KmpIO** if you need a single library.

---

## 8. Image Processing in KMP

### Color extraction / image analysis

#### Colormath (by ajalt)
- **Repository**: [github.com/ajalt/colormath](https://github.com/ajalt/colormath)
- **KMP**: YES (all targets)
- **Features**: Color conversion (RGB, HSL, HSV, LAB, LCH, CMYK, etc.), color manipulation, color space transforms
- **Use case**: Color math operations, NOT pixel-level image analysis

#### ColorPicker Compose (by skydoves)
- **Repository**: [github.com/skydoves/colorpicker-compose](https://github.com/skydoves/colorpicker-compose)
- **KMP**: YES
- **Features**: Pick colors from images by tapping, brightness/alpha slider, ARGB adjustment
- **Use case**: User-facing color picker UI component

#### Image loading: Coil 3
- **Website**: [coil-kt.github.io/coil](https://coil-kt.github.io/coil/)
- **KMP**: YES (Compose Multiplatform)
- **Features**: Memory/disk caching, downsampling, automatic lifecycle management
- **Verdict**: The standard image loading library for CMP

#### Image picking: Peekaboo
- **Repository**: [github.com/onseok/peekaboo](https://github.com/onseok/peekaboo)
- **Features**: Image picker with `toImageBitmap()` conversion
- **Platforms**: Android, iOS

### Shared pixel-level image analysis
**No mature cross-platform image processing library exists for KMP** (equivalent to OpenCV or similar). For color extraction from bitmaps, you need:
- `expect`/`actual` wrapping platform APIs (Android `Bitmap`, iOS `UIImage`/CoreGraphics)
- Or use **Colormath** for color space math after extracting pixel values platform-specifically

**Recommendation**: Use **Coil 3** for image loading, **Colormath** for color operations, and `expect`/`actual` for pixel-level image analysis.

---

## 9. Screen Brightness Control

### No KMP library exists for this.

This is a platform-specific feature that requires `expect`/`actual` implementation:

**Android**:
```kotlin
// actual implementation
val window = (context as Activity).window
val layoutParams = window.attributes
layoutParams.screenBrightness = 1.0f // 0.0 to 1.0
window.attributes = layoutParams
```

**iOS**:
```kotlin
// actual implementation (via Kotlin/Native interop)
UIScreen.mainScreen.brightness = 1.0 // 0.0 to 1.0
```

**Recommendation**: Create a simple `expect`/`actual` wrapper. It is ~10 lines of platform code per target. No library needed.

---

## 10. Project Setup -- Latest Recommended Versions (March 2026)

### Kotlin
| Version | Status | Notes |
|---------|--------|-------|
| **2.3.0** | Latest stable (Dec 2025) | Language features, unused return value checker, explicit backing fields |
| **2.3.20-RC2** | Release candidate (Mar 3, 2026) | Tooling release, performance improvements |
| **2.1.20** | Minimum for CMP 1.10 | Required for Compose Hot Reload |

### Android Gradle Plugin (AGP)
| Version | Status | Notes |
|---------|--------|-------|
| **9.1.0** | Latest stable (Mar 2026) | API level 36.1 support |
| **9.0.1** | Stable (Jan 2026) | New KMP library plugin (`com.android.kotlin.multiplatform.library`) |
| **8.10.0** | Previous stable (May 2025) | Last 8.x release |

**IMPORTANT**: AGP 9.0 introduces a **new simplified Android KMP library plugin** (`com.android.kotlin.multiplatform.library`). The old `com.android.library` + `kotlin.multiplatform` combination in the same module is **no longer compatible** with AGP 9.x. Migration required.

### Compose Multiplatform
| Version | Kotlin Requirement |
|---------|-------------------|
| **1.10.1** | Kotlin 2.1.20+ (min), 2.2.20+ (recommended for native/web) |
| **1.10.0** | Same |

### Gradle
| Version | Compatibility |
|---------|--------------|
| **9.0.0** | Compatible with Kotlin 2.3.0 |
| **8.6** | Compatible with Kotlin 2.1.x |

### Recommended `gradle/libs.versions.toml`

```toml
[versions]
kotlin = "2.3.0"
agp = "9.1.0"
compose-multiplatform = "1.10.1"
koin = "4.1.1"
room = "2.8.3"
sqldelight = "2.0.2"
navigation = "3.0.0"  # or whatever the latest Nav3 artifact version is
coil = "3.1.0"
okio = "3.9.0"
filekit = "0.11.0"
colormath = "3.6.0"

[plugins]
kotlin-multiplatform = { id = "org.jetbrains.kotlin.multiplatform", version.ref = "kotlin" }
compose-multiplatform = { id = "org.jetbrains.compose", version.ref = "compose-multiplatform" }
compose-compiler = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
android-application = { id = "com.android.application", version.ref = "agp" }
android-library = { id = "com.android.library", version.ref = "agp" }
room = { id = "androidx.room", version.ref = "room" }
ksp = { id = "com.google.devtools.ksp", version = "2.3.0-1.0.30" }
```

---

## Summary: Production Readiness Matrix

| Area | Library/Solution | Status | Recommendation |
|------|-----------------|--------|----------------|
| **Shared UI** | Compose Multiplatform 1.10.1 | **Stable** | Use it |
| **Navigation** | Navigation 3 | **Stable** (CMP 1.10+) | Use it |
| **DI** | Koin 4.1.1 | **Stable** | Use it |
| **Local DB** | Room KMP 2.8.x / SQLDelight 2.x | **Both stable** | Room if Android-first, SQLDelight if KMP-first |
| **Camera/Barcode scan** | CameraK / QRKit | **Experimental** | QRKit for simple cases, expect/actual for production |
| **Barcode generation** | QRKit / QRCode-Kotlin | **Stable** | QRKit for multi-format, QRCode-Kotlin for QR only |
| **File picking** | FileKit 0.10+ | **Stable** | Use it |
| **File I/O + Zip** | Okio / KmpIO | **Partial** | expect/actual for zip |
| **Image loading** | Coil 3 | **Stable** | Use it |
| **Image processing** | Colormath + expect/actual | **Partial** | No full KMP solution |
| **Screen brightness** | expect/actual | **N/A** | DIY (~10 lines per platform) |
| **Kotlin** | 2.3.0 | **Stable** | Use it |
| **AGP** | 9.1.0 | **Stable** | Note migration from 8.x required |
| **Gradle** | 8.6 -- 9.0 | **Stable** | Use 8.6+ minimum |
