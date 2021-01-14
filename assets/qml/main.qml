/*
 * Copyright (c) 2020-2021 Alex Spataru <https://github.com/alex-spataru>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import QtQuick 2.12
import QtQuick.Dialogs 1.1
import QtQuick.Window 2.12
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.12

import Qt.labs.settings 1.0

import "Windows"

ApplicationWindow {
    id: app

    //
    // Global properties
    //
    readonly property int spacing: 8
    property bool firstValidPacket: false
    readonly property color windowBackgroundColor: "#121920"
    readonly property string monoFont: {
        switch (Qt.platform.os) {
        case "osx":
            return "Menlo"
        case "windows":
            return "Consolas"
        default:
            return "Monospace"
        }
    }

    //
    // We use this variable to ask the user if he/she wants to enable/disable
    // automatic update checking on the second run
    //
    property int appLaunchStatus: 0
    property bool automaticUpdates: false

    //
    // Window geometry
    //
    visible: false
    minimumWidth: 1080
    minimumHeight: 660
    title: CppAppName + " v" + CppAppVersion

    //
    // Theme options
    //
    palette.text: "#fff"
    palette.buttonText: "#fff"
    palette.windowText: "#fff"
    palette.window: app.windowBackgroundColor

    //
    // Startup code
    //
    Component.onCompleted: {
        // Hide dialogs, show devices pane
        about.hide()
        devices.show()
        csvPlayer.hide()

        // Hide everything except the terminal
        data.opacity = 0
        widgets.opacity = 0
        terminal.opacity = 1

        // Load JSON map file (if any)
        CppJsonGenerator.readSettings()

        // Display the window & check for updates in 500 ms (we do this so that
        // we wait for the window to read settings before showing it)
        timer.start()
    }

    //
    // Clears the console text & displays a mini-tutorial
    //
    function showWelcomeGuide() {
        terminal.text = CppTranslator.welcomeConsoleText()  + "\n\n"
    }

    //
    // Startup timer
    //
    Timer {
        id: timer
        interval: 500
        onTriggered: {
            // Startup verifications to ensure that bad settings
            // do not make our app reside outside screen
            if (x < 0 || x >= Screen.desktopAvailableWidth)
                x = 100
            if (y < 0 || y >= Screen.desktopAvailableHeight)
                y = 100

            // Startup verifications to ensure that app fits in current screen
            if (width > Screen.desktopAvailableWidth) {
                x = 100
                width = Screen.desktopAvailableWidth - x
            }

            // Startup verifications to ensure that app fits in current screen
            if (height > Screen.desktopAvailableHeight) {
                y = 100
                height = Screen.desktopAvailableHeight - y
            }

            // Show app window
            app.visible = true
            app.showWelcomeGuide()

            // Increment app launch count until 3:
            // Value & meaning:
            // - 1: first launch
            // - 2: second launch, ask to enable automatic updater
            // - 3: we don't care the number of times the user launched the app
            if (appLaunchStatus < 3)
                ++appLaunchStatus

            // Second launch ask user if he/she wants to enable automatic updates
            if (appLaunchStatus == 2)
                automaticUpdatesMessageDialog.visible = true

            // Check for updates (if we are allowed)
            if (automaticUpdates)
                CppUpdater.checkForUpdates(CppAppUpdaterUrl)
        }
    }

    //
    // Hide console & device manager when we receive first valid packet
    //
    Connections {
        target: CppJsonGenerator
        enabled: !app.firstValidPacket
        function onPacketReceived()  {
            app.firstValidPacket = true
            uiConfigTimer.start()
        }
    } Timer {
        id: uiConfigTimer
        interval: 250
        onTriggered: {
            devices.hide()
            toolbar.dataClicked()
        }
    }

    //
    // Show console tab on serial disconnect
    //
    Connections {
        target: CppDataProvider
        function onDataReset() {
            toolbar.consoleClicked()
            devices.show()
            app.firstValidPacket = false
        }
    }

    //
    // Save window size & position
    //
    Settings {
        property alias appX: app.x
        property alias appY: app.y
        property alias appW: app.width
        property alias appH: app.height
        property alias appStatus: app.appLaunchStatus
        property alias autoUpdater: app.automaticUpdates
    }

    //
    // Main layout
    //
    ColumnLayout {
        spacing: 0
        anchors.fill: parent

        Toolbar {
            z: 1
            id: toolbar
            Layout.fillWidth: true
            Layout.minimumHeight: 48
            Layout.maximumHeight: 48
            dataChecked: data.visible
            aboutChecked: about.visible
            consoleChecked: terminal.visible
            widgetsChecked: widgets.visible
            devicesChecked: devices.visible
            onAboutClicked: about.visible ? about.hide() : about.show()
            onDevicesClicked: devices.visible ? devices.hide() : devices.show()

            onDataClicked: {
                data.opacity    = 1
                terminal.opacity = 0
                widgets.opacity = 0
                dataChecked     = true
                consoleChecked  = false
                widgetsChecked  = false
            }

            onConsoleClicked: {
                data.opacity    = 0
                terminal.opacity = 1
                widgets.opacity = 0
                consoleChecked  = true
                dataChecked     = false
                widgetsChecked  = false
            }

            onWidgetsClicked: {
                data.opacity    = 0
                terminal.opacity = 0
                widgets.opacity = 1
                dataChecked     = false
                widgetsChecked  = true
                consoleChecked  = false
            }
        }

        RowLayout {
            spacing: 0
            clip: true
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Console {
                    id: terminal
                    anchors.fill: parent

                    // Animate on show
                    enabled: opacity > 0
                    visible: opacity > 0
                    Behavior on opacity {NumberAnimation{}}

                    // Show translated welcome text on lang. change
                    Connections {
                        target: CppTranslator
                        function onLanguageChanged() {
                            app.showWelcomeGuide()
                        }
                    }
                }

                DataGrid {
                    id: data
                    anchors.fill: parent

                    // Animate on show
                    visible: opacity > 0
                    Behavior on opacity {NumberAnimation{}}
                }

                Widgets {
                    id: widgets
                    anchors.fill: parent

                    // Animate on show
                    enabled: opacity > 0
                    visible: opacity > 0
                    Behavior on opacity {NumberAnimation{}}
                }
            }

            DeviceManager {
                id: devices
                property int displayedWidth: 320

                function show() {
                    opacity = 1
                    displayedWidth = 320
                }

                function hide() {
                    opacity = 0
                    displayedWidth = 0
                }

                visible: opacity > 0
                Layout.fillHeight: true
                Layout.minimumWidth: displayedWidth
                Layout.maximumWidth: displayedWidth

                Behavior on opacity {NumberAnimation{}}
                Behavior on displayedWidth {NumberAnimation{}}
            }
        }
    }

    //
    // About window
    //
    About {
        id: about
    }

    //
    // CSV player window
    //
    CsvPlayer {
        id: csvPlayer
    }

    //
    // Enable/disable automatic updates dialog
    //
    MessageDialog {
        id: automaticUpdatesMessageDialog

        title: CppAppName
        icon: StandardIcon.Question
        modality: Qt.ApplicationModal
        standardButtons: StandardButton.Yes | StandardButton.No
        text: "<h3>" + qsTr("Check for updates automatically?") + "</h3>"
        informativeText: qsTr("Should %1 automatically check for updates? " +
                              "You can always check for updates manually from " +
                              "the \"About\" dialog").arg(CppAppName);

        // Behavior when the user clicks on "Yes"
        onAccepted: {
            app.automaticUpdates = true
            CppUpdater.checkForUpdates(CppAppUpdaterUrl)
        }

        // Behavior when the user clicks on "No"
        onRejected: {
            app.automaticUpdates = false
        }
    }
}
