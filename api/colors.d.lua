---@meta

---This terminal palette has 16 immutable entries. Pass exactly one color, not a
---bitmask combination. Palette RGB values can change per monitor. These indices
---do not change. The British spelling colours identifies the same namespace.
---The namespace has no combine, subtract, test or other CC color utility functions.
---@enum TC.Color
colors = {
    ---The white palette entry uses blit digit 0.
    white = 1,
    ---The orange palette entry uses blit digit 1.
    orange = 2,
    ---The magenta palette entry uses blit digit 2.
    magenta = 4,
    ---The lightBlue palette entry uses blit digit 3.
    lightBlue = 8,
    ---The yellow palette entry uses blit digit 4.
    yellow = 16,
    ---The lime palette entry uses blit digit 5.
    lime = 32,
    ---The pink palette entry uses blit digit 6.
    pink = 64,
    ---The gray palette entry uses blit digit 7.
    gray = 128,
    ---The lightGray palette entry uses blit digit 8.
    lightGray = 256,
    ---The cyan palette entry uses blit digit 9.
    cyan = 512,
    ---The purple palette entry uses blit digit a.
    purple = 1024,
    ---The blue palette entry uses blit digit b.
    blue = 2048,
    ---The brown palette entry uses blit digit c.
    brown = 4096,
    ---The green palette entry uses blit digit d.
    green = 8192,
    ---The red palette entry uses blit digit e.
    red = 16384,
    ---The black palette entry uses blit digit f.
    black = 32768,
    ---This is the exact British-spelling alias of gray.
    grey = 128,
    ---This is the exact British-spelling alias of lightGray.
    lightGrey = 256,
}

---This is the same read-only color namespace, with the grey and lightGrey aliases.
colours = colors
