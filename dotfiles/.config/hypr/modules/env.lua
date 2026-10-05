--Environment variables
 
hl.env("XCURSOR_SIZE", "20")
hl.env("HYPRCURSOR_SIZE", "20")

--GUI toolkits backend
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

--QT 
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")