-- animation

hl.curve("easeOutCubic", { type = "bezier", points = { {0.33, 1}, { 0.68, 1} } })

hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 1,
    bezier = "easeOutCubic",
    style = "slide",
})
hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 1,
    bezier = "easeOutCubic",
    style = "slide",
})
hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 1,
    bezier = "easeOutCubic",
    style = "slide",
})
hl.animation({
    leaf = "windowsMove",
    enabled = true,
    speed = 1,
    bezier = "easeOutCubic",
})
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 1,
    bezier = "easeOutCubic",
    style = "slidefade 10%",
})
hl.animation({
    leaf = "specialWorkspace",
    enabled = true,
    speed = 1,
    bezier = "easeOutCubic",
    style = "slidefade 10%",
})
hl.animation({
    leaf = "fade",
    enabled = false,
})
hl.animation({
    leaf = "border",
    enabled = false,
})
hl.animation({
    leaf = "borderangle",
    enabled = false,
})
hl.animation({
    leaf = "layers",
    enabled = false,
})
