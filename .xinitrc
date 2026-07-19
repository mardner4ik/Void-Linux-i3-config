# Make sure XDG_DATA_DIRS always includes the standard app-data locations
# (where .desktop files live) *before* dbus-run-session starts a fresh
# session bus — some environments (live ISOs especially) don't have it
# set at all, which makes rofi's drun mode show an empty/partial list
# even when the apps are actually installed.
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

exec dbus-run-session i3
