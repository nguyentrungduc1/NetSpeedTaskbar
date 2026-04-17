; NetSpeedTaskbar.ahk - AutoHotkey v2
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

#NoTrayIcon   ; Ẩn tray icon

; ── Config ───────────────────────────────────────────────────────────────────
global CFG := {
    W:        130,
    H:        50,
    BG:       "0D0D0D",
    UpColor:  "FF4444",
    DnColor:  "00E676",
    Interval: 1000,
    AppName:  "NetSpeedTaskbar",
    IniFile:  A_ScriptDir "\NetSpeed.ini"
}

; ── Network state ─────────────────────────────────────────────────────────────
global prevSent := 0
global prevRecv := 0
global prevTime := A_TickCount

; ── Build GUI ─────────────────────────────────────────────────────────────────
global gGui := Gui("-Caption +AlwaysOnTop +ToolWindow")
gGui.BackColor := CFG.BG

; Upload row
gGui.SetFont("s13 Bold c" CFG.UpColor, "Consolas")
global lblUpArrow := gGui.Add("Text", "x6 y4 w16 h20 BackgroundTrans", "↑")
global lblUp      := gGui.Add("Text", "x24 y4 w100 h20 BackgroundTrans", "-- B/s")

; Download row
gGui.SetFont("s13 Bold c" CFG.DnColor, "Consolas")
global lblDnArrow := gGui.Add("Text", "x6 y26 w16 h20 BackgroundTrans", "↓")
global lblDown    := gGui.Add("Text", "x24 y26 w100 h20 BackgroundTrans", "-- B/s")

; ── Position (đọc vị trí đã lưu) ─────────────────────────────────────────────
MonitorGetWorkArea(1, &waL, &waT, &waR, &waB)

defaultX := waR - CFG.W - 8
defaultY := waB - CFG.H - 4

global gX := IniRead(CFG.IniFile, "Window", "X", defaultX)
global gY := IniRead(CFG.IniFile, "Window", "Y", defaultY)

gGui.Show("x" gX " y" gY " w" CFG.W " h" CFG.H " NoActivate")

; ── Keep topmost ─────────────────────────────────────────────────────────────
ForceTopmost()

; ── Drag chuẩn + lưu vị trí ─────────────────────────────────────────────────
OnMessage(0x0201, WM_LBUTTONDOWN)

WM_LBUTTONDOWN(wp, lp, msg, hwnd) {
    if !IsOurWindow(hwnd)
        return

    ; Drag như title bar thật
    PostMessage(0xA1, 2,,, gGui.Hwnd)

    ; Lưu vị trí sau khi kéo
    SetTimer(SavePosition, -500)
}

; ── Right-click menu ─────────────────────────────────────────────────────────
OnMessage(0x0205, WM_RBUTTONUP)

global gMenu := Menu()
gMenu.Add("Khởi động cùng Windows", ToggleStartup)
gMenu.Add()
gMenu.Add("Thoát", (*) => ExitApp())

if IsStartupEnabled()
    gMenu.Check("Khởi động cùng Windows")

WM_RBUTTONUP(wp, lp, msg, hwnd) {
    if !IsOurWindow(hwnd)
        return

    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    gMenu.Show(mx, my)
}

; ── Network init ─────────────────────────────────────────────────────────────
ReadNetBytes(&prevSent, &prevRecv)

; ── Timers ───────────────────────────────────────────────────────────────────
SetTimer(UpdateSpeed, CFG.Interval)
SetTimer(ForceTopmost, 2000)

; ═════════════════════════════════════════════════════════════════════════════

ForceTopmost() {
    DllCall("SetWindowPos"
        , "Ptr",  gGui.Hwnd
        , "Ptr",  -1
        , "Int",  0, "Int", 0, "Int",  0, "Int", 0
        , "UInt", 0x0003 | 0x0010)
}

UpdateSpeed() {
    global prevSent, prevRecv, prevTime

    ReadNetBytes(&curSent, &curRecv)

    now := A_TickCount
    dt  := (now - prevTime) / 1000.0

    if (dt > 0.1) {
        up := (curSent - prevSent) / dt
        dn := (curRecv - prevRecv) / dt

        lblUp.Text   := FmtSpeed(up)
        lblDown.Text := FmtSpeed(dn)
    }

    prevSent := curSent
    prevRecv := curRecv
    prevTime := now
}

ReadNetBytes(&sent, &recv) {
    sent := 0
    recv := 0

    try {
        for nic in ComObjGet("winmgmts:").ExecQuery(
            "SELECT BytesSentPersec,BytesReceivedPersec FROM Win32_PerfRawData_Tcpip_NetworkInterface")
        {
            sent += nic.BytesSentPersec
            recv += nic.BytesReceivedPersec
        }
    }
    catch {
    }
}

FmtSpeed(bps) {
    if (bps < 0)
        return "0 B/s"
    else if (bps < 1024)
        return Format("{:.0f} B/s", bps)
    else if (bps < 1048576)
        return Format("{:.1f} KB/s", bps/1024)
    else if (bps < 1073741824)
        return Format("{:.1f} MB/s", bps/1048576)
    else
        return Format("{:.2f} GB/s", bps/1073741824)
}

IsOurWindow(hwnd) {
    return (hwnd = gGui.Hwnd
         || hwnd = lblUp.Hwnd
         || hwnd = lblDown.Hwnd
         || hwnd = lblUpArrow.Hwnd
         || hwnd = lblDnArrow.Hwnd)
}

; ── Lưu vị trí ───────────────────────────────────────────────────────────────
SavePosition() {
    global gGui, CFG

    WinGetPos(&x, &y,,, gGui.Hwnd)

    IniWrite(x, CFG.IniFile, "Window", "X")
    IniWrite(y, CFG.IniFile, "Window", "Y")
}

; ── Startup ──────────────────────────────────────────────────────────────────
IsStartupEnabled() {
    try {
        RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", CFG.AppName)
        return true
    }
    return false
}

ToggleStartup(*) {
    if IsStartupEnabled() {
        RegDelete("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", CFG.AppName)
        gMenu.UnCheck("Khởi động cùng Windows")
        MsgBox("Đã TẮT khởi động cùng Windows", "NetSpeed", 0x40)
    }
    else {
        RegWrite('"' A_ScriptFullPath '"', "REG_SZ"
               , "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
               , CFG.AppName)

        gMenu.Check("Khởi động cùng Windows")
        MsgBox("Đã BẬT khởi động cùng Windows", "NetSpeed", 0x40)
    }
}