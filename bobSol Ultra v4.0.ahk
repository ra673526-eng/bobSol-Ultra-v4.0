#SingleInstance Off
#NoEnv
#MaxThreadsPerHotkey 2
SetWorkingDir %A_ScriptDir%

; ── GLOBAL STATE ──────────────────────────────────────────────────────────────
GlobalRunning     := 0
LoopCycles        := 0
ElapsedTime       := 0
LifetimeSpawns    := 0
LastSpawnTick     := 0
TotalSpawnGap     := 0
SpawnRateSamples  := 0
CDStartTick       := 0
AlertCooldownEnd  := 0
LastAutoSpawnTick := 0
LastPixelFailLog  := 0

; Rolling pixel baseline — updated each loop iteration for delta-based detection
BC1 := 0, BC2 := 0, BC3 := 0, BC4 := 0, BC5 := 0

; Monitored pixel coordinates (ability zone, bottom-right, 1080p calibrated)
; Adjust these coordinates if detection feels too sensitive or too slow.
MX1 := 1080, MY1 := 850
MX2 := 1120, MY2 := 890
MX3 := 1150, MY3 := 950
MX4 := 1080, MY4 := 960
MX5 := 1200, MY5 := 870
PixThreshold := 80   ; Sum of |R|+|G|+|B| delta per sample point to trigger alert

Pad2(n) {
    return (n < 10 ? "0" : "") . n
}

JsonEscape(str) {
    str := StrReplace(str, "\", "\\")
    str := StrReplace(str, Chr(34), "\" . Chr(34))
    str := StrReplace(str, "`n", "\n")
    str := StrReplace(str, "`r", "\r")
    return str
}

RefreshProbabilityHUD() {
    global LifetimeSpawns
    CurrentProbability := (1 - (7499 / 7500) ** LifetimeSpawns) * 100
    FormatChance := SubStr(CurrentProbability, 1, 5)
    RemainingSpawns := 7500 - LifetimeSpawns
    if (RemainingSpawns < 0)
        RemainingSpawns := 0
    HoursLeft := (RemainingSpawns * 15) / 3600
    FormatHours := SubStr(HoursLeft, 1, 4)
    GuiControl,, HUDLifetime, Total Global Spawns: %LifetimeSpawns%
    GuiControl,, HUDChance,   Current Luck Value: %FormatChance%`%
    GuiControl,, HUDEstimate, Est. Remaining: %FormatHours% hrs
}

; ── TRAY ──────────────────────────────────────────────────────────────────────
Menu, Tray, NoStandard
Menu, Tray, Add, 🥊 Open bobSol Panel, TrayOpen
Menu, Tray, Add, Exit bobSol, TrayExit
Menu, Tray, Tip, bobSol Ultra - Idle
Menu, Tray, Default, 🥊 Open bobSol Panel

; ── GUI BUILD ─────────────────────────────────────────────────────────────────
Gui, +AlwaysOnTop -MaximizeBox
Gui, Color, 111111, 1D1D1D
Gui, Font, c00AEFF s14 Bold, Segoe UI
Gui, Add, Text, x15 y15 w810 Center, 🥊 bobSol Ultra v4.0 🥊

Gui, Font, cWhite s10 Bold, Segoe UI
Gui, Add, Tab3, x15 y50 w810 h400 cWhite, Main Control|Stats Overview|Discord|Preset/Info

; ── TAB 1: MAIN CONTROL ───────────────────────────────────────────────────────
Gui, Tab, 1
Gui, Font, s11 Norm cWhite
Gui, Add, Text, x40 y95 w730 h30, Engine Mode: E Key Loop (500ms) + Pixel Badge Zone Monitor.

Gui, Font, s10 Norm cRed
Gui, Add, GroupBox, x40 y140 w730 h260, Requirements
Gui, Font, s11 Norm cWhite
Gui, Add, Text, x70 y180 w670 h30, • Resolution: 1080p Only
Gui, Add, Text, x70 y225 w670 h30, • Windows Scaling: 100`% Scale
Gui, Add, Text, x70 y270 w670 h30, • Roblox State: Windowed Mode
Gui, Add, Text, x70 y315 w670 h30, • Focus: Leave UI open over game
Gui, Font, s10 Italic cGray
Gui, Add, Text, x70 y360 w670 h30, Double-check windows display scaling metrics before executing a run cycle!

; ── TAB 2: STATS OVERVIEW ─────────────────────────────────────────────────────
Gui, Tab, 2

Gui, Font, s10 Bold c00AEFF
Gui, Add, GroupBox, x40 y95 w350 h128, Live Session Telemetry
Gui, Font, s12 Bold cGreen
Gui, Add, Text, x60 y118 w310 h25 vHUDRuntime, Session Time: 00:00:00
Gui, Font, s12 Bold cWhite
Gui, Add, Text, x60 y150 w310 h25 vHUDCycles, Actual Replica Spawns: 0
Gui, Font, s11 Norm cWhite
Gui, Add, Text, x60 y178 w310 h25 vHUDAvgRate, Avg Spawn Rate: --

Gui, Font, s10 Bold c00AEFF
Gui, Add, GroupBox, x40 y231 w350 h55, Replica Ability Cooldown (15s)
Gui, Font, s14 Bold cYellow
Gui, Add, Text, x60 y252 w310 h30 vHUDCooldown, CD: --

Gui, Font, s10 Bold c00AEFF
Gui, Add, GroupBox, x40 y294 w350 h118, Probability Math (1 in 7,500)
Gui, Font, s11 Norm cWhite
Gui, Add, Text, x60 y314 w310 h22 vHUDLifetime, Total Global Spawns: 0
Gui, Add, Text, x60 y337 w310 h22 vHUDChance, Current Luck Value: 0.00`%
Gui, Font, s11 Bold cYellow
Gui, Add, Text, x60 y361 w310 h25 vHUDEstimate, Est. Remaining: 31.2 hrs

Gui, Font, s10 Bold cWhite
Gui, Add, Button, x40 y420 w350 h25 gExportSession, 💾 Export Session Log

Gui, Font, s10 Bold c00AEFF
Gui, Add, GroupBox, x410 y95 w370 h295, Real-Time Diagnostic Engine Logs
Gui, Font, s9 Norm c00FF00
Gui, Add, Edit, x425 y120 w340 h248 ReadOnly vTerminalConsole HwndHwndConsole, [System] Panel loaded. Ready for execution.

; ── TAB 3: DISCORD ────────────────────────────────────────────────────────────
Gui, Tab, 3
Gui, Font, s11 Norm cWhite
Gui, Add, Text, x40 y100 w730 h25, Webhook URL:
Gui, Add, Edit, x40 y130 w730 h30 vDiscordURL,

Gui, Add, Text, x40 y185 w730 h25, Ping Target Role / User ID:
Gui, Add, Edit, x40 y215 w730 h30 vDiscordPing, @here

Gui, Add, Button, x40 y275 w730 h45 gTestDiscord, Send Test Notification

; ── TAB 4: PRESET / INFO ──────────────────────────────────────────────────────
Gui, Tab, 4

; Left column
Gui, Font, s10 Bold c00AEFF
Gui, Add, GroupBox, x40 y95 w370 h140, About bobSol Ultra
Gui, Font, s10 Norm cWhite
Gui, Add, Text, x60 y118 w340 h20, v4.0 — AutoHotkey v1 Macro Engine
Gui, Add, Text, x60 y140 w340 h20, Presses E every 500ms to activate replica ability.
Gui, Add, Text, x60 y162 w340 h20, Monitors pixel zone for badge movement detection.
Gui, Add, Text, x60 y184 w340 h20, Sends screenshot + Discord alert when triggered.
Gui, Add, Text, x60 y206 w340 h20, Export session logs via the Stats Overview tab.

Gui, Font, s10 Bold c00AEFF
Gui, Add, GroupBox, x40 y243 w370 h70, Hotkeys
Gui, Font, s10 Norm cWhite
Gui, Add, Text, x60 y263 w340 h20, F1  →  Start macro engine
Gui, Add, Text, x60 y285 w340 h20, F2  →  Stop macro engine

Gui, Font, s10 Bold c00AEFF
Gui, Add, GroupBox, x40 y321 w370 h110, Timing Reference
Gui, Font, s10 Norm cWhite
Gui, Add, Text, x60 y341 w340 h20, E Key Loop:       500ms per press cycle
Gui, Add, Text, x60 y363 w340 h20, Ability Cooldown: 15 seconds per spawn cycle
Gui, Add, Text, x60 y385 w340 h20, Alert Cooldown:   5 minutes between alerts
Gui, Add, Text, x60 y407 w340 h20, Odds Target:      1 in 7,500 replica spawns

; Right column
Gui, Font, s10 Bold c00AEFF
Gui, Add, GroupBox, x420 y95 w370 h175, Pixel Monitor Zone (1080p Calibrated)
Gui, Font, s10 Norm cWhite
Gui, Add, Text, x440 y118 w340 h20, Zone: Bottom-right ability area (Roblox UI)
Gui, Font, s10 Norm cGray
Gui, Add, Text, x440 y140 w340 h20, P1: (1080, 850)       P2: (1120, 890)
Gui, Add, Text, x440 y162 w340 h20, P3: (1150, 950)       P4: (1080, 960)
Gui, Add, Text, x440 y184 w340 h20, P5: (1200, 870)
Gui, Font, s10 Norm cWhite
Gui, Add, Text, x440 y208 w340 h20, Delta Threshold:  80 (sum of |R|+|G|+|B|)
Gui, Font, s10 Italic cGray
Gui, Add, Text, x440 y230 w340 h20, Adjust PixThreshold at top of script to tune.

Gui, Font, s10 Bold c00AEFF
Gui, Add, GroupBox, x420 y278 w370 h155, Discord Webhook Notes
Gui, Font, s10 Norm cWhite
Gui, Add, Text, x440 y300 w340 h20, Enter your webhook URL in the Discord tab.
Gui, Add, Text, x440 y322 w340 h20, Test button fires a text-only ping (no file).
Gui, Add, Text, x440 y344 w340 h20, Badge alert fires a full screenshot + POST.
Gui, Add, Text, x440 y366 w340 h20, Ping field defaults to @here (configurable).
Gui, Font, s10 Norm cRed
Gui, Add, Text, x440 y390 w340 h20, PowerShell ExecutionPolicy must allow scripts.
Gui, Add, Text, x440 y412 w340 h20, Screenshots auto-saved to system temp folder.

; ── MASTER BUTTONS ────────────────────────────────────────────────────────────
Gui, Tab
Gui, Font, s12 Bold

Gui, Add, Button, x15 y462 w395 h50 gStartMacro, START RUN (F1)
Gui, Add, Button, x430 y462 w395 h50 gStopMacro, STOP MACRO (F2)

Gui, Font, s12 Bold cRed
Gui, Add, Text, x15 y527 w810 h30 vStatusText, Status: Stopped

Gui, Show, w840 h575, bobSol Ultra
WinSet, Transparent, 254, bobSol Ultra

SetTimer, UpdateStatsTimer, 1000
SetTimer, UpdateCDTimer, 100
return

; ── TRAY HANDLERS ─────────────────────────────────────────────────────────────
TrayOpen:
    Gui, Show
return
TrayExit:
    ExitApp

; ── LIVE TELEMETRY (1s tick) ──────────────────────────────────────────────────
UpdateStatsTimer:
    if (GlobalRunning = 0)
        return
    ElapsedTime++
    Hrs  := Floor(ElapsedTime / 3600)
    Mins := Floor((ElapsedTime - (Hrs * 3600)) / 60)
    Secs := Mod(ElapsedTime, 60)
    pHrs  := Pad2(Hrs)
    pMins := Pad2(Mins)
    pSecs := Pad2(Secs)
    GuiControl,, HUDRuntime, Session Time: %pHrs%:%pMins%:%pSecs%
    Menu, Tray, Tip, bobSol Ultra - Running | Spawns: %LoopCycles%
return

; ── CD COUNTDOWN (100ms tick) ─────────────────────────────────────────────────
UpdateCDTimer:
    if (GlobalRunning = 0 || CDStartTick = 0) {
        GuiControl,, HUDCooldown, CD: --
        return
    }
    CDMs    := Mod(A_TickCount - CDStartTick, 15000)
    CDRem   := (15000 - CDMs) / 1000.0
    CDSec   := Floor(CDRem)
    CDTenth := Floor((CDRem - CDSec) * 10)
    pCD     := CDSec . "." . CDTenth . "s"
    if (CDSec < 1) {
        GuiControl, +cGreen, HUDCooldown
        GuiControl,, HUDCooldown, ⚡ READY! (%pCD%)
    } else {
        GuiControl, +cYellow, HUDCooldown
        GuiControl,, HUDCooldown, CD: %pCD%
    }
return

; ── SESSION EXPORT ────────────────────────────────────────────────────────────
ExportSession:
    GuiControlGet, LogContent,, TerminalConsole
    FormatTime, ExportStamp,, yyyy-MM-dd_HH-mm-ss
    FileName := A_ScriptDir . "\bobSol_Session_" . ExportStamp . ".txt"
    MinsRun  := Floor(ElapsedTime / 60)
    SecsRun  := Mod(ElapsedTime, 60)
    ExportHeader := "=== bobSol Ultra - Session Export ===" . "`n"
    ExportHeader .= "Exported At:       " . ExportStamp . "`n"
    ExportHeader .= "Session Spawns:    " . LoopCycles . "`n"
    ExportHeader .= "Lifetime Spawns:   " . LifetimeSpawns . "`n"
    ExportHeader .= "Session Duration:  " . MinsRun . "m " . SecsRun . "s`n"
    ExportHeader .= "=====================================`n`n"
    ExportHeader .= "--- Terminal Log ---`n"
    FileAppend, %ExportHeader%%LogContent%, %FileName%
    if (ErrorLevel)
        MsgBox, 16, Export Failed, Could not write file. Check script directory permissions.
    else
        MsgBox, 64, Export Complete, Session log saved!`n`n%FileName%
return

; ── LOG EVENT ─────────────────────────────────────────────────────────────────
LogEvent(NewText) {
    Global HwndConsole
    FormatTime, Timestamp,, HH:mm:ss
    GuiControlGet, CurrentLog,, TerminalConsole
    UpdatedLog := CurrentLog . "`n[" . Timestamp . "] " . NewText
    GuiControl,, TerminalConsole, %UpdatedLog%
    ControlSend,, ^{End}, ahk_id %HwndConsole%
}

; ── TEST DISCORD ──────────────────────────────────────────────────────────────
TestDiscord:
    Gui, Submit, NoHide
    if (DiscordURL = "") {
        MsgBox, 48, Missing Link, Please enter a valid Discord Webhook URL!
        return
    }
    GuiControl, +cYellow, StatusText
    GuiControl,, StatusText, Status: Transmitting Test...
    LogEvent("[Network] Dispatching payload to Discord...")
    DiscordOk := SendDiscordNotification(DiscordURL, DiscordPing, "Webhook Test Connection Successful.")
    if (DiscordOk) {
        LogEvent("[Network] Discord test delivered successfully.")
        if (GlobalRunning = 1) {
            GuiControl, +cGreen, StatusText
            GuiControl,, StatusText, Status: Running...
        } else {
            GuiControl, +cRed, StatusText
            GuiControl,, StatusText, Status: Stopped
        }
    } else {
        LogEvent("[Network] Discord test failed — check webhook URL and network.")
        GuiControl, +cRed, StatusText
        GuiControl,, StatusText, Status: Discord Test Failed
        MsgBox, 48, Discord Test Failed, Webhook test did not succeed.`nCheck the URL and try again.
    }
return

; ── START MACRO ───────────────────────────────────────────────────────────────
F1::
StartMacro:
    if (GlobalRunning = 1)
        return

    LoopCycles        := 0
    ElapsedTime       := 0
    LastSpawnTick     := 0
    TotalSpawnGap     := 0
    SpawnRateSamples  := 0
    LastAutoSpawnTick := 0
    CDStartTick       := A_TickCount
    AlertCooldownEnd  := 0

    GuiControl,, HUDCycles,   Actual Replica Spawns: 0
    GuiControl,, HUDRuntime,  Session Time: 00:00:00
    GuiControl,, HUDEstimate, Est. Remaining: 31.2 hrs
    GuiControl,, HUDAvgRate,  Avg Spawn Rate: --
    RefreshProbabilityHUD()

    Gui, Submit, NoHide
    GlobalRunning := 1

    GuiControl, +cGreen, StatusText
    GuiControl,, StatusText, Status: Running...
    Menu, Tray, Tip, bobSol Ultra - Running | Spawns: 0
    LogEvent("[Engine] E key loop started. Badge zone monitor active.")

    PixelGetColor, BC1, %MX1%, %MY1%, RGB
    PixelGetColor, BC2, %MX2%, %MY2%, RGB
    PixelGetColor, BC3, %MX3%, %MY3%, RGB
    PixelGetColor, BC4, %MX4%, %MY4%, RGB
    PixelGetColor, BC5, %MX5%, %MY5%, RGB
    LogEvent("[Monitor] Pixel baseline sampled at (" . MX1 . "," . MY1 . ") → (" . MX5 . "," . MY5 . ").")

    LastAutoSpawnTick := A_TickCount

    While (GlobalRunning = 1) {

        Send, {e down}
        Sleep, 50
        Send, {e up}

        if (A_TickCount - LastAutoSpawnTick >= 15000) {
            LoopCycles++
            LifetimeSpawns++
            LastAutoSpawnTick += 15000

            if (LastSpawnTick != 0) {
                SpawnGap      := (A_TickCount - LastSpawnTick) / 1000
                TotalSpawnGap += SpawnGap
                SpawnRateSamples++
                AvgGap    := TotalSpawnGap / SpawnRateSamples
                FormatGap := SubStr(AvgGap, 1, 5)
                GuiControl,, HUDAvgRate, Avg Spawn Rate: %FormatGap%s
            }
            LastSpawnTick := A_TickCount

            CurrentProbability := (1 - (7499 / 7500) ** LifetimeSpawns) * 100
            FormatChance := SubStr(CurrentProbability, 1, 5)

            RemainingSpawns := 7500 - LifetimeSpawns
            if (RemainingSpawns < 0)
                RemainingSpawns := 0
            HoursLeft   := (RemainingSpawns * 15) / 3600
            FormatHours := SubStr(HoursLeft, 1, 4)

            GuiControl,, HUDCycles,   Actual Replica Spawns: %LoopCycles%
            GuiControl,, HUDLifetime, Total Global Spawns: %LifetimeSpawns%
            GuiControl,, HUDChance,   Current Luck Value: %FormatChance%`%
            GuiControl,, HUDEstimate, Est. Remaining: %FormatHours% hrs

            LogEvent("[Ability] Cycle complete. Est. session spawns: " . LoopCycles)
        }

        if (A_TickCount > AlertCooldownEnd) {
            PrevC1 := BC1, PrevC2 := BC2, PrevC3 := BC3, PrevC4 := BC4, PrevC5 := BC5
            PixelGetColor, BC1, %MX1%, %MY1%, RGB
            PixelGetColor, BC2, %MX2%, %MY2%, RGB
            PixelGetColor, BC3, %MX3%, %MY3%, RGB
            PixelGetColor, BC4, %MX4%, %MY4%, RGB
            PixelGetColor, BC5, %MX5%, %MY5%, RGB
            PixelReadOk := (ErrorLevel = 0)

            if (PixelReadOk) {
                D1 := ColorDiff(BC1, PrevC1)
                D2 := ColorDiff(BC2, PrevC2)
                D3 := ColorDiff(BC3, PrevC3)
                D4 := ColorDiff(BC4, PrevC4)
                D5 := ColorDiff(BC5, PrevC5)
                if (D1 > PixThreshold
                 || D2 > PixThreshold
                 || D3 > PixThreshold
                 || D4 > PixThreshold
                 || D5 > PixThreshold) {

                    AlertCooldownEnd := A_TickCount + 300000
                    Gui, Submit, NoHide
                    LogEvent("[ALERT] Pixel movement detected in badge zone! Firing alert...")
                    TakeScreenshotAndAlert(DiscordURL, DiscordPing . " Detected pixel movement in the circled area! The badge was possibly obtained.")
                    GuiControl, +cYellow, StatusText
                    GuiControl,, StatusText, Status: ⚠ BADGE ZONE MOVEMENT!
                    Menu, Tray, Tip, bobSol Ultra - ALERT SENT!
                    SoundBeep, 900, 400
                    SoundBeep, 700, 300
                }
            }
        }

        Sleep, 450
    }
return

; ── STOP MACRO ────────────────────────────────────────────────────────────────
F2::
StopMacro:
    if (GlobalRunning == 0)
        return
    GlobalRunning := 0
    CDStartTick   := 0
    GuiControl, +cRed, StatusText
    GuiControl,, StatusText, Status: Stopped
    Menu, Tray, Tip, bobSol Ultra - Stopped
    LogEvent("[Engine] Engine paused by operator request.")
return

; ── COLOR DIFFERENCE ──────────────────────────────────────────────────────────
ColorDiff(C1, C2) {
    R := Abs(((C1 >> 16) & 0xFF) - ((C2 >> 16) & 0xFF))
    G := Abs(((C1 >> 8)  & 0xFF) - ((C2 >> 8)  & 0xFF))
    B := Abs((C1 & 0xFF) - (C2 & 0xFF))
    return R + G + B
}

; ── SCREENSHOT + DISCORD FILE ALERT ──────────────────────────────────────────
TakeScreenshotAndAlert(WebhookURL, AlertMsg) {
    if (WebhookURL = "") {
        LogEvent("[Alert] No webhook URL configured — screenshot skipped.")
        return
    }

    TS        := A_TickCount
    ScrFile   := A_Temp . "\bobsol_" . TS . ".png"
    PSFile    := A_Temp . "\bobsol_" . TS . ".ps1"
    ScrFilePS := StrReplace(ScrFile, "\", "\\")
    URLClean  := StrReplace(WebhookURL, "'", "''")
    MsgClean  := StrReplace(AlertMsg,   "'", "''")

    PS := ""
    PS .= "Add-Type -AssemblyName 'System.Windows.Forms','System.Drawing'" . "`n"
    PS .= "$f = '" . ScrFilePS . "'" . "`n"
    PS .= "$b = New-Object System.Drawing.Bitmap([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width,[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height)" . "`n"
    PS .= "$g = [System.Drawing.Graphics]::FromImage($b)" . "`n"
    PS .= "$g.CopyFromScreen(0,0,0,0,$b.Size)" . "`n"
    PS .= "$b.Save($f)" . "`n"
    PS .= "$g.Dispose(); $b.Dispose()" . "`n"
    PS .= "Start-Sleep -Milliseconds 300" . "`n"
    PS .= "$bytes = [System.IO.File]::ReadAllBytes($f)" . "`n"
    PS .= "$str = [System.Text.Encoding]::GetEncoding('iso-8859-1').GetString($bytes)" . "`n"
    PS .= "$bnd = [System.Guid]::NewGuid().ToString()" . "`n"
    PS .= "$CRLF = [char]13 + [char]10" . "`n"
    PS .= "$body = '--' + $bnd + $CRLF +" . "`n"
    PS .= "    'Content-Disposition: form-data; name=""content""' + $CRLF + $CRLF +" . "`n"
    PS .= "    '" . MsgClean . "' + $CRLF +" . "`n"
    PS .= "    '--' + $bnd + $CRLF +" . "`n"
    PS .= "    'Content-Disposition: form-data; name=""file""; filename=""screenshot.png""' + $CRLF +" . "`n"
    PS .= "    'Content-Type: image/png' + $CRLF + $CRLF +" . "`n"
    PS .= "    $str + $CRLF + '--' + $bnd + '--'" . "`n"
    PS .= "try {" . "`n"
    PS .= "    Invoke-WebRequest -Uri '" . URLClean . "' -Method Post -ContentType ('multipart/form-data; boundary=' + $bnd) -Body $body" . "`n"
    PS .= "} catch { }" . "`n"

    FileDelete, %PSFile%
    FileAppend, %PS%, %PSFile%

    RunCmd := "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File """ . PSFile . """"
    Run, %RunCmd%,, Hide
    LogEvent("[Network] Screenshot captured and webhook dispatched.")
}

; ── TEXT-ONLY DISCORD POST ────────────────────────────────────────────────────
SendDiscordNotification(URL, PingTarget, MessageText) {
    CleanMessage := PingTarget . " " . MessageText
    SafeMessage  := JsonEscape(CleanMessage)
    JSONPayload  := "{""content"": """ . SafeMessage . """}"
    try {
        WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        WebRequest.Open("POST", URL, false)
        WebRequest.SetRequestHeader("Content-Type", "application/json")
        WebRequest.Send(JSONPayload)
        HttpStatus := WebRequest.Status
        return (HttpStatus >= 200 && HttpStatus < 300)
    } catch {
        return false
    }
}

; Minimize to tray on window close — use tray menu to fully exit
GuiClose:
    Gui, Hide
return