import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.desktop.modules.bar
import qs.desktop.modules.common
import qs.desktop.modules.dock
import "../../../../shared/qml/i18n"

ControlCenterCard {
    id: dndCard
    objectName: "control-center-donotdisturbcard"
    required property var service
    ControlCenterSelection {
        pointer: dndPointer
        cornerRadius: dndCard.cardRadius
        selected: dndCard.service.doNotDisturbEnabled
    }
    visible: cardShown && coordinator.cardAnchor !== null
    Rectangle {
        id: dndDisc
        width: 34; height: 34; radius: 17
        anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
        color: dndCard.service.doNotDisturbEnabled
            ? ThemeService.tileActiveFill
            : (ThemeService.isDark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.05))
        opacity: dndPointer.containsMouse && !dndPointer.pressed ? 1.0 : 0.92
        Behavior on color { ColorAnimation { duration: 140 } }

        Image {
            anchors.centerIn: parent
            width: 18; height: 18
            source: BundledIcons.source("do-not-disturb")
            sourceSize.width: 36; sourceSize.height: 36
            fillMode: Image.PreserveAspectFit
            smooth: true
            layer.enabled: true
            layer.effect: MultiEffect {
                colorization: 1.0
                colorizationColor: dndCard.service.doNotDisturbEnabled
                    ? ThemeService.tileActiveGlyph : ThemeService.tileGlyph
            }
        }
    }
    GlassText {
        objectName: "control-center-dnd-title"
        anchors { left: dndDisc.right; leftMargin: 8; right: parent.right; rightMargin: 8; top: parent.top; topMargin: 8 }
        text: I18n.tr("Do Not Disturb")
        elide: Text.ElideRight
        color: ThemeService.foregroundColor
        font { pixelSize: 12; weight: Font.Medium; family: "Noto Sans CJK SC" }
    }
    GlassText {
        anchors { left: dndDisc.right; leftMargin: 8; right: parent.right; rightMargin: 8; bottom: parent.bottom; bottomMargin: 7 }
        elide: Text.ElideRight
        text: dndCard.service.doNotDisturbEnabled ? I18n.tr("On") : I18n.tr("Off")
        color: dndCard.service.doNotDisturbEnabled
            ? ThemeService.tileActiveGlyph : ThemeService.foregroundColor
        opacity: dndCard.service.doNotDisturbEnabled ? 0.9 : 0.5
        font { pixelSize: 11; family: "Noto Sans CJK SC" }
    }
    ToolTip.visible: dndPointer.containsMouse
    ToolTip.delay: 500
    ToolTip.text: I18n.tr("Do Not Disturb")
    Accessible.name: I18n.tr("Do Not Disturb")
    Accessible.description: dndCard.service.doNotDisturbEnabled ? I18n.tr("On") : I18n.tr("Off")
    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: dndCard.service.doNotDisturbEnabled
    Accessible.onPressAction: dndCard.service.toggleDoNotDisturb()
    MouseArea {
        id: dndPointer
        objectName: "dndPointer"
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: dndCard.service.toggleDoNotDisturb()
    }
}
