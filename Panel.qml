pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    property var manifest: null
    moduleName: "io.github.camerontucker.lenslink"
    ipcTarget: "lenslink.camera"
    manageIpc: false
    property var cameraStatus: ({connected: false, standby: false, camera: {}, obs: {available: false, virtual: false, scene: ""}, status: "Checking LensLink…"})
    property string message: ""
    property bool previewEnabled: true
    property string previewImage: ""
    property string previewScene: ""
    property int pollFailures: 0
    property int obsFailures: 0
    property string previewError: ""
    property double lastFrameAt: 0
    property int previewFrames: 0
    property real pendingPanX: 0
    property real pendingPanY: 0
    property real pendingZoom: 0
    property real requestedZoom: 0
    property var viewFraming: null
    property bool viewReady: false
    property bool viewBusy: false
    readonly property bool viewWanted: opened && cameraStatus.obs.available
    function queueZoom(delta) {
        const base = requestedZoom || framing.zoom || 1
        pendingZoom = Math.max(1, Math.min(5, base * Math.exp(delta)))
        requestedZoom = pendingZoom
        viewScheduler.interaction()
        flushPan()
    }
    property var lensChoices: []
    property var resolutionChoices: []
    property var fpsChoices: []
    property var codecChoices: []
    property var micChoices: []
    property var micLabels: []
    readonly property var framing: viewFraming || cameraStatus.obs.framing || ({zoom: 1})
    function updateChoices(name, value) {
        const next = value || []
        if (JSON.stringify(root[name]) !== JSON.stringify(next)) root[name] = next
    }
    function flushPan() {
        if (!viewReady || viewBusy || !viewProc.running || busy) return
        let name = "frame", args = []
        if (pendingZoom) { name = "zoom"; args = [pendingZoom]; pendingZoom = 0 }
        else if (pendingPanX || pendingPanY) {
            name = "pan"; args = [pendingPanX, pendingPanY, previewBox.width, previewBox.height]
            pendingPanX = 0; pendingPanY = 0
        } else if (!snapshotActive) return
        viewBusy = true
        viewDeadline.restart()
        viewProc.write(JSON.stringify({command: name, arguments: args, preview: snapshotActive}) + "\n")
    }
    readonly property bool snapshotActive: opened && previewEnabled && cameraStatus.obs.available && !previewActive
    readonly property bool busy: action.running
    readonly property var cameraState: cameraStatus.camera || ({})
    readonly property var connectionState: cameraStatus.obs.connection || ({})
    readonly property bool live: cameraStatus.connected && !cameraStatus.standby
    readonly property string backend: Qt.resolvedUrl("lenslink_backend.py").toString().replace("file://", "")
    readonly property var virtualDevice: {
        const inputs = devices.videoInputs
        for (let i = 0; i < inputs.length; ++i)
            if (String(inputs[i].description).toLowerCase().indexOf("obs virtual camera") >= 0) return inputs[i]
        return devices.defaultVideoInput
    }
    readonly property bool virtualAvailable: String(virtualDevice.description || "").toLowerCase().indexOf("obs virtual camera") >= 0
    readonly property bool previewActive: opened && previewEnabled && cameraStatus.obs.virtual && virtualAvailable
    function command(name, args) {
        return ["/usr/bin/timeout", "--kill-after=1s", "14s", "/usr/bin/python3", "-I", "-B", backend, name].concat((args || []).map(function(v) { return JSON.stringify(v) }))
    }
    function refresh() { if (!poll.running && !busy) poll.running = true }
    function run(name, args) {
        if (busy) return
        message = "Working…"
        action.command = command(name, args)
        action.running = true
    }
    function safe(value) { return String(value || "").replace(/</g, "＜").replace(/>/g, "＞").replace(/&/g, "＆") }
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    visible: true
    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰄀"
        opacity: root.live ? 1 : 0.5
        tooltipText: "iPhone LensLink · " + root.safe(root.cameraStatus.status)
        onPressed: function(code) {
            if (code === Qt.MiddleButton) root.refresh()
            else if (root.opened) root.close()
            else root.open()
        }
    }
    BoundedProcess {
        id: poll
        command: root.command("state")
        onCompleted: function(output, error, code) {
            try {
                const data = JSON.parse(output)
                if (code !== 0 || typeof data.connected !== "boolean" || !data.obs || !data.camera) throw new Error("invalid")
                root.pollFailures = 0
                if (!data.obs.available && root.cameraStatus.obs.available && root.obsFailures < 2) {
                    root.obsFailures += 1
                    data.obs = root.cameraStatus.obs
                } else root.obsFailures = data.obs.available ? 0 : root.obsFailures + 1
                root.cameraStatus = data
                if (!root.viewBusy && !root.pendingZoom && !root.pendingPanX && !root.pendingPanY)
                    root.viewFraming = data.obs.framing || null
                root.updateChoices("lensChoices", data.camera.lenses)
                root.updateChoices("resolutionChoices", data.camera.resolutions)
                root.updateChoices("fpsChoices", data.camera.frameRates)
                root.updateChoices("codecChoices", data.camera.codecs)
                root.updateChoices("micChoices", (data.camera.mics || []).map(function(m) { return m.id }))
                root.updateChoices("micLabels", (data.camera.mics || []).map(function(m) { return m.name }))
            } catch (e) {
                root.pollFailures += 1
                if (root.pollFailures >= 3) root.cameraStatus = {connected: false, standby: false, camera: {}, obs: {available: false, virtual: false, scene: ""}, status: "Status unavailable; retrying"}
            }
        }
    }
    BoundedProcess {
        id: action
        onCompleted: function(output, error, code) {
            try { const data = JSON.parse(output); root.message = String(data.error || data.message || "Finished") }
            catch (e) { root.message = "Camera request failed" }
            refreshAfterAction.restart()
        }
    }
    BoundedProcess {
        id: viewProc
        outputLimit: 131072
        streaming: true
        stdinEnabled: true
        command: ["/usr/bin/python3", "-I", "-B", "-u", root.backend, "view_serve"]
        onLineReady: function(line) {
            viewDeadline.stop()
            root.viewBusy = false
            try {
                const data = JSON.parse(line)
                if (data.ready === true) { root.viewReady = true; root.flushPan(); return }
                if (data.error) {
                    root.previewError = String(data.error)
                    root.requestedZoom = 0
                    viewProc.running = false
                    return
                }
                root.viewFraming = data.framing || null
                if (!root.pendingZoom) root.requestedZoom = 0
                if (root.snapshotActive && typeof data.image === "string") {
                    root.previewImage = data.image
                    root.previewFrames += 1
                    root.lastFrameAt = Date.now()
                    root.previewScene = String(data.scene)
                }
                root.previewError = ""
            } catch (e) { root.previewError = "Preview paused; retrying…" }
        }
        onCompleted: {
            root.viewReady = false; root.viewBusy = false
            root.pendingPanX = 0; root.pendingPanY = 0; root.pendingZoom = 0; root.requestedZoom = 0
            viewDeadline.stop()
            if (root.viewWanted) viewRestart.restart()
        }
    }
    Timer { id: viewDeadline; interval: 9000; onTriggered: { root.previewError = "OBS response timed out; reconnecting…"; viewProc.running = false } }
    Timer { id: viewRestart; interval: 800; onTriggered: if (root.viewWanted) viewProc.running = true }
    ViewScheduler {
        id: viewScheduler
        running: root.viewWanted
        inFlight: root.viewBusy || root.busy
        pendingWork: root.pendingZoom !== 0 || root.pendingPanX !== 0 || root.pendingPanY !== 0
        onDispatch: root.flushPan()
    }
    onViewWantedChanged: {
        if (viewWanted) { viewProc.running = true; viewDeadline.restart() }
        else {
            viewRestart.stop(); viewProc.running = false; viewFraming = null
            previewImage = ""; previewError = ""
        }
    }
    onSnapshotActiveChanged: if (!opened || !previewEnabled) { previewImage = ""; previewError = "" }
    Timer { id: refreshAfterAction; interval: 500; onTriggered: root.refresh() }
    Timer { interval: root.opened ? 3000 : 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    onOpenedChanged: {
        if (opened) refresh()
        else { pendingPanX = 0; pendingPanY = 0; pendingZoom = 0; requestedZoom = 0; previewImage = ""; previewError = "" }
    }
    IpcHandler {
        target: root.ipcTarget
        function open(): void { root.open() }
        function close(): void { root.close() }
        function refresh(): void { root.refresh() }
        function page(name: string): void {
            const index = ["camera", "exposure", "format"].indexOf(name)
            if (index >= 0) { tabs.currentIndex = index; root.open() }
        }
        function diagnostics(): string {
            return JSON.stringify({opened: root.opened, live: root.live, status: root.cameraStatus.status,
                obs: root.cameraStatus.obs, previewActive: root.previewActive, snapshotActive: root.snapshotActive, snapshotReady: root.previewImage !== "", previewFrames: root.previewFrames, viewReady: root.viewReady, viewBusy: root.viewBusy, previewError: root.previewError, frameAgeMs: root.lastFrameAt ? Date.now() - root.lastFrameAt : -1, framing: root.framing, videoWidth: video.sourceRect.width,
                videoHeight: video.sourceRect.height, cameraError: camera.errorString, busy: root.busy, previewEnabled: root.previewEnabled, devices: devices.videoInputs.map(function(d) { return String(d.description) })})
        }
    }
    MediaDevices { id: devices }
    Camera { id: camera; cameraDevice: root.virtualDevice; active: root.previewActive }
    CaptureSession { camera: camera; videoOutput: video }
    KeyboardPanel {
        id: popup
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keys
        contentWidth: popup.fittedContentWidth(Style.space(420))
        contentHeight: popup.fittedContentHeight(content.implicitHeight, Style.space(730))
        PanelKeyCatcher {
            id: keys
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction) }
            ScrollView {
                id: scroll
                contentWidth: availableWidth
                anchors.fill: parent
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    id: content
                    width: scroll.availableWidth
                    spacing: 10
                    PanelHero {
                        Layout.fillWidth: true
                        title: "iPhone LensLink"
                        meta: root.safe(root.cameraStatus.status)
                        foreground: root.barForeground
                        fontFamily: root.bar ? root.bar.fontFamily : "sans-serif"
                    }
                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        color: root.barForeground
                        text: (root.cameraState.lens || "iPhone") + " · " + (root.connectionState.mode === "dial" ? "Wi-Fi" : root.connectionState.mode === "usb" ? "USB" : "LensLink") + (root.cameraState.resolution ? " · " + root.cameraState.resolution : "") + (root.cameraState.fps ? " · " + root.cameraState.fps + " fps" : "")
                    }
                    Rectangle {
                        id: previewBox
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.preferredHeight: width * 9 / 16
                        Layout.maximumHeight: width * 9 / 16
                        color: "#111111"
                        radius: 8
                        clip: true
                        VideoOutput { id: video; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectFit; visible: root.previewActive }
                        Image {
                            anchors.fill: parent
                            source: root.previewImage
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            asynchronous: true
                            retainWhileLoading: true
                            visible: root.snapshotActive && root.previewImage !== ""
                        }
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 28
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            color: "#dddddd"
                            visible: (!root.previewActive && (!root.snapshotActive || root.previewImage === "")) || (root.previewActive && camera.error !== Camera.NoError)
                            text: camera.error !== Camera.NoError && root.previewActive ? camera.errorString : (root.snapshotActive ? "Loading OBS preview…" : "Open OBS and enable Preview to see your meeting output.")
                            textFormat: Text.PlainText
                        }
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.previewError
                            color: "#ffcc66"
                            visible: root.previewError !== ""
                        }
                        CropDragArea {
                            anchors.fill: parent
                            enabled: (root.previewActive || root.snapshotActive) && root.cameraStatus.obs.scene === "iPhone LensLink"
                            panEnabled: root.framing.zoom > 1.001
                            onZoomed: function(delta) { root.queueZoom(delta) }
                            onDragged: function(dx, dy) { root.pendingPanX += dx; root.pendingPanY += dy; viewScheduler.interaction() }
                            onFinished: root.flushPan()
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "OBS output · " + (root.snapshotActive ? root.previewScene : root.cameraStatus.obs.scene) + (root.snapshotActive ? " · preview" : "")
                        color: root.barForeground
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                    }
                    Button {
                        visible: !root.cameraStatus.obs.available
                        text: "Start OBS"
                        onClicked: {
                            Quickshell.execDetached(["/usr/bin/systemctl", "--user", "start", "obs-lenslink.service"])
                            root.message = "Starting OBS; waiting for its WebSocket server…"
                            refreshAfterAction.restart()
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Button { text: "Use iPhone scene"; enabled: root.cameraStatus.obs.available && !root.busy; onClicked: root.run("select_scene") }
                        Button {
                            text: !root.cameraStatus.obs.virtualSupported ? "Virtual camera unavailable" : (root.cameraStatus.obs.virtual ? "Stop virtual camera" : "Start virtual camera")
                            enabled: root.cameraStatus.obs.virtualSupported && root.cameraStatus.obs.available && !root.busy && (root.cameraStatus.obs.virtual || (root.live && root.cameraStatus.obs.scene === "iPhone LensLink"))
                            onClicked: root.run(root.cameraStatus.obs.virtual ? "stop_virtual" : "start_virtual")
                        }
                    }
                    RowLayout {
                        CheckBox { text: "Preview"; checked: root.previewEnabled; onToggled: root.previewEnabled = checked }
                        Button { text: "Center crop"; enabled: root.cameraStatus.obs.scene === "iPhone LensLink" && !root.busy; onClicked: root.run("center") }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Orientation"; color: root.barForeground }
                        ComboBox {
                            Layout.fillWidth: true
                            model: ["Landscape", "Portrait", "Landscape flipped", "Portrait flipped"]
                            currentIndex: [0, 90, 180, 270].indexOf(Number(root.framing.rotation))
                            enabled: root.cameraStatus.obs.scene === "iPhone LensLink" && currentIndex >= 0 && !root.busy
                            onActivated: function(index) { root.run("orientation", [[0, 90, 180, 270][index]]) }
                        }
                        Button {
                            text: "Rotate 180°"
                            enabled: root.cameraStatus.obs.scene === "iPhone LensLink" && typeof root.framing.rotation === "number" && !root.busy
                            onClicked: root.run("rotate_180")
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.framing.zoom > 1.001 ? "Drag to reframe · pinch or scroll over the picture to zoom" : "Pinch or scroll over the picture to zoom, then drag to reframe."
                        wrapMode: Text.WordWrap
                        color: root.barForeground
                        opacity: 0.65
                        font.pixelSize: 12
                    }
                    CameraSlider {
                        label: "Framing zoom"; from: 1; to: 5; stepSize: 0.05; suffix: "×"
                        readback: root.framing.zoom
                        foreground: root.barForeground
                        enabled: !!root.cameraStatus.obs.framing && !root.busy
                        onRequested: function(value) { root.run("framing_zoom", [value]) }
                    }
                    Button {
                        visible: Number(root.cameraState.zoom || 1) > 1.01
                        text: "Make current lens zoom draggable"
                        enabled: !!root.cameraStatus.obs.framing && !root.busy
                        onClicked: root.run("convert_zoom")
                    }
                    TabBar {
                        id: tabs
                        Layout.fillWidth: true
                        TabButton { text: "Camera"; topPadding: 10; bottomPadding: 10; leftPadding: 14; rightPadding: 14 }
                        TabButton { text: "Exposure / WB"; topPadding: 10; bottomPadding: 10; leftPadding: 14; rightPadding: 14 }
                        TabButton { text: "Format / audio"; topPadding: 10; bottomPadding: 10; leftPadding: 14; rightPadding: 14 }
                    }
                    ColumnLayout {
                        visible: tabs.currentIndex === 0
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Connection · " + (root.connectionState.mode === "dial" ? "Wi-Fi" : root.connectionState.mode === "usb" ? "USB" : "unavailable")
                            textFormat: Text.PlainText
                            color: root.barForeground
                        }
                        TextField {
                            id: wifiAddress
                            Layout.fillWidth: true
                            placeholderText: "Phone IP address shown in LensLink"
                            maximumLength: 64
                            enabled: !!root.connectionState.mode && !root.busy
                            Binding {
                                target: wifiAddress; property: "text"
                                value: root.connectionState.host || ""
                                when: !wifiAddress.activeFocus && !wifiAddress.edited
                                restoreMode: Binding.RestoreNone
                            }
                            property bool edited: false
                            onTextEdited: edited = true
                        }
                        RowLayout {
                            Button {
                                text: "Connect over Wi-Fi"
                                enabled: !!root.connectionState.mode && wifiAddress.text.trim() !== "" && !root.busy
                                onClicked: root.run("connection", [{mode: "dial", host: wifiAddress.text.trim()}])
                            }
                            Button {
                                text: "Use USB"
                                enabled: !!root.connectionState.mode && root.connectionState.mode !== "usb" && !root.busy
                                onClicked: root.run("connection", [{mode: "usb"}])
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "For Wi-Fi, keep LensLink open and use the same network as this computer. Switching reconnects the camera."
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            color: root.barForeground
                            opacity: 0.7
                        }
                        ComboBox {
                            Layout.fillWidth: true
                            model: root.lensChoices
                            currentIndex: root.lensChoices.indexOf(root.cameraState.lens)
                            enabled: root.live && count > 0 && !root.busy
                            onActivated: root.run("selectLens", [currentText])
                        }
                        CameraSlider {
                            label: "Lens zoom (fixed center)"; from: 1; to: Number(root.cameraState.maxZoom || 1); suffix: "×"
                            readback: Number(root.cameraState.zoom || 1)
                            foreground: root.barForeground
                            enabled: root.live && typeof root.cameraState.zoom === "number" && !root.busy
                            onRequested: function(value) { root.run("zoom", [value]) }
                        }
                        RowLayout {
                            Button { text: "Auto focus"; selected: root.cameraState.focusMode === "auto"; enabled: root.live && !!root.cameraState.focusMode && !root.busy; onClicked: root.run("focus", ["auto"]) }
                            Button { text: "Lock focus"; selected: root.cameraState.focusMode === "locked"; enabled: root.live && typeof root.cameraState.lensPosition === "number" && !root.busy; onClicked: root.run("focus", ["locked"]) }
                        }
                        CameraSlider {
                            label: "Manual focus"; from: 0; to: 1; stepSize: 0.01; decimals: 2
                            readback: Number(root.cameraState.lensPosition || 0)
                            foreground: root.barForeground
                            enabled: root.live && typeof root.cameraState.lensPosition === "number" && !root.busy
                            onRequested: function(value) { root.run("focus_position", [value]) }
                        }
                        CheckBox {
                            visible: root.cameraState.hasFlashlight === true
                            text: "Flashlight"; checked: root.cameraState.flashlight === true
                            enabled: root.live && !root.busy
                            onToggled: root.run("flashlight", [checked])
                        }
                        CheckBox {
                            visible: root.cameraState.supportsGreenScreen === true
                            text: "LensLink green screen"; checked: root.cameraState.greenScreen === true
                            enabled: root.live && !root.busy
                            onToggled: root.run("green_screen", [{on: checked}])
                        }
                        CameraSlider {
                            visible: root.cameraState.greenScreenDepth === true
                            label: "Green screen depth"; from: 0; to: 5; suffix: " m"
                            readback: Number(root.cameraState.greenScreenMaxDistance || 0)
                            foreground: root.barForeground; enabled: root.live && !root.busy
                            onRequested: function(value) { root.run("green_screen", [{maxDistance: value}]) }
                        }
                    }
                    ColumnLayout {
                        visible: tabs.currentIndex === 1
                        Layout.fillWidth: true
                        CameraSlider {
                            label: "Exposure compensation"; from: -2; to: 2; suffix: " EV"
                            readback: Number(root.cameraState.exposureBias || 0)
                            foreground: root.barForeground
                            enabled: root.live && root.cameraState.exposureMode !== "manual" && typeof root.cameraState.exposureBias === "number" && !root.busy
                            onRequested: function(value) { root.run("exposure_bias", [value]) }
                        }
                        RowLayout {
                            visible: root.cameraState.supportsManualExposure === true
                            Button { text: "Auto exposure"; selected: root.cameraState.exposureMode === "auto"; enabled: root.live && !root.busy; onClicked: root.run("exposure", [{mode: "auto"}]) }
                            Button { text: "Manual exposure"; selected: root.cameraState.exposureMode === "manual"; enabled: root.live && !root.busy; onClicked: root.run("exposure", [{mode: "manual", iso: root.cameraState.iso, shutterSeconds: root.cameraState.shutterSeconds}]) }
                        }
                        CameraSlider {
                            visible: root.cameraState.supportsManualExposure === true
                            label: "ISO"; from: Number(root.cameraState.minISO || 1); to: Number(root.cameraState.maxISO || 1); stepSize: 1; decimals: 0
                            readback: Number(root.cameraState.iso || 1)
                            foreground: root.barForeground; enabled: root.live && !root.busy
                            onRequested: function(value) { root.run("exposure", [{mode: "manual", iso: value}]) }
                        }
                        CameraSlider {
                            visible: root.cameraState.supportsManualExposure === true
                            label: "Shutter"; from: Number(root.cameraState.minShutterSeconds || 0.001) * 1000; to: Number(root.cameraState.maxShutterSeconds || 0.033) * 1000; stepSize: 0.01; decimals: 2; suffix: " ms"
                            readback: Number(root.cameraState.shutterSeconds || 0.001) * 1000
                            foreground: root.barForeground; enabled: root.live && !root.busy
                            onRequested: function(value) { root.run("exposure", [{mode: "manual", shutterSeconds: value / 1000}]) }
                        }
                        RowLayout {
                            visible: root.cameraState.supportsWhiteBalanceLock === true
                            Button { text: "Auto white balance"; selected: root.cameraState.whiteBalanceMode === "auto"; enabled: root.live && !root.busy; onClicked: root.run("white_balance", [{mode: "auto"}]) }
                            Button { text: "Lock WB"; selected: root.cameraState.whiteBalanceMode === "locked"; enabled: root.live && !root.busy; onClicked: root.run("white_balance", [{mode: "locked", temperature: root.cameraState.whiteBalanceTemperature}]) }
                        }
                        CameraSlider {
                            visible: root.cameraState.supportsWhiteBalanceLock === true
                            label: "White balance"; from: 2500; to: 8000; stepSize: 100; decimals: 0; suffix: " K"
                            readback: Number(root.cameraState.whiteBalanceTemperature || 5000)
                            foreground: root.barForeground; enabled: root.live && !root.busy
                            onRequested: function(value) { root.run("white_balance", [{mode: "locked", temperature: value}]) }
                        }
                    }
                    ColumnLayout {
                        visible: tabs.currentIndex === 2
                        Layout.fillWidth: true
                        Text { text: "Resolution / frame rate / codec"; color: root.barForeground }
                        RowLayout {
                            ComboBox { model: root.resolutionChoices; currentIndex: root.resolutionChoices.indexOf(root.cameraState.resolution); enabled: root.live && !root.busy; onActivated: root.run("set_format", [{resolution: currentText}]) }
                            ComboBox { model: root.fpsChoices; currentIndex: root.fpsChoices.indexOf(root.cameraState.fps); enabled: root.live && !root.busy; onActivated: root.run("set_format", [{fps: Number(currentText)}]) }
                            ComboBox { model: root.codecChoices; currentIndex: root.codecChoices.indexOf(root.cameraState.codec); enabled: root.live && !root.busy; onActivated: root.run("set_format", [{codec: currentText}]) }
                        }
                        ComboBox {
                            visible: root.cameraState.micEnabled === true
                            model: root.micLabels
                            currentIndex: root.micChoices.indexOf(root.cameraState.mic)
                            enabled: root.live && !root.busy
                            onActivated: function(index) { root.run("mic", [root.micChoices[index]]) }
                        }
                        CheckBox { text: "Auto-start phone camera"; checked: root.cameraStatus.autoStart === true; enabled: !root.busy && (root.live || root.cameraStatus.standby); onToggled: root.run("autostart", [checked]) }
                        Button { text: "Recalibrate lip sync"; enabled: root.live && !root.busy && root.cameraStatus.sync !== "off"; onClicked: root.run("recalibrate") }
                    }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: root.barForeground
                        text: "Portrait & Studio Light: adjust in the iPhone’s Control Center while LensLink is streaming. Effects carry through to OBS. Changing lens may make effects unavailable."
                    }
                    RowLayout {
                        Button {
                            text: root.cameraStatus.standby ? "Start phone camera" : "Stop phone camera"
                            enabled: (root.live || root.cameraStatus.standby) && !root.busy
                            onClicked: root.run(root.cameraStatus.standby ? "start_stream" : "stop_stream")
                        }

                    }
                    Text {
                        Layout.fillWidth: true
                        color: root.barForeground
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                        text: root.message || (root.live && !root.cameraState.zoom ? "Waiting for phone control readback…" : "Select OBS Virtual Camera in your meeting app. Closing this panel releases its preview; broadcasting continues until stopped.")
                    }
                }
            }
        }
    }
}
