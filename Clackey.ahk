; ==========================================================
;  Clackey - Vimium-style keyboard navigation for Windows
; ==========================================================
;
;  SHORTCUTS (always available):
;    Alt+f     → Show hint labels, type letters to click
;    Alt+j / k → Scroll down / up
;    Alt+d / u → Half page down / up
;
;  ALWAYS ACTIVE:
;    F3        → UIA Inspector (element info under cursor)
;    ScrollLock → Pause/resume all Clackey hotkeys
;
;  PRIVACY:
;    The scanner NEVER reads text, names, or values.
;    Only position (x,y,w,h) and type ("Button", "ComboBox").
;    The Inspector (F3) reads names only when YOU trigger it.
;
;  Requires: AutoHotkey v2.0+, Descolada UIA-v2 library
; ==========================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

#Include lib\UIA.ahk
#Include src\Scanner.ahk
#Include src\Overlay.ahk
#Include src\HintEngine.ahk

; ----------------------------------------------------------
; Configuration
; ----------------------------------------------------------
class Config {
    ; --- Hotkeys ---
    static TriggerKey     := "f"         ; Hint mode (Alt+f)
    static InspectKey     := "F3"        ; Inspector (always active)
    static ScrollDownKey  := "j"         ; Scroll down (Alt+j)
    static ScrollUpKey    := "k"         ; Scroll up (Alt+k)
    static HalfDownKey    := "d"         ; Half page down (Alt+d)
    static HalfUpKey      := "u"         ; Half page up (Alt+u)

    ; --- Scroll settings ---
    static ScrollLines    := 3           ; Lines per Alt+j/k
    static HalfPageLines  := 10          ; Lines per Alt+d/u

    ; --- Hint settings ---
    static HintChars      := "asdfghjkl" ; Home row keys
    static PrivacyMode    := true        ; NEVER read text/names
    static MaxElements    := 200         ; Max number of elements

    ; --- Appearance ---
    static BgColor        := "FFCC00"    ; Hint background (yellow)
    static TextColor      := "000000"    ; Hint text (black)
    static FontSize       := 11          ; Font size
    static FontName       := "Consolas"  ; Font family
    static TransKey       := "010101"    ; Transparency color key
    static HintOpacity    := 220         ; Label opacity (0=invisible, 255=solid)

    ; --- Debug ---
    static ShowTiming     := false       ; Show timing info

    ; --- Scan types ---
    ; Which element types to scan (comma-separated).
    ; ListItem + MenuItem are also AUTOMATICALLY added on re-scan after dropdown.
    static ScanTypes := "Button,CheckBox,ComboBox,DataItem,Edit,Hyperlink,ListItem,MenuItem,RadioButton,SplitButton,TabItem,TreeItem"

    static Load() {
        f := A_ScriptDir "\settings.ini"
        if !FileExist(f)
            return

        ; Hotkeys
        this.TriggerKey    := IniRead(f, "General", "TriggerKey", this.TriggerKey)
        this.InspectKey    := IniRead(f, "General", "InspectKey", this.InspectKey)
        this.ScrollDownKey := IniRead(f, "Navigation", "ScrollDown", this.ScrollDownKey)
        this.ScrollUpKey   := IniRead(f, "Navigation", "ScrollUp", this.ScrollUpKey)
        this.HalfDownKey   := IniRead(f, "Navigation", "HalfPageDown", this.HalfDownKey)
        this.HalfUpKey     := IniRead(f, "Navigation", "HalfPageUp", this.HalfUpKey)

        ; Scroll
        this.ScrollLines   := Integer(IniRead(f, "Navigation", "ScrollLines", "3"))
        this.HalfPageLines := Integer(IniRead(f, "Navigation", "HalfPageLines", "10"))

        ; Hints
        this.HintChars   := IniRead(f, "General", "HintChars", this.HintChars)
        this.PrivacyMode := !!Integer(IniRead(f, "General", "PrivacyMode", "1"))
        this.MaxElements := Integer(IniRead(f, "General", "MaxElements", "200"))
        this.ShowTiming  := !!Integer(IniRead(f, "General", "ShowTiming", "0"))
        this.ScanTypes   := IniRead(f, "General", "ScanTypes", this.ScanTypes)

        ; Appearance
        this.BgColor     := IniRead(f, "Appearance", "BgColor", this.BgColor)
        this.TextColor   := IniRead(f, "Appearance", "TextColor", this.TextColor)
        this.FontSize    := Integer(IniRead(f, "Appearance", "FontSize", "11"))
        this.FontName    := IniRead(f, "Appearance", "FontName", this.FontName)
        this.HintOpacity := Integer(IniRead(f, "Appearance", "HintOpacity", String(this.HintOpacity)))
    }
}

; ----------------------------------------------------------
; Initialization
; ----------------------------------------------------------
Config.Load()
global g_HintActive := false
global g_Paused := false

; --- Alt+key shortcuts ---
HotIf(ActiveCheck)
Hotkey("!" Config.TriggerKey, (*) => ActivateHints())
Hotkey("!" Config.ScrollDownKey, (*) => ScrollDown())
Hotkey("!" Config.ScrollUpKey, (*) => ScrollUp())
Hotkey("!" Config.HalfDownKey, (*) => ScrollHalfDown())
Hotkey("!" Config.HalfUpKey, (*) => ScrollHalfUp())
HotIf()

; --- Always active ---
Hotkey(Config.InspectKey, (*) => InspectElement())
Hotkey("ScrollLock", (*) => TogglePause())

; Tray menu
TraySetIcon("shell32.dll", 173)
A_TrayMenu.Delete()
A_TrayMenu.Add("Clackey", (*) => "")
A_TrayMenu.Disable("Clackey")
A_TrayMenu.Add()
A_TrayMenu.Add("Inspector (" Config.InspectKey ")", (*) => InspectElement())
A_TrayMenu.Add("Pause (ScrollLock)", (*) => TogglePause())
A_TrayMenu.Add()
A_TrayMenu.Add("Settings", (*) => Run(A_ScriptDir "\settings.ini"))
A_TrayMenu.Add("Reload", (*) => Reload())
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", (*) => ExitApp())

ToolTip("Clackey active`n"
    . "Alt+" Config.TriggerKey " = hints | "
    . "Alt+" Config.ScrollDownKey "/" Config.ScrollUpKey " = scroll | "
    . "Alt+" Config.HalfDownKey "/" Config.HalfUpKey " = half page`n"
    . Config.InspectKey " = inspect | ScrollLock = pause")
SetTimer(() => ToolTip(), -4000)

Persistent()

; ----------------------------------------------------------
; Mode check
; ----------------------------------------------------------

/**
 * Alt+key shortcuts work whenever hints are not active
 * and Clackey is not paused. No text field detection needed
 * — Alt+key never conflicts with normal typing.
 */
ActiveCheck(ThisHotkey) {
    global g_HintActive, g_Paused
    return !g_HintActive && !g_Paused
}

; ----------------------------------------------------------
; Navigation functions
; ----------------------------------------------------------

/** Scroll down (Alt+j) */
ScrollDown() {
    Send("{WheelDown " Config.ScrollLines "}")
}

/** Scroll up (Alt+k) */
ScrollUp() {
    Send("{WheelUp " Config.ScrollLines "}")
}

/** Half page down (Alt+d) */
ScrollHalfDown() {
    Send("{WheelDown " Config.HalfPageLines "}")
}

/** Half page up (Alt+u) */
ScrollHalfUp() {
    Send("{WheelUp " Config.HalfPageLines "}")
}

/**
 * Pause/resume all Clackey hotkeys.
 * ScrollLock = emergency stop when something behaves unexpectedly.
 * All keys work 100% normally until you press ScrollLock again.
 */
TogglePause() {
    global g_Paused
    g_Paused := !g_Paused
    if g_Paused {
        ShowStatus("Clackey PAUSED (ScrollLock to resume)", 5000)
        TraySetIcon("shell32.dll", 132)
    } else {
        ShowStatus("Clackey ACTIVE", 2000)
        TraySetIcon("shell32.dll", 173)
    }
}

; ----------------------------------------------------------
; Hint mode (core logic)
; ----------------------------------------------------------

ActivateHints() {
    global g_HintActive
    if g_HintActive
        return
    g_HintActive := true
    overlay := ""
    maxRescans := 3
    rescanCount := 0

    try {
        hwnd := WinGetID("A")
        if !hwnd
            throw Error("No active window")

        ; Loop: after ExpandCollapse (dropdown/menu) automatically
        ; re-scan so you can select items in the dropdown
        Loop {
            ; --- Determine scan types ---
            ; On re-scan after expand: add ListItem + MenuItem
            ; so dropdown items and submenus are found.
            currentTypes := Config.ScanTypes
            if (rescanCount > 0) {
                if !InStr(currentTypes, "ListItem")
                    currentTypes .= ",ListItem"
                if !InStr(currentTypes, "MenuItem")
                    currentTypes .= ",MenuItem"
            }

            ; 1. Scan
            tTotal := A_TickCount
            scanResult := ElementScanner.Scan(
                hwnd, Config.PrivacyMode, Config.MaxElements, currentTypes
            )
            elements := scanResult.elements

            if elements.Length = 0 {
                if rescanCount = 0
                    ShowStatus("No elements found"
                        . (Config.ShowTiming ? " (scan:" scanResult.scanMs "ms)" : ""))
                break
            }

            ; 2. Generate + show hints
            hints := HintEngine.Generate(elements, Config.HintChars)
            overlay := HintOverlay(hints)
            overlay.Show(hwnd)

            if Config.ShowTiming {
                ShowStatus(
                    elements.Length "/" scanResult.rawCount " el"
                    . " | scan:" scanResult.scanMs "ms"
                    . " | cache:" (scanResult.usedCache ? "yes" : "no")
                    . (rescanCount > 0 ? " | rescan #" rescanCount : "")
                , 5000)
            }

            ; 3. Capture keyboard input
            result := CaptureHintInput(hints, overlay)
            overlay.Destroy()
            overlay := ""

            if !result.matched
                break

            ; 4. Execute action
            action := ExecuteHint(result.hint, result.clickType)

            ; 5. Auto re-scan after dropdown/menu opened
            if (action = "expand" && rescanCount < maxRescans) {
                rescanCount++
                Sleep(300)
                try hwnd := WinGetID("A")
                continue
            }
            break
        }
    } catch as err {
        if overlay
            overlay.Destroy()
        ShowStatus("Error: " err.Message)
    }

    g_HintActive := false
}

; ----------------------------------------------------------
; Input handling
; ----------------------------------------------------------

/**
 * Capture keyboard input during hint mode.
 *
 * PREFIX KEYS (before typing hint code):
 *   .  → right click mode
 *   ,  → double click mode
 *   /  → middle click mode
 *   (none) → left click (default)
 *
 * Backspace resets click mode when no hint chars typed yet.
 */
CaptureHintInput(hints, overlay) {
    state := {typed: "", matched: false, hint: "", clickType: "left"}

    ih := InputHook("C")
    ih.KeyOpt("{Escape}", "E")
    ih.KeyOpt("{Backspace}", "NS")
    ih.VisibleText := false

    ih.OnChar := OnHintChar.Bind(state, hints, overlay)
    ih.OnKeyDown := OnHintKeyDown.Bind(state, hints, overlay)

    ih.Start()
    ih.Wait()

    ToolTip()  ; Clear any click mode tooltip
    return state
}

OnHintChar(state, hints, overlay, ih, char) {
    char := StrLower(char)

    ; --- Prefix keys: change click type before typing hint code ---
    if StrLen(state.typed) = 0 {
        if char = "." {
            state.clickType := "right"
            ShowStatus("RIGHT CLICK → type hint code", 0)
            return
        }
        if char = "," {
            state.clickType := "double"
            ShowStatus("DOUBLE CLICK → type hint code", 0)
            return
        }
        if char = "/" {
            state.clickType := "middle"
            ShowStatus("MIDDLE CLICK → type hint code", 0)
            return
        }
    }

    if !InStr(Config.HintChars, char)
        return

    ; Clear click mode tooltip once typing starts
    if StrLen(state.typed) = 0 && state.clickType != "left"
        ToolTip()

    state.typed .= char
    visibleCount := 0
    lastHint := ""

    for hint in hints {
        if SubStr(hint.code, 1, StrLen(state.typed)) = state.typed {
            visibleCount++
            lastHint := hint
            overlay.SetVisible(hint.code, true)
        } else {
            overlay.SetVisible(hint.code, false)
        }
    }

    if visibleCount = 1 {
        state.matched := true
        state.hint := lastHint
        ih.Stop()
    } else if visibleCount = 0 {
        ih.Stop()
    }
}

OnHintKeyDown(state, hints, overlay, ih, vk, sc) {
    if vk != 8
        return

    ; Backspace with no hint chars typed: reset click mode
    if StrLen(state.typed) = 0 {
        if state.clickType != "left" {
            state.clickType := "left"
            ToolTip()  ; Clear click mode tooltip
        }
        return
    }

    state.typed := SubStr(state.typed, 1, -1)
    for hint in hints {
        show := (StrLen(state.typed) = 0)
              || (SubStr(hint.code, 1, StrLen(state.typed)) = state.typed)
        overlay.SetVisible(hint.code, show)
    }
}

; ----------------------------------------------------------
; Action execution
; ----------------------------------------------------------

/**
 * Clicks the matched element. Returns the action type:
 *   "expand"  → dropdown/menu opened (triggers re-scan)
 *   "click"   → normal click
 *
 * @param {Object} hint      - The matched hint object
 * @param {String} clickType - "left", "right", "double", or "middle"
 */
ExecuteHint(hint, clickType := "left") {
    el := hint.element
    ct := hint.ctrlType

    ; === Non-standard click types: direct mouse click ===
    ; Right click, double click, and middle click bypass UIA patterns
    ; and use real mouse clicks at the element's center position.
    if (clickType != "left") {
        CoordMode("Mouse", "Screen")
        centerX := hint.x + (hint.w // 2)
        centerY := hint.y + (hint.h // 2)

        if clickType = "right" {
            Click(centerX, centerY, "Right")
        } else if clickType = "double" {
            Click(centerX, centerY, 2)
        } else if clickType = "middle" {
            Click(centerX, centerY, "Middle")
        }
        return "click"
    }

    ; === ComboBox (50003), SplitButton (50031) ===
    ; Always "expand" → re-scan for dropdown items
    if (ct = 50003 || ct = 50031) {
        try {
            pattern := el.ExpandCollapsePattern
            if pattern.ExpandCollapseState = 0
                pattern.Expand()
            else
                pattern.Collapse()
            return "expand"
        }
        try {
            el.Click()
            return "expand"
        }
        try {
            el.Click("left")
            return "expand"
        }
        CoordMode("Mouse", "Screen")
        Click(hint.x + (hint.w // 2), hint.y + (hint.h // 2))
        return "expand"
    }

    ; === MenuItem (50011) ===
    if (ct = 50011) {
        try {
            if el.IsExpandCollapsePatternAvailable {
                el.ExpandCollapsePattern.Expand()
                return "expand"
            }
        }
        try {
            el.InvokePattern.Invoke()
            return "click"
        }
        try {
            el.Click()
            return "click"
        }
    }

    ; === ListItem (50007) ===
    if (ct = 50007) {
        try {
            el.SelectionItemPattern.Select()
            return "click"
        }
        try {
            el.InvokePattern.Invoke()
            return "click"
        }
        try {
            el.Click()
            return "click"
        }
    }

    ; === All other types ===
    try {
        el.Click()
        return "click"
    }
    try {
        el.Click("left")
        return "click"
    }
    CoordMode("Mouse", "Screen")
    Click(hint.x + (hint.w // 2), hint.y + (hint.h // 2))
    return "click"
}

; ----------------------------------------------------------
; UIA Inspector
; ----------------------------------------------------------

InspectElement() {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)

    try {
        el := UIA.ElementFromPoint(mx, my)

        info := ""
        ctrlType := 0
        try ctrlType := el.Type
        typeName := ""
        try typeName := el.LocalizedControlType

        info .= "TYPE:  " typeName " (" ctrlType ")`n"
        try info .= "NAME:  " el.Name "`n"
        try info .= "ID:    " el.AutomationId "`n"
        try info .= "CLASS: " el.ClassName "`n"
        try {
            v := el.Value
            if v != ""
                info .= "VALUE: " v "`n"
        }
        try {
            loc := el.Location
            info .= "POS:   x=" loc.x " y=" loc.y " w=" loc.w " h=" loc.h "`n"
        }

        info .= "`n--- PATTERNS ---`n"
        patterns := ""

        try {
            if el.IsInvokePatternAvailable
                patterns .= "  Invoke          - clickable`n"
        }
        try {
            if el.IsExpandCollapsePatternAvailable {
                state := ""
                try {
                    s := el.ExpandCollapsePattern.ExpandCollapseState
                    state := s = 0 ? " [collapsed]" : s = 1 ? " [expanded]" : ""
                }
                patterns .= "  ExpandCollapse  - expandable" state "`n"
            }
        }
        try {
            if el.IsTogglePatternAvailable {
                state := ""
                try {
                    s := el.TogglePattern.CurrentToggleState
                    state := s = 1 ? " [on]" : " [off]"
                }
                patterns .= "  Toggle          - on/off" state "`n"
            }
        }
        try {
            if el.IsSelectionItemPatternAvailable {
                state := ""
                try {
                    s := el.SelectionItemPattern.IsSelected
                    state := s ? " [selected]" : ""
                }
                patterns .= "  SelectionItem   - selectable" state "`n"
            }
        }
        try {
            if el.IsValuePatternAvailable
                patterns .= "  Value           - editable value`n"
        }
        try {
            if el.IsScrollPatternAvailable
                patterns .= "  Scroll          - scrollable`n"
        }
        try {
            if el.IsRangeValuePatternAvailable
                patterns .= "  RangeValue      - slider`n"
        }

        if patterns = ""
            patterns := "  (no patterns found)`n"
        info .= patterns

        try el.Highlight(2000, "Red", 3)
        MsgBox(info, "UIA Inspector - Clackey", "64")

    } catch as err {
        MsgBox("Could not inspect element:`n" err.Message,
               "UIA Inspector", "48")
    }
}

; ----------------------------------------------------------
; Utility functions
; ----------------------------------------------------------

ShowStatus(msg, duration := 2000) {
    ToolTip(msg)
    SetTimer(() => ToolTip(), -duration)
}
