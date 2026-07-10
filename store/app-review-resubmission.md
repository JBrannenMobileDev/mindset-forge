# App Store Resubmission Checklist

Use this after building a new release with Future Self background audio (audio_service custom handler).

## 1. Screenshots (Guideline 2.3.10)

**Root cause:** The status bar was hidden via `UIStatusBarHidden` (iOS), `windowFullscreen` (Android), and immersive splash settings. Screenshots showed a plain dark top with no visible iOS time/battery row, which App Review flagged as a non-iOS status bar.

**After the fix:** The app shows the standard iOS status bar with white icons on the dark `#0A0A0F` background. Re-capture all screenshots from the updated build.

1. Open [App Store Connect](https://appstoreconnect.apple.com) → MindsetForge → **App Store** tab → **Previews and Screenshots**.
2. Click **View All Sizes in Media Manager** and replace every slot (6.7", 6.5", 5.5", iPad if applicable).
3. Capture on a **real iPhone** or iOS Simulator with the correct device frame. Required shots:
   - Dashboard
   - Coach Chat (callback moment if possible)
   - Future Self player (active session)
   - Goals / Actions
   - Affirmations
   - Journal
4. Verify each image shows a **visible iOS status bar**: white time, signal, and battery on the dark background.
5. Poster-style marketing slides are fine; any in-app UI inside phone mockups must be from iOS.

## 2. Screen recording for App Review (Guideline 2.5.4)

Record on a **physical iPhone** (not Simulator):

1. Sign in and open **Mindset** → **Future Self** → start a practice session with audio (beats + narration).
2. Let narration play for at least 10 seconds.
3. Press the **Side button** to lock the screen (or swipe home).
4. Show audio still playing (audible in recording, or unlock to show lock-screen media controls).
5. Upload the `.mov` to **App Review Information → Notes** (or attach in the rejection reply thread).

**Reviewer path:** Mindset tab → Future Self → tap a scene → Start Practice.

## 3. Reply to App Review (paste into Resolution Center)

```
2.3.10 — Screenshots
The status bar was previously hidden via fullscreen/immersive settings. We now show the standard iOS status bar with light icons on our dark background. All screenshots have been re-captured on iPhone to reflect this, across every device size in Media Manager (View All Sizes).

2.5.4 — Background audio
MindsetForge includes Future Self Practice (Mindset → Future Self → Start Practice): guided AI narration with optional binaural beats for eyes-closed meditation. Audio continues when the screen locks via our audio_service integration (narration + binaural bed play together). A screen recording on a physical device demonstrating background playback is attached in App Review Information.
```

## 4. Submit

1. Upload the new build (version bump if needed).
2. Attach the screen recording.
3. Send the reply above in App Store Connect.
4. Resubmit for review.
