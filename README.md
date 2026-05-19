# Ingridio

An AI-powered recipe assistant that turns ingredients on hand into practical meal ideas. Snap your fridge, pantry, or countertop and get ingredient detection, recipe matching, and guided cooking in one workflow.

<div align="center">

<img width="1408" height="768" alt="Ingridio hero preview" src="https://github.com/user-attachments/assets/80e94e6e-7e7e-4c29-b71c-233ab7b8dc5f" />

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Gemini AI](https://img.shields.io/badge/Gemini_2.0_Flash-AI_Powered-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev)
[![Cloud Run](https://img.shields.io/badge/Google_Cloud_Run-Deployed-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)](https://cloud.google.com/run)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

[Live demo](https://ingridio-378480318821.europe-west1.run.app/) · [Repository](https://github.com/saadhtiwana/Ingridio)

</div>

## Overview

Ingridio is built for fast, low-friction cooking decisions. It uses Google Gemini vision capabilities to identify ingredients from user photos, then generates recipes that fit the ingredients, preferences, and cooking context.

## Key capabilities

- Ingredient detection from camera or gallery images
- Recipe suggestions tailored to available ingredients
- Dietary preference filtering for practical meal planning
- Guided cooking mode with structured steps and timers
- Support for English and Urdu recipe output
- Cloud deployment through Google Cloud Run

## Screenshots

<div align="center">

| Onboarding | Scan | Results | Recipe |
| --- | --- | --- | --- |
| <img src="https://github.com/user-attachments/assets/2e9f7d31-bd3f-45c8-9eca-1e921dfbe968" width="180" alt="Onboarding screen" /> | <img src="https://github.com/user-attachments/assets/d098480c-7f6e-4cd8-8fdd-adf4c6d698ab" width="180" alt="Scan screen" /> | <img src="https://github.com/user-attachments/assets/eba105fe-98b2-4b40-aa95-af3f5545764d" width="180" alt="Results screen" /> | <img src="https://github.com/user-attachments/assets/d3d7d249-9bf8-4e64-891b-67d1cd4c34a5" width="180" alt="Recipe screen" /> |

</div>

## How it works

1. Capture a photo of the ingredients you have.
2. Send the image to Gemini-powered vision analysis.
3. Match the detected ingredients against recipe logic and user preferences.
4. Follow the cooking flow from recipe selection to guided steps.

## Tech stack

| Layer | Technology |
| --- | --- |
| Frontend | Flutter and Dart |
| AI vision | Google Gemini 2.0 Flash API |
| Deployment | Google Cloud Run |
| AI workflow | Google AI Studio |
| Containerization | Docker and Nginx |
| Configuration | flutter_dotenv |

## Architecture

```
Flutter app
    -> Camera or gallery input
    -> GeminiService
    -> Ingredient detection
    -> Recipe generation and ranking
    -> Guided cooking experience
    -> Google Cloud Run deployment
```

## Getting started

### Prerequisites

- Flutter SDK 3.x or later
- Dart 3.x or later
- Google AI Studio API key

### Installation

```bash
git clone https://github.com/saadhtiwana/Ingridio.git
cd Ingridio
flutter pub get
echo "GEMINI_API_KEY=your_api_key_here" > assets/.env
flutter run
```

### Build for web

```bash
flutter build web --release
```

### Deploy to Cloud Run

```bash
docker build -t ingridio .
gcloud run deploy ingridio --source .
```

## Project structure

```
lib/
├── data/
├── logic/
├── models/
├── screens/
├── services/
└── widgets/
```

## Contributors

This project includes contributions from:

- [saadhtiwana](https://github.com/saadhtiwana)
- [abdullahxdev](https://github.com/abdullahxdev)

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
