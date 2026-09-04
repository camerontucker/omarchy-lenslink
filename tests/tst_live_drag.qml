import QtQuick
import QtTest
import ".."

Item {
    id: root
    width: 500; height: 300
    property real pendingX: 0
    property real pendingY: 0
    property int previewUpdates: 0
    property int updatesWhilePressed: 0
    property bool inFlight: false
    CropDragArea {
        id: drag
        anchors.fill: parent
        onDragged: function(dx,dy) {
            root.pendingX += dx; root.pendingY += dy
            scheduler.interaction()
        }
    }
    ViewScheduler {
        id: scheduler
        running: true
        inFlight: root.inFlight
        pendingWork: root.pendingX !== 0 || root.pendingY !== 0
        onDispatch: {
            root.inFlight = true
            root.pendingX = 0; root.pendingY = 0
            response.start()
        }
    }
    // Emulate async OBS completion; same one-in-flight contract as Panel.qml.
    Timer {
        id: response
        interval: 8
        onTriggered: {
            root.previewUpdates++
            if (drag.pressed) root.updatesWhilePressed++
            root.inFlight = false
        }
    }
    TestCase {
        name: "PreviewDuringDrag"
        when: windowShown
        function test_frames_arrive_before_pointer_release() {
            root.previewUpdates = 0; root.updatesWhilePressed = 0
            mousePress(drag, 100, 100)
            for (let i=1; i<=60; i++) {
                mouseMove(drag, 100+i*2, 100+i, 1)
                wait(5)
            }
            verify(drag.pressed)
            verify(root.updatesWhilePressed >= 3,
                   "Continuous pointer input must not starve preview responses")
            mouseRelease(drag, 220, 160)
            tryCompare(root, "pendingX", 0)
            tryCompare(root, "pendingY", 0)
        }
        function test_inflight_response_coalesces_input() {
            response.stop()
            root.inFlight = true
            root.pendingX = 42
            const before = root.previewUpdates
            wait(120)
            compare(root.previewUpdates, before)
            compare(root.pendingX, 42)
            root.inFlight = false
            tryCompare(root, "pendingX", 0)
        }
    }
}
