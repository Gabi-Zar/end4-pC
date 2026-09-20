pragma Singleton

import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."

Singleton {
    id: root

    property string query: ""

    function ensurePrefix(prefix) {
        if ([Config.options.search.prefix.action, Config.options.search.prefix.app, Config.options.search.prefix.clipboard, Config.options.search.prefix.emojis, Config.options.search.prefix.symbols, Config.options.search.prefix.math, Config.options.search.prefix.shellCommand, Config.options.search.prefix.webSearch, Config.options.search.prefix.file,].some(i => root.query.startsWith(i))) {
            root.query = prefix + root.query.slice(1);
        } else {
            root.query = prefix + root.query;
        }
    }
    
    Process {
        id: keywordHarvester
        property var pendingPages: []
        property string currentPageName: ""
        
        function startHarvesting() {
            root.settingsKeywordsCache = {}; 
            pendingPages = root.settingsIndex.slice();
            next();
        }

        function next() {
            if (pendingPages.length === 0) {
                return;
            }
            
            let currentPage = pendingPages.shift();
            let fullPath = FileUtils.trimFileProtocol(
                Quickshell.shellPath("modules/ii/settings/pages/" + currentPage.path)
            )

            let rawCommand = "grep -oP \"title:\\s*Translation.tr\\(['\\\"].*?['\\\"]\\)\" " + fullPath + " | sed -E \"s/title:\\s*Translation.tr\\(['\\\"](.*)['\\\"]\\)/\\1/g\" | tr '\\n' ' '";
            
            command = ["bash", "-c", rawCommand];
            
            keywordHarvester.currentPageName = currentPage.page;
            running = true;
        }

        onExited: (exitCode, exitStatus) => {
            keywordHarvester.next();
        }

        stdout: SplitParser {
            onRead: data => {
                let cache = root.settingsKeywordsCache;
                cache[keywordHarvester.currentPageName] = (cache[keywordHarvester.currentPageName] || "") + " " + data;
                root.settingsKeywordsCache = cache;
            }
        }
    }

    Component.onCompleted: {
        keywordHarvester.startHarvesting();
    }


    // https://specifications.freedesktop.org/menu/latest/category-registry.html
    property list<string> mainRegisteredCategories: ["AudioVideo", "Development", "Education", "Game", "Graphics", "Network", "Office", "Science", "Settings", "System", "Utility"]
    property list<string> appCategories: DesktopEntries.applications.values.reduce((acc, entry) => {
        for (const category of entry.categories) {
            if (!acc.includes(category) && mainRegisteredCategories.includes(category)) {
                acc.push(category);
            }
        }
        return acc;
    }, []).sort()

    property var settingsKeywordsCache: ({})

    property var settingsIndex: [
        { page: "General",   path: "GeneralConfig.qml" },
        { page: "Bar",       path: "BarConfig.qml" },
        { page: "Desktop",   path: "BackgroundConfig.qml" },
        { page: "Interface", path: "InterfaceConfig.qml" },
        { page: "Services",  path: "ServicesConfig.qml" },
        { page: "Hyprland",  path: "HyprlandConfig.qml" },
        { page: "About",     path: "About.qml" },
        { page: "Quick",     path: "QuickConfig.qml" },
    ]

    // Load user action scripts from ~/.config/illogical-impulse/actions/
    // Uses FolderListModel to auto-reload when scripts are added/removed
    property var userActionScripts: {
        const actions = [];
        for (let i = 0; i < userActionsFolder.count; i++) {
            const fileName = userActionsFolder.get(i, "fileName");
            const filePath = userActionsFolder.get(i, "filePath");
            if (fileName && filePath) {
                const actionName = fileName.replace(/\.[^/.]+$/, ""); // strip extension
                actions.push({
                    action: actionName,
                    execute: ((path) => (args) => {
                        Quickshell.execDetached([path, ...(args ? args.split(" ") : [])]);
                    })(FileUtils.trimFileProtocol(filePath.toString()))
                });
            }
        }
        return actions;
    }

    FolderListModel {
        id: userActionsFolder
        folder: Qt.resolvedUrl(Directories.userActions)
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
    }

    property var searchActions: [
        {
            action: "accentcolor",
            execute: args => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch", "--color", ...(args != '' ? [`${args}`] : [])]);
            }
        },
        {
            action: "dark",
            execute: () => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "dark", "--noswitch"]);
            }
        },
        {
            action: "konachanwallpaper",
            execute: () => {
                Quickshell.execDetached([Quickshell.shellPath("scripts/colors/random/random_konachan_wall.sh")]);
            }
        },
        {
            action: "light",
            execute: () => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "light", "--noswitch"]);
            }
        },
        {
            action: "superpaste",
            execute: args => {
                if (!/^(\d+)/.test(args.trim())) {
                    // Invalid if doesn't start with numbers
                    Quickshell.execDetached(["notify-send", Translation.tr("Superpaste"), Translation.tr("Usage: <tt>%1superpaste NUM_OF_ENTRIES[i]</tt>\nSupply <tt>i</tt> when you want images\nExamples:\n<tt>%1superpaste 4i</tt> for the last 4 images\n<tt>%1superpaste 7</tt> for the last 7 entries").arg(Config.options.search.prefix.action), "-a", "Shell"]);
                    return;
                }
                const syntaxMatch = /^(?:(\d+)(i)?)/.exec(args.trim());
                const count = syntaxMatch[1] ? parseInt(syntaxMatch[1]) : 1;
                const isImage = !!syntaxMatch[2];
                Cliphist.superpaste(count, isImage);
            }
        },
        {
            action: "todo",
            execute: args => {
                Todo.addTask(args);
            }
        },
        {
            action: "wallpaper",
            execute: () => {
                Hyprland.dispatch(`hl.dsp.global("quickshell:wallpaperSelectorToggle")`)
            }
        },
        {
            action: "wipeclipboard",
            execute: () => {
                Quickshell.execDetached(["bash", "-c", "rm -f ~/.cache/cliphist/db"]);
            }
        },
        {
            action: "unsplash",
            execute: args => {
                if (!args || args.trim().length === 0) {
                    Quickshell.execDetached(["notify-send", "Unsplash", Translation.tr("Usage: /unsplash YOUR_API_KEY"), "-a", "Shell"]);
                    return;
                }
                KeyringStorage.setNestedField(["apiKeys", "unsplash"], args.trim());
                Quickshell.execDetached(["notify-send", "Unsplash", Translation.tr("API key saved!"), "-a", "Shell"]);
            }
        },
        {
            action: "wallhaven",
            execute: args => {
                if (!args || args.trim().length === 0) {
                    Quickshell.execDetached(["notify-send", "Wallhaven", Translation.tr("Usage: /wallhaven YOUR_API_KEY"), "-a", "Shell"]);
                    return;
                }
                KeyringStorage.setNestedField(["apiKeys", "wallhaven"], args.trim());
                Quickshell.execDetached(["notify-send", "Wallhaven", Translation.tr("API key saved!"), "-a", "Shell"]);
            }
        },
        {
            action: "pexels",
            execute: args => {
                if (!args || args.trim().length === 0) {
                    Quickshell.execDetached(["notify-send", "Pexels", Translation.tr("Usage: /pexels YOUR_API_KEY"), "-a", "Shell"]);
                    return;
                }
                KeyringStorage.setNestedField(["apiKeys", "pexels"], args.trim());
                Quickshell.execDetached(["notify-send", "Pexels", Translation.tr("API key saved!"), "-a", "Shell"]);
            }
        },
        {
            action: "openweather",
            execute: args => {
                if (!args || args.trim().length === 0) {
                    Quickshell.execDetached(["notify-send", "OpenWeather", Translation.tr("Usage: /openweather YOUR_API_KEY"), "-a", "Shell"]);
                    return;
                }
                KeyringStorage.setNestedField(["apiKeys", "openweather"], args.trim());
                Quickshell.execDetached(["notify-send", "OpenWeather", Translation.tr("API key saved!"), "-a", "Shell"]);
                Weather.getData();
            }
        },
    ]

    // Combined built-in and user actions
    property var allActions: searchActions.concat(userActionScripts)

    property string mathResult: ""
    property bool clipboardWorkSafetyActive: {
        const enabled = Config.options.workSafety.enable.clipboard;
        const sensitiveNetwork = (StringUtils.stringListContainsSubstring(Network.networkName.toLowerCase(), Config.options.workSafety.triggerCondition.networkNameKeywords));
        return enabled && sensitiveNetwork;
    }

    function containsUnsafeLink(entry) {
        if (entry == undefined)
            return false;
        const unsafeKeywords = Config.options.workSafety.triggerCondition.linkKeywords;
        return StringUtils.stringListContainsSubstring(entry.toLowerCase(), unsafeKeywords);
    }

    Timer {
        id: nonAppResultsTimer
        interval: Config.options.search.nonAppResultDelay
        onTriggered: {
            let expr = root.query;
            if (expr.startsWith(Config.options.search.prefix.math)) {
                expr = expr.slice(Config.options.search.prefix.math.length);
            }
            mathProc.calculateExpression(expr);
        }
    }

    Process {
        id: mathProc
        property list<string> baseCommand: ["qalc", "-t"]
        function calculateExpression(expression) {
            mathProc.running = false;
            mathProc.command = baseCommand.concat(expression);
            mathProc.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                root.mathResult = data;
            }
        }
    }

    ////////////////// File / folder search (fd) //////////////////

    // type:xxx maps to one of these groups when it matches, otherwise xxx is used as a literal extension
    property var fileTypeGroups: ({
        pdf: ["pdf"],
        doc: ["doc", "docx", "odt", "rtf", "txt", "md"],
        sheet: ["xls", "xlsx", "ods", "csv"],
        slide: ["ppt", "pptx", "odp"],
        image: ["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp"],
        video: ["mp4", "mkv", "webm", "mov", "avi"],
        audio: ["mp3", "flac", "wav", "ogg", "m4a"],
        archive: ["zip", "tar", "gz", "7z", "rar", "xz"],
    })

    // Latest results from fd, one raw path per line (directories end with "/")
    property var fileSearchResults: []
    // The raw search text (still containing any type:/exclude: keywords) that
    // fileSearchResults currently corresponds to. Used to avoid re-triggering fd every
    // time `results` re-evaluates because fileSearchResults itself just changed.
    property string lastFileSearchQuery: ""

    // type:folder / type:dir / type:directory -> directories only (-t d)
    // type:file                               -> files only (-t f)
    // These are mutually exclusive with the extension groups below (folders have no extension)
    property var fileTypeAliases: ({
        folder: "d", dir: "d", directory: "d",
        file: "f",
    })

    // Opens `path` (a folder, or a file's parent folder) in Config.options.apps.fileManager
    // if set, otherwise falls back to xdg-open. Bypassing xdg-open is useful when the
    // system has no correct inode/directory mime association (common on bare Hyprland
    // setups), which otherwise makes xdg-open fall back to something unexpected.
    function revealInFileManager(path) {
        const fm = (Config.options.apps.fileManager ?? "").trim();
        if (fm.length > 0) {
            Quickshell.execDetached(fm.split(/\s+/).concat([path]));
        } else {
            Quickshell.execDetached(["xdg-open", path]);
        }
    }

    // Parses "type:xxx" and "exclude:xxx" keywords out of the query and turns
    // the rest into an argv list for fd. Both keywords can be repeated.
    function buildFdArgs(rawQuery) {
        let text = rawQuery;
        let extensions = [];
        let excludes = [];
        let typeFilter = null; // "d" (folders only) or "f" (files only), via type:folder / type:file

        text = text.replace(/\btype:(\S+)/gi, (match, value) => {
            const key = value.toLowerCase();
            if (root.fileTypeAliases[key]) {
                typeFilter = root.fileTypeAliases[key];
            } else {
                extensions = extensions.concat(root.fileTypeGroups[key] ?? [key]);
            }
            return " ";
        });
        text = text.replace(/\bexclude:(\S+)/gi, (match, value) => {
            excludes.push(value);
            return " ";
        });
        text = text.trim();

        const roots = Config.options.search.fileSearchPaths.length > 0
            ? Config.options.search.fileSearchPaths
            : [FileUtils.trimFileProtocol(Directories.home)];

        let args = ["--color", "never", "--max-results", "30"];
        // Fixed-strings = plain substring search. Only makes sense when there's
        // actual text left to search for; an empty --fixed-strings pattern
        // behaves differently from an empty regex pattern (which matches everything).
        if (text.length > 0)
            args.push("--fixed-strings");
        if (typeFilter)
            args = args.concat(["--type", typeFilter]);
        // Folders have no extension, so type:folder + type:pdf together would
        // just match nothing with fd - skip the (meaningless) extension filter in that case
        if (typeFilter !== "d") {
            for (const ext of extensions)
                args = args.concat(["--extension", ext]);
        }
        for (const excl of excludes)
            args = args.concat(["--exclude", `*${excl}*`]);
        args.push("--"); // guard against a search term that looks like a flag
        args.push(text); // "" here means "match everything" (see above)
        return args.concat(roots);
    }

    Timer {
        id: fileSearchTimer
        interval: Config.options.search.fileResultDelay
        onTriggered: {
            if (!root.query.startsWith(Config.options.search.prefix.file)) return;
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.file);
            fileSearchProc.search(root.buildFdArgs(searchString));
        }
    }

    Process {
        id: fileSearchProc
        property var lines: []
        function search(args) {
            fileSearchProc.running = false;
            fileSearchProc.lines = [];
            fileSearchProc.command = ["fd"].concat(args);
            fileSearchProc.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                if (data.length > 0)
                    fileSearchProc.lines.push(data);
            }
        }
        onExited: (exitCode, exitStatus) => {
            // Batched into a single property write so `results` only recomputes once per search
            root.fileSearchResults = fileSearchProc.lines.slice();
        }
    }

    property list<var> results: {
        // Search results are handled here
        ////////////////// Skip? //////////////////
        if (root.query == "")
            return [];

        ///////////// Special cases ///////////////
        if (root.query.startsWith(Config.options.search.prefix.clipboard)) {
            // Clipboard
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.clipboard);
            return Cliphist.fuzzyQuery(searchString).map((entry, index, array) => {
                const mightBlurImage = Cliphist.entryIsImage(entry) && root.clipboardWorkSafetyActive;
                let shouldBlurImage = mightBlurImage;
                if (mightBlurImage) {
                    shouldBlurImage = shouldBlurImage && (root.containsUnsafeLink(array[index - 1]) || root.containsUnsafeLink(array[index + 1]));
                }
                const type = `#${entry.match(/^\s*(\S+)/)?.[1] || ""}`;
                return resultComp.createObject(null, {
                    rawValue: entry,
                    name: StringUtils.cleanCliphistEntry(entry),
                    verb: "",
                    type: type,
                    execute: () => {
                        Cliphist.copy(entry);
                    },
                    actions: [resultComp.createObject(null, {
                            name: Translation.tr("Copy"),
                            iconName: "content_copy",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                Cliphist.copy(entry);
                            }
                        }), resultComp.createObject(null, {
                            name: Translation.tr("Delete"),
                            iconName: "delete",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                Cliphist.deleteEntry(entry);
                            }
                        })],
                    blurImage: shouldBlurImage
                });
            }).filter(Boolean);
        } else if (root.query.startsWith(Config.options.search.prefix.emojis)) {
            // Emojis
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.emojis);
            return Emojis.fuzzyQuery(searchString).map(entry => {
                const emoji = entry.match(/^\s*(\S+)/)?.[1] || "";
                return resultComp.createObject(null, {
                    rawValue: entry,
                    name: entry.replace(/^\s*\S+\s+/, ""),
                    iconName: emoji,
                    iconType: LauncherSearchResult.IconType.Text,
                    verb: Translation.tr("Copy"),
                    type: Translation.tr("Emoji"),
                    execute: () => {
                        Quickshell.clipboardText = entry.match(/^\s*(\S+)/)?.[1];
                    }
                });
            }).filter(Boolean);
        } else if (root.query.startsWith(Config.options.search.prefix.keybinds ?? "<")) {
            // Keybinds
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.keybinds ?? "<");
            const flatBinds = (function flatten(node) {
                let result = [...(node.keybinds ?? [])];
                for (const child of (node.children ?? [])) {
                    result = result.concat(flatten(child));
                }
                return result;
            })(HyprlandKeybinds.keybinds);

            return flatBinds.filter(bind => {
                if (!bind.comment) return false;
                if (searchString.length === 0) return true;
                return bind.comment.toLowerCase().includes(searchString.toLowerCase())
                    || bind.key.toLowerCase().includes(searchString.toLowerCase());
            }).map(bind => {
                const modsStr = bind.mods.join(" + ");
                const keyStr  = modsStr.length > 0 ? `${modsStr} + ${bind.key}` : bind.key;
                return resultComp.createObject(null, {
                    name: bind.comment,
                    iconName: "keyboard",
                    iconType: LauncherSearchResult.IconType.Material,
                    verb: keyStr,
                    type: Translation.tr("Keybind"),
                    comment: keyStr,
                    execute: () => {
                        Quickshell.clipboardText = keyStr;
                    }
                });
            }).filter(Boolean);
        } else if (root.query.startsWith(Config.options.search.prefix.file)) {
            // Files & folders (fd), supports "type:pdf" and "exclude:name" keywords
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.file);

            if (searchString.trim().length === 0) {
                // Bare "!" with nothing typed yet: don't dump the whole home directory
                root.lastFileSearchQuery = "";
                if (root.fileSearchResults.length > 0)
                    root.fileSearchResults = [];
                return [];
            }

            // Only (re)trigger a search when the text actually changed. Without this
            // guard, fresh results landing in fileSearchResults would themselves
            // cause `results` to re-evaluate, which would restart the timer again,
            // forever, even with no new keystroke.
            if (searchString !== root.lastFileSearchQuery) {
                root.lastFileSearchQuery = searchString;
                fileSearchTimer.restart();
            }

            return root.fileSearchResults.map(rawPath => {
                const isDir = rawPath.endsWith("/");
                const cleanPath = isDir ? rawPath.slice(0, -1) : rawPath;
                const parentPath = FileUtils.parentDirectory(cleanPath);
                return resultComp.createObject(null, {
                    name: FileUtils.fileNameForPath(cleanPath),
                    comment: cleanPath,
                    type: isDir ? Translation.tr("Folder") : Translation.tr("File"),
                    iconName: isDir ? "folder" : "description",
                    iconType: LauncherSearchResult.IconType.Material,
                    verb: Translation.tr("Open"),
                    execute: () => {
                        if (isDir)
                            root.revealInFileManager(cleanPath);
                        else
                            Quickshell.execDetached(["xdg-open", cleanPath]);
                    },
                    actions: [resultComp.createObject(null, {
                        name: Translation.tr("Show in file manager"),
                        iconName: "folder_open",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            root.revealInFileManager(parentPath);
                        }
                    })]
                });
            }).filter(Boolean);
        } else if (root.query.startsWith(Config.options.search.prefix.symbols)) {
            // Material Symbols
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.symbols);
            return MaterialSymbolsSearch.fuzzyQuery(searchString).map(entry => {
                const tabIdx = entry.indexOf("\t");
                const symName = tabIdx >= 0 ? entry.slice(0, tabIdx) : entry;
                const symTags = tabIdx >= 0 ? entry.slice(tabIdx + 1) : "";
                return resultComp.createObject(null, {
                    rawValue: entry,
                    name: symName,
                    iconName: symName,
                    iconType: LauncherSearchResult.IconType.Material,
                    verb: Translation.tr("Copy"),
                    type: Translation.tr("Symbol"),
                    comment: symTags,
                    execute: () => {
                        Quickshell.clipboardText = symName;
                    }
                });
            }).filter(Boolean);
        }

        ////////////////// Init ///////////////////
        nonAppResultsTimer.restart();
        const mathResultObject = resultComp.createObject(null, {
            name: root.mathResult,
            verb: Translation.tr("Copy"),
            type: Translation.tr("Math result"),
            fontType: LauncherSearchResult.FontType.Monospace,
            iconName: 'calculate',
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                Quickshell.clipboardText = root.mathResult;
            }
        });
        const appResultObjects = AppSearch.fuzzyQuery(StringUtils.cleanPrefix(root.query, Config.options.search.prefix.app)).map(entry => {
            return resultComp.createObject(null, {
                type: Translation.tr("App"),
                id: entry.id,
                name: entry.name,
                iconName: entry.icon,
                iconType: LauncherSearchResult.IconType.System,
                verb: Translation.tr("Open"),
                execute: () => {
                    if (!entry.runInTerminal)
                        entry.execute();
                    else {
                        // Probably needs more proper escaping, but this will do for now
                        Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(entry.command.join(' '))}'`]);
                    }
                },
                comment: entry.comment,
                runInTerminal: entry.runInTerminal,
                genericName: entry.genericName,
                keywords: entry.keywords,
                actions: entry.actions.map(action => {
                    return resultComp.createObject(null, {
                        name: action.name,
                        iconName: action.icon,
                        iconType: LauncherSearchResult.IconType.System,
                        execute: () => {
                            if (!action.runInTerminal)
                                action.execute();
                            else {
                                Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(action.command.join(' '))}'`]);
                            }
                        }
                    });
                })
            });
        });
        ////////////////// Settings search //////////////////
        const settingsQuery = root.query.toLowerCase().trim();

        const settingsResults = root.settingsIndex.reduce((acc, page) => {
            const dynamicKeywords = (root.settingsKeywordsCache[page.page] || "").toLowerCase();
            const query = root.query.toLowerCase().trim();
            if (query === "") return acc;

            if (page.page.toLowerCase().includes(query) || dynamicKeywords.includes(query)) {
                acc.push(resultComp.createObject(null, {
                    name: page.page,
                    comment: dynamicKeywords.includes(query) ? "Section: " + query : "Settings for " + page.page,
                    verb: Translation.tr("Go"),
                    type: Translation.tr("Settings"),
                    iconName: "settings",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        GlobalStates.settingsOpen = true;
                        Qt.callLater(() => {
                            GlobalStates.settingsPage = page.page + ":" + query;
                        });
                        root.query = "";
                    }
                }));
            }
            return acc;
        }, []);
        const commandResultObject = resultComp.createObject(null, {
            name: StringUtils.cleanPrefix(root.query, Config.options.search.prefix.shellCommand).replace("file://", ""),
            verb: Translation.tr("Run"),
            type: Translation.tr("Command"),
            fontType: LauncherSearchResult.FontType.Monospace,
            iconName: 'terminal',
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                let cleanedCommand = root.query.replace("file://", "");
                cleanedCommand = StringUtils.cleanPrefix(cleanedCommand, Config.options.search.prefix.shellCommand);
                if (cleanedCommand.startsWith(Config.options.search.prefix.shellCommand)) {
                    cleanedCommand = cleanedCommand.slice(Config.options.search.prefix.shellCommand.length);
                }
                Quickshell.execDetached(["bash", "-c", root.query.startsWith('sudo') ? `${Config.options.apps.terminal} fish -C '${cleanedCommand}'` : cleanedCommand]);
            }
        });
        const webSearchResultObject = resultComp.createObject(null, {
            name: StringUtils.cleanPrefix(root.query, Config.options.search.prefix.webSearch),
            verb: Translation.tr("Search"),
            type: Translation.tr("Web search"),
            iconName: 'travel_explore',
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                let query = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.webSearch);
                let url = Config.options.search.engineBaseUrl + query;
                for (let site of Config.options.search.excludedSites) {
                    url += ` -site:${site}`;
                }
                Qt.openUrlExternally(url);
            }
        });
        const launcherActionObjects = root.allActions.map(action => {
            const actionString = `${Config.options.search.prefix.action}${action.action}`;
            if (actionString.startsWith(root.query) || root.query.startsWith(actionString)) {
                return resultComp.createObject(null, {
                    name: root.query.startsWith(actionString) ? root.query : actionString,
                    verb: Translation.tr("Run"),
                    type: Translation.tr("Action"),
                    iconName: 'settings_suggest',
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        action.execute(root.query.split(" ").slice(1).join(" "));
                    }
                });
            }
            return null;
        }).filter(Boolean);

        //////// Prioritized by prefix /////////
        let result = [];
        const startsWithNumber = /^\d/.test(root.query);
        const startsWithMathPrefix = root.query.startsWith(Config.options.search.prefix.math);
        const startsWithShellCommandPrefix = root.query.startsWith(Config.options.search.prefix.shellCommand);
        const startsWithWebSearchPrefix = root.query.startsWith(Config.options.search.prefix.webSearch);
        if (startsWithNumber || startsWithMathPrefix) {
            result.push(mathResultObject);
        } else if (startsWithShellCommandPrefix) {
            result.push(commandResultObject);
        } else if (startsWithWebSearchPrefix) {
            result.push(webSearchResultObject);
        }

        //////////////// Apps //////////////////
        result = result.concat(appResultObjects);
        ////////////// Settings ////////////////
        result = result.concat(settingsResults);
        ////////// Launcher actions ////////////
        result = result.concat(launcherActionObjects);

        /// Math result, command, web search ///
        if (Config.options.search.prefix.showDefaultActionsWithoutPrefix) {
            if (!startsWithShellCommandPrefix)
                result.push(commandResultObject);
            if (!startsWithNumber && !startsWithMathPrefix)
                result.push(mathResultObject);
            if (!startsWithWebSearchPrefix)
                result.push(webSearchResultObject);
        }
        
        return result;
    }

    Component {
        id: resultComp
        LauncherSearchResult {}
    }
}
