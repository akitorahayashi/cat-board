## Overview

Cat Board is an iOS app designed to efficiently process and display a large number of cat images.

Since the screening process involves machine learning, verification on a real device such as an iPhone 16 is recommended. Simulators may not provide sufficient performance.

## Architecture

- **Multi-Module Configuration**
  - Xcode project management with Xcodegen
  - Module management with SwiftPM

- **Swift Concurrency**
  - Asynchronous processing control with `async/await`
  - Concurrency safety with `actor`

- **SwiftData**
  - Caching URLs fetched from the Cat API
  - Caching prefetched URLs
  - Automatic replenishment and deletion features

- **Performance Optimization**
  - Fast image loading through prefetching and caching
  - High-speed image display with batch processing
  - Chunked layout + LazyVStack

- **Dependency Injection**
  - Dependency Inversion Principle
  - Elimination of external dependencies like networking

## Directory Structure

```
.
├── .github/
├── CatBoardApp/
├── CatAPIClient/
├── CatImageLoader/
├── CatImagePrefetcher/
├── CatImageScreener/
├── CatImageURLRepository/
├── CatBoardTests/
├── CatBoardUITests/
├── fastlane/
├── project.envsubst.yml
├── Makefile
├── Mintfile
├── .swiftlint.yml
├── .swiftformat
├── README.md
└── .gitignore
```

## Key Features

### 1. Layout
Utilizes `LazyVStack` and `TieredGridLayout` to provide a smooth scrolling experience while optimizing memory usage.

### 2. Swift Concurrency
By implementing concurrent processing using `actor` and `MainActor`, "Bad Access" errors have been completely eliminated. Each component (CatImagePrefetcher, CatImageURLRepository, CatImageLoader, CatImageScreener) is implemented as an `actor`, preventing data races and enabling efficient parallel processing. UI updates and SwiftData operations are explicitly controlled on the `MainActor` to achieve predictable state management.

### 3. Multi-Layer Caching System
Implements a caching system using Kingfisher and SwiftData. It combines a memory cache (limited to 200MB), a disk cache (limited to 500MB, valid for 3 days), and persistence of fetched and prefetched URLs with SwiftData to achieve faster display. When displaying images, `.memoryCacheExpiration(.seconds(3600))` and `.diskCacheExpiration(.expired)` are used to release the cache for a short period after display.

### 4. Automatic Image URL Management
`CatImageURLRepository` monitors the stock of image URLs. When the number of available URLs falls below a certain threshold, it automatically fetches new image URLs via `CatAPIClient`. This replenishment process runs asynchronously in the background for efficient updates. The fetched URLs are persisted through SwiftData, ensuring they are immediately available on the next app launch.

### 5. Prefetching
A prefetching feature prepares the next images to be displayed in advance. Prefetched URLs are saved in SwiftData and can be used on the next launch. This speeds up the initial image display when the app is launched on subsequent occasions.

### 6. Screening
A machine learning model checks all cat images before display, automatically filtering out inappropriate ones to ensure only safe images are shown. A flag is also available in the code for developers to display only images identified as potentially unsafe.

### 7. Error Handling and Recovery
Each module implements its own error handling to manage exceptions such as network errors, decoding errors, and memory access issues. Stable operation is achieved through settings like a maximum of 5 retries and a 10-second timeout.

## Setup

### 1. Environment Configuration

Copy `.env.example` to `.env` and configure your local environment:

```bash
cp .env.example .env
```

Edit `.env` with your local simulator settings:

```bash
# ローカルシミュレータの設定
LOCAL_SIMULATOR_UDID="YOUR_UDID"     

# Apple Developer
APPLE_ID="your_apple_id@example.com"
TEAM_ID="YOUR_TEAM_ID"
```

To find your simulator's UDID, run:
```bash
xcrun simctl list devices
# or use xcsiml for a cleaner output:
# xcsiml list
```

### 2. Dependencies & Project Generation

Install dependencies:
```bash
bundle install  # Ruby dependencies (fastlane)
mint bootstrap  # Swift dependencies (swiftformat, swiftlint)
```

Generate Xcode project (with env values):
```bash
make gen-proj   # Generates project.yml from project.envsubst.yml and runs xcodegen
```

## Unit Tests

- **GalleryViewModelTests**: Verifies ViewModel's image loading, additional fetching, clearing, maximum count limit, and integration with screening.
- **CatImagePrefetcherTests**: Verifies automatic execution of prefetching, prevention of duplicate execution, and integration with screening.
- **CatImageURLRepositoryTests**: Verifies image URL fetching, caching, and automatic replenishment functions.
- **CatImageScreenerTests**: Verifies the screening functionality.

## UI Tests

- Initial screen display on app launch, scroll view, and confirmation of the first image's presence.
- Refresh button behavior, image redisplay, and confirmation that no error state occurs.
- Display of error state, retry button behavior, and confirmation of recovery to a normal state.
- Confirmation of additional image fetching through scrolling.