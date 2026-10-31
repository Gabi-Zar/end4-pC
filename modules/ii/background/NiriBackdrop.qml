pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions as CF
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland

Variants {
    id: wallpaperBackdropRoot
    model: Quickshell.screens

    Loader {
        id: loader
        required property var modelData
        active: WM.compositor === "niri"

        sourceComponent: PanelWindow {
            id: backdrop
            screen: loader.modelData

            // Native wallpaper rendering removed - skwd-wall (external) manages
            // wallpapers now. This niri-only backdrop is kept inert/empty.

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell:wallpaper"
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
        }
    }
}
