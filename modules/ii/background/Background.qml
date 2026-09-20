pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.common.functions as CF
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Native wallpaper rendering/picking/blur/transitions have been removed: wallpapers
// are managed externally by skwd-wall, sitting on the Wayland "background" layer
// below this window's "bottom" layer. `wallpaper` below is kept as an inert,
// invisible placeholder (not deleted outright) purely so the many desktop widgets
// that expect a `wallpaperItem` Image reference (for e.g. blur-behind effects)
// keep working without needing to touch each of their implementations.
Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: bgRoot

        required property var modelData

        property list<HyprlandWorkspace> workspacesForMonitor: Hyprland.workspaces.values.filter(workspace => workspace.monitor && workspace.monitor.name == monitor.name)
        property var activeWorkspaceWithFullscreen: workspacesForMonitor.filter(workspace => ((workspace.toplevels.values.filter(window => window.wayland?.fullscreen)[0] != undefined) && workspace.active))[0]
        visible: true

        readonly property bool hiddenForFullscreen: !GlobalStates.screenLocked
            && (activeWorkspaceWithFullscreen != undefined)
            && Config?.options.background.hideWhenFullscreen

        property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

        screen: modelData
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:background"
        WlrLayershell.keyboardFocus: GlobalStates.desktopWidgetKeyboardFocus
            ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"

        // Input mask: by default a layer-shell PanelWindow with no mask captures
        // ALL pointer input across its entire area, which blocked mouse position
        // from ever reaching skwd-wall's own surface on the layer below. Restrict
        // the clickable/hoverable area to just the currently active desktop widgets
        // (tracked live by WidgetCanvas.registeredWidgets) so empty desktop space
        // passes pointer events straight through to skwd-wall.
        //
        // Trade-off: WidgetCanvas's own click-drag rubber-band multi-select (starting
        // from empty desktop space) and the old right-click desktop menu both relied
        // on this window capturing the whole screen. Since the desktop menu is gone
        // (redundant with Settings, per your Super+I) and dragging/selecting a widget
        // by clicking directly on it still works (individual widgets stay inside the
        // mask), this should be a non-issue - but rubber-band-selecting several widgets
        // by starting the drag from *empty* desktop space will no longer start a selection,
        // since that empty space is no longer part of this window's input area.
        // NOTE: this masking approach (Instantiator + Region.regions) is based on
        // Quickshell's documented API but I could not runtime-test it (no Wayland
        // compositor in my sandbox, unlike the fd-based file search). Test it and
        // ping me if the mask doesn't behave as expected.
        property list<var> widgetMaskRegions: []
        mask: Region {
            regions: bgRoot.widgetMaskRegions
        }
        Instantiator {
            model: widgetCanvas.registeredWidgets
            delegate: Region {
                required property var modelData
                item: modelData
            }
            onObjectAdded: (index, object) => {
                bgRoot.widgetMaskRegions = bgRoot.widgetMaskRegions.concat([object])
            }
            onObjectRemoved: (index, object) => {
                bgRoot.widgetMaskRegions = bgRoot.widgetMaskRegions.filter(r => r !== object)
            }
        }

        Item {
            anchors.fill: parent
            opacity: bgRoot.hiddenForFullscreen ? 0 : 1
            enabled: !bgRoot.hiddenForFullscreen

            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            // Inert placeholder - see note at the top of the file. Renders nothing.
            StyledImage {
                id: wallpaper
                anchors.fill: parent
                source: ""
                visible: false
            }

            /* Widgets Loader */
            WidgetCanvas {
                id: widgetCanvas
                anchors.fill: parent

                transitions: Transition {
                    PropertyAnimation {
                        properties: "width,height"
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                    AnchorAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }

                WidgetsLoader {
                    screen: bgRoot.screen
                    wallpaperItem: wallpaper
                    wallpaperSafetyTriggered: false
                }
            }
        }
    }
}
