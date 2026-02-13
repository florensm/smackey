; ==========================================================
; ElementScanner - UIA-based interactive element scanner
; ==========================================================
; PERFORMANCE:
;   - CacheRequest: BoundingRectangle + ControlType in one call
;   - Single FindElements with batched OR condition
;   - Smart Chromium detection: skip activation for non-Chromium
;   - Lazy init: CacheRequest created once, reused
;
; PRIVACY:
;   - Privacy mode: reads ONLY BoundingRectangle and ControlType
;     (ControlType is e.g. "Button", "ComboBox" - no sensitive data)
;     NO text, names, or values.
;
; HOW IT WORKS:
;   UIA asks the APPLICATION: "give me all your interactive
;   elements". The app responds via its accessibility provider.
;   Slow apps have slow providers - that's on the app, not us.
; ==========================================================

class ElementScanner {

    ; Control types considered interactive
    static InteractiveTypes := [
        "Button",         ; Buttons, toolbar buttons
        "CheckBox",       ; Checkboxes
        "ComboBox",       ; Dropdown menus
        "Edit",           ; Text fields
        "Hyperlink",      ; Links
        "ListItem",       ; List items
        "MenuItem",       ; Menu items
        "RadioButton",    ; Radio buttons
        "Slider",         ; Sliders
        "SplitButton",    ; Split buttons (button + dropdown)
        "TabItem",        ; Tab headers
        "TreeItem",       ; Tree view items
        "DataItem"        ; Data grid items
    ]

    ; Lazy-initialized CacheRequest
    static _cr := ""

    /**
     * Initialize UIA CacheRequest. Called once.
     * Caches BoundingRectangle + ControlType so we can read both
     * without extra COM calls after FindElements.
     */
    static _EnsureInit() {
        if this._cr
            return
        try this._cr := UIA.CreateCacheRequest(["BoundingRectangle", "ControlType"])
        catch
            this._cr := ""
    }

    /**
     * Scan the active window for interactive elements.
     *
     * @param {Integer} hwnd         - Window handle to scan
     * @param {Boolean} privacyMode  - true = don't read text/names
     * @param {Integer} maxElements  - Maximum number of elements
     * @param {String}  scanTypes    - Comma-separated types (optional)
     *   If empty/0: uses default InteractiveTypes
     *   E.g. "Button,ComboBox,Hyperlink,MenuItem"
     */
    static Scan(hwnd, privacyMode := true, maxElements := 200, scanTypes := "") {
        this._EnsureInit()
        t0 := A_TickCount

        ; Use configurable types or default list
        if scanTypes is String && scanTypes != "" {
            types := StrSplit(scanTypes, ",", " ")
        } else {
            types := this.InteractiveTypes
        }

        ; Build OR condition
        conditions := []
        for typeName in types
            conditions.Push({Type: typeName})

        ; Smart Chromium detection
        try winClass := WinGetClass(hwnd)
        catch
            winClass := ""
        isChromium := InStr(winClass, "Chrome")
        chromiumMs := isChromium ? 300 : 0

        ; Get UIA element
        winEl := UIA.ElementFromHandle(hwnd,, chromiumMs)
        tAfterHandle := A_TickCount

        ; FindElements with CacheRequest → FindAllBuildCache
        ; Retrieves BoundingRectangle + ControlType in ONE call
        try {
            if this._cr
                rawElements := winEl.FindElements(conditions, 4, 0, 0, this._cr)
            else
                rawElements := winEl.FindElements(conditions, 4)
        } catch {
            return {elements: [], scanMs: A_TickCount - t0, rawCount: 0,
                    handleMs: 0, findMs: 0, filterMs: 0, usedCache: false}
        }
        tAfterFind := A_TickCount

        ; Get window bounds
        WinGetPos(&winX, &winY, &winW, &winH, hwnd)
        winR := winX + winW
        winB := winY + winH

        ; Filter with CACHED positions (zero extra COM calls)
        results := []
        useCached := !!this._cr

        for el in rawElements {
            if results.Length >= maxElements
                break

            try {
                loc := useCached ? el.CachedLocation : el.Location

                if loc.w < 5 || loc.h < 5
                    continue

                if (loc.x + loc.w < winX || loc.x > winR
                    || loc.y + loc.h < winY || loc.y > winB)
                    continue

                ; ControlType is NOT privacy-sensitive (it's "Button",
                ; "ComboBox" etc.) and is needed for smart click strategy
                item := {
                    x: loc.x,
                    y: loc.y,
                    w: loc.w,
                    h: loc.h,
                    element: el,
                    ctrlType: useCached ? el.CachedType : 0
                }

                ; Only read names/values when privacy mode is OFF
                if !privacyMode {
                    try item.name := el.Name
                    try item.typeName := el.LocalizedControlType
                }

                results.Push(item)
            } catch {
                continue
            }
        }

        return {
            elements: results,
            scanMs: A_TickCount - t0,
            handleMs: tAfterHandle - t0,
            findMs: tAfterFind - tAfterHandle,
            filterMs: A_TickCount - tAfterFind,
            rawCount: rawElements.Length,
            usedCache: useCached
        }
    }
}
