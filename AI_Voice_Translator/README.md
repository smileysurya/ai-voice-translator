<<<<<<< HEAD
# AI Voice Translator v2

A real-time, AI-powered voice translation application. This project enables seamless "walkie-talkie" style voice-to-voice translation, live voice calling, and text translation. 

The application is built using a modern stack consisting of a **Flutter** frontend for cross-platform support (Web, Mobile, Desktop) and a **Node.js** backend utilizing **OpenAI** for high-quality Speech-to-Text (Whisper), Translation (GPT-4o-mini), and Text-to-Speech capabilities.

---

## 🌟 Features
- **Walkie-Talkie Translation**: Record a voice message and instantly hear the translated audio playback.
- **Live Calls**: Join a shared translation room and converse in real-time. Each side speaks in their native language and hears the translated audio.
- **Text Translation**: A robust fallback for typing text and getting instant, accurate translations.
- **History & Saving**: All translations are securely saved using local SQLite storage and Firebase Auth for user management.
- **Cross-Platform**: Built natively with Flutter to support Web, iOS, Android, and Desktop environments out of the box.

---

## 🛠️ Technology Stack

### Backend
- **Node.js** & **Express**: Robust REST API framework.
- **Socket.io**: Real-time websocket communication for live translation calls.
- **Multer**: For handling multiparty form data (audio file uploads).
- **OpenAI API**: 
  - `whisper-1` for highly accurate transcription.
  - `gpt-4o-mini` for fast and context-aware translation.
  - `tts-1` for natural-sounding speech generation.

### Frontend
- **Flutter**: The main UI toolkit.
- **Firebase Auth**: Secure user authentication.
- **just_audio** & **record**: Robust audio recording and playback.
- **socket_io_client**: Connecting to the backend for live rooms.
- **sqflite** / **shared_preferences**: Local data persistence.

---

## 🚀 Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for development and testing.

### Prerequisites
- [Node.js](https://nodejs.org/) (v16.x or newer recommended)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.0.0 or higher)
- An active [OpenAI API Key](https://platform.openai.com/account/api-keys)

---

### Step 1: Backend Setup

The backend handles the computationally heavy translation pipeline and all real-time web socket connections.

1. **Navigate to the backend directory:**
   ```bash
   cd backend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Configure Environment Variables:**
   Create a `.env` file in the `backend` directory and add your OpenAI Key:
   ```env
   PORT=3000
   OPENAI_API_KEY=your_openai_api_key_here
   ```

4. **Start the backend server:**
   You can start the server in development mode (which auto-reloads on file changes):
   ```bash
   npm run dev
   ```
   *(Alternatively, use `npm start` for production mode).* The server will typically run on `http://localhost:3000`.

---

### Step 2: Frontend Setup

The frontend Flutter application connects to your backend services.

1. **Navigate to the frontend directory:**
   ```bash
   cd flutter_app
   ```

2. **Fetch Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure the Backend URL (If testing on physical devices):**
   By default, the app expects the backend to be running on `http://localhost:3000`. If you are running the app on a physical mobile device or an emulator, you may need to update the server endpoints in `lib/constants.dart` to your machine's local IP address (e.g., `http://192.168.1.x:3000`).

4. **Run the Flutter Application:**
   Run the app on your preferred platform (e.g., Chrome, Edge, or a physical mobile device):
   ```bash
   # Run on Chrome (Web)
   flutter run -d chrome

   # Run on Windows Desktop
   flutter run -d windows

   # Run on a connected Android/iOS device
   flutter run
   ```

---

## 📌 Important Commands Summary

| Action | Command | Directory |
| :--- | :--- | :--- |
| **Backend: Install packages** | `npm install` | `/backend` |
| **Backend: Run Dev Server** | `npm run dev` | `/backend` |
| **Backend: Run Prod Server** | `npm start` | `/backend` |
| **Frontend: Fetch packages** | `flutter pub get` | `/flutter_app` |
| **Frontend: Check devices** | `flutter devices` | `/flutter_app` |
| **Frontend: Run App (Web)** | `flutter run -d chrome` | `/flutter_app` |
| **Frontend: Clean Project** | `flutter clean` | `/flutter_app` |

---

## 🔒 Environment Variables

**Backend (`backend/.env`):**
- `PORT` - The port the Node.js server listens on (default: `3000`)
- `OPENAI_API_KEY` - Your active OpenAI API key for AI functions.

*(If Firebase is fully integrated on the backend later, add `FIREBASE_ADMIN_CREDENTIALS` as well).*

## ⚠️ Troubleshooting

- **Socket errors on Web:** Ensure your `baseUrl` in the Flutter app begins with `http://` instead of `https://` if you have not configured SSL for your local backend.
- **Audio Recording Permissions:** If using mobile or web, ensure you actively accept the browser/device microphone permissions prompt when tapping "Record".
- **"Const variables must be initialized":** Ensure you are importing the package containing the constants properly. 

---
*Developed with Flutter & Node.js for ultra-low latency translations.*
=======
# AI-voice-translator
>>>>>>> ac15de0ecabe3f52fde2f0cce766a93a9e7181bf
