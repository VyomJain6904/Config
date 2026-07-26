import QtQuick
import qs.core

Rectangle {
    id: root

    default property alias content: body.data
    property int margin: Theme.popupMargin

    color: Theme.bg
    border.color: Theme.borderStrong
    border.width: Theme.pillBorderWidth
    radius: Theme.radius

    PillShadow { cornerRadius: root.radius }

    Item {
        id: body

        anchors.fill: parent
        anchors.margins: root.margin
    }
}
