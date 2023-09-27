import Blockstream.Green
import Blockstream.Green.Core
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "util.js" as UtilJS

StackViewPage {
    signal checked(var mnemonic)
    required property var mnemonic

    id: self
    title: qsTrId('id_recovery_phrase_check')
    contentItem: ColumnLayout {
        readonly property bool checked: {
            if (repeater.count === 0) return false
            for (let i = 0; i < repeater.count; i++) {
                if (!repeater.itemAt(i).match) {
                    return false
                }
            }
            return true
        }

        onCheckedChanged: {
            if (checked) self.checked(self.mnemonic)
        }

        Pane {
            Layout.alignment: Qt.AlignCenter
            background: null
            padding: 0
            contentItem: ColumnLayout {
                spacing: 10
                Label {
                    Layout.alignment: Qt.AlignCenter
                    font.family: 'SF Compact Display'
                    font.pixelSize: 14
                    font.weight: 600
                    opacity: 0.4
                    text: 'Make sure you got everything right'
                }
                Repeater {
                    id: repeater
                    model: {
                        const count = 6
                        const size = self.mnemonic.length
                        const indexes = [...Array(size).keys()]
                        const result = []
                        while (result.length < count) {
                            const remove = indexes.length * Math.random()
                            const [index] = indexes.splice(remove, 1)
                            result.push(index)
                        }
                        return result.sort((a, b) => a - b)
                    }
                    delegate: Collapsible {
                        id: checker
                        readonly property int word: modelData
                        readonly property bool match: self.mnemonic[checker.word] === field.text
                        Layout.fillWidth: true
                        collapsed: index > 0 && !repeater.itemAt(index - 1).match
                        contentHeight: field.implicitHeight
                        Rectangle {
                            border.width: 2
                            border.color: '#00B45A'
                            color: 'transparent'
                            radius: 12
                            anchors.fill: field
                            anchors.margins: -4
                            z: -1
                            visible: {
                                if (checker.collapsed) return false
                                if (checker.animating) return false
                                if (field.activeFocus) {
                                    switch (field.focusReason) {
                                    case Qt.TabFocusReason:
                                    case Qt.BacktabFocusReason:
                                    case Qt.ShortcutFocusReason:
                                        return true
                                    }
                                }
                                return false
                            }
                        }
                        TextField {
                            id: field
                            width: parent.width
                            enabled: !checker.match
                            padding: 15
                            topPadding: 15
                            bottomPadding: 15
                            bottomInset: 0
                            leftPadding: 50
                            rightPadding: 40
                            font.family: 'SF Compact Display'
                            font.pixelSize: 14
                            font.weight: 400
                            focus: !parent.collapsed && !parent.match
                            background: Rectangle {
                                radius: 5
                                color: '#222226'
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.margins: 15
                                    font.family: 'SF Compact Display'
                                    font.pixelSize: 14
                                    font.weight: 700
                                    text: checker.word + 1
                                }
                                Image {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: parent.right
                                    anchors.margins: 15
                                    source: 'qrc:/svg2/check-green.svg'
                                    opacity: checker.match ? 1 : 0
                                    Behavior on opacity {
                                        SmoothedAnimation {
                                            velocity: 4
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    footer: ColumnLayout {
        Image {
            Layout.alignment: Qt.AlignCenter
            source: 'qrc:/svg2/house.svg'
        }
        Label {
            Layout.alignment: Qt.AlignCenter
            font.family: 'SF Compact Display'
            font.pixelSize: 12
            font.weight: 600
            text: qsTrId('id_make_sure_to_be_in_a_private')
        }
    }
}
