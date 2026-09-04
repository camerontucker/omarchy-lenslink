pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: control
    property string label: ""
    property real readback: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0.1
    property int decimals: 1
    property string suffix: ""
    property color foreground: "white"
    signal requested(real value)
    Layout.fillWidth: true
    spacing: 2
    Text {
        text: control.label + " · " + slider.value.toFixed(control.decimals) + control.suffix
        color: control.foreground
        textFormat: Text.PlainText
    }
    Slider {
        id: slider
        objectName: "cameraSliderInput"
        Layout.fillWidth: true
        from: control.from; to: Math.max(control.from + 0.000001, control.to)
        stepSize: control.stepSize
        Binding {
            target: slider; property: "value"; value: control.readback
            when: !slider.pressed && !settle.running
            restoreMode: Binding.RestoreNone
        }
        onPressedChanged: if (!pressed && enabled) { settle.restart(); control.requested(value) }
        onMoved: if (!pressed) keyboardCommit.restart()
        Timer { id: keyboardCommit; interval: 150; onTriggered: { settle.restart(); control.requested(slider.value) } }
        Timer { id: settle; interval: 1800 }
    }
}
