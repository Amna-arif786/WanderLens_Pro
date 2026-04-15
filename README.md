# WanderLens 🌍

WanderLens is a travel-focused social media application built with Flutter and Firebase. It allows users to share their travel experiences through photos, which are automatically verified using AI (Google Vision & ML Kit) to ensure they are high-quality travel destinations.

## Features 🚀

- **AI-Powered Image Verification**: Automatically checks if a photo is a travel destination, monument, or landmark.
- **Dynamic Post Feed**: See travel posts from all over the world.
- **Interactive Map**: Explore destinations by city and location.
- **Save & Wishlist**: Bookmark your favorite travel spots for future trips.
- **Help & Support**: Direct real-time chat with administrators for any issues.
- **Privacy Controls**: Choose who can see your travel memories (Public, Friends, or Only Me).

## Getting Started 🛠️

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Firebase Account](https://firebase.google.com/)
- [Cloudinary Account](https://cloudinary.com/) (for image hosting)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/wanderlens.git
   cd wanderlens
   ```

2. **Setup Environment Variables:**
   Create a `.env` file in the root folder and add your credentials (see `.env.example`).

3. **Firebase Setup:**
   - Add `google-services.json` to `android/app/`.
   - Add `GoogleService-Info.plist` to `ios/Runner/`.
   - Run `flutterfire configure` to generate `lib/firebase_options.dart`.

4. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

5. **Run the app:**
   ```bash
   flutter run
   ```

## Environment Variables 🔑

Check `.env.example` for the required keys. You will need:
- Cloudinary Cloud Name & Upload Preset
- Google Cloud Vision API Key (for advanced AI verification)

## Contributing 🤝

Contributions are welcome! Please feel free to submit a Pull Request.

## License 📜

This project is licensed under the MIT License.
