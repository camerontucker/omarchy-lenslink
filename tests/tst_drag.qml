import QtQuick
import QtTest
import ".."

Item {
    width: 500; height: 400
    Flickable {
        anchors.fill: parent
        contentHeight: 800
        CropDragArea {
            id: drag
            width: 480; height: 270
        }
    }
    SignalSpy { id: moves; target: drag; signalName: "dragged" }
    SignalSpy { id: zoom; target: drag; signalName: "zoomed" }
    SignalSpy { id: finished; target: drag; signalName: "finished" }
    TestCase {
        name: "CropDrag"
        when: windowShown
        function init() { moves.clear(); finished.clear(); zoom.clear(); drag.enabled = true; drag.panEnabled = true }
        function test_continuous_drag_survives_scroll_container() {
            mousePress(drag, 100, 100)
            mouseMove(drag, 140, 120, 30)
            mouseMove(drag, 180, 150, 30)
            mouseRelease(drag, 180, 150)
            compare(finished.count, 1)
            let dx=0, dy=0
            for (const args of moves.signalArguments) { dx+=args[0]; dy+=args[1] }
            compare(dx, 80); compare(dy, 50)
        }
        function test_wheel_zooms_at_full_frame_without_panning() {
            drag.panEnabled = false
            mouseWheel(drag, 100, 100, 0, 120)
            compare(zoom.count, 1)
            verify(zoom.signalArguments[0][0] > 0)
            mouseWheel(drag, 100, 100, 0, -120)
            compare(zoom.count, 2)
            verify(zoom.signalArguments[1][0] < 0)
            mouseDrag(drag, 100, 100, 40, 20)
            compare(moves.count, 0)
        }
        function test_disabled_crop_does_not_pan() {
            drag.enabled = false
            mouseDrag(drag, 100, 100, 80, 50)
            compare(moves.count, 0)
        }
    }
}
