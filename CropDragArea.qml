import QtQuick

MouseArea {
    id: area
    signal dragged(real dx, real dy)
    signal finished()
    signal zoomed(real logarithmicDelta)
    property bool panEnabled: true
    hoverEnabled: true
    onWheel: function(wheel) {
        const amount = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y * 0.004 : wheel.angleDelta.y / 120 * 0.12
        if (amount !== 0) zoomed(amount)
        wheel.accepted = true
    }
    PinchHandler {
        target: null
        onScaleChanged: function(delta) { if (active && delta > 0) area.zoomed(Math.log(delta)) }
    }
    cursorShape: pressed ? Qt.ClosedHandCursor : (enabled && panEnabled ? Qt.OpenHandCursor : Qt.ArrowCursor)
    preventStealing: true
    property real lastX: 0
    property real lastY: 0
    onPressed: function(mouse) { lastX = mouse.x; lastY = mouse.y }
    onPositionChanged: function(mouse) {
        if (!pressed || !panEnabled) return
        dragged(mouse.x-lastX, mouse.y-lastY)
        lastX = mouse.x; lastY = mouse.y
    }
    onReleased: finished()
}
