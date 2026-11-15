import QtQuick
import qs.desktop.modules.bar
import qs.desktop.modules.common
import qs.desktop.modules.dock
import "../../../../shared/qml/i18n"

KosFloatPanel {
    id: sessionConfirm
    objectName: "control-center-session-confirmation"
    property string actionLabel: ""
    signal cancelRequested()
    signal confirmRequested()
    modal: true
    backdropMode: "none"
    dismissOnBackdrop: false
    shadowEnabled: false
    contentPadding: 0
    radius: 24
    cornerExponent: 2.35
    materialTone: "auto"
    material: "regular"
    materialDepth: 0
    scrimLevel: ThemeService.isLightBackdrop ? "strong" : "subtle"
    scrimFixed: false
    blurOverrideEnabled: false
    maskContent: false
    onBackdropClicked: sessionConfirm.cancelRequested()

    Item {
        width: 304
        height: 208

        Rectangle {
            width: 56
            height: 56
            radius: width / 2
            anchors {
                top: parent.top
                topMargin: 20
                horizontalCenter: parent.horizontalCenter
            }
            color: sessionConfirm.contentControlFill
            border.width: 1
            border.color: sessionConfirm.contentControlBorder

            BundledIcon {
                anchors.centerIn: parent
                width: 28
                height: 28
                name: BundledIcons.roleName(sessionConfirm.actionLabel === "poweroff"
                    ? "powerOff"
                    : (sessionConfirm.actionLabel === "reboot" ? "reboot" : "logout"))
                color: sessionConfirm.contentForegroundColor
                outlined: false
            }
        }

        Text {
            anchors {
                top: parent.top
                topMargin: 88
                left: parent.left
                right: parent.right
            }
            horizontalAlignment: Text.AlignHCenter
            renderType: Text.NativeRendering
            text: sessionConfirm.actionLabel === "poweroff" ? I18n.tr("Power off now?")
                : (sessionConfirm.actionLabel === "reboot" ? I18n.tr("Restart now?") : I18n.tr("Log out now?"))
            color: sessionConfirm.contentForegroundColor
            font {
                pixelSize: 16
                weight: Font.DemiBold
                family: "SF Pro Display, Inter, Noto Sans, sans-serif"
            }
        }

        Text {
            anchors {
                top: parent.top
                topMargin: 114
                left: parent.left
                right: parent.right
            }
            horizontalAlignment: Text.AlignHCenter
            renderType: Text.NativeRendering
            text: I18n.tr("Unsaved work may be lost")
            color: sessionConfirm.contentSecondaryColor
            font {
                pixelSize: 12
                family: "SF Pro Display, Inter, Noto Sans, sans-serif"
            }
        }

        Row {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 18
            }
            spacing: 12

            Rectangle {
                width: 104
                height: 32
                radius: height / 2
                color: cancelMouse.containsMouse
                    ? (sessionConfirm.finalGlassIsDark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.12))
                    : sessionConfirm.contentControlFill
                border.width: 1
                border.color: sessionConfirm.contentControlBorder

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    text: I18n.tr("Cancel")
                    color: sessionConfirm.contentForegroundColor
                    font {
                        pixelSize: 13
                        weight: Font.Medium
                        family: "SF Pro Display, Inter, Noto Sans, sans-serif"
                    }
                }

                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sessionConfirm.cancelRequested()
                }
            }

            Rectangle {
                width: 104
                height: 32
                radius: height / 2
                color: executeConfirmMouse.containsMouse
                    ? (sessionConfirm.actionLabel === "logout"
                        ? (sessionConfirm.finalGlassIsDark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.12))
                        : (sessionConfirm.finalGlassIsDark ? Qt.rgba(1.0, 0.23, 0.19, 0.35) : Qt.rgba(1.0, 0.23, 0.19, 0.25)))
                    : (sessionConfirm.actionLabel === "logout"
                        ? sessionConfirm.contentControlFill
                        : (sessionConfirm.finalGlassIsDark ? Qt.rgba(1.0, 0.23, 0.19, 0.22) : Qt.rgba(1.0, 0.23, 0.19, 0.12)))
                border.width: 1
                border.color: sessionConfirm.actionLabel === "logout"
                    ? sessionConfirm.contentControlBorder
                    : (sessionConfirm.finalGlassIsDark ? Qt.rgba(1.0, 0.23, 0.19, 0.45) : Qt.rgba(1.0, 0.23, 0.19, 0.30))

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    text: sessionConfirm.actionLabel === "poweroff" ? I18n.tr("Power Off")
                        : (sessionConfirm.actionLabel === "reboot" ? I18n.tr("Restart") : I18n.tr("Log Out"))
                    color: sessionConfirm.actionLabel === "logout"
                        ? sessionConfirm.contentForegroundColor
                        : (sessionConfirm.finalGlassIsDark ? "#ff453a" : "#d70015")
                    font {
                        pixelSize: 13
                        weight: Font.DemiBold
                        family: "SF Pro Display, Inter, Noto Sans, sans-serif"
                    }
                }

                MouseArea {
                    id: executeConfirmMouse
                    objectName: "executeConfirmMouse"
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sessionConfirm.confirmRequested()
                }
            }
        }
    }
}
