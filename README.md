KrishiDoc
KrishiDoc is a Flutter-based, multilingual mobile app for real-time plant disease diagnosis and agricultural advisory, powered by a custom GCP inference API and Google’s Gemini LLM. It supports English, नेपाली (Nepali), and हिन्दी (Hindi), and includes voice I/O, image capture, and chat-style Q&A.

🚀 Features

Image-based disease classification• Capture or select a leaf image• Sends to a GCP endpoint for high-accuracy disease prediction• Displays top prediction name & confidence  

Multilingual LLM advisory• “Symptoms” & “Treatment” buttons invoke a system-prompted Gemini model• Returns 5–10 symptom lines or treatment plans in the selected language• Markdown-formatted replies for bold, lists, etc.

Chatbot interface• Ask free-form questions about crop care, pests, weather, etc.• Role-based system prompt ensures precise, domain-specific answers  

User preferences & state• Language selection (English, नेपाली, हिन्दी)• TTS/STT integration for voice-based Q&A• History of past diagnoses & chats (requires Firebase setup)• Email/password login/logout (optional)

Modern UI/UX• Gradient backgrounds, branded Flutter logo splash• Custom chat bubbles with contrasting user/AI colors• Loading animations for model inference



📁 Project Structure
krishidoc/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── disease_model.dart
│   │   └── chat_model.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── disease_provider.dart
│   │   ├── chat_provider.dart
│   │   └── settings_provider.dart
│   ├── screens/
│   │   ├── home_page.dart
│   │   ├── classifying_page.dart
│   │   ├── disease_result_page.dart
│   │   ├── llm_chat_page.dart
│   │   ├── history_page.dart
│   │   ├── login_page.dart
│   │   └── settings_page.dart
│   ├── services/
│   │   └── api_service.dart
│   ├── utils/
│   │   ├── constants.dart
│   │   └── localization.dart
│   └── widgets/
│       ├── custom_button.dart
│       └── language_selector.dart
├── pubspec.yaml
└── README.md


🔧 Installation & Setup

Clone the repo  
git clone https://github.com/your-org/krishidoc.git
cd krishidoc


Install dependencies  
flutter pub get


Configure GCP & Gemini APIsIn lib/services/api_service.dart, set:  
const String PLANT_API_URL = 'https://your-plant-api/predict/';
const String GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/...';
const String GOOGLE_API_KEY = 'YOUR_GOOGLE_API_KEY';


(Optional) Firebase Setup• Place google-services.json in android/app/• Place GoogleService-Info.plist in ios/Runner/• Uncomment Firebase.initializeApp() in main.dart

Run the app  
flutter run




🌐 Localization
UI strings live in lib/utils/localization.dart and ARB files (for full intl support).Supported: en (English), ne (नेपाली), hi (हिन्दी).Change via the language dropdown in the top AppBar.

🛠️ Dependencies

Flutter SDK ≥ 3.22
provider for state management
http for REST calls
image_picker, flutter_tts, speech_to_text
firebase_core, firebase_auth, cloud_firestore (optional)
flutter_markdown for rich text rendering


🤝 Contributing

Fork the repository
Create a feature branch (git checkout -b feature/...)
Commit changes & push (git push origin feature/...)
Open a Pull Request


📄 License
This project is licensed under the MIT License. See LICENSE for details.