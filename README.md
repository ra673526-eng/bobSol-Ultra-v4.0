# bobSol-Ultra-v4.0
# bobSol Ultra v4.0

An AutoHotkey v1 Macro Engine designed for automated gameplay, pixel detection, and Discord logging.

## 📝 Features
* **v4.0 — AutoHotkey v1 Macro Engine**
* Presses `E` every 500ms to activate replica ability.
* Monitors pixel zone for badge movement detection.
* Sends screenshot + Discord alert when triggered.
* Export session logs via the *Stats Overview* tab.

## ⌨️ Hotkeys
* **`F1`** → Start macro engine
* **`F2`** → Stop macro engine

## ⏱️ Timing Reference
* **E Key Loop:** 500ms per press cycle
* **Ability Cooldown:** 15 seconds per spawn cycle
* **Alert Cooldown:** 5 minutes between alerts
* **Odds Target:** 1 in 7,500 replica spawns

## 🖥️ Pixel Monitor Zone (1080p Calibrated)
* **Zone:** Bottom-right ability area (Roblox UI)
* **Calibration Points:**
  ```text
  P1: (1080, 850)    P2: (1120, 890)
  P3: (1150, 950)    P4: (1080, 960)
  P5: (1200, 870)
  ```
* **Delta Threshold:** 80 (sum of `|R|+|G|+|B|`)
* *Note: Adjust `PixThreshold` at the top of the script to tune.*

## 💬 Discord Webhook Notes
* Enter your webhook URL in the Discord tab.
* The test button fires a text-only ping (no file).
* The badge alert fires a full screenshot + POST.
* The ping field defaults to `@here` (configurable).
* ⚠️ **PowerShell ExecutionPolicy must allow scripts.**
* Screenshots are auto-saved to the system temp folder.
