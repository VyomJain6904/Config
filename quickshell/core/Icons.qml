pragma Singleton

import Quickshell

Singleton {

    function addIconSource(sources, source) {
        if (typeof source !== "string" && !(source instanceof String)) {
            return;
        }

        if (source.length === 0) {
            return;
        }

        if (sources.indexOf(source) < 0) {
            sources.push(source);
        }
    }

    function decodeIconPart(value) {
        try {
            return decodeURIComponent(value);
        } catch (error) {
            return value;
        }
    }

    function looksLikeIconFilePath(path) {
        return /\.(ico|png|svg|tga|webp|xpm)$/i.test(path);
    }

    function iconNameFallbacks(iconName) {
        const names = [iconName];

        if (iconName.indexOf("-symbolic") < 0) {
            names.push(iconName + "-symbolic");
        }

        if (iconName === "blueman" || iconName === "blueman-tray") {
            names.push("blueman-tray");
            names.push("blueman");
            names.push("blueman-active");
            names.push("bluetooth-active-symbolic");
            names.push("bluetooth-symbolic");
        } else if (iconName === "org.remmina.Remmina-status") {
            names.push("org.remmina.Remmina");
            names.push("org.remmina.Remmina-symbolic");
        }

        return names;
    }

    function addIconThemeFileSources(sources, themeRoot, iconName) {
        if (themeRoot.length === 0 || iconName.length === 0) {
            return;
        }

        const rootPath = themeRoot.replace(/\/+$/, "");
        const names = iconNameFallbacks(iconName);
        const sizes = ["24x24", "32x32", "22x22", "16x16", "48x48", "scalable"];
        const categories = ["status", "apps", "devices", "actions", "emblems"];
        const extensions = ["svg", "png"];

        for (let nameIndex = 0; nameIndex < names.length; nameIndex++) {
            const name = names[nameIndex];

            for (let sizeIndex = 0; sizeIndex < sizes.length; sizeIndex++) {
                const size = sizes[sizeIndex];

                for (let categoryIndex = 0; categoryIndex < categories.length; categoryIndex++) {
                    const category = categories[categoryIndex];

                    for (let extensionIndex = 0; extensionIndex < extensions.length; extensionIndex++) {
                        addIconSource(sources, "file://" + rootPath + "/" + size + "/" + category + "/" + name + "." + extensions[extensionIndex]);
                    }
                }
            }

            for (let categoryIndex = 0; categoryIndex < categories.length; categoryIndex++) {
                const category = categories[categoryIndex];

                for (let sizeIndex = 0; sizeIndex < sizes.length; sizeIndex++) {
                    const size = sizes[sizeIndex];
                    const numSize = size.split("x")[0]; // "24x24" -> "24"

                    for (let extensionIndex = 0; extensionIndex < extensions.length; extensionIndex++) {
                        addIconSource(sources, "file://" + rootPath + "/" + category + "/" + numSize + "/" + name + "." + extensions[extensionIndex]);
                        addIconSource(sources, "file://" + rootPath + "/" + category + "/" + size + "/" + name + "." + extensions[extensionIndex]);
                    }
                }

                for (let extensionIndex = 0; extensionIndex < extensions.length; extensionIndex++) {
                    addIconSource(sources, "file://" + rootPath + "/" + category + "/" + name + "." + extensions[extensionIndex]);
                }
            }

            addIconSource(sources, "file://" + rootPath + "/" + name);

            for (let extensionIndex = 0; extensionIndex < extensions.length; extensionIndex++) {
                addIconSource(sources, "file://" + rootPath + "/" + name + "." + extensions[extensionIndex]);
            }
        }
    }

    function addMacTahoeFallbacks(sources, iconName) {
        const home = Quickshell.env("HOME") || "";
        const xdgDataHome = Quickshell.env("XDG_DATA_HOME") || (home.length > 0 ? home + "/.local/share" : "");

        addIconThemeFileSources(sources, "/usr/share/icons/MacTahoe", iconName);
        addIconThemeFileSources(sources, "/usr/share/icons/hicolor", iconName);
        addIconThemeFileSources(sources, "/usr/local/share/icons/MacTahoe", iconName);
        addIconThemeFileSources(sources, "/usr/local/share/icons/hicolor", iconName);

        // Flatpak system-wide icon exports
        addIconThemeFileSources(sources, "/var/lib/flatpak/exports/share/icons/hicolor", iconName);

        if (xdgDataHome.length > 0) {
            addIconThemeFileSources(sources, xdgDataHome + "/icons/MacTahoe", iconName);
            addIconThemeFileSources(sources, xdgDataHome + "/icons/hicolor", iconName);
            // Flatpak user icon exports
            addIconThemeFileSources(sources, xdgDataHome + "/flatpak/exports/share/icons/hicolor", iconName);
        }

        if (home.length > 0) {
            addIconThemeFileSources(sources, home + "/.icons/MacTahoe", iconName);
            addIconThemeFileSources(sources, home + "/.icons/hicolor", iconName);
            addIconThemeFileSources(sources, home + "/.local/share/flatpak/exports/share/icons/hicolor", iconName);
        }
    }

    function addCheckedThemeSources(sources, iconName) {
        const names = iconNameFallbacks(iconName);

        for (let index = 0; index < names.length; index++) {
            addIconSource(sources, Quickshell.iconPath(names[index], true));
        }
    }
    function trayIconSources(trayItem) {
        let rawIconName = decodeIconPart(trayItem.icon);
        let iconName = rawIconName;
        const iconPath = decodeIconPart(trayItem.iconPath);

        // Quickshell prefixes tray icons with its image provider (e.g. image://icon/discord)
        // We need the raw name to match our custom flatpak resolution rules
        if (iconName && iconName.indexOf("image://icon/") === 0) {
            iconName = iconName.substring(13); // remove "image://icon/"
        }

        console.log("TRAY ICON REQUEST:", "id=", trayItem.id, "iconName=", iconName, "rawIconName=", rawIconName, "iconPath=", iconPath);

        const sources = [];

        // Always add the raw Quickshell provided URI as the last resort fallback
        if (rawIconName && rawIconName.indexOf("image://") === 0) {
            addIconSource(sources, rawIconName);
        }

        // Special case flameshot
        if (trayItem.id === "flameshot") {
            // Already hidden in TrayArea, but just in case
            return sources;
        } else if (iconName === "flameshot-tray") {
            addIconSource(sources, "file:///usr/share/icons/MacTahoe/48x48/apps/flameshot.png");
            addIconSource(sources, "file:///usr/share/icons/MacTahoe/scalable/apps/flameshot.svg");
            addIconSource(sources, "image://icon/flameshot-tray-symbolic");
            addIconSource(sources, "image://icon/flameshot");
            addIconSource(sources, "image://icon/org.flameshot.Flameshot");
        }

        // Special case: Discord flatpak - sends "discord" as icon name but icon is
        // in the flatpak hicolor export as "com.discordapp.Discord"
        if (iconName === "discord" || trayItem.id === "discord" || iconName === "com.discordapp.Discord" || (trayItem.id && trayItem.id.indexOf("discord") >= 0)) {
            addIconSource(sources, "file:///var/lib/flatpak/exports/share/icons/hicolor/scalable/apps/com.discordapp.Discord.svg");
            addIconSource(sources, "file:///usr/share/icons/MacTahoe/apps/scalable/discord.svg");
            addIconSource(sources, "file:///usr/share/icons/MacTahoe/apps/scalable/com.discordapp.Discord.svg");
            addIconSource(sources, "image://icon/discord");
            addIconSource(sources, "image://icon/com.discordapp.Discord");
        }

        // Special case: Telegram flatpak - uses "telegram-panel" / "org.telegram.desktop" as icon name
        if (iconName === "telegram-panel" || iconName === "org.telegram.desktop" || (trayItem.id && trayItem.id.indexOf("telegram") >= 0)) {
            addIconSource(sources, "file:///usr/share/icons/MacTahoe/status/16/telegram-panel.svg");
            addIconSource(sources, "file:///usr/share/icons/MacTahoe/status/22/telegram-panel.svg");
            addIconSource(sources, "file:///usr/share/icons/MacTahoe/apps/scalable/telegram-desktop.svg");
            addIconSource(sources, "file:///usr/share/icons/MacTahoe/apps/scalable/org.telegram.desktop.svg");
            addIconSource(sources, "file:///var/lib/flatpak/exports/share/icons/hicolor/64x64/apps/org.telegram.desktop.png");
            addIconSource(sources, "image://icon/telegram-panel");
            addIconSource(sources, "image://icon/org.telegram.desktop");
        }
        if (iconName === "telegram-attention-panel") {
            addIconSource(sources, "file:///usr/share/icons/MacTahoe/status/16/telegram-attention-panel.svg");
            addIconSource(sources, "file:///usr/share/icons/MacTahoe/status/22/telegram-attention-panel.svg");
        }
        if (iconName === "telegram-mute-panel") {
            addIconSource(sources, "file:///usr/share/icons/MacTahoe/status/16/telegram-mute-panel.svg");
            addIconSource(sources, "file:///usr/share/icons/MacTahoe/status/22/telegram-mute-panel.svg");
        }

        if (looksLikeIconFilePath(iconPath)) {
            addIconSource(sources, "file://" + iconPath);
        } else if (looksLikeIconFilePath(iconName)) {
            addIconSource(sources, "file://" + iconName);
        } else if (iconName === "steam_tray_mono") {
            addIconSource(sources, "file:///usr/share/pixmaps/steam_tray_mono.png");
        } else if (iconName.length > 0) {
            const names = iconNameFallbacks(iconName);
            const home = Quickshell.env("HOME") || "";
            const xdgDataHome = Quickshell.env("XDG_DATA_HOME") || (home.length > 0 ? home + "/.local/share" : "");
            for (let i = 0; i < names.length; i++) {
                // Search MacTahoe (primary theme)
                addIconThemeFileSources(sources, "/usr/share/icons/MacTahoe", names[i]);
                if (home.length > 0) {
                    addIconThemeFileSources(sources, home + "/.local/share/icons/MacTahoe", names[i]);
                }
                addIconThemeFileSources(sources, "/usr/local/share/icons/MacTahoe", names[i]);

                // Search hicolor (standard fallback - system)
                addIconThemeFileSources(sources, "/usr/share/icons/hicolor", names[i]);
                addIconThemeFileSources(sources, "/usr/local/share/icons/hicolor", names[i]);

                // Search flatpak icon exports (system-wide flatpak - Discord, Telegram, etc.)
                addIconThemeFileSources(sources, "/var/lib/flatpak/exports/share/icons/hicolor", names[i]);

                // Search flatpak icon exports (user-local flatpak)
                if (xdgDataHome.length > 0) {
                    addIconThemeFileSources(sources, xdgDataHome + "/flatpak/exports/share/icons/hicolor", names[i]);
                }
                if (home.length > 0) {
                    addIconThemeFileSources(sources, home + "/.local/share/flatpak/exports/share/icons/hicolor", names[i]);
                    addIconThemeFileSources(sources, home + "/.local/share/icons/hicolor", names[i]);
                }

                addIconSource(sources, "image://icon/" + names[i]);
            }
        }

        if (typeof iconName !== "string" && !(iconName instanceof String)) {
            return sources;
        }

        if (iconName.length === 0) {
            return sources;
        }

        const iconString = trayItem.icon;
        if (typeof iconString === "string" && iconString.indexOf("image://icon/") === 0) {
            const queryIndex = iconString.indexOf("?path=");
            const iconStart = "image://icon/".length;
            const parsedIconName = decodeIconPart(queryIndex >= 0 ? iconString.substring(iconStart, queryIndex) : iconString.substring(iconStart));

            if (parsedIconName.indexOf("/") === 0) {
                addIconSource(sources, "file://" + parsedIconName);
                addIconSource(sources, iconString);
                return sources;
            }

            if (queryIndex >= 0) {
                let innerIconPath = iconString.substring(queryIndex + "?path=".length);
                const iconPathEnd = innerIconPath.indexOf("&");

                if (iconPathEnd >= 0) {
                    innerIconPath = innerIconPath.substring(0, iconPathEnd);
                }

                innerIconPath = decodeIconPart(innerIconPath);
                if (parsedIconName.indexOf("/") !== 0) {
                    if (innerIconPath.indexOf("/") === 0 && looksLikeIconFilePath(innerIconPath)) {
                        addIconSource(sources, "file://" + innerIconPath);
                    }

                    addIconSource(sources, "file://" + innerIconPath + "/" + parsedIconName);
                    addIconSource(sources, "file://" + innerIconPath + "/" + parsedIconName + ".png");
                    addIconSource(sources, "file://" + innerIconPath + "/" + parsedIconName + ".svg");
                    addIconSource(sources, "file://" + innerIconPath + "/" + parsedIconName + ".ico");
                    addIconSource(sources, "file://" + innerIconPath + "/" + parsedIconName + ".tga");
                    addIconThemeFileSources(sources, innerIconPath, parsedIconName);
                }
            }

            addMacTahoeFallbacks(sources, parsedIconName);
            addCheckedThemeSources(sources, parsedIconName);
            addIconSource(sources, iconString);
            return sources;
        }

        if (typeof iconString === "string") {
            if (iconString.indexOf("image://") === 0 || iconString.indexOf("file://") === 0 || iconString.indexOf("qrc:") === 0) {
                addIconSource(sources, iconString);
                return sources;
            }

            if (iconString.indexOf("/") === 0 && iconString.indexOf("file://") !== 0) {
                addIconSource(sources, "file://" + iconString);
                return sources;
            }

            if (iconString === "dialog-password") {
                addIconSource(sources, Quickshell.iconPath("dialog-password-symbolic", true));
            }

            addMacTahoeFallbacks(sources, iconString);
            addCheckedThemeSources(sources, iconString);
            addIconSource(sources, iconString);
        }
        return sources;
    }
}
