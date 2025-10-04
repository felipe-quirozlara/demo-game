-- Level 1: gradual random enemies and a small boss later
return {
    name = "Level 1",
    platforms = {
        {0, 560, 800, 40}, -- ground
        {150, 450, 120, 20},
        {350, 360, 120, 20},
        {540, 280, 120, 20},
        {40, 320, 80, 20}
    },
    -- initial immediate spawns (optional)
    initial = {
        { type = "grunt", count = 2 }
    },
    -- scripted counts and order: 10 basic (grunt), 5 medium (soldier), 1 boss
    counts = { grunt = 5, soldier = 3, boss = 1 },
    order = { "grunt", "soldier", "boss" },
    spawnInterval = 0.8,
    -- grouped spawns: each group has type, count, requiredPercent to proceed
    groups = {
        { type = "grunt", count = 5, requiredPercent = 0.6 },
        { type = "soldier", count = 3, requiredPercent = 0.7 },
        { type = "boss", count = 1, requiredPercent = 1.0 },
    },
    -- disable random spawns for fully scripted level
    randomSpawns = false,
    -- timed events (optional)
    events = {
        { time = 20, type = "boss" },
    }
}
