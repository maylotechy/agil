# AGIL (Inspired by "Agila")
### *Digital Vision as Sharp as an Eagle*

## 1. Introduction
**AGIL** is a specialized cybersecurity application inspired by the **Agila** (Eagle), the king of birds known for its legendary "sharp eye" and the ability to spot potential threats from vast distances. Just as an eagle monitors its territory for the slightest movement, AGIL scans the user's digital environment—SMS and Emails—to identify microscopic malicious patterns in URLs and message structures that the human eye often overlooks.

## 2. Objectives
*   **Primary Objective**: To develop an intelligent system capable of identifying and classifying phishing threats with high accuracy across multiple communication channels.
*   **Specific Objectives**:
    *   Implement a 3-layer detection pipeline (Blacklist, ML, and AI Reasoning).
    *   Provide real-time scanning for SMS and Gmail inboxes using the "Sharp-Eye" heuristic engine.
    *   Offer transparent "AI Explanations" to educate users on why a specific message is deemed suspicious.
    *   Achieve an F1-score of at least 0.90 in phishing classification.
    *   Enable safe link inspection through a Sandbox Preview environment.

## 3. Scope
*   **Functional Scope**: Manual URL/text scanning, automated SMS inbox monitoring, Gmail API integration, and a "Safety Library" for user awareness.
*   **Technical Scope**: Flutter-based mobile frontend, Python Flask backend, Scikit-learn for ML, and Google Cloud Vertex AI (Gemini) for heuristic reasoning.
*   **Limitations**: Requires active internet connection for real-time AI reasoning; SMS scanning is currently restricted to Android due to iOS permission limitations.

## 4. Problem Definition & Formulation
### The Problem
Phishing remains the most common cyber threat globally. Attackers exploit human psychology (urgency, fear, curiosity) to steal credentials and financial data. Traditional security often fails because it relies solely on static blacklists, which cannot keep up with thousands of new malicious domains created daily.

### Statistics
> [!IMPORTANT]
> According to the **FBI IC3 2023 Report**, phishing was the top crime type reported, with **298,878 complaints** and losses exceeding **$1.1 Billion**. Furthermore, the Anti-Phishing Working Group (APWG) observed nearly **5 million phishing attacks** in 2023, making it the worst year on record for digital scams.

## 5. System Architecture & Design
The system follows a Client-Server architecture with a specialized **3-Layer Security Pipeline**.

### System Flow Diagram
![Figure 1: System Flow Diagram](Place_Mermaid_Figure_Here)

### System Structure
1.  **Frontend (Flutter)**: 
    *   **Main Shell**: Manages the navigation between Scan, SMS, Gmail, and History.
    *   **Scanning Engine**: Uses Google ML Kit for Text Recognition (OCR) to extract URLs from screenshots.
    *   **Sandbox**: A controlled WebView environment to safely inspect links.
2.  **Backend (Python Flask)**:
    *   **Inference Engine**: Hosts the Random Forest model and manages API calls to external security databases.
    *   **Reasoning Engine**: Connects to LLMs (Groq/Gemini) to generate human-readable explanations.
3.  **Connection**: The Frontend communicates with the Backend via RESTful API calls (`POST /api/scan`) using JSON data packets over HTTP.

## 6. Functional Features
*   **AI Scan (Manual)**: Users can paste text or upload photos of messages to extract and analyze links.
*   **Inbox Guardian (SMS)**: Automatically fetches messages from the device inbox, filters for URLs, and scans them in batches.
*   **Email Sentinel (Gmail)**: Securely connects to Google via OAuth2 to scan the user's Inbox and Spam folders for malicious attachments or links.
*   **Threat Center (History)**: A unified dashboard to track all past scans, classified by "Phishing," "Suspicious," or "Safe."
*   **Safety Library**: An educational hub featuring awareness videos and a "Phishing Encyclopedia" to improve user digital literacy.

## 7. Intelligent Components
### Random Forest Classifier
We utilized a Random Forest model trained on the "Phishing Websites Dataset." The model extracts features from URLs (SSL status, domain length, etc.) to predict if they are legitimate or fraudulent.

### Generative AI Heuristics via Vertex AI
For the final layer of protection, AGIL utilizes **Google Cloud Vertex AI**, leveraging the **Gemini 2.5 Flash** model. This provides state-of-the-art heuristic analysis:
*   **Reasoning Engine**: When the ML model flags a threat, Gemini provides a human-readable "Reasoning" output. This bridges the "black box" gap of traditional ML, explaining exactly *why* a message is suspicious.
*   **Contextual Understanding**: Unlike static filters, Gemini can detect nuanced social engineering tactics, such as impersonation of bank officials or high-pressure language.

### User Feedback & Reinforcement Learning Loop
To improve the system's accuracy over time, AGIL includes a **Reinforcement Learning Loop** driven by user feedback:
*   **Thumbs-Up/Down Feedback**: After every scan, users can provide feedback on the AI's verdict.
*   **Data Collection**: This feedback is logged and can be used to re-train the Random Forest model or fine-tune the AI reasoning prompts.
*   **Continuous Improvement**: By involving the user in the classification process, the system learns from real-world edge cases that it might have missed initially.

## 8. Implementation, Evaluation & Results
### Model Evaluation
The system was evaluated using a standard 80/20 train-test split. The results are summarized below:

#### Confusion Matrix Analysis
![Figure 2: Confusion Matrix](Place_Confusion_Matrix_Here)

*   **Accuracy**: 0.905
*   **Precision**: 0.903
*   **Recall**: 0.934
*   **F1-Score**: 0.918

#### Feature Importance
![Figure 3: Feature Importance Chart](Place_Feature_Importance_Here)

Based on the Random Forest analysis, the most significant indicators of phishing are:
1.  **SSLfinal_State**: Represents ~70% of the predictive power, confirming that HTTPS status and certificate validity are critical.
2.  **having_Sub_Domain**: Attackers often use complex subdomains to mimic legitimate sites.
3.  **Prefix_Suffix**: The presence of hyphens (-) in the domain name.

## 9. Ethics & Responsible AI
*   **Privacy**: The system uses read-only permissions for Gmail and SMS. No personal data is stored on the server; scan records remain locally on the user's device.
*   **Bias Mitigation**: The 3-layer approach reduces "False Positives" (labeling a safe link as phishing) by requiring multiple signals before a final verdict is issued.
*   **User Autonomy**: The system provides a "Sandbox Preview," allowing users to view a site safely without fully interacting with it.

## 10. Conclusion
**AGIL** successfully integrates traditional security with modern Intelligent Systems. By achieving a 90.5% accuracy rate and providing human-readable explanations, the project offers a proactive solution to personal cybersecurity.
