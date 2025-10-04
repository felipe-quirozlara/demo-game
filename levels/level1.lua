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
    -- timed events: time in seconds from level start
    events = {
        { time = 5, type = "grunt" },
        { time = 8, type = "soldier" },
        { time = 12, type = "grunt" },
        { time = 20, type = "boss" },
    }
}
