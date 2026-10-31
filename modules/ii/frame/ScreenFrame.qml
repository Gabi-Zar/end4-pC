import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Scope {
    id: root
    function frameThicknessFor(screenName) { return Config.barOption(screenName, "frameThickness") }
    function frameColorFor(screenName) { return Appearance.getColorFromName(Config.barOption(screenName, "frameColor")) }
    function centerOnlyFor(screenName) { return Config.barOption(screenName, "layouts.leftLayout").length === 0 && Config.barOption(screenName, "layouts.rightLayout").length === 0 }
    function hideBarSideFrameFor(screenName) { return Config.barOption(screenName, "cornerStyle") === 0 }
    function barPositionFor(screenName) {
        if (Config.barOption(screenName, "vertical"))
            return Config.barOption(screenName, "bottom") ? "right" : "left"
        return Config.barOption(screenName, "bottom") ? "bottom" : "top"
    }

    function frameVisibleFor(side, screenName) {
        if (!Config.barOption(screenName, "showFrame")) return false
        if (Config.barOption(screenName, "cornerStyle") === 0 && side === root.barPositionFor(screenName)) {
            return root.centerOnlyFor(screenName) || !Config.barOption(screenName, "showBackground")
        }
        return true
    }

    function edgeNeedsInput(side, screenName) {
        if (!frameVisibleFor(side, screenName)) return false
        const dockWants = Config.options.dock.enable && Config.options.dock.hoverToReveal && Config.options.dock.position === side
        const barWants = Config.barOption(screenName, "autoHide.enable") && root.barPositionFor(screenName) === side
        return dockWants || barWants
    }

    component FrameHoverArea: MouseArea {
        required property string side
        required property string screenName
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: root.edgeNeedsInput(side, screenName)
        onContainsMouseChanged: GlobalStates.setFrameHover(screenName, side, containsMouse)
    }

    Variants {
        model: Quickshell.screens

        Item {
            id: frameGroup
            required property var modelData
            readonly property string __barScreen: frameGroup.modelData?.name ?? ""

            PanelWindow { // top
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: root.frameVisibleFor("top", frameGroup.__barScreen) ? root.frameThicknessFor(frameGroup.__barScreen) : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitHeight: root.frameThicknessFor(frameGroup.__barScreen)
                anchors { top: true; left: true; right: true }
                mask: Region { item: root.edgeNeedsInput("top", frameGroup.__barScreen) ? topRect : null }

                Rectangle { id: topRect; anchors.fill: parent; color: root.frameColorFor(frameGroup.__barScreen); visible: root.frameVisibleFor("top", frameGroup.__barScreen) }

                FrameHoverArea { side: "top"; screenName: frameGroup.modelData.name }
            }

            PanelWindow { // bottom
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: root.frameVisibleFor("bottom", frameGroup.__barScreen) ? root.frameThicknessFor(frameGroup.__barScreen) : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitHeight: root.frameThicknessFor(frameGroup.__barScreen)
                anchors { bottom: true; left: true; right: true }
                mask: Region { item: root.edgeNeedsInput("bottom", frameGroup.__barScreen) ? bottomRect : null }

                Rectangle { id: bottomRect; anchors.fill: parent; color: root.frameColorFor(frameGroup.__barScreen); visible: root.frameVisibleFor("bottom", frameGroup.__barScreen) }

                FrameHoverArea { side: "bottom"; screenName: frameGroup.modelData.name }
            }

            PanelWindow { // left
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: root.frameVisibleFor("left", frameGroup.__barScreen) ? root.frameThicknessFor(frameGroup.__barScreen) : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitWidth: root.frameThicknessFor(frameGroup.__barScreen)
                anchors { left: true; top: true; bottom: true }
                mask: Region { item: root.edgeNeedsInput("left", frameGroup.__barScreen) ? leftRect : null }

                Rectangle { id: leftRect; anchors.fill: parent; color: root.frameColorFor(frameGroup.__barScreen); visible: root.frameVisibleFor("left", frameGroup.__barScreen) }

                FrameHoverArea { side: "left"; screenName: frameGroup.modelData.name }
            }

            PanelWindow { // right
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: root.frameVisibleFor("right", frameGroup.__barScreen) ? root.frameThicknessFor(frameGroup.__barScreen) : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitWidth: root.frameThicknessFor(frameGroup.__barScreen)
                anchors { right: true; top: true; bottom: true }
                mask: Region { item: root.edgeNeedsInput("right", frameGroup.__barScreen) ? rightRect : null }

                Rectangle { id: rightRect; anchors.fill: parent; color: root.frameColorFor(frameGroup.__barScreen); visible: root.frameVisibleFor("right", frameGroup.__barScreen) }

                FrameHoverArea { side: "right"; screenName: frameGroup.modelData.name }
            }
        }
    }
}