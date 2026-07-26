import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.core

IconImage {
    id: root

    property string iconName: ""
    property var preferredNames: []
    property bool providerFallback: true
    property var iconSources: []
    property int iconSourceIndex: 0

    function rebuildSources() {
        if (iconName.length > 0 || preferredNames.length > 0) {
            const sources = [];

            for (let i = 0; i < preferredNames.length; i++) {
                const preferred = preferredNames[i];
                if (preferred && preferred.length > 0) {
                    Icons.addMacTahoeFallbacks(sources, preferred);
                    Icons.addIconSource(sources, Quickshell.iconPath(preferred, true));
                    if (providerFallback) {
                        Icons.addIconSource(sources, "image://icon/" + preferred);
                    }
                }
            }

            if (iconName.length > 0) {
                Icons.addMacTahoeFallbacks(sources, iconName);
                Icons.addIconSource(sources, Quickshell.iconPath(iconName, true));
                if (providerFallback) {
                    Icons.addIconSource(sources, "image://icon/" + iconName);
                }
            }

            iconSources = sources;
        } else {
            iconSources = [];
        }
        iconSourceIndex = 0;
    }

    onIconNameChanged: rebuildSources()
    onPreferredNamesChanged: rebuildSources()
    onProviderFallbackChanged: rebuildSources()

    source: iconSources.length > iconSourceIndex ? iconSources[iconSourceIndex] : ""
    implicitSize: Math.max(width, height)
    asynchronous: true
    mipmap: true
    visible: status === Image.Ready

    onStatusChanged: {
        if (status === Image.Error && iconSourceIndex < iconSources.length - 1) {
            iconSourceIndex += 1;
        }
    }
}
