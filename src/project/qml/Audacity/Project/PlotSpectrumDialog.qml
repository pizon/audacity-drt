/*
 * Audacity: A Digital Audio Editor
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Muse.Ui
import Muse.UiComponents
import Audacity.Project

StyledDialogView {
    id: root

    title: qsTrc("project/plotspectrum", "Frequency Analysis")

    contentWidth: 720
    contentHeight: 560
    resizable: true

    property alias model: spectrumModel

    PlotSpectrumModel {
        id: spectrumModel
    }

    Component.onCompleted: {
        if (!spectrumModel.load()) {
            root.reject()
        }
    }

    onClosed: {
        spectrumModel.close()
    }

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // Vertical axis labels
            Item {
                id: yAxis

                Layout.preferredWidth: 52
                Layout.fillHeight: true

                Repeater {
                    model: spectrumModel.yTicks

                    delegate: Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        y: plotArea.height * (1.0 - modelData.position) - height / 2
                        height: 16
                        visible: modelData.label !== ""

                        StyledTextLabel {
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignRight
                            text: modelData.label
                            font: ui.theme.bodyFont
                        }
                    }
                }

                StyledTextLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    text: spectrumModel.yUnit
                    font: ui.theme.bodyBoldFont
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                Rectangle {
                    id: plotArea

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#FEFEFE"
                    border.color: ui.theme.fontPrimaryColor
                    border.width: 1
                    clip: true

                    onWidthChanged: spectrumModel.plotWidth = Math.max(0, Math.floor(width) - 2)

                    Canvas {
                        id: plotCanvas
                        anchors.fill: parent
                        anchors.margins: 1

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.fillStyle = "#FFFFFF"
                            ctx.fillRect(0, 0, width, height)

                            var samples = spectrumModel.plotSamples
                            if (!samples || samples.length === 0) {
                                ctx.fillStyle = ui.theme.fontPrimaryColor
                                ctx.font = "12px sans-serif"
                                var msg = spectrumModel.hasEnoughData
                                          ? qsTrc("project/plotspectrum", "No data")
                                          : qsTrc("project/plotspectrum", "Not enough data selected.")
                                var metrics = ctx.measureText(msg)
                                ctx.fillText(msg, (width - metrics.width) / 2, height / 2)
                                return
                            }

                            if (spectrumModel.drawGrid) {
                                ctx.strokeStyle = "#DDDDDD"
                                ctx.lineWidth = 1
                                var xt = spectrumModel.xTicks
                                for (var i = 0; i < xt.length; ++i) {
                                    var x = xt[i].position * width
                                    ctx.beginPath()
                                    ctx.moveTo(x, 0)
                                    ctx.lineTo(x, height)
                                    ctx.stroke()
                                }
                                var yt = spectrumModel.yTicks
                                for (var j = 0; j < yt.length; ++j) {
                                    var y = (1.0 - yt[j].position) * height
                                    ctx.beginPath()
                                    ctx.moveTo(0, y)
                                    ctx.lineTo(width, y)
                                    ctx.stroke()
                                }
                            }

                            ctx.fillStyle = spectrumModel.algorithm === 0 ? "#2C5AA0" : "#2C8A5A"
                            for (var k = 0; k < samples.length; ++k) {
                                var h = samples[k] * (height - 1)
                                if (h > 0) {
                                    ctx.fillRect(k, height - h, 1, h)
                                }
                            }

                            if (spectrumModel.hoverActive && spectrumModel.peakPosition >= 0) {
                                var px = spectrumModel.peakPosition * width
                                ctx.strokeStyle = "#FF2020"
                                ctx.beginPath()
                                ctx.moveTo(px, 0)
                                ctx.lineTo(px, height)
                                ctx.stroke()
                            }
                        }

                        Connections {
                            target: spectrumModel
                            function onPlotChanged() { plotCanvas.requestPaint() }
                            function onHoverChanged() { plotCanvas.requestPaint() }
                            function onDrawGridChanged() { plotCanvas.requestPaint() }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: containsMouse ? Qt.CrossCursor : Qt.ArrowCursor

                            onPositionChanged: function(mouse) {
                                spectrumModel.updateHover(mouse.x, mouse.y, width, height)
                            }
                            onExited: spectrumModel.clearHover()
                        }
                    }
                }

                // Horizontal axis
                Item {
                    id: xAxis
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    Repeater {
                        model: spectrumModel.xTicks

                        delegate: Item {
                            x: modelData.position * parent.width - width / 2
                            width: 48
                            height: parent.height
                            visible: modelData.label !== ""

                            StyledTextLabel {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                text: modelData.label
                                font: ui.theme.bodyFont
                            }
                        }
                    }

                    StyledTextLabel {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        text: spectrumModel.xUnit
                        font: ui.theme.bodyBoldFont
                    }
                }
            }

            // Zoom / pan controls
            ColumnLayout {
                Layout.preferredWidth: 36
                Layout.fillHeight: true
                spacing: 4

                StyledTextLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: "+"
                }

                Slider {
                    id: zoomSlider
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignHCenter
                    orientation: Qt.Vertical
                    from: 1
                    to: 100
                    stepSize: 1
                    value: spectrumModel.zoom
                    onMoved: spectrumModel.zoom = value
                }

                StyledTextLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: "−"
                }

                ScrollBar {
                    id: panBar
                    Layout.fillHeight: true
                    Layout.preferredWidth: 12
                    Layout.alignment: Qt.AlignHCenter
                    orientation: Qt.Vertical
                    policy: ScrollBar.AlwaysOn
                    size: spectrumModel.panMax > 0 ? spectrumModel.panPage / spectrumModel.panMax : 1
                    position: spectrumModel.panMax > 0 ? spectrumModel.pan / spectrumModel.panMax : 0
                    onPositionChanged: {
                        if (spectrumModel.panMax > 0) {
                            spectrumModel.pan = Math.round(position * spectrumModel.panMax)
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            StyledTextLabel {
                text: qsTrc("project/plotspectrum", "Cursor:")
            }
            TextInputField {
                Layout.fillWidth: true
                readOnly: true
                currentText: spectrumModel.cursorText
            }

            StyledTextLabel {
                text: qsTrc("project/plotspectrum", "Peak:")
            }
            TextInputField {
                Layout.fillWidth: true
                readOnly: true
                currentText: spectrumModel.peakText
            }

            CheckBox {
                text: qsTrc("project/plotspectrum", "Grids")
                checked: spectrumModel.drawGrid
                onClicked: spectrumModel.drawGrid = !spectrumModel.drawGrid
            }
        }

        ProgressBar {
            Layout.fillWidth: true
            visible: spectrumModel.analyzing
            from: 0
            to: 1
            value: spectrumModel.progress
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 6
            columnSpacing: 8
            rowSpacing: 8

            StyledTextLabel { text: qsTrc("project/plotspectrum", "Algorithm:") }
            StyledDropdown {
                Layout.fillWidth: true
                Layout.columnSpan: 1
                model: spectrumModel.algorithmNames
                currentIndex: spectrumModel.algorithm
                onActivated: function(index, value) { spectrumModel.algorithm = index }
            }

            StyledTextLabel { text: qsTrc("project/plotspectrum", "Size:") }
            StyledDropdown {
                Layout.fillWidth: true
                model: spectrumModel.sizeNames
                currentIndex: spectrumModel.sizeChoice
                onActivated: function(index, value) { spectrumModel.sizeChoice = index }
            }

            FlatButton {
                text: qsTrc("project/plotspectrum", "Export...")
                onClicked: spectrumModel.exportData()
            }

            FlatButton {
                text: qsTrc("project/plotspectrum", "Replot")
                onClicked: spectrumModel.replot()
            }

            StyledTextLabel { text: qsTrc("project/plotspectrum", "Function:") }
            StyledDropdown {
                Layout.fillWidth: true
                model: spectrumModel.windowFuncNames
                currentIndex: spectrumModel.windowFunc
                onActivated: function(index, value) { spectrumModel.windowFunc = index }
            }

            StyledTextLabel { text: qsTrc("project/plotspectrum", "Axis:") }
            StyledDropdown {
                Layout.fillWidth: true
                enabled: spectrumModel.axisEnabled
                model: spectrumModel.axisNames
                currentIndex: spectrumModel.axisChoice
                onActivated: function(index, value) { spectrumModel.axisChoice = index }
            }

            Item { Layout.fillWidth: true; Layout.columnSpan: 2 }
        }

        ButtonBox {
            Layout.fillWidth: true
            navigationPanel.section: root.navigationSection

            FlatButton {
                text: qsTrc("global", "Close")
                buttonRole: ButtonBoxModel.AcceptRole
                buttonId: ButtonBoxModel.Close
                onClicked: {
                    spectrumModel.close()
                    root.accept()
                }
            }
        }
    }
}
