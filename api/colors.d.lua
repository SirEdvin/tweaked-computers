---@meta

---The immutable 16-entry terminal palette. Pass exactly one color, not a bitmask
---combination. Palette RGB values may change per monitor; these indices do not.
---The British spelling colours is the identical namespace. No combine, subtract,
---test or other CC color utility functions are provided.
---@enum TC.Color
colors = {
    ---white palette entry; blit digit 0.
    white = 1,
    ---orange palette entry; blit digit 1.
    orange = 2,
    ---magenta palette entry; blit digit 2.
    magenta = 4,
    ---lightBlue palette entry; blit digit 3.
    lightBlue = 8,
    ---yellow palette entry; blit digit 4.
    yellow = 16,
    ---lime palette entry; blit digit 5.
    lime = 32,
    ---pink palette entry; blit digit 6.
    pink = 64,
    ---gray palette entry; blit digit 7.
    gray = 128,
    ---lightGray palette entry; blit digit 8.
    lightGray = 256,
    ---cyan palette entry; blit digit 9.
    cyan = 512,
    ---purple palette entry; blit digit a.
    purple = 1024,
    ---blue palette entry; blit digit b.
    blue = 2048,
    ---brown palette entry; blit digit c.
    brown = 4096,
    ---green palette entry; blit digit d.
    green = 8192,
    ---red palette entry; blit digit e.
    red = 16384,
    ---black palette entry; blit digit f.
    black = 32768,
    ---Exact British-spelling alias of gray.
    grey = 128,
    ---Exact British-spelling alias of lightGray.
    lightGrey = 256,
}

---Identical read-only color namespace, including grey/lightGrey aliases.
colours = colors
