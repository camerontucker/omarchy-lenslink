import QtQuick

// Keep the clock fixed. Restarting a gesture timer and binding this timer's
// interval to it postpones every frame until pointer movement stops.
Timer {
    id: scheduler
    interval: 33
    repeat: true
    property bool inFlight: false
    property bool pendingWork: false
    property double interactiveUntil: 0
    property double lastDispatch: 0
    signal dispatch()

    function interaction() { interactiveUntil = Date.now() + 250 }

    onTriggered: {
        if (inFlight) return
        const now = Date.now()
        if (!pendingWork && now >= interactiveUntil && now - lastDispatch < 100) return
        lastDispatch = now
        dispatch()
    }
}
