import Blockstream.Green
import Blockstream.Green.Core
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window

import "analytics.js" as AnalyticsJS

StackLayout {
    id: self
    required property string title
    required property string network
    readonly property string location: `/${network}`
    readonly property WalletView currentWalletView: {
        for (let i = 0; i < wallet_view_repeater.count; ++i) {
            const view = wallet_view_repeater.itemAt(i)
            if (view.match) return view
        }
        return null
    }
    readonly property bool active: window.navigation.param.view === self.network

    currentIndex: {
        let index = 0
        for (let i = 0; i < wallet_view_repeater.count; ++i) {
            if (wallet_view_repeater.itemAt(i).match) {
                return 1 + i
            }
        }
        return index
    }

    MainPage {
        header: MainPageHeader {
            contentItem: RowLayout {
                spacing: 16
                Label {
                    text: self.title
                    font.pixelSize: 24
                    font.styleName: 'Medium'
                    Layout.fillWidth: true
                }
                GButton {
                    text: qsTrId('id_create_new_wallet')
                    highlighted: true
                    large: true
                    onClicked: navigation.set({ flow: 'signup', network: self.network, type: (self.network === 'liquid' ? undefined : 'default') })
                }
                GButton {
                    large: true
                    text: qsTrId('id_restore_green_wallet')
                    onClicked: navigation.set({ flow: 'restore', network: self.network })
                }
                GButton {
                    text: qsTrId('id_watchonly_login')
                    large: true
                    onClicked: watch_only_login_dialog.createObject(window).open()
                }
            }
        }
        footer: StatusBar {
            contentItem: RowLayout {
                SessionBadge {
                    session: HttpManager.session
                }
            }
        }
        Component {
            id: watch_only_login_dialog
            WatchOnlyLoginDialog {
                network: NetworkManager.networkWithServerType(self.network, 'green')
            }
        }

        contentItem: Pane {
            padding: 0
            background: Label {
                visible: wallet_list_view.count===0
                text: qsTrId('id_looks_like_you_havent_used_a');
                horizontalAlignment: Qt.AlignHCenter
                verticalAlignment: Qt.AlignVCenter
            }
            contentItem: GListView {
                id: wallet_list_view
                clip: true
                currentIndex: -1
                model: WalletListModel {
                    network: self.network
                }
                delegate: WalletListDelegate {
                    width: ListView.view.contentWidth
                }
            }
        }
    }

    Repeater {
        id: wallet_view_repeater
        model: WalletListModel {
            justAuthenticated: true
            network: self.network
        }
        delegate: WalletView {
            property bool match: wallet.ready && navigation.param.wallet === wallet.id
            AnalyticsView {
                name: 'Overview'
                segmentation: AnalyticsJS.segmentationSession(wallet)
                active: match
            }
        }
    }
}
