; ==========================================================
; HintOverlay - Transparent hint label overlay
; ==========================================================
; Creates a transparent window with colored hint labels
; positioned at each interactive element.
;
; DESIGN:
;   - Semi-transparent labels so elements remain visible
;   - Compact sizing to reduce overlap on dense UIs
;   - Labels positioned above elements to avoid obscuring them
;   - Click-through so the overlay doesn't steal mouse input
;
; TECHNIQUE:
;   - Single GUI with TransColor for background transparency
;   - WS_EX_TRANSPARENT (0x20) for click-through
;   - WinSetTransColor with opacity level for semi-transparency
;   - Supports multi-monitor via virtual screen fallback
; ==========================================================

class HintOverlay {
    gui := ""
    controls := Map()
    originX := 0
    originY := 0

    __New(hints) {
        this.hints := hints
    }

    /**
     * Create and show the overlay with all hint labels.
     * @param {Integer} targetHwnd - Optional: HWND of target window
     *   for scoped overlay (smaller = faster)
     */
    Show(targetHwnd := 0) {
        ; Determine overlay bounds
        ; Preferred: window size + margin (smaller, faster)
        ; Fallback: entire virtual screen
        pad := 40  ; Margin for hints at the edge
        if targetHwnd {
            try {
                WinGetPos(&wX, &wY, &wW, &wH, targetHwnd)
                this.originX := wX - pad
                this.originY := wY - pad
                overlayW := wW + (pad * 2)
                overlayH := wH + (pad * 2)
            } catch {
                this._UseVirtualScreen(&pad)
                overlayW := SysGet(78)
                overlayH := SysGet(79)
            }
        } else {
            this._UseVirtualScreen(&pad)
            overlayW := SysGet(78)
            overlayH := SysGet(79)
        }

        ; Create transparent, click-through overlay
        this.gui := Gui(
            "-Caption +AlwaysOnTop +ToolWindow -DPIScale +E0x20"
        )
        this.gui.BackColor := Config.TransKey
        this.gui.MarginX := 0
        this.gui.MarginY := 0
        this.gui.SetFont(
            "s" Config.FontSize " Bold c" Config.TextColor,
            Config.FontName
        )

        ; Label dimensions
        charW := Config.FontSize           ; Estimated char width (monospace)
        labelH := Config.FontSize + 6     ; Height with padding
        labelPadX := 6                     ; Horizontal padding

        ; Add a text control for each hint
        for hint in this.hints {
            labelW := (StrLen(hint.code) * charW) + labelPadX

            ; Position on the element itself (top-left corner)
            lx := hint.x - this.originX
            ly := hint.y - this.originY

            ; Clamp to overlay edges
            lx := Max(0, Min(lx, overlayW - labelW))
            ly := Max(0, Min(ly, overlayH - labelH))

            ctrl := this.gui.AddText(
                "x" lx " y" ly
                " w" labelW " h" labelH
                " Center Background" Config.BgColor,
                StrUpper(hint.code)
            )
            this.controls[hint.code] := ctrl
        }

        ; Show overlay without stealing focus
        this.gui.Show(
            "x" this.originX " y" this.originY
            " w" overlayW " h" overlayH " NoActivate"
        )

        ; Make background transparent + labels semi-transparent
        ; Format: "Color Opacity" where Opacity = 0 (invisible) to 255 (solid)
        ; The background color becomes fully transparent, everything else
        ; (hint labels) gets the specified opacity level.
        WinSetTransColor(
            Config.TransKey " " Config.HintOpacity,
            this.gui.Hwnd
        )
    }

    /**
     * Fallback: use entire virtual screen as overlay area.
     */
    _UseVirtualScreen(&pad) {
        this.originX := SysGet(76)   ; SM_XVIRTUALSCREEN
        this.originY := SysGet(77)   ; SM_YVIRTUALSCREEN
        pad := 0
    }

    /**
     * Show or hide a specific hint label.
     * @param {String}  code    - The hint code (e.g. "as")
     * @param {Boolean} visible - true = show, false = hide
     */
    SetVisible(code, visible) {
        if this.controls.Has(code)
            this.controls[code].Visible := visible
    }

    /**
     * Destroy the overlay completely.
     */
    Destroy() {
        if this.gui {
            this.gui.Destroy()
            this.gui := ""
        }
        this.controls := Map()
    }
}
