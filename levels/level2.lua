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
    counts = { grunt = 15, soldier = 7, boss = 1 },
    order = { "grunt", "grunt", "soldier", "grunt", "boss" },
    spawnInterval = 0.6,
    randomSpawns = false,
    initial = {
        { type = "grunt", count = 3 },
    },
    events = {
        { time = 18, type = "boss" },
    }
}
