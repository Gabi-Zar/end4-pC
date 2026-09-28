import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Scope {
    id: bar

    Variants {
        model: {
            const screens = Quickshell.screens;
            // Evaluated before any per-screen window exists, so this is always the
            // global default - "which screens show a bar" isn't itself per-screen.
            const list = Config.options.bar.screenList;
            const base = (!list || list.length === 0) ? screens : screens.filter(screen => list.includes(screen.name));
            // Each screen's own orientation setting decides which of Bar/VerticalBar it gets
            return base.filter(screen => !!Config.barOption(screen.name, "vertical"));
        }
        LazyLoader {
            id: barLoader
            active: GlobalStates.barOpen && !GlobalStates.screenLocked
            required property ShellScreen modelData
            component: PanelWindow {
                id: barRoot
                screen: barLoader.modelData
                readonly property string __barScreen: barRoot.screen?.name ?? ""
                property bool showBarBackground: Config.barOption(barRoot.__barScreen, "showBackground")

                property var brightnessMonitor: Brightness.getMonitorForScreen(barLoader.modelData)
                
                Timer {
                    id: showBarTimer
                    interval: (Config.barOption(barRoot.__barScreen, "autoHide.showWhenPressingSuper.delay") ?? 100)
                    repeat: false
                    onTriggered: { barRoot.superShow = true }
                }
                Connections {
                    target: GlobalStates
                    function onSuperDownChanged() {
                        if (!Config.barOption(barRoot.__barScreen, "autoHide.showWhenPressingSuper.enable")) return;
                        if (GlobalStates.superDown) showBarTimer.restart();
                        else { showBarTimer.stop(); barRoot.superShow = false; }
                    }
                }
                property bool superShow: false
                property bool mustShow: hoverRegion.containsMouse || superShow
                exclusionMode: ExclusionMode.Ignore
                property int normalExclusiveZone: (Config.barOption(barRoot.__barScreen, "autoHide.enable") && (!mustShow || !Config.barOption(barRoot.__barScreen, "autoHide.pushWindows")))
                    ? 0
                    : Appearance.sizes.baseVerticalBarWidth
                        + (Config.barOption(barRoot.__barScreen, "cornerStyle") === 1 ? Appearance.sizes.hyprlandGapsOut : 0)
                        + (Config.barOption(barRoot.__barScreen, "cornerStyle") === 3 ? (Appearance.sizes.hyprlandGapsOut || 5) : 0)

                exclusiveZone: (barContent.centerOnly && Config.barOption(barRoot.__barScreen, "centerOnlyReserveFrame"))
                    ? Config.barOption(barRoot.__barScreen, "frameThickness")
                    : normalExclusiveZone
                WlrLayershell.namespace: "quickshell:verticalBar"
                implicitWidth: Appearance.sizes.verticalBarWidth + Appearance.rounding.screenRounding
                mask: Region { item: hoverMaskRegion }
                color: "transparent"

                anchors {
                    left: !Config.barOption(barRoot.__barScreen, "bottom")
                    right: Config.barOption(barRoot.__barScreen, "bottom")
                    top: true
                    bottom: true
                }

                Component.onCompleted: { GlobalFocusGrab.addPersistent(barRoot); }
                Component.onDestruction: { GlobalFocusGrab.removePersistent(barRoot); }

                MouseArea {
                    id: hoverRegion
                    hoverEnabled: true
                    anchors.fill: parent

                    Item {
                        id: hoverMaskRegion
                        anchors {
                            fill: barContent
                            leftMargin: -Config.barOption(barRoot.__barScreen, "autoHide.hoverRegionWidth")
                            rightMargin: -Config.barOption(barRoot.__barScreen, "autoHide.hoverRegionWidth")
                        }
                    }

                    RoundCorner {
                        id: topPillCorner
                        visible: barContent.centerOnly && showBarBackground && Config.barOption(barRoot.__barScreen, "cornerStyle") === 0
                        y: barContent.centerPillY - implicitSize
                        implicitSize: Appearance.rounding.screenRounding
                        color: Config.barOption(barRoot.__barScreen, "followFrameColor")
                            ? Appearance.getColorFromName(Config.barOption(barRoot.__barScreen, "frameColor"))
                            : Appearance.colors.colLayer0
                        corner: RoundCorner.CornerEnum.BottomLeft

                        states: State {
                            name: "right"
                            when: Config.barOption(barRoot.__barScreen, "bottom")
                            AnchorChanges {
                                target: topPillCorner
                                anchors.left: undefined
                                anchors.right: barContent.right
                            }
                            PropertyChanges {
                                target: topPillCorner
                                corner: RoundCorner.CornerEnum.BottomRight
                            }
                        }
                        AnchorChanges {
                            target: topPillCorner
                            anchors.left: barContent.right
                            anchors.right: undefined
                        }
                    }

                    RoundCorner {
                        id: bottomPillCorner
                        visible: barContent.centerOnly && showBarBackground && Config.barOption(barRoot.__barScreen, "cornerStyle") === 0
                        y: barContent.centerPillY + barContent.centerPillHeight
                        implicitSize: Appearance.rounding.screenRounding
                        color: Config.barOption(barRoot.__barScreen, "followFrameColor")
                            ? Appearance.getColorFromName(Config.barOption(barRoot.__barScreen, "frameColor"))
                            : Appearance.colors.colLayer0
                        corner: RoundCorner.CornerEnum.TopLeft

                        states: State {
                            name: "right"
                            when: Config.barOption(barRoot.__barScreen, "bottom")
                            AnchorChanges {
                                target: bottomPillCorner
                                anchors.left: undefined
                                anchors.right: barContent.right
                            }
                            PropertyChanges {
                                target: bottomPillCorner
                                corner: RoundCorner.CornerEnum.TopRight
                            }
                        }
                        AnchorChanges {
                            target: bottomPillCorner
                            anchors.left: barContent.right
                            anchors.right: undefined
                        }
                    }

                    VerticalBarContent {
                        id: barContent
                        screenName: barRoot.__barScreen

                        implicitWidth: Appearance.sizes.verticalBarWidth
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: parent.left
                            right: undefined
                            leftMargin: (Config.barOption(barRoot.__barScreen, "autoHide.enable") && !mustShow) 
                                ? -Appearance.sizes.verticalBarWidth 
                                : (Config.barOption(barRoot.__barScreen, "cornerStyle") === 3 ? (Appearance.sizes.hyprlandGapsOut || 5) : 0)
                        }
                        Behavior on anchors.leftMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Behavior on anchors.rightMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }

                        states: State {
                            name: "right"
                            when: Config.barOption(barRoot.__barScreen, "bottom")
                            AnchorChanges {
                                target: barContent
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: undefined
                                    right: parent.right
                                }
                            }
                            PropertyChanges {
                                target: barContent
                                anchors.topMargin: 0
                                anchors.rightMargin: (Config.barOption(barRoot.__barScreen, "autoHide.enable") && !mustShow)
                                    ? -Appearance.sizes.barHeight
                                    : (Config.barOption(barRoot.__barScreen, "cornerStyle") === 3 ? (Appearance.sizes.hyprlandGapsOut || 5) : 0)
                            }
                        }
                    }

                    // Round decorators
                    Loader {
                        id: roundDecorators
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: barContent.right
                            right: undefined
                        }
                        width: Appearance.rounding.screenRounding
                        active: showBarBackground && Config.barOption(barRoot.__barScreen, "cornerStyle") === 0 && !barContent.centerOnly

                        states: State {
                            name: "right"
                            when: Config.barOption(barRoot.__barScreen, "bottom")
                            AnchorChanges {
                                target: roundDecorators
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: undefined
                                    right: barContent.left
                                }
                            }
                        }

                        sourceComponent: Item {
                            implicitHeight: Appearance.rounding.screenRounding
                            RoundCorner {
                                id: topCorner
                                anchors { left: parent.left; right: parent.right; top: parent.top }
                                implicitSize: Appearance.rounding.screenRounding
                                color: showBarBackground
                                    ? (Config.barOption(barRoot.__barScreen, "followFrameColor") && Config.barOption(barRoot.__barScreen, "frameColor")
                                        ? Appearance.getColorFromName(Config.barOption(barRoot.__barScreen, "frameColor"))
                                        : Appearance.colors.colLayer0)
                                    : "transparent"
                                corner: RoundCorner.CornerEnum.TopLeft
                                states: State {
                                    name: "bottom"
                                    when: Config.barOption(barRoot.__barScreen, "bottom")
                                    PropertyChanges { topCorner.corner: RoundCorner.CornerEnum.TopRight }
                                }
                            }
                            RoundCorner {
                                id: bottomCorner
                                anchors {
                                    bottom: parent.bottom
                                    left: !Config.barOption(barRoot.__barScreen, "bottom") ? parent.left : undefined
                                    right: Config.barOption(barRoot.__barScreen, "bottom") ? parent.right : undefined
                                }
                                implicitSize: Appearance.rounding.screenRounding
                                color: showBarBackground
                                    ? (Config.barOption(barRoot.__barScreen, "followFrameColor") && Config.barOption(barRoot.__barScreen, "frameColor")
                                        ? Appearance.getColorFromName(Config.barOption(barRoot.__barScreen, "frameColor"))
                                        : Appearance.colors.colLayer0)
                                    : "transparent"
                                corner: RoundCorner.CornerEnum.BottomLeft
                                states: State {
                                    name: "bottom"
                                    when: Config.barOption(barRoot.__barScreen, "bottom")
                                    PropertyChanges { bottomCorner.corner: RoundCorner.CornerEnum.BottomRight }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "bar"
        function toggle(): void { GlobalStates.barOpen = !GlobalStates.barOpen }
        function close(): void { GlobalStates.barOpen = false }
        function open(): void { GlobalStates.barOpen = true }
    }

    CompositorGlobalShortcut {
        name: "barToggle"
        description: "Toggles bar on press"
        onPressed: { GlobalStates.barOpen = !GlobalStates.barOpen; }
    }
    CompositorGlobalShortcut {
        name: "barOpen"
        description: "Opens bar on press"
        onPressed: { GlobalStates.barOpen = true; }
    }
    CompositorGlobalShortcut {
        name: "barClose"
        description: "Closes bar on press"
        onPressed: { GlobalStates.barOpen = false; }
    }
}
