<div align="center">

# 📸 Quicks

**A private, offline memory collection and gallery experience built with Flutter.**

[![Flutter](https://img.shields.io/badge/Flutter-3.10.7+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)](https://dart.dev)

</div>

---

## ✨ Overview

**Quicks** is a simple, beautiful replacement for modern camera apps, designed exclusively for **offline memory collection**. In a world driven by social media and oversharing, Quicks goes in the opposite direction: it is **fully private**.

No uploads, no cloud sync, no social sharing features. Your data is yours alone, stored only on your physical device. Quicks is built for people who want to cherish their personal moments in peace, wrapped in a highly polished, aesthetic, and dynamic "squircle" design language.

## 🚀 Features

### 🔒 Privacy First
- **Zero Cloud Sync:** Your photos never leave your device.
- **No Social Media:** A pure memory collection experience devoid of likes, shares, or tracking.
- **Full Data Ownership:** All images are saved directly to your local file system.

### 📷 Camera Experience
- **Squircle Viewfinder:** A uniquely rounded camera preview with a subtle, glowing shadow effect.
- **Fast Capture:** Seamless photo taking with an instant shutter animation.
- **Background Processing:** Automatic orientation baking and 1:1 square cropping handled in a background isolate for zero UI stutter.
- **Live Moment Strip:** A smoothly animated horizontal strip of your most recent captures that slides and fades into view as you take them.

### 🖼️ Gallery & Navigation
- **Stack "Fan" View:** A beautiful, swipeable (tap-to-cycle) deck of cards displaying your history with alternating, balanced fan distribution and 3D depth shadows.
- **Grid View:** Toggle seamlessly into a structured grid view with smooth scale animations and haptic feedback.
- **Glassmorphism:** A blurred backdrop filter that provides a premium, frosted-glass effect when viewing photos.
- **OS-Level Deletion:** Permanently delete photos from physical storage directly from the preview screen.
- **Context-Aware Metadata:** Beautifully formatted, floating timestamps showing exactly when the moment was captured.

### ✨ Photo Filters (FDK)
- **Filter Development Kit:** A centralized, modular architecture for creating and managing custom photo overlays (`photo_filters.dart`).
- **Dynamic Scaling:** Overlays automatically adapt their sizes, shadows, and densities between small thumbnails and large views.
- **Current Filters:** 
  - **Candy Crush Day:** A bubbly, vibrant day-of-the-week watermark using Google Fonts (`Chewy`), paired with an elegant timestamp.
  - **Retro TV Scanlines:** A vintage CRT effect built with an ultra-efficient CustomPainter, generating dense scanlines and subtle static noise.

### 🎨 UI & Aesthetics
- **Micro-animations:** Custom bouncing effects on buttons, smooth fade transitions, and scaling animations for a responsive, "alive" feel.
- **Premium Dark Mode:** A deep, immersive dark theme that makes your photos pop.

---

## 🛠️ Tech Stack

- **Framework:** [Flutter](https://flutter.dev/)
- **Language:** [Dart](https://dart.dev/)
- **Key Packages:**
  - `camera` - For low-level device camera control.
  - `image` - For background image processing, cropping, and orientation fixing.
  - `path_provider` & `path` - For persistent local file storage and history JSON management.
  - `google_fonts` - For dynamic, beautiful typography (e.g., the Candy Crush filter).

---

## 📁 Project Structure

```text
lib/
├── main.dart                  # App entry point and theme configuration
├── camera_screen.dart         # Main camera UI, history strip, and capture logic
├── photo_preview_screen.dart  # Stack & Grid gallery viewer with deletion & metadata
├── photo_filters.dart         # Filter Development Kit (FDK) core, defining all overlays and painters
└── squircle_clipper.dart      # Custom mathematical clipper for the signature squircle shape
```

---

## 🏁 Getting Started

### Prerequisites

- Flutter SDK `^3.10.7`
- A physical Android or iOS device (the camera plugin may not work optimally on simulators)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/quicks.git
   cd quicks
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

*(Note: Make sure your device is plugged in or running via a wireless debugging connection.)*

---

## 💡 How it Works

1. **Capturing:** When the shutter is pressed, `CameraController` takes a picture. The image path is instantly saved to history for immediate viewing, while a background `compute` isolate handles the heavy lifting of baking the orientation and cropping it to a perfect square.
2. **Persistence:** Your photo history is serialized to JSON and saved locally (`history.json`), meaning your moments are right there when you relaunch the app.
3. **Squircle Math:** The custom `SquircleClipper` uses a mathematical formula ($|x|^n + |y|^n = 1$) to generate smooth, continuous curves that look far more natural than standard rounded rectangles.

---

## 🗺️ Roadmap (To-Dos)

We have some exciting features planned for the future of Quicks:
- [x] **Custom Filters:** Implement stunning photo filters to give moments a unique vibe.
- [x] **Filter Development Kit (FDK):** Allow advanced users to create, tweak, and import their own custom filters.
- [ ] **Memory Book Creation:** Automatically generate and export curated memory books as high-quality PDFs.

---

## 🤝 Contributing

Quicks is an open and evolving project. **Feel free to edit, fork, and contribute!** Whether it's adding new features (like those in our roadmap), fixing bugs, or improving the design, pull requests are always welcome.

---

<div align="center">
  <i>Crafted with passion for private memory collection.</i>
</div>
