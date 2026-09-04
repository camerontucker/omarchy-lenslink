import QtQuick
import QtTest
import ".."

Item {
    width: 500; height: 160
    CameraSlider { id: control; width: 480; readback: 0.2; from: 0; to: 1 }
    SignalSpy { id: requests; target: control; signalName: "requested" }
    TestCase {
        name: "CameraSlider"
        when: windowShown
        function test_poll_does_not_move_held_slider() {
            const slider = findChild(control, "cameraSliderInput")
            verify(slider !== null)
            mousePress(slider, 220, slider.height/2)
            mouseMove(slider, 300, slider.height/2, 20)
            const held = slider.value
            control.readback = 0.1
            wait(20)
            compare(slider.value, held)
            mouseRelease(slider, 300, slider.height/2)
            compare(requests.count, 1)
            compare(requests.signalArguments[0][0], held)
        }
    }
}
