import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell.Hyprland

ContentPage {
    id: page
    forceWidth: true

    function goTo(term) {
        const t = term.toLowerCase().trim()

        function findTarget(rootItem) {
            for (let i = 0; i < rootItem.children.length; i++) {
                let child = rootItem.children[i]
                if (child.title && child.title.toLowerCase().includes(t)) {
                    return child
                }
            }

            for (let i = 0; i < rootItem.children.length; i++) {
                let found = findTarget(rootItem.children[i])
                if (found) return found
            }
            return null
        }

        let target = findTarget(mainLayout)
        if (target) {
            let pos = target.mapToItem(mainLayout, 0, 0)
            page.contentY = Math.max(0, pos.y - 0)
        }
    }

    property var allWidgets: [
        { id: "leftSidebarButton", name: Translation.tr("Left Sidebar Button"),  icon: "left_panel_open" },
        { id: "workspaces",        name: Translation.tr("Workspaces"),           icon: "steppers" },
        { id: "weatherBar",        name: Translation.tr("Weather"),              icon: "flare" },
        { id: "media",             name: Translation.tr("Media"),                icon: "music_note" },
        { id: "resources",         name: Translation.tr("Resources"),            icon: "empty_dashboard" },
        { id: "systemIcons",       name: Translation.tr("System Icons"),         icon: "info" },
        { id: "networkSpeed",      name: Translation.tr("Network Speed"),        icon: "network_check" },
        { id: "clockWidget",       name: Translation.tr("Clock"),                icon: "schedule" },
        { id: "utilButtons",       name: Translation.tr("Util Buttons"),         icon: "toggle_on" },
        { id: "sysTray",           name: Translation.tr("Tray"),                 icon: "inbox" },
        { id: "batteryIndicator",  name: Translation.tr("Battery"),              icon: "battery_android_frame_full" },
        { id: "bluetooth",         name: Translation.tr("Bluetooth"),            icon: "bluetooth" },
        { id: "activeWindow",      name: Translation.tr("Active Window"),        icon: "subtitles" },
        { id: "powerButton",       name: Translation.tr("Power Button"),         icon: "power_settings_new" },
        { id: "updatesCount",      name: Translation.tr("Updates"),              icon: "deployed_code_update" },
        { id: "docktoPanel",       name: Translation.tr("Dock to Panel"),        icon: "apps" },
        { id: "visualizer",        name: Translation.tr("Visualizer"),           icon: "graphic_eq" },
        { id: "hyprlandXkbIndicator",   name: Translation.tr("Keyboard Layout"), icon: "keyboard" },
        { id: "divisor",            name: Translation.tr("Divider"),             icon: "horizontal_distribute" },
        { id: "launcherButton",     name: Translation.tr("Launcher Button"),     icon: "search" },
        { id: "dynamicIsland",     name: Translation.tr("Dynamic Island"),     icon: "nest_wifi_pro" },
    ]

    function availableFor(section) {
        let used = [
            ...page.barVal("layouts.leftLayout"),
            ...page.barVal("layouts.middleLayout"),
            ...page.barVal("layouts.rightLayout")
        ]
        if (section === "middle" && page.barVal("layouts.middleLayout").length > 0) {
            return page.barVal("layouts.middleLayout").includes("dynamicIsland") ? [] : allWidgets.filter(w => {
                if (w.id === "dynamicIsland") return false
                if (w.id === "divisor" && page.barVal("borderless") !== "transparent") return false
                const multipleAllowed = ["visualizer", "divisor"]
                return !used.includes(w.id) || multipleAllowed.includes(w.id)
            })
        }
        const multipleAllowed = ["visualizer", "divisor"]
        return allWidgets.filter(w => {
            if (w.id === "divisor" && page.barVal("borderless") !== "transparent") return false
            if (w.id === "dynamicIsland" && (page.barVal("vertical") || section !== "middle")) return false
            return !used.includes(w.id) || multipleAllowed.includes(w.id)
        })
    }

    function getWidgetName(id) {
        const w = allWidgets.find(w => w.id === id)
        return w ? w.name : id
    }

    // "" = editing the global defaults. Otherwise the name of the screen being customized.
    property string selectedScreen: ""

    // Every control below reads/writes through these two, instead of touching
    // Config.options.bar.* directly, so it transparently edits either the global
    // defaults or the selected screen's override.
    function barVal(path) {
        return Config.barOption(page.selectedScreen, path)
    }
    function setBarVal(path, value) {
        if (page.selectedScreen === "")
            Config.setNestedValue("bar." + path, value)
        else
            Config.setBarOption(page.selectedScreen, path, value)
    }

    ColumnLayout {
        id: mainLayout 
        Layout.fillWidth: true   
        Layout.fillHeight: true
        spacing: 20

        ContentSection {
            icon: "tune"
            shape: MaterialShape.Shape.Puffy
            visible: Hyprland.monitors.values.length > 1
            title: Translation.tr("Customize per screen")
            ContentSubsection {
                title: Translation.tr("Editing settings for")

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    text: page.selectedScreen === ""
                        ? Translation.tr("Changes below apply to every screen, except ones customized individually.")
                        : Translation.tr("Changes below only apply to this screen.")
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    RippleButtonWithIcon {
                        materialIcon: "public"
                        mainText: Translation.tr("Global (default)")
                        colBackground: page.selectedScreen === "" ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                        onClicked: page.selectedScreen = ""
                    }
                    Repeater {
                        model: Hyprland.monitors
                        delegate: RippleButtonWithIcon {
                            required property var modelData
                            materialIcon: "monitor"
                            mainText: modelData.name + (Config.screenHasBarOverrides(modelData.name) ? " •" : "")
                            colBackground: page.selectedScreen === modelData.name ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                            onClicked: page.selectedScreen = modelData.name
                        }
                    }
                }

                RippleButtonWithIcon {
                    visible: page.selectedScreen !== "" && Config.screenHasBarOverrides(page.selectedScreen)
                    materialIcon: "restart_alt"
                    mainText: Translation.tr("Reset this screen to global defaults")
                    onClicked: {
                        Config.options.bar.perScreenOverrides = Config.options.bar.perScreenOverrides.filter(e => e.screen !== page.selectedScreen)
                    }
                }
            }
        }

        ContentSection {
            icon: "monitor"
            shape: MaterialShape.Shape.ClamShell
            visible: Hyprland.monitors.values.length > 1
            title: Translation.tr("Screens")
            ContentSubsection {
                title: Translation.tr("Show bar on")

                ColumnLayout {
                    id: monitorsCol
                    Layout.fillWidth: true
                    spacing: 2

                    Rectangle {
                        id: allRow
                        Layout.fillWidth: true
                        implicitHeight: allSwitchItem.implicitHeight + 16 + 8
                        color: Appearance.colors.colLayer1
                        topLeftRadius: Appearance.rounding.normal
                        topRightRadius: Appearance.rounding.normal
                        bottomLeftRadius: Appearance.rounding.unsharpenmore
                        bottomRightRadius: Appearance.rounding.unsharpenmore

                        ConfigSwitch {
                            id: allSwitchItem
                            anchors { fill: parent; margins: 8 }
                            buttonIcon: "tv_displays"
                            text: Translation.tr("All")
                            onCheckedChanged: {
                                if (checked) Config.options.bar.screenList = []
                            }

                            Binding {
                                target: allSwitchItem
                                property: "checked"
                                value: Config.options.bar.screenList.length === 0
                                restoreMode: Binding.RestoreBinding
                            }
                        }
                    }

                    Repeater {
                        model: Hyprland.monitors
                        delegate: Rectangle {
                            id: monitorRow
                            required property var modelData
                            required property int index
                            readonly property bool isLast: index === Hyprland.monitors.values.length - 1

                            Layout.fillWidth: true
                            implicitHeight: switchItem.implicitHeight + 16 + 8
                            color: Appearance.colors.colLayer1
                            topLeftRadius:     Appearance.rounding.unsharpenmore
                            topRightRadius:    Appearance.rounding.unsharpenmore
                            bottomLeftRadius:  isLast ? Appearance.rounding.normal : Appearance.rounding.unsharpenmore
                            bottomRightRadius: isLast ? Appearance.rounding.normal : Appearance.rounding.unsharpenmore

                            ConfigSwitch {
                                id: switchItem
                                anchors { fill: parent; margins: 8 }
                                buttonIcon: "monitor"
                                text: monitorRow.modelData.name
                                onCheckedChanged: {
                                    const allNames = Hyprland.monitors.values.map(m => m.name)
                                    let list = Config.options.bar.screenList.length === 0 ? allNames.slice() : Config.options.bar.screenList.slice()
                                    if (checked) {
                                        if (!list.includes(monitorRow.modelData.name)) list.push(monitorRow.modelData.name)
                                    } else {
                                        list = list.filter(s => s !== monitorRow.modelData.name)
                                    }
                                    Config.options.bar.screenList = list.length === allNames.length ? [] : list
                                }

                                Binding {
                                    target: switchItem
                                    property: "checked"
                                    value: Config.options.bar.screenList.length === 0 || Config.options.bar.screenList.includes(monitorRow.modelData.name)
                                    restoreMode: Binding.RestoreBinding
                                }
                            }
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "splitscreen_add"
            shape: MaterialShape.Shape.Cookie6Sided
            title: Translation.tr("Bar layout")

            GroupedList {
                LayoutSection {
                    sectionTitle: page.barVal("vertical") ? Translation.tr("Top") : Translation.tr("Left")
                    layout: page.barVal("layouts.leftLayout")
                    availableWidgets: page.availableFor("left")
                    getWidgetName: page.getWidgetName
                    onUpdate: list => page.setBarVal("layouts.leftLayout", list)
                }

                LayoutSection {
                    sectionTitle: Translation.tr("Center")
                    layout: page.barVal("layouts.middleLayout")
                    availableWidgets: page.availableFor("middle")
                    getWidgetName: page.getWidgetName
                    onUpdate: list => page.setBarVal("layouts.middleLayout", list)
                }

                LayoutSection {
                    sectionTitle: page.barVal("vertical") ? Translation.tr("Bottom") : Translation.tr("Right")
                    layout: page.barVal("layouts.rightLayout")
                    availableWidgets: page.availableFor("right")
                    getWidgetName: page.getWidgetName
                    onUpdate: list => page.setBarVal("layouts.rightLayout", list)
                }
            }
        }

        ContentSection {
            icon: "pivot_table_chart"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Positioning & Styles")
            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Bar position")
                    icon: "swap_vert"
                    currentValue: (page.barVal("bottom") ? 1 : 0) | (page.barVal("vertical") ? 2 : 0)
                    onSelected: newValue => {
                        page.setBarVal("bottom", (newValue & 1) !== 0);

                        page.setBarVal("vertical", (newValue & 2) !== 0);
                    }
                    options: [
                        { displayName: Translation.tr("Top"),    icon: "arrow_upward",   value: 0 },
                        { displayName: Translation.tr("Left"),   icon: "arrow_back",     value: 2 },
                        { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: 1 },
                        { displayName: Translation.tr("Right"),  icon: "arrow_forward",  value: 3 }
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Bar style")
                    icon: "style"
                    currentValue: page.barVal("cornerStyle")
                    onSelected: newValue => { page.setBarVal("cornerStyle", newValue); }
                    options: [
                        { displayName: Translation.tr("Hug"),     icon: "line_curve", value: 0 },
                        { displayName: Translation.tr("Float"),   icon: "view_day",   value: 1 },
                        { displayName: Translation.tr("Islands"), icon: "crop_3_2",   value: 2 },
                        { displayName: Translation.tr("M3"), icon: "interests",   value: 3 },
                        { displayName: Translation.tr("Panel"), icon: "toolbar",   value: 4 }
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Group style")
                    icon: "tab_group"
                    currentValue: page.barVal("borderless")
                    onSelected: newValue => { page.setBarVal("borderless", newValue); }
                    options: [
                        { displayName: Translation.tr(""),          icon: "block",          value: "transparent" },
                        { displayName: Translation.tr("Pills"),     icon: "pill",           value: "pills" },
                        { displayName: Translation.tr("Separated"), icon: "view_column_2",  value: "separated" },
                        { displayName: Translation.tr("Segmented"), icon: "tablet",           value: "segmented" },
                    ]
                }
                ColorSelectionArray {
                    icon: "brush"
                    text: Translation.tr("Group Color")
                    options: ["primaryContainer", "secondaryContainer", "tertiaryContainer", "layer1", "layer0"]
                    currentValue: page.barVal("groupColor")
                    onSelected: newValue => {
                        page.setBarVal("groupColor", newValue)
                    }
                }
                ConfigRow{
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "variable_insert"
                        text: Translation.tr("Show Background")
                        enabled: page.barVal("cornerStyle") === 0 || page.barVal("cornerStyle") === 1
                        checked: page.barVal("showBackground")
                        onCheckedChanged: { page.setBarVal("showBackground", checked); }
                    }
                    ConfigSelectionArray {
                        text: Translation.tr("Autohide")
                        icon: "preview_off"
                        currentValue: page.barVal("autoHide.enable")
                        onSelected: newValue => { page.setBarVal("autoHide.enable", newValue); }
                        options: [
                            { displayName: Translation.tr("No"),  icon: "close", value: false },
                            { displayName: Translation.tr("Yes"), icon: "check", value: true }
                        ]
                    }
                }
                ConfigSwitch {
                    buttonIcon: "expand"
                    enabled: page.barVal("showFrame")
                    text: Translation.tr("Overlap windows when center-only")
                    checked: page.barVal("centerOnlyReserveFrame")
                    onCheckedChanged: { page.setBarVal("centerOnlyReserveFrame", checked); }
                }
                ConfigRow {
                    ConfigSwitch {
                        buttonIcon: "panorama_wide_angle"
                        text: Translation.tr("Show Frame")
                        checked: page.barVal("showFrame")

                        property bool switchReady: false
                        Component.onCompleted: Qt.callLater(() => switchReady = true)

                        onCheckedChanged: {
                            if (switchReady && checked) {
                                GlobalStates.refreshBar();
                            }
                            page.setBarVal("showFrame", checked);
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "colors"
                        enabled: page.barVal("showFrame")
                        text: Translation.tr("Follow Frame Color")
                        checked: page.barVal("followFrameColor")
                        onCheckedChanged: { page.setBarVal("followFrameColor", checked); }
                    }
                }
                ConfigSpinBox {
                    icon: "eraser_size_1"
                    text: Translation.tr("Frame thickness")
                    value: page.barVal("frameThickness")
                    from: 2
                    to: 10
                    stepSize: 1
                    onValueChanged: {
                        page.setBarVal("frameThickness", value);
                    }
                }
                ColorSelectionArray {
                    icon: "imagesearch_roller"
                    text: Translation.tr("Frame Color")
                    options: ["primaryContainer", "secondaryContainer", "tertiaryContainer", "layer0", "black"] // sorry only solid colors transparency looks bad
                    currentValue: page.barVal("frameColor")
                    onSelected: newValue => {
                        page.setBarVal("frameColor", newValue)
                    }
                }
            }
        }

        ContentSection {
            icon: "nest_wifi_pro"
            shape: MaterialShape.Shape.Cookie4Sided
            title: Translation.tr("Dynamic Island")

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Left widget")
                    icon: "right_panel_open"
                    currentValue: page.barVal("dynamicIsland.leftWidget")
                    onSelected: newValue => { page.setBarVal("dynamicIsland.leftWidget", newValue); }
                    options: [
                        { displayName: Translation.tr(""),    icon: "block",        value: "none" },
                        { displayName: Translation.tr("Clock"),   icon: "schedule",     value: "clockWidget" },
                        { displayName: Translation.tr("Weather"), icon: "partly_cloudy_day", value: "weatherBar" },
                        { displayName: Translation.tr("Updates"), icon: "update",       value: "updatesCount" }
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Right widget")
                    icon: "left_panel_open"
                    currentValue: page.barVal("dynamicIsland.rightWidget")
                    onSelected: newValue => { page.setBarVal("dynamicIsland.rightWidget", newValue); }
                    options: [
                        { displayName: Translation.tr(""),         icon: "block",        value: "none" },
                        { displayName: Translation.tr("System icons"), icon: "settings",     value: "systemIcons" },
                        { displayName: Translation.tr("Tray"),  icon: "apps",         value: "sysTray" },
                        { displayName: Translation.tr("Util buttons"), icon: "widgets",   value: "utilButtons" }
                    ]
                }
            }

            ContentSubsection {
                Layout.topMargin: 10
                title: Translation.tr("Media")
                GroupedList {
                    ConfigSelectionArray {
                        text: Translation.tr("Visualizer style")
                        icon: "graphic_eq"
                        currentValue: page.barVal("dynamicIsland.visualizerStyle")
                        onSelected: newValue => { page.setBarVal("dynamicIsland.visualizerStyle", newValue); }
                        options: [
                            { displayName: Translation.tr(""),      icon: "block",       value: "none" },
                            { displayName: Translation.tr("Dots"),  icon: "steppers",     value: "dots" },
                            { displayName: Translation.tr("Wave"),  icon: "ssid_chart",   value: "wave" }
                        ]
                    }
                    ConfigSwitch {
                        buttonIcon: "play_circle"
                        text: Translation.tr("Show media controls")
                        checked: page.barVal("dynamicIsland.showMediaControls")
                        onCheckedChanged: { page.setBarVal("dynamicIsland.showMediaControls", checked); }
                    }
                }
            }
        }

        ContentSection {
            icon: "notifications"
            shape: MaterialShape.Shape.Bun
            title: Translation.tr("Notifications")
            
            GroupedList {
                ConfigComboBox { // too much items for configselectionarray - I know it's not the best place to put this but I can change it later
                    text: Translation.tr("Popup position")
                    buttonIcon: "my_location" 
                    currentValue: Config.options.notifications.position
                    fieldWidth: 50
                    onSelected: newValue => {
                        Config.options.notifications.position = newValue;
                    }
                    model: [
                        {
                            displayName: Translation.tr("Top left"),
                            value: "top_left"
                        },
                        {
                            displayName: Translation.tr("Top center"),
                            value: "top_center"
                        },
                        {
                            displayName: Translation.tr("Top right"),
                            value: "top_right"
                        },
                        {
                            displayName: Translation.tr("Bottom left"),
                            value: "bottom_left"
                        },
                        {
                            displayName: Translation.tr("Bottom center"),
                            value: "bottom_center"
                        },
                        {
                            displayName: Translation.tr("Bottom right"),
                            value: "bottom_right"
                        }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "counter_2"
                    text: Translation.tr("Unread indicator: show count")
                    checked: page.barVal("indicators.notifications.showUnreadCount")
                    onCheckedChanged: { page.setBarVal("indicators.notifications.showUnreadCount", checked); }
                }
                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Timeout duration (if not defined by notification) (ms)")
                    value: Config.options.notifications.timeout
                    from: 1000
                    to: 60000
                    stepSize: 1000
                    onValueChanged: {
                        Config.options.notifications.timeout = value;
                    }
                }
            }
        }

        ContentSection {
            shape: MaterialShape.Shape.Square
            icon: "inbox_customize"
            title: Translation.tr("Tray")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "keep"; text: Translation.tr("Make icons pinned by default")
                    checked: Config.options.tray.invertPinnedItems
                    onCheckedChanged: { Config.options.tray.invertPinnedItems = checked; }
                }
                ConfigSwitch {
                    buttonIcon: "colors"; text: Translation.tr("Tint icons")
                    checked: Config.options.tray.monochromeIcons
                    onCheckedChanged: { Config.options.tray.monochromeIcons = checked; }
                }
            }
        }

        ContentSection {
            icon: "vertical_align_center"
            shape: MaterialShape.Shape.Diamond
            title: Translation.tr("Divider")

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Style")
                    icon: "style"
                    currentValue: page.barVal("divider.style")
                    onSelected: newValue => { page.setBarVal("divider.style", newValue); }
                    options: [
                        { displayName: Translation.tr("Line"),  icon: "more_vert",       value: "rect" },
                        { displayName: Translation.tr("Dot"),   icon: "fiber_manual_record", value: "dot" },
                        { displayName: Translation.tr("Space"), icon: "space_bar",       value: "space" }
                    ]
                }
                ConfigSpinBox {
                    icon: "width"
                    enabled: page.barVal("divider.style") === "space"
                    text: Translation.tr("Space width (px)")
                    value: page.barVal("divider.spacing")
                    from: 4
                    to: 400
                    stepSize: 2
                    onValueChanged: {
                        page.setBarVal("divider.spacing", value);
                    }
                }
            }
        }

        ContentSection {
            icon: "buttons_alt"
            shape: MaterialShape.Shape.SoftBurst
            title: Translation.tr("Utility buttons")

            GroupedList {
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "screenshot_region"
                        text: Translation.tr("Screen snip")
                        checked: page.barVal("utilButtons.showScreenSnip")
                        onCheckedChanged: { page.setBarVal("utilButtons.showScreenSnip", checked) }
                    }
                    ConfigSwitch {
                        buttonIcon: "colorize"
                        text: Translation.tr("Color picker")
                        checked: page.barVal("utilButtons.showColorPicker")
                        onCheckedChanged: { page.setBarVal("utilButtons.showColorPicker", checked) }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "keyboard"
                        text: Translation.tr("Keyboard toggle")
                        checked: page.barVal("utilButtons.showKeyboardToggle")
                        onCheckedChanged: { page.setBarVal("utilButtons.showKeyboardToggle", checked) }
                    }
                    ConfigSwitch {
                        buttonIcon: "mic"
                        text: Translation.tr("Mic toggle")
                        checked: page.barVal("utilButtons.showMicToggle")
                        onCheckedChanged: { page.setBarVal("utilButtons.showMicToggle", checked) }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "dark_mode"
                        text: Translation.tr("Dark/Light toggle")
                        checked: page.barVal("utilButtons.showDarkModeToggle")
                        onCheckedChanged: { page.setBarVal("utilButtons.showDarkModeToggle", checked) }
                    }
                    ConfigSwitch {
                        buttonIcon: "speed"
                        text: Translation.tr("Performance Profile")
                        checked: page.barVal("utilButtons.showPerformanceProfileToggle")
                        onCheckedChanged: { page.setBarVal("utilButtons.showPerformanceProfileToggle", checked) }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "screen_record"
                        text: Translation.tr("Record Screen")
                        checked: page.barVal("utilButtons.showScreenRecord")
                        onCheckedChanged: { page.setBarVal("utilButtons.showScreenRecord", checked) }
                    }
                }
            }
        }

        ContentSection {
            shape: MaterialShape.Shape.Cookie12Sided
            icon: "steppers"; title: Translation.tr("Workspaces")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "counter_1"; text: Translation.tr("Always show numbers")
                    checked: page.barVal("workspaces.alwaysShowNumbers")
                    onCheckedChanged: { page.setBarVal("workspaces.alwaysShowNumbers", checked); }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Numbers style")
                    icon: "looks_3"
                    currentValue: JSON.stringify(page.barVal("workspaces.numberMap"))
                    onSelected: newValue => {
                        page.setBarVal("workspaces.numberMap", JSON.parse(newValue))
                    }
                    options: [
                        { displayName: Translation.tr("Normal"),    icon: "timer_10",        value: '[]' },
                        { displayName: Translation.tr("Han chars"), icon: "glyphs",          value: '["一","二","三","四","五","六","七","八","九","十","十一","十二","十三","十四","十五","十六","十七","十八","十九","二十"]' },
                        { displayName: Translation.tr("Roman"),     icon: "account_balance", value: '["I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII","XIII","XIV","XV","XVI","XVII","XVIII","XIX","XX"]' }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "award_star"; text: Translation.tr("Show app icons")
                    checked: page.barVal("workspaces.showAppIcons")
                    onCheckedChanged: { page.setBarVal("workspaces.showAppIcons", checked); }
                }
                ConfigSpinBox {
                    icon: "view_column"; text: Translation.tr("Workspaces shown")
                    value: page.barVal("workspaces.shown")
                    from: 1; to: 30
                    onValueChanged: { page.setBarVal("workspaces.shown", value); }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Indicator style")
                    icon: "page_control"
                    currentValue: page.barVal("workspaces.indicatorStyle") ?? "icon"
                    onSelected: newValue => {
                        page.setBarVal("workspaces.indicatorStyle", newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Dots"),  icon: "radio_button_checked",   value: "dot" },
                        { displayName: Translation.tr("Icons"), icon: "interests",              value: "icon" },
                    ]
                }
            }
        }

        ContentSection {
            icon: "empty_dashboard"
            shape: MaterialShape.Shape.Burst
            title: Translation.tr("Resources")

            GroupedList {
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "planner_review"
                        text: Translation.tr("CPU")
                        checked: page.barVal("resources.alwaysShowCpu")
                        onCheckedChanged: { page.setBarVal("resources.alwaysShowCpu", checked) }
                    }
                    ConfigSwitch {
                        buttonIcon: "thermostat"
                        text: Translation.tr("CPU Temperature")
                        checked: page.barVal("resources.alwaysShowCpuTemp")
                        onCheckedChanged: { page.setBarVal("resources.alwaysShowCpuTemp", checked) }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "memory"
                        text: Translation.tr("RAM")
                        checked: page.barVal("resources.alwaysShowRam")
                        onCheckedChanged: { page.setBarVal("resources.alwaysShowRam", checked) }
                    }
                    ConfigSwitch {
                        buttonIcon: "storage"
                        text: Translation.tr("Disk")
                        checked: page.barVal("resources.alwaysShowDisk")
                        onCheckedChanged: { page.setBarVal("resources.alwaysShowDisk", checked) }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "swap_horiz"
                        text: Translation.tr("Swap")
                        checked: page.barVal("resources.alwaysShowSwap")
                        onCheckedChanged: { page.setBarVal("resources.alwaysShowSwap", checked) }
                    }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Style")
                    icon: "style"
                    currentValue: page.barVal("resources.style")
                    onSelected: newValue => { page.setBarVal("resources.style", newValue); }
                    options: [
                        { displayName: Translation.tr("Filled"),    icon: "incomplete_circle",  value: "filled" },
                        { displayName: Translation.tr("Outline"),   icon: "circles",            value: "outline" }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "decimal_increase"; text: Translation.tr("Show Percentage")
                    checked: page.barVal("resources.showValue")
                    onCheckedChanged: { page.setBarVal("resources.showValue", checked); }
                }
                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Polling interval (ms)")
                    value: Config.options.resources.updateInterval
                    from: 100
                    to: 10000
                    stepSize: 100
                    onValueChanged: {
                        Config.options.resources.updateInterval = value;
                    }
                }
            }
        }

        ContentSection {
            icon: "music_note"
            shape: MaterialShape.Shape.Sunny
            title: Translation.tr("Media")

            GroupedList {
                ConfigTextArea {
                    id: preferredPlayerField
                    Layout.fillWidth: true
                    buttonIcon: "play_circle"
                    text: Translation.tr("Preferred Player")
                    placeholderText: Translation.tr("e.g. spotify, firefox")
                    value: page.barVal("media.preferredPlayer")
                    onValueChanged: {
                        mediaDebounceTimer.restart();
                    }

                    Timer {
                        id: mediaDebounceTimer
                        interval: 600
                        repeat: false
                        onTriggered: {
                            page.setBarVal("media.preferredPlayer", preferredPlayerField.value);
                        }
                    }
                }
                ConfigSwitch {
                    buttonIcon: "keep"; text: Translation.tr("Pin media controls")
                    checked: page.barVal("media.alwaysVisible")
                    onCheckedChanged: { page.setBarVal("media.alwaysVisible", checked); }
                }
                ConfigSwitch {
                    buttonIcon: "titlecase"; text: Translation.tr("Show only title")
                    checked: page.barVal("media.onlyTitle")
                    onCheckedChanged: { page.setBarVal("media.onlyTitle", checked); }
                }
                ConfigSpinBox {
                    icon: "width"
                    text: Translation.tr("Max media width")
                    value: page.barVal("media.maxWidth")
                    from: 100
                    to: 500
                    stepSize: 10
                    onValueChanged: {
                        page.setBarVal("media.maxWidth", value);
                    }
                }
            }
        }

        ContentSection {
            shape: MaterialShape.Shape.Puffy
            icon: "tooltip"; title: Translation.tr("Tooltips")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "visibility"; text: Translation.tr("Enable")
                    checked: page.barVal("tooltips.enable")
                    onCheckedChanged: { page.setBarVal("tooltips.enable", checked); }
                }
                ConfigSwitch {
                    buttonIcon: "ads_click"; text: Translation.tr("Click to show")
                    checked: page.barVal("tooltips.clickToShow")
                    onCheckedChanged: { page.setBarVal("tooltips.clickToShow", checked); }
                    enabled: page.barVal("tooltips.enable")
                }
            }
        }
    }
}
