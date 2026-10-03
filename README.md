# Interview Trainer Web and Mobile Application With AI Integration

A full-stack artificial intelligence application designed to simulate real-world technical job interviews and provide instant, actionable feedback. Built with a native iOS client (Swift) and a robust Python backend powered by the Gemini API.

<p align="center">
  <!-- Ekran görüntülerini ve gifleri buraya ekleyeceksin -->
  <img src="assets/screenshot1.png" width="250">
  <img src="assets/screenshot2.png" width="250">
</p>

##  Features
* **Real-Time AI Coaching:** Dynamic, natural conversation flows powered by advanced LLMs.
* **Native iOS Experience:** Smooth, responsive, and intuitive user interface built with Swift.
* **Custom API Integration:** Dedicated Python backend managing session states, prompts, and secure API requests.
* **Modular Architecture:** Clean code separation between the frontend UI and backend logic.

##  What I Learned
As a first-year computer engineering student, this represents my first large-scale, end-to-end software development project. Building this application pushed me far beyond standard coursework, teaching me how to:
* Architect a full-stack system from scratch.
* Bridge the gap between a mobile client (Swift) and a server-side application (Python).
* Work with RESTful APIs, JSON parsing, and LLM integrations.
* Manage environments, dependencies, and version control.

##  Tech Stack
* **Frontend:** Swift, UIKit/SwiftUI (iOS)
* **Backend:** Python, FastAPI/Flask (Server)
* **AI Engine:** Gemini API
* **Tools:** Xcode, Antigravity IDE

##  How to Run Locally

### 1. Backend Setup (Mac/Linux)
Open your terminal, navigate to the backend folder, and install the required dependencies:
```bash
pip install -r requirements.txt
```
Start the local server (Ensure it runs on port 8000).

### 2. iOS Setup
1. Open the `.xcodeproj` or `.xcworkspace` file in Xcode.
2. Navigate to the `Config.swift` file in the project directory.
3. Update the `serverHost` variable with your computer's local IP address (e.g., `192.168.x.x`). 
```swift
public struct Config {
    public static let serverHost: String = "YOUR_LOCAL_IP_HERE"
    public static let serverPort: Int = 8000
    // ...
}
```
4. Build and run the app on the Xcode Simulator or your physical iPhone. Ensure your iPhone and Mac are connected to the same Wi-Fi network.

##  Future Roadmap
- [ ] Deploy the backend to a cloud platform for remote access.
- [ ] Implement voice-to-text integration for spoken interview simulations.
- [ ] Add user authentication and history tracking.
