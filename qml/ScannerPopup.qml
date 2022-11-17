import Blockstream.Green 0.1
import Blockstream.Green.Core 0.1
import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.5
import QtQuick.Controls.Material 2.3
import QtQuick.Layouts 1.12
import QtMultimedia 5.13
import QtGraphicalEffects 1.15
import QtQuick.Shapes 1.0

Popup {
    readonly property bool available: QtMultimedia.availableCameras.length > 0
    signal codeScanned(string code)

    id: self
    background: MouseArea {
        hoverEnabled: true
    }
    x: parent.width / 2 - width / 2
    y: -height
    contentItem: Loader {
        active: self.visible
        sourceComponent: Item {
            implicitWidth: 300
            implicitHeight: 200
            scale: self.background.containsMouse ? 1.05 : (self.visible ? 1 : 0)
            transformOrigin: Item.Bottom
            Behavior on scale {
                NumberAnimation {
                    easing.type: Easing.OutBack
                    duration: 400
                }
            }
            Shape {
                anchors.fill: parent
                PopupBalloon {
                    strokeWidth: 0
                    fillColor: constants.c700
                }
            }
            ScannerView {
                anchors.fill: parent
                id: scanner_view
                onCodeScanned: {
                    self.codeScanned(code)
                    self.close()
                }
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Shape {
                        width: scanner_view.width
                        height: scanner_view.height
                        PopupBalloon {
                            strokeWidth: 1
                            strokeColor: 'transparent'
                            fillColor: 'white'
                        }
                    }
                }
            }
            Shape {
                anchors.fill: parent
                layer.samples: 4
                PopupBalloon {
                    strokeColor: constants.g400
                    strokeWidth: 1
                    fillColor: 'transparent'
                }
            }
            ToolButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                hoverEnabled: false
                flat: true
                icon.source: 'qrc:/svg/cancel.svg'
                icon.width: 16
                icon.height: 16
                onClicked: self.close()
            }
        }
    }
}
