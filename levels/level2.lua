-- Level 2: heavier waves
return {
    name = "Level 2",
    platforms = {
        {0, 560, 800, 40}, -- ground
        {120, 480, 100, 20},
        {300, 400, 140, 20},
        {520, 320, 120, 20},
        {680, 240, 80, 20}
    },
    initial = {
        { type = "grunt", count = 3 },
        { type = "soldier", count = 1 },
    },
    events = {
        { time = 4, type = "grunt" },
        { time = 6, type = "grunt" },
        { time = 10, type = "soldier" },
        { time = 18, type = "boss" },
    }
}
