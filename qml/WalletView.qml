import Blockstream.Green
import Blockstream.Green.Core
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "util.js" as UtilJS

MainPage {
    signal openWallet(Wallet wallet)
    signal removeWallet(Wallet wallet)
    signal closeWallet(Wallet wallet)
    signal closeDevice(Device device)
    property Wallet wallet
    property Device device
    Component.onCompleted: {
        const wallet = self.wallet
        if (!wallet) {
            if (self.device instanceof JadeDevice) {
                stack_view.push(jade_page, { device: self.device, login: true }, StackView.Immediate)
            } else {
                stack_view.push(terms_of_service_page, {}, StackView.Immediate)
            }
        } else if (wallet.context) {
            stack_view.push(loading_page, { context: wallet.context }, StackView.Immediate)
        } else if (wallet.login instanceof WatchonlyData) {
            stack_view.push(watch_only_login_page, { wallet }, StackView.Immediate)
        } else if (wallet.login instanceof DeviceData) {
            stack_view.push(device_page, { wallet }, StackView.Immediate)
        } else if (wallet.login instanceof PinData) {
            stack_view.push(pin_login_page, { wallet }, StackView.Immediate)
        } else {
            stack_view.push(restore_wallet_page, { wallet }, StackView.Immediate)
        }
    }
    id: self
    title: stack_view.currentItem?.title ?? null
    contentItem: GStackView {
        id: stack_view
        focus: true
    }

    Component {
        id: device_page
        DevicePage {
            padding: 60
            onDeviceSelected: (device) => {
                if (device instanceof JadeDevice) {
                    stack_view.push(jade_page, { device, login: true })
                }
                if (device instanceof LedgerDevice) {
                    stack_view.push(ledger_page, { device, remember: true })
                }
            }
            onRemoveClicked: self.removeWallet(self.wallet)
            onCloseClicked: self.closeWallet(self.wallet)
        }
    }

    Component {
        id: jade_page
        JadePage {
            onLoginFinished: (context) => {
                self.wallet = context.wallet
                stack_view.replace(null, loading_page, { context }, StackView.PushTransition)
            }
            onFirmwareUpdated: stack_view.pop()
            onCloseClicked: self.closeDevice(self.device)
        }
    }

    Component {
        id: ledger_page
        LedgerPage {
            onLoginFinished: (context) => {
                self.wallet = context.wallet
                stack_view.replace(null, loading_page, { context }, StackView.PushTransition)
            }
            onLoginFailed: stack_view.pop()
        }
    }

    Component {
        id: terms_of_service_page
        TermOfServicePage {
            onAddWallet: stack_view.push(add_wallet_page)
            onUseDevice: stack_view.push(use_device_page)
        }
    }

    Component {
        id: add_wallet_page
        AddWalletPage {
            onNewWallet: stack_view.push(mnemonic_warnings_page)
            onRestoreWallet: stack_view.push(restore_wallet_page)
            // TODO present singlesig or multisig options once singlesig watchonly login is implemented
            // onWatchOnlyWallet: stack_view.push(watch_only_wallet_page)
            onWatchOnlyWallet: stack_view.push(multisig_watch_only_network_page)
        }
    }

    Component {
        id: use_device_page
        UseDevicePage {
            onConnectJadeClicked: stack_view.push(connect_jade_page)
            onConnectLedgerClicked: stack_view.push(connect_ledger_page)
        }
    }

    Component {
        id: connect_jade_page
        ConnectJadePage {
            onDeviceSelected: (device) => stack_view.push(jade_page, { device, login: true })
        }
    }

    Component {
        id: connect_ledger_page
        ConnectLedgerPage {
            onDeviceSelected: (device, remember) => stack_view.push(ledger_page, { device, remember })
        }
    }

    Component {
        id: mnemonic_warnings_page
        MnemonicWarningsPage {
            padding: 60
            onAccepted: stack_view.push(mnemonic_backup_page)
        }
    }

    Component {
        id: mnemonic_backup_page
        MnemonicBackupPage {
            padding: 60
            onSelected: (mnemonic) => stack_view.push(mnemonic_check_page, { mnemonic })
        }
    }

    Component {
        id: mnemonic_check_page
        MnemonicCheckPage {
            padding: 60
            onChecked: (mnemonic) => stack_view.push(register_page, { mnemonic })
        }
    }

    Component {
        id: register_page
        RegisterPage {
            onRegisterFinished: (context) => {
                self.wallet = context.wallet
                stack_view.push(setup_pin_page, { context })
            }
        }
    }

    Component {
        id: setup_pin_page
        SetupPinPage {
            onFinished: (context) => stack_view.replace(null, loading_page, { context }, StackView.PushTransition)
        }
    }

    Component {
        id: restore_wallet_page
        RestorePage {
            onMnemonicEntered: (wallet, mnemonic, password) => stack_view.push(restore_check_page, { wallet, mnemonic, password })
            onRemoveClicked: self.removeWallet(self.wallet)
            onCloseClicked: self.closeWallet(self.wallet)
        }
    }

    Component {
        id: restore_check_page
        RestoreCheckPage {
            onRestoreFinished: (context) => {
                self.wallet = context.wallet
                stack_view.push(setup_pin_page, { context })
            }
            onAlreadyRestored: (wallet) => stack_view.replace(already_restored_page, { wallet })
            onMismatch: stack_view.pop()
        }
    }

    Component {
        id: already_restored_page
        AlreadyRestoredPage {
            onOpenWallet: (wallet) => {
                self.openWallet(wallet)
                stack_view.replace(null, terms_of_service_page, {}, StackView.Immediate)
            }
            onCancel: stack_view.replace(null, terms_of_service_page, {}, StackView.PushTransition)
        }
    }

    Component {
        id: watch_only_wallet_page
        WatchOnlyWalletPage {
            onMultisigWallet: stack_view.push(multisig_watch_only_network_page)
        }
    }

    Component {
        id: multisig_watch_only_network_page
        MultisigWatchOnlyNetworkPage {
            onNetworkSelected: (network) => stack_view.push(multisig_watch_only_add_page, { network })
        }
    }

    Component {
        id: multisig_watch_only_add_page
        MultisigWatchOnlyAddPage {
            onLoginFinished: (context) => {
                self.wallet = context.wallet
                stack_view.replace(null, loading_page, { context }, StackView.PushTransition)
            }
        }
    }

    Component {
        id: watch_only_login_page
        WatchOnlyLoginPage {
            onLoginFinished: (context) => {
                self.wallet = context.wallet
                stack_view.replace(null, loading_page, { context }, StackView.PushTransition)
            }
            onRemoveClicked: self.removeWallet(self.wallet)
            onCloseClicked: self.closeWallet(self.wallet)
        }
    }

    Component {
        id: pin_login_page
        PinLoginPage {
            onLoginFinished: (context) => {
                stack_view.replace(null, loading_page, { context }, StackView.PushTransition)
            }
            onRestoreClicked: stack_view.replace(restore_wallet_page, { wallet: self.wallet })
            onRemoveClicked: self.removeWallet(self.wallet)
            onCloseClicked: self.closeWallet(self.wallet)
        }
    }

    Component {
        id: loading_page
        LoadingPage {
            onLoadFinished: (context) => {
                stack_view.replace(null, overview_page, { context }, StackView.PushTransition)
            }
        }
    }

    Component {
        id: overview_page
        OverviewPage {
            Component.onDestruction: self.wallet.disconnect()
            onLogout: {
                const wallet = self.wallet
                if (wallet.login instanceof DeviceData) {
                    stack_view.replace(null, device_page, { wallet, login: false }, StackView.Immediate)
                    return
                } else if (wallet?.context?.device instanceof JadeDevice) {
                    stack_view.replace(null, jade_page, { device: wallet?.context?.device, login: false })
                    return
                }
                if (!wallet || !wallet.persisted) {
                    stack_view.replace(null, terms_of_service_page, {}, StackView.PushTransition)
                    return
                }
                if (wallet.login instanceof WatchonlyData) {
                    stack_view.replace(null, watch_only_login_page, { wallet }, StackView.PushTransition)
                    return
                }
                if (wallet.login instanceof PinData) {
                    stack_view.replace(null, pin_login_page, { wallet }, StackView.PushTransition)
                    return
                }
                stack_view.replace(null, restore_wallet_page, { wallet }, StackView.PushTransition)
            }
        }
    }
}
