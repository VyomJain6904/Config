import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    FALLBACK ICON RENDERER (FallbackIcon.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Intelligent icon rendering engine that automatically cycles through fallback
 * icon themes, file paths, and image providers if a primary icon lookup fails.
 * ─────────────────────────────────────────────────────────────────────────────
 */
IconImage {
    id: root

    // ── Public Properties ────────────────────────────────────────────────────
    property string iconName: ""            // Primary targeted icon identifier
    property var preferredNames: []         // Ordered array of fallback candidate names
    property bool providerFallback: true    // Whether to query Qt image:// icon provider
    property var iconSources: []            // Generated pipeline of valid source URIs
    property int iconSourceIndex: 0         // Current active source URI index in pipeline

    // =========================================================================
    // 1. SOURCE PIPELINE GENERATOR
    // =========================================================================
    // Builds an exhaustive prioritized list of candidate icon paths to try.
    function rebuildSources() {
        if (iconName.length > 0 || preferredNames.length > 0) {
            const sources = [];

            // Process preferred override names first
            for (let i = 0; i < preferredNames.length; i++) {
                const preferred = preferredNames[i];
                if (preferred && preferred.length > 0) {
                    if (preferred.indexOf("/") === 0) {
                        // Absolute local filesystem path
                        Icons.addIconSource(sources, "file://" + preferred);
                    } else if (preferred.indexOf("file://") === 0 || preferred.indexOf("image://") === 0) {
                        // Fully qualified URI scheme
                        Icons.addIconSource(sources, preferred);
                    } else {
                        // Named theme theme lookup with macOS icon theme fallbacks
                        Icons.addMacTahoeFallbacks(sources, preferred);
                        Icons.addIconSource(sources, Quickshell.iconPath(preferred, true));
                        if (providerFallback) {
                            Icons.addIconSource(sources, "image://icon/" + preferred);
                        }
                    }
                }
            }

            // Process primary icon name candidate
            if (iconName.length > 0) {
                if (iconName.indexOf("/") === 0) {
                    Icons.addIconSource(sources, "file://" + iconName);
                } else if (iconName.indexOf("file://") === 0 || iconName.indexOf("image://") === 0) {
                    Icons.addIconSource(sources, iconName);
                } else {
                    Icons.addMacTahoeFallbacks(sources, iconName);
                    Icons.addIconSource(sources, Quickshell.iconPath(iconName, true));
                    if (providerFallback) {
                        Icons.addIconSource(sources, "image://icon/" + iconName);
                    }
                }
            }

            iconSources = sources;
        } else {
            iconSources = [];
        }
        iconSourceIndex = 0;
    }

    // Reconstruct source candidates whenever inputs change
    onIconNameChanged: rebuildSources()
    onPreferredNamesChanged: rebuildSources()
    onProviderFallbackChanged: rebuildSources()

    // =========================================================================
    // 2. RENDER & ERROR RECOVERY SETTINGS
    // =========================================================================

    source: iconSources.length > iconSourceIndex ? iconSources[iconSourceIndex] : ""
    implicitSize: Math.max(width, height)
    asynchronous: true
    mipmap: true
    visible: status === Image.Ready

    // Automatically step to next fallback source URI if current image fails loading
    onStatusChanged: {
        if (status === Image.Error && iconSourceIndex < iconSources.length - 1) {
            iconSourceIndex += 1;
        }
    }
}
