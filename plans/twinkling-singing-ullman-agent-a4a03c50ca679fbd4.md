# iOS Loyalty Card Wallet App -- Research Report (March 2026)

Comprehensive research for building a premium-quality iOS loyalty card wallet app with SwiftUI.

---

## 1. SwiftUI iOS 18+ Capabilities

### 1.1 Mesh Gradients (iOS 18+)

`MeshGradient` is a new view type that creates two-dimensional gradients from a 2D grid of positioned colors. Each vertex has a position, color, and four surrounding Bezier control points. This is perfect for premium card backgrounds.

```swift
MeshGradient(
    width: 3, height: 3,
    points: [
        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
        [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
    ],
    colors: [
        .red, .purple, .indigo,
        .orange, .white, .blue,
        .yellow, .green, .mint
    ]
)
```

Can be animated by changing point positions over time for a living, breathing card background effect.

### 1.2 Navigation Transitions -- Zoom / Hero Animations (iOS 18+)

New `NavigationTransition` protocol with `matchedTransitionSource` modifier. Three-step process:

1. Create a `@Namespace`
2. Mark source view with `.matchedTransitionSource(id:in:)`
3. Apply `.navigationTransition(.zoom(sourceID:in:))` to destination

Works across NavigationStack pushes, sheets, and full-screen covers -- unlike the older `matchedGeometryEffect` which had limitations across presentations.

```swift
@Namespace var namespace

// Source (card in list)
CardView(card)
    .matchedTransitionSource(id: card.id, in: namespace)

// Destination (full card detail)
CardDetailView(card)
    .navigationTransition(.zoom(sourceID: card.id, in: namespace))
```

### 1.3 ScrollView Improvements (iOS 18+)

- **`onScrollGeometryChange(for:of:action:)`** -- React to scroll geometry changes (content offsets, size, position). Two closures: first transforms `ScrollGeometry` into an equatable value, second fires on change.
- **`scrollPosition(id:)`** -- Precise scroll positioning by ID (improved from iOS 17).
- **Scroll phases** -- Detect moving vs. idle states.

### 1.4 Custom Container Views (iOS 18+)

New `Subview` struct and `ForEach(subviewOf:)` API for building custom containers:

```swift
struct CardStack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Group(subviews: content) { subviews in
            // Iterate resolved subviews, apply custom layout
            ForEach(subviews) { subview in
                subview
                    .padding()
                    .background(.ultraThinMaterial)
            }
        }
    }
}
```

`SubviewsCollection` conforms to `RandomAccessCollection`. iOS 18+ only.

### 1.5 TabView with `Tab` Children (iOS 18+)

TabView now uses dedicated `Tab` child views. The tab bar can transition between a floating tab bar and a sidebar (useful for iPad).

### 1.6 Other Notable iOS 18 Additions

- **`@Entry` macro** -- Simpler custom environment values
- **`@Previewable`** -- Use `@State` directly in SwiftUI previews
- **Pre-compiled Metal shaders** -- Eliminates shader compilation lag
- **`.rotate` SF Symbol animation** -- New built-in symbol effect
- **Custom text effects** -- Fine-grained text animation control
- **`@MainActor` on View protocol** -- All view properties/methods run on main actor (architectural change)
- **Color blending** -- New color mixing APIs

### 1.7 iOS 17 APIs Still Relevant

- **`matchedGeometryEffect`** -- Still works for same-presentation transitions
- **`contentTransition(.numericText())`** -- Animated number changes
- **`scrollTargetBehavior(.viewAligned)`** -- Snap scrolling (card carousel)
- **`sensoryFeedback()`** -- Declarative haptics (iOS 17+)
- **`@Observable` macro** -- Modern observation (iOS 17+)
- **`PhaseAnimator` / `KeyframeAnimator`** -- Multi-phase animations

---

## 2. Architecture for a Local-First iOS App

### 2.1 SwiftData (Recommended for New SwiftUI Apps)

**Status (March 2026):** 3 years old. Has stabilized significantly since the iOS 18 refactoring. Still slower than Core Data and GRDB for raw read/write, but the gap is closing.

**Pros:**
- Native SwiftUI integration (`@Model`, `@Query`, `@Environment(\.modelContext)`)
- Zero-boilerplate persistence
- Built-in CloudKit sync (see section 4)
- `@Attribute(.externalStorage)` for images/binary data
- Apple's forward investment direction

**Cons:**
- All properties must be optional or have defaults (CloudKit requirement)
- `@Attribute(.unique)` incompatible with CloudKit sync
- Cannot match Core Data's microsecond-level optimizations
- Limited conflict resolution APIs
- iOS 17+ minimum

**Verdict for this app:** **Use SwiftData.** A loyalty card wallet has simple data models (Card, Group, BarcodeScan), moderate data volume, and benefits enormously from built-in CloudKit sync and SwiftUI integration.

### 2.2 GRDB.swift (Best Performance Alternative)

**Status:** Mature, actively maintained. `GRDBQuery` v0.11.0 (March 2025) provides SwiftUI integration via `@Query` property wrapper. Point-Free's `SharingGRDB` library further optimizes SwiftUI usage.

**Pros:**
- Raw SQLite performance (fastest option)
- Full SQL access + fluent Query Interface
- `ValueObservation` for reactive updates
- `DatabasePool` for concurrent reads
- No iOS version constraints

**Cons:**
- No built-in CloudKit sync (must implement manually or use CKSyncEngine)
- More boilerplate than SwiftData
- External dependency

**Verdict:** Use if you need maximum performance or if you must support iOS 15/16. Overkill for a card wallet with ~100-500 items.

### 2.3 Core Data

**Status:** Mature (20+ years), still maintained, but clearly in maintenance mode. Apple is investing in SwiftData.

**Verdict:** Only use for existing codebases or complex migration scenarios. Not recommended for new SwiftUI apps in 2026.

### 2.4 Recommendation

```
SwiftData (primary recommendation)
  + @Attribute(.externalStorage) for card photos
  + CloudKit sync for multi-device
  + Simple @Model / @Query integration
```

### 2.5 Image Storage Strategy

Use `@Attribute(.externalStorage)` for card photos/images:

```swift
@Model
class LoyaltyCard {
    var storeName: String
    var cardNumber: String
    var barcodeType: String
    @Attribute(.externalStorage) var frontImage: Data?
    @Attribute(.externalStorage) var backImage: Data?
    var headerColor: String?
    // ...
}
```

SwiftData stores the binary data in a hidden `_EXTERNAL_DATA` directory and keeps only a filename reference in the database. This keeps the SQLite database lightweight.

**CloudKit caveat:** The sync behavior of `.externalStorage` with CloudKit is not fully documented. Test thoroughly. For guaranteed sync, consider storing images as `CKAsset` via direct CloudKit API or limiting image size.

---

## 3. Barcode Scanning and Generation

### 3.1 Scanning: VisionKit `DataScannerViewController` (iOS 16+)

**Recommended approach.** Provides a ready-to-use camera interface with live scanning overlay.

```swift
// SwiftUI wrapper needed (UIViewControllerRepresentable)
let scanner = DataScannerViewController(
    recognizedDataTypes: [.barcode(symbologies: [
        .qr, .ean13, .ean8, .code128, .code39,
        .pdf417, .aztec, .upce, .dataMatrix,
        .itf14, .codabar, .code93
    ])],
    qualityLevel: .balanced,
    recognizesMultipleItems: false,
    isHighlightingEnabled: true
)
```

**Configurable:** quality level (fast/balanced/accurate), multi-item recognition, pinch-to-zoom, highlighting.

**Delegate methods:** `didAdd`, `didTapOn`, `didRemove` via `DataScannerViewControllerDelegate`.

**Hardware requirement:** Requires device with A12 Bionic+ (iPhone XS and later). Check `DataScannerViewController.isSupported`.

### 3.2 Scanning: AVFoundation (Fallback)

Lower-level, more control, works on older devices:

```swift
let metadataOutput = AVCaptureMetadataOutput()
metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
// Set types after adding to session
metadataOutput.metadataObjectTypes = [
    .qr, .ean13, .ean8, .code128, .code39, .pdf417,
    .aztec, .upce, .dataMatrix, .itf14, .code93
]
```

### 3.3 Supported Barcode Symbologies (Complete List)

**1D Barcodes:**
| Format | Scan (AVFoundation) | Scan (VisionKit) | Generate (CIFilter) |
|--------|---------------------|-------------------|----------------------|
| Code 128 | Yes | Yes | Yes (`CICode128BarcodeGenerator`) |
| Code 39 | Yes | Yes | No |
| Code 93 | Yes | Yes | No |
| EAN-13 | Yes | Yes | No (use Code128) |
| EAN-8 | Yes | Yes | No |
| UPC-E | Yes | Yes | No |
| ITF-14 | Yes | Yes | No |
| Codabar | Yes | Yes | No |
| Interleaved 2 of 5 | Yes | Yes | No |

**2D Barcodes:**
| Format | Scan (AVFoundation) | Scan (VisionKit) | Generate (CIFilter) |
|--------|---------------------|-------------------|----------------------|
| QR Code | Yes | Yes | Yes (`CIQRCodeGenerator`) |
| Aztec | Yes | Yes | Yes (`CIAztecCodeGenerator`) |
| PDF417 | Yes | Yes | Yes (`CIPDF417BarcodeGenerator`) |
| Data Matrix | Yes | Yes | No |

### 3.4 Barcode Generation with CIFilter

```swift
func generateBarcode(from string: String, type: String) -> UIImage? {
    guard let filter = CIFilter(name: type) else { return nil }
    let data = string.data(using: .ascii)
    filter.setValue(data, forKey: "inputMessage")

    // Scale up (CIFilter output is tiny)
    guard let output = filter.outputImage else { return nil }
    let transform = CGAffineTransform(scaleX: 10, y: 10)
    let scaled = output.transformed(by: transform)

    let context = CIContext()
    guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cgImage)
}

// Usage:
// QR: "CIQRCodeGenerator"
// Code128: "CICode128BarcodeGenerator"
// Aztec: "CIAztecCodeGenerator"
// PDF417: "CIPDF417BarcodeGenerator"
```

**Limitation:** CIFilter only generates 4 barcode types. For EAN-13, EAN-8, UPC-E, Code 39, etc., you need either a third-party library or custom Core Graphics drawing.

### 3.5 Missing Barcode Types -- Workarounds

For barcode types not supported by CIFilter (EAN-13, EAN-8, UPC-E, Code 39, Data Matrix):

1. **RSBarcodes_Swift** -- Open-source library supporting 1D and 2D barcode generation
2. **Custom Core Graphics rendering** -- Draw bars manually using the barcode specification
3. **Store a screenshot of the barcode** -- Capture from the scanning phase and save as image

**Recommendation:** For a loyalty card app, the most common types are Code 128, EAN-13, QR Code, and Code 39. Implement CIFilter for QR/Code128/Aztec/PDF417, and use RSBarcodes_Swift or custom rendering for EAN-13 and Code 39.

---

## 4. iCloud Sync

### 4.1 SwiftData + CloudKit (Recommended)

**Zero-code sync** for private database:

```swift
@main
struct LoyaltyWalletApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [LoyaltyCard.self, CardGroup.self])
        // CloudKit sync is automatic when:
        // 1. iCloud capability is added
        // 2. CloudKit container is configured
        // 3. Background Modes > Remote Notifications is enabled
    }
}
```

**Model requirements for CloudKit:**
- All properties must have default values or be optional
- All relationships must be optional
- NO `@Attribute(.unique)` (incompatible with CloudKit)
- Supported types: String, Int, Double, Bool, Date, UUID, URL, Data

### 4.2 Image Sync Strategy

**Option A: `@Attribute(.externalStorage)` (Simple, Uncertain)**
- Transparently stores images outside the SQLite DB
- CloudKit sync behavior not fully documented
- May work but needs thorough testing

**Option B: CKAsset via Direct CloudKit (Reliable, More Code)**
- Store images as `CKAsset` in CloudKit
- Full control over upload/download
- More code but predictable behavior

**Option C: Hybrid (Recommended)**
- Use SwiftData for card metadata (syncs automatically)
- Store images in app's Documents directory with deterministic filenames
- Use a separate `CKRecord` with `CKAsset` for image sync
- Or: store small images (<1MB) as `Data` in SwiftData (will sync)

### 4.3 Conflict Resolution

SwiftData/CloudKit uses NSPersistentCloudKitContainer's merge policies under the hood:
- **Default behavior:** Last-writer-wins (server timestamp)
- **No custom conflict resolution API** in SwiftData as of iOS 18
- **Change tags** on CKRecord detect conflicts -- if the tag is stale, CloudKit treats it as a conflict

**Practical strategy for a card wallet:**
- Cards are rarely edited simultaneously across devices
- Last-writer-wins is acceptable for most fields
- For card photos: use deterministic filenames (cardID-front.jpg) to avoid duplication

### 4.4 Alternatives

| Approach | Complexity | Sharing | Offline | Best For |
|----------|-----------|---------|---------|----------|
| SwiftData + CloudKit | Low | Private only | Yes | Single-user sync |
| CKSyncEngine (iOS 17+) | Medium | Private + Shared | Yes | Custom sync logic |
| iCloud Key-Value Store | Trivial | N/A | Yes | Small settings (<1MB total) |
| Direct CloudKit API | High | Full control | Yes | Complex sharing scenarios |

**Recommendation:** SwiftData + CloudKit for card data. iCloud Key-Value Store for app preferences/settings.

---

## 5. Premium Design Patterns

### 5.1 What Makes Apps Feel Premium

Studying Things 3, Bear, Obsidian, Fantastical, and Apple's own apps:

**Spatial Awareness:**
- Views have a sense of depth (shadows, materials, layering)
- Elements animate from where they came from (zoom transitions)
- Drag gestures with momentum and rubber-banding

**Animation Quality:**
- Spring animations everywhere (not linear/ease-in-out)
- Matched geometry transitions between states
- Micro-animations on interactions (button press scale, toggle bounce)
- Staggered animations for lists (items appear in sequence)

**Material & Color:**
- `.ultraThinMaterial` / `.regularMaterial` for glass effects
- Dynamic color extraction from content (card image -> UI accent)
- Consistent color system with semantic naming
- Support for both light and dark mode with equal care

**Typography:**
- SF Pro (system font) with careful weight choices
- `.title`, `.headline`, `.body`, `.caption` semantic styles
- Custom fonts sparingly for brand elements
- Dynamic Type support throughout

**Haptics:**
- Confirmation haptics on save/complete
- Selection haptics on picker changes
- Impact haptics on card flip/snap
- Warning haptics on destructive actions

### 5.2 Spring Animation Parameters

```swift
// Quick, snappy (buttons, toggles)
.animation(.spring(response: 0.3, dampingFraction: 0.75), value: state)

// Balanced (card transitions, navigation)
.animation(.spring(response: 0.55, dampingFraction: 0.75), value: state)

// Dramatic (modal presentations, hero transitions)
.animation(.spring(response: 0.9, dampingFraction: 0.75), value: state)

// Bouncy (playful elements, cards settling)
.animation(.spring(response: 0.5, dampingFraction: 0.5), value: state)

// Apple's recommended default
.animation(.spring, value: state)  // uses system default
```

### 5.3 Haptic Feedback Patterns (iOS 17+)

```swift
// Declarative (preferred in SwiftUI)
.sensoryFeedback(.success, trigger: cardSaved)
.sensoryFeedback(.selection, trigger: selectedCard)
.sensoryFeedback(.impact(weight: .medium), trigger: cardFlipped)
.sensoryFeedback(.warning, trigger: deleteAttempted)

// Imperative (when you need precise timing)
let impact = UIImpactFeedbackGenerator(style: .medium)
impact.prepare()  // Prime the Taptic Engine
impact.impactOccurred()

// Available feedback types:
// .success, .warning, .error
// .selection
// .impact(weight: .light/.medium/.heavy, intensity: 0...1)
// .increase, .decrease
// .start, .stop
```

### 5.4 Color System Design

```swift
// Semantic color definitions
extension Color {
    // Brand
    static let cardPrimary = Color("CardPrimary")
    static let cardSecondary = Color("CardSecondary")

    // Surfaces
    static let surfaceBackground = Color(.systemBackground)
    static let surfaceCard = Color(.secondarySystemBackground)
    static let surfaceElevated = Color(.tertiarySystemBackground)

    // Adaptive text
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)
}

// Dynamic color from card image (dominant color extraction)
// Use DominantColors library or CIAreaAverage filter
```

### 5.5 Premium UI Patterns for a Card Wallet

1. **Card Stack with Parallax** -- Cards in a vertical scroll with subtle depth offset
2. **Flip Animation** -- 3D rotation to show front/back of card
3. **Drag to Reorder** -- With spring physics and haptic feedback
4. **Pull-to-Search** -- Elastic pull-down reveals search bar
5. **Contextual Menus** -- Long-press for quick actions (delete, share, favorite)
6. **Adaptive Headers** -- Shrink/expand with scroll position
7. **Empty States** -- Illustrated, not just text
8. **Skeleton Loading** -- Shimmer effect while loading images

---

## 6. Deployment Target

### 6.1 iOS Adoption Rates (March 2026)

| iOS Version | Share (all iPhones) | Share (last 4 years) |
|-------------|---------------------|----------------------|
| iOS 26 | ~74% | ~74% |
| iOS 18 | ~15% | ~20% |
| iOS 17 | ~6% | ~4% |
| iOS 16 and earlier | ~5% | ~2% |

### 6.2 Recommendation: iOS 17 Minimum

**iOS 17 minimum** gives you ~95% reach of iPhones sold in the last 4 years. You get:
- SwiftData
- `@Observable` macro
- `sensoryFeedback()` modifier
- `scrollTargetBehavior`
- `contentTransition(.numericText())`
- `PhaseAnimator` / `KeyframeAnimator`
- `matchedGeometryEffect` (iOS 15+, but improved in 17)
- CKSyncEngine

**iOS 18 additions** (nice-to-have, use `if #available`):
- `MeshGradient` -- Use `if #available(iOS 18, *)` with linear gradient fallback
- `NavigationTransition` zoom -- Use `if #available` with standard push fallback
- Custom container views (Subview/ForEach subviews) -- Use standard ForEach fallback
- `onScrollGeometryChange` -- Use GeometryReader fallback
- `TabView` with `Tab` children -- Use older TabView syntax fallback

**iOS 18 minimum** gives you ~89-94% reach but lets you use all new APIs without availability checks. Consider if your target audience skews toward recent iPhone owners.

### 6.3 API Availability Summary

| API | Minimum iOS |
|-----|-------------|
| SwiftData | 17.0 |
| `@Observable` | 17.0 |
| `sensoryFeedback()` | 17.0 |
| `scrollTargetBehavior` | 17.0 |
| DataScannerViewController | 16.0 |
| CKSyncEngine | 17.0 |
| MeshGradient | 18.0 |
| NavigationTransition (zoom) | 18.0 |
| Custom containers (Subview) | 18.0 |
| `onScrollGeometryChange` | 18.0 |
| Tab (new TabView) | 18.0 |
| `@Entry` macro | 18.0 |
| `@Previewable` | 18.0 |

---

## 7. Testing

### 7.1 XCTest + Swift Testing (2025+)

Swift Testing (`import Testing`) is the modern replacement for XCTest introduced at WWDC 2024:

```swift
import Testing

@Test func cardCreation() {
    let card = LoyaltyCard(storeName: "IKEA", cardNumber: "123456")
    #expect(card.storeName == "IKEA")
    #expect(card.barcodeType == .ean13)
}

@Test(arguments: BarcodeType.allCases)
func barcodeGeneration(type: BarcodeType) {
    let image = BarcodeGenerator.generate(value: "12345", type: type)
    #expect(image != nil)
}
```

### 7.2 SwiftUI Previews as Visual Tests

```swift
#Preview("Card - Light Mode") {
    CardView(card: .preview)
        .preferredColorScheme(.light)
}

#Preview("Card - Dark Mode") {
    CardView(card: .preview)
        .preferredColorScheme(.dark)
}

#Preview("Card Stack - Many Cards") {
    CardListView()
        .modelContainer(PreviewData.container)
}
```

Previews are NOT automated tests but serve as rapid visual verification during development.

### 7.3 Snapshot Testing

**Library:** [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) by Point-Free.

```swift
import SnapshotTesting
import XCTest

final class CardViewSnapshotTests: XCTestCase {
    func testCardView() {
        let view = CardView(card: .preview)
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }

    func testCardViewDarkMode() {
        let view = CardView(card: .preview)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }
}
```

**Key points:**
- Supports both image snapshots and text-based hierarchy snapshots
- Works with Swift Testing and XCTestCase
- First run records reference snapshots; subsequent runs compare
- Minor OS updates can break snapshots (pixel-level comparison)
- Best for catching unintended regressions, not for initial design

### 7.4 UI Testing (XCUITest)

```swift
final class LoyaltyWalletUITests: XCTestCase {
    func testAddCardFlow() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Add Card"].tap()
        app.textFields["Store Name"].tap()
        app.typeText("IKEA")
        app.buttons["Scan Barcode"].tap()
        // ... camera interaction requires physical device
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["IKEA"].exists)
    }
}
```

### 7.5 Testing Strategy Recommendation

| Layer | Tool | What to Test |
|-------|------|--------------|
| Model/Logic | Swift Testing | Data transformations, barcode parsing, Catima import |
| ViewModel | Swift Testing | State transitions, async operations |
| Views | Snapshot Testing | Visual regressions, dark mode, Dynamic Type |
| Integration | XCUITest | Critical user flows (add card, scan, search) |
| Visual | SwiftUI Previews | Rapid iteration during development |

---

## 8. Open-Source Swift Libraries

### 8.1 Barcode Generation

| Library | Stars | Status | Formats |
|---------|-------|--------|---------|
| **RSBarcodes_Swift** | ~700 | Maintained | 1D + 2D (Code39, EAN-13, EAN-8, UPC-E, Code128, QR, Aztec, PDF417) |
| **CIFilter (built-in)** | -- | Apple | QR, Code128, Aztec, PDF417 only |

**Recommendation:** Start with CIFilter for the 4 supported types. Add RSBarcodes_Swift only if you need EAN-13, EAN-8, UPC-E, or Code 39 generation. Many loyalty cards use Code 128 or QR, which CIFilter covers.

### 8.2 Color Extraction from Images

| Library | Stars | Approach | Best For |
|---------|-------|----------|----------|
| **DominantColors** | ~200 | K-means clustering | Multiple dominant colors (palette) |
| **UIImageColors** | ~3.2k | Custom algorithm | Background, primary, secondary, detail colors |
| **swift-vibrant** | ~100 | Port of node-vibrant | Vibrant/muted/dark-vibrant palettes |
| **CIAreaAverage (built-in)** | -- | Core Image filter | Single average color (fastest) |

**Recommendation:** Use **UIImageColors** for extracting a color palette from card photos (background + text color pair), or **CIAreaAverage** if you just need a single dominant color for the card header.

```swift
// CIAreaAverage (built-in, no dependencies)
extension UIImage {
    var dominantColor: UIColor? {
        guard let ciImage = CIImage(image: self) else { return nil }
        let filter = CIFilter(name: "CIAreaAverage",
                              parameters: [kCIInputImageKey: ciImage,
                                          kCIInputExtentKey: CIVector(cgRect: ciImage.extent)])
        guard let output = filter?.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext().render(output, toBitmap: &bitmap, rowBytes: 4,
                          bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                          format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return UIColor(red: CGFloat(bitmap[0])/255, green: CGFloat(bitmap[1])/255,
                       blue: CGFloat(bitmap[2])/255, alpha: CGFloat(bitmap[3])/255)
    }
}
```

### 8.3 Catima Import/Export Format

**Catima** is the leading open-source loyalty card app for Android (GPLv3+).

**Export format:** ZIP file containing `catima.csv` + optional card images.

**CSV structure (version 2):**
```
2                          <-- version number

_id,name                   <-- group table header
1,"Supermarkets"           <-- group rows

_id,store,note,validfrom,expiry,balance,balancetype,cardid,barcodeid,barcodetype,headercolor,starstatus,lastused,archive
1,"IKEA","Member card","","2027-01-01","","","12345678","12345678","EAN_13","-1","0","",""

cardId,groupId             <-- card-group linking
1,1
```

**Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `_id` | Integer | Internal ID |
| `store` | String | Store/brand name |
| `note` | String (multiline) | User notes |
| `validfrom` | Date string | Valid from date |
| `expiry` | Date string | Expiration date |
| `balance` | String | Card balance |
| `balancetype` | String | Balance currency/type |
| `cardid` | String | Card number (text on card) |
| `barcodeid` | String | Barcode value (may differ from cardid) |
| `barcodetype` | String | Barcode symbology (EAN_13, CODE_128, QR_CODE, etc.) |
| `headercolor` | Integer | Android color int (-1 = none) |
| `starstatus` | Integer | 0 = not starred, 1 = starred |
| `lastused` | Date string | Last used timestamp |
| `archive` | String | Archive status |

**Image files in ZIP:** Named by card `_id` (e.g., `card_1_front.png`, `card_1_back.png`). Exact naming convention should be verified against the Android source code.

**Barcode type values:** `AZTEC`, `CODABAR`, `CODE_39`, `CODE_93`, `CODE_128`, `DATA_MATRIX`, `EAN_8`, `EAN_13`, `ITF`, `PDF_417`, `QR_CODE`, `UPC_A`, `UPC_E`.

### 8.4 Other Useful Libraries

| Library | Purpose | Notes |
|---------|---------|-------|
| **swift-snapshot-testing** | Snapshot tests | Point-Free, de facto standard |
| **SFSafeSymbols** | Type-safe SF Symbols | Compile-time symbol validation |
| **Nuke** | Image loading/caching | For remote card logos |
| **SwiftLint** | Code style enforcement | Consistency |

---

## 9. Architectural Recommendations Summary

### Recommended Stack

```
Target:           iOS 17.0+ (with @available checks for iOS 18 features)
UI:               SwiftUI (100%)
Architecture:     MVVM with @Observable (iOS 17+)
Persistence:      SwiftData
Sync:             SwiftData + CloudKit (automatic)
Settings sync:    iCloud Key-Value Store
Barcode scan:     VisionKit DataScannerViewController
Barcode render:   CIFilter + RSBarcodes_Swift (for EAN-13, Code 39)
Color extraction: UIImageColors or CIAreaAverage
Testing:          Swift Testing + swift-snapshot-testing
Import:           Catima ZIP parser (custom)
```

### Feature Prioritization by iOS Version

**Works on iOS 17 (core features):**
- SwiftData storage + CloudKit sync
- Barcode scanning (DataScannerViewController)
- Barcode rendering (CIFilter)
- Spring animations, haptic feedback
- @Observable ViewModels
- Card list with scroll snapping

**Enhanced on iOS 18 (progressive enhancement):**
- MeshGradient card backgrounds
- Zoom navigation transitions (card -> detail)
- Custom container views for card layouts
- onScrollGeometryChange for parallax effects
- @Entry for cleaner environment values
