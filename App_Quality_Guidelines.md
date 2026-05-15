# Android App Quality Guidelines: A Comprehensive Guide for AI & Developers

This document outlines the core pillars, technical requirements, and adaptive standards for modern Android application development. Use this as a reference for code reviews, architecture planning, and UI/UX audits.

---

## 1. The Core App Quality Pillars
These are the fundamental requirements for any app to be considered "high quality" on the Google Play Store.

### A. Visual Experience & UX
* **Material Design:** Adhere to Material 3 principles (M3). Use standardized components for consistency.
* **State Preservation:** The app must save user data and scroll position when moving to the background or during configuration changes (e.g., screen rotation).
* **Back Navigation:** Implement predictable back-button behavior using the System Back gesture.
* **Touch Targets:** Ensure all interactive elements have a minimum size of **48x48dp**.

### B. Technical Performance
* **Startup Time:** Cold start should be < 2 seconds; Warm start < 1 second.
* **Stability:** Maintain a crash-free rate above 99% and minimize "Application Not Responding" (ANR) errors.
* **Frame Rate:** Target 60 FPS (standard) or 120 FPS (high-refresh-rate devices) to avoid "jank" during animations and scrolling.

### C. Privacy & Security
* **Permission Scoping:** Request permissions in context (only when needed) rather than at launch. 
* **Data Minimization:** Only request the minimum necessary permissions. Use the Photo Picker instead of full Media permissions where possible.
* **HTTPS:** All network traffic must be encrypted via TLS.

---

## 2. Adaptive App Quality (Form Factors)
With the fragmentation of devices, apps must adapt to tablets, foldables, and desktop modes.

* **Tier 3 (Adaptive Ready):** Support for basic resizing. No letterboxing (black bars) on large screens. Support for mouse/keyboard input.
* **Tier 2 (Adaptive Optimized):** Use Multi-pane layouts (e.g., List-Detail view) for tablets. Optimized navigation rails instead of bottom bars.
* **Tier 1 (Adaptive Differentiated):** Advanced support for foldable postures (Half-opened/Tabletop mode). Drag-and-drop support between windows.

---

## 3. The "Android Excellence" Checklist
| Category | Requirement |
| :--- | :--- |
| **Notifications** | Use `MessagingStyle` for chats. Provide meaningful notification channels. |
| **Accessibility** | Minimum contrast ratio of 4.5:1. Support screen readers (TalkBack) with content descriptions. |
| **Deep Linking** | Implement Android App Links to handle web URLs directly in-app. |
| **Battery** | Use WorkManager for background tasks to optimize Doze mode efficiency. |
| **Internationalization** | Support RTL (Right-to-Left) layouts and per-app language preferences. |

---

## 4. Google Play Store Requirements
* **Metadata:** Use high-quality, truthful screenshots without device frames.
* **Privacy Policy:** Must be linked in the store listing and available within the app.
* **Target API:** Always target within one year of the latest Android version release.

---
*Reference: [Official Android Developers Quality Guidelines](https://developer.android.com/docs/quality)*
