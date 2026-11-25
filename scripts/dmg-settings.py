# dmgbuild settings: the installer window people see when they open the .dmg.
# Passed defines: app (path to Orbitile.app), background (TIFF), icon (.icns).
import os

app = defines["app"]  # noqa: F821  (provided by dmgbuild)

format = "UDZO"
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}
background = defines["background"]  # noqa: F821
icon = defines["icon"]  # noqa: F821

window_rect = ((200, 200), (660, 400))
icon_size = 128
text_size = 13
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
default_view = "icon-view"
arrange_by = None

icon_locations = {
    os.path.basename(app): (180, 185),
    "Applications": (480, 185),
}
