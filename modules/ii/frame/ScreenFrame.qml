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

    component FrameCornerWindow: PanelWindow {
        id: cornerPanelWindow
        property var corner
        readonly property string __barScreen: cornerPanelWindow.screen?.name ?? ""

        visible: Config.barOption(cornerPanelWindow.__barScreen, "showFrame")
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "quickshell:screenframe-corner"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: cornerWidget.isTopLeft || cornerWidget.isTopRight
            left: cornerWidget.isBottomLeft || cornerWidget.isTopLeft
            bottom: cornerWidget.isBottomLeft || cornerWidget.isBottomRight
            right: cornerWidget.isTopRight || cornerWidget.isBottomRight
        }
        margins {
            left: cornerWidget.isLeft ? root.frameThicknessFor(cornerPanelWindow.__barScreen) : 0
            right: cornerWidget.isRight ? root.frameThicknessFor(cornerPanelWindow.__barScreen) : 0
            top: cornerWidget.isTop ? root.frameThicknessFor(cornerPanelWindow.__barScreen) : 0
            bottom: cornerWidget.isBottom ? root.frameThicknessFor(cornerPanelWindow.__barScreen) : 0
        }

        implicitWidth: cornerWidget.implicitWidth
        implicitHeight: cornerWidget.implicitHeight

        RoundCorner {
            id: cornerWidget
            anchors.fill: parent
            corner: cornerPanelWindow.corner
            implicitSize: 22 // fix me >> variable
            color: root.frameColorFor(cornerPanelWindow.__barScreen)
        }
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
                mask: Region {}

                Rectangle { anchors.fill: parent; color: root.frameColorFor(frameGroup.__barScreen); visible: root.frameVisibleFor("top", frameGroup.__barScreen) }
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
                mask: Region {}

                Rectangle { anchors.fill: parent; color: root.frameColorFor(frameGroup.__barScreen); visible: root.frameVisibleFor("bottom", frameGroup.__barScreen) }
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
                mask: Region {}

                Rectangle { anchors.fill: parent; color: root.frameColorFor(frameGroup.__barScreen); visible: root.frameVisibleFor("left", frameGroup.__barScreen) }
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
                mask: Region {}

                Rectangle { anchors.fill: parent; color: root.frameColorFor(frameGroup.__barScreen); visible: root.frameVisibleFor("right", frameGroup.__barScreen) }
            }

            FrameCornerWindow { screen: frameGroup.modelData; corner: RoundCorner.CornerEnum.TopLeft }
            FrameCornerWindow { screen: frameGroup.modelData; corner: RoundCorner.CornerEnum.TopRight }
            FrameCornerWindow { screen: frameGroup.modelData; corner: RoundCorner.CornerEnum.BottomLeft }
            FrameCornerWindow { screen: frameGroup.modelData; corner: RoundCorner.CornerEnum.BottomRight }
        }
    }
}