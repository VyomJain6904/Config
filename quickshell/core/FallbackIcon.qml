import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.core

IconImage {
    id: root

    property string iconName: ""
    property var iconSources: []
    property int iconSourceIndex: 0

    onIconNameChanged: {
        if (iconName.length > 0) {
            const sources = [];
            Icons.addHicolorFallbacks(sources, iconName);
            Icons.addIconSource(sources, Quickshell.iconPath(iconName, true));
            Icons.addIconSource(sources, "image://icon/" + iconName);
            iconSources = sources;
        } else {
            iconSources = [];
        }
        iconSourceIndex = 0;
    }

    source: iconSources.length > iconSourceIndex ? iconSources[iconSourceIndex] : ""
    asynchronous: true
    mipmap: true
    visible: status === Image.Ready

    onStatusChanged: {
        if (status === Image.Error && iconSourceIndex < iconSources.length - 1) {
            iconSourceIndex += 1;
        }
    }
}
