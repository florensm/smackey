; ==========================================================
; HintEngine - Hint code generation
; ==========================================================
; Generates short letter combinations for each element using
; home-row keys. Uses base-N encoding where N = the number
; of hint characters.
;
; EXAMPLES with "asdfghjkl" (9 characters):
;   <= 9 elements   : 1 char  (a, s, d, f, ...)
;   <= 81 elements  : 2 chars (aa, as, ad, ...)
;   <= 729 elements : 3 chars (aaa, aas, ...)
;
; FILTERING:
;   The first character is the most significant. Typing the
;   first character immediately filters to a subgroup.
;   E.g. with 2-char hints: "a" → shows aa, as, ad, ...
; ==========================================================

class HintEngine {

    /**
     * Generate hint objects with codes assigned to elements.
     *
     * @param {Array}  elements  - Array of {x, y, w, h, element}
     * @param {String} hintChars - String of characters to use
     * @returns {Array} Array of {code, x, y, w, h, element}
     */
    static Generate(elements, hintChars) {
        count := elements.Length
        base := StrLen(hintChars)

        if count = 0
            return []

        ; Calculate minimum code length
        ; base^codeLen >= count
        codeLen := 1
        while (base ** codeLen) < count
            codeLen++

        ; Generate hints with codes
        hints := []
        for idx, el in elements {
            code := this.IndexToCode(idx - 1, codeLen, hintChars)
            hints.Push({
                code:     code,
                x:        el.x,
                y:        el.y,
                w:        el.w,
                h:        el.h,
                element:  el.element,
                ctrlType: el.HasOwnProp("ctrlType") ? el.ctrlType : 0
            })
        }

        return hints
    }

    /**
     * Convert a numeric index to a letter code.
     * Most significant character first (for efficient filtering).
     *
     * @param {Integer} index  - Zero-based index
     * @param {Integer} length - Code length
     * @param {String}  chars  - Character set string
     * @returns {String} Code string (e.g. "as", "df")
     */
    static IndexToCode(index, length, chars) {
        base := StrLen(chars)
        code := ""
        remaining := index

        Loop length {
            divisor := base ** (length - A_Index)
            charIdx := (remaining // divisor) + 1
            remaining := Mod(remaining, divisor)
            code .= SubStr(chars, charIdx, 1)
        }

        return code
    }
}
