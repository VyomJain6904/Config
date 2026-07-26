pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

FloatingWindow {
    id: root

    required property var powerMenuModel

    visible: powerMenuModel.visible
    implicitWidth: 460
    implicitHeight: 580
    title: "Quickshell Utility"
    color: Theme.transparent

    onVisibleChanged: {
        if (visible) {
            content.forceActiveFocus();
        } else {
            root.powerMenuModel.close();
        }
    }

    readonly property var cancelAction: {
        "label": "Cancel",
        "detail": "Return to power menu"
    }

    readonly property var confirmButtonAction: {
        "label": "Confirm",
        "detail": powerMenuModel.pendingAction ? powerMenuModel.pendingAction.label : ""
    }

    ShellSurface {
        id: content

        anchors.fill: parent
        anchors.bottomMargin: 12
        focus: true

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                if (root.powerMenuModel.confirming) {
                    root.powerMenuModel.cancelConfirmation();
                } else {
                    root.powerMenuModel.close();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                root.powerMenuModel.moveSelection(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                root.powerMenuModel.moveSelection(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.powerMenuModel.activateSelected();
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.listSpacing

            RowLayout {
                Layout.fillWidth: true
                visible: !root.powerMenuModel.confirming
                UiText {
                    Layout.fillWidth: true
                    text: "Power"
                    color: Theme.textStrong
                    font.pixelSize: Theme.titleFontSize
                    font.bold: true
                }
                UiText {
                    text: "x"
                    color: closeMouse.containsMouse ? Theme.accent : Theme.textMuted
                    font.pixelSize: Theme.titleFontSize
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.powerMenuModel.close()
                    }
                }
            }

            Repeater {
                model: root.powerMenuModel.confirming ? [] : root.powerMenuModel.sessionActions

                delegate: PowerMenuActionButton {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    action: modelData
                    danger: modelData.id === "shutdown"
                    selected: index === root.powerMenuModel.selectedActionIndex
                    onActivated: root.powerMenuModel.requestAction(modelData)
                }
            }

            ColumnLayout {
                visible: root.powerMenuModel.confirming
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.sectionSpacing

                Text {
                    Layout.fillWidth: true
                    text: root.powerMenuModel.pendingAction ? root.powerMenuModel.pendingAction.label : ""
                    color: Theme.textStrong
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.inputFontSize
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: "This action will affect the current session or system."
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignBottom
                    spacing: Theme.listSpacing

                    PowerMenuActionButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.confirmButtonHeight
                        action: root.cancelAction
                        compact: true
                        selected: root.powerMenuModel.selectedConfirmIndex === 0
                        onActivated: root.powerMenuModel.cancelConfirmation()
                    }

                    PowerMenuActionButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.confirmButtonHeight
                        action: root.confirmButtonAction
                        compact: true
                        danger: true
                        selected: root.powerMenuModel.selectedConfirmIndex === 1
                        onActivated: root.powerMenuModel.confirmAction()
                    }
                }
            }
        }
    }
}
