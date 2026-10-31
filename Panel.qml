import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "local.easytier"
  ipcTarget: "local.easytier"
  manageIpc: false

  property var statusData: ({ state: "loading", message: "正在检查…", peers: [] })
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var peers: statusData.peers instanceof Array ? statusData.peers : []
  readonly property bool available: statusData.state === "ready"
  readonly property string serviceName: String(settings.serviceName || "easytier-omarchy.service")
  readonly property bool serviceNameValid: /^[A-Za-z0-9_.@-]+\.service$/.test(serviceName)
  readonly property bool serviceControllable: serviceNameValid && ["active", "inactive", "failed"].indexOf(statusData.service) !== -1
  property bool confirming: false
  property string serviceMessage: ""
  readonly property int intervalSeconds: Math.max(10, Math.min(3600, Number(settings.refreshIntervalSec) || 30))

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function copyIp(ip) {
    if (ip) Quickshell.execDetached(["wl-copy", "--", String(ip)])
  }
  function refresh() {
    if (!probe.running) probe.running = true
  }
  function requestToggle() {
    if (serviceControllable && !serviceAction.running) { confirming = true; serviceMessage = "" }
  }
  function confirmToggle() {
    if (!confirming || !serviceControllable || serviceAction.running) return
    confirming = false
    serviceMessage = "等待管理员授权…"
    serviceAction.command = ["pkexec", "/usr/bin/systemctl", statusData.service === "active" ? "stop" : "start", "--", serviceName]
    serviceAction.running = true
  }
  function parse(raw) {
    try { statusData = JSON.parse(raw) }
    catch (e) { statusData = { state: "unavailable", message: "状态数据无法读取", peers: [] } }
  }
  onOpenedChanged: { if (opened) { refresh(); Qt.callLater(function() { keyCatcher.forceActiveFocus() }) } else confirming = false }
  Component.onCompleted: refresh()

  Process {
    id: probe
    command: ["python3", decodeURIComponent(Qt.resolvedUrl("status.py").toString().replace(/^file:\/\//, "")), root.serviceName]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parse(text) }
    onExited: function(code) {
      if (code !== 0) root.statusData = { state: "unavailable", message: "状态检查失败", peers: [] }
    }
  }
  Process {
    id: serviceAction
    running: false
    command: []
    onExited: function(code) {
      root.serviceMessage = code === 0 ? "操作完成，正在刷新状态" : "操作失败或授权已取消"
      delayedRefresh.restart()
    }
  }
  Timer { id: delayedRefresh; interval: 800; onTriggered: root.refresh() }
  Timer { interval: root.intervalSeconds * 1000; running: true; repeat: true; onTriggered: root.refresh() }
  IpcHandler {
    target: root.ipcTarget
    function toggle(): void { root.toggle() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function refresh(): void { root.refresh() }
    function status(): string { return String(root.statusData.state || "unknown") }
  }
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        EasyTierMark { anchors.centerIn: parent; size: Style.space(14); tint: root.barForeground }
      }
    }
    tooltipText: "EasyTier"
    dimmed: !root.available
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refresh()
      else if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }
  component EasyTierMark: Item {
    id: mark
    property real size: 18
    property color tint: root.foreground
    width: size
    height: size
    Image {
      id: markImage
      anchors.fill: parent
      source: Qt.resolvedUrl("assets/easytier-mark.svg")
      sourceSize.width: Math.ceil(mark.size * 2)
      sourceSize.height: Math.ceil(mark.size * 2)
      fillMode: Image.PreserveAspectFit
      smooth: true
      visible: false
    }
    MultiEffect {
      anchors.fill: markImage
      source: markImage
      colorization: 1
      colorizationColor: mark.tint
    }
  }
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))
    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
        else if (t === "c" || t === "C") root.copyIp(root.statusData.ip)
        else if (t === "t" || t === "T") root.requestToggle()
        else if ((t === "y" || t === "Y") && root.confirming) root.confirmToggle()
        else if (t === "n" || t === "N") root.confirming = false
      }
      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
          id: column
          width: parent.width
          spacing: Style.space(12)
          PanelHero {
            width: parent.width
            title: "EasyTier"
            meta: root.statusData.message || "正在检查…"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              EasyTierMark { size: Style.font.display; tint: root.available ? root.foreground : root.dim }
            }
            trailingControl: Component {
              ToggleSwitch {
                visible: root.serviceControllable
                checked: root.statusData.service === "active"
                busy: serviceAction.running
                foreground: root.foreground
                onToggled: root.requestToggle()
              }
            }
          }
          Text {
            visible: root.serviceMessage !== "" || !root.serviceControllable
            width: parent.width
            text: root.serviceMessage || (root.statusData.service === "missing" ? "未找到配置的系统服务；请在插件设置中指定服务名" : "无法确定服务状态，开关不可用")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
          Column {
            visible: root.confirming
            width: parent.width
            spacing: Style.space(8)
            Text {
              width: parent.width
              text: root.statusData.service === "active" ? "确认关闭 EasyTier 组网？现有连接将中断。" : "确认启动 EasyTier 组网？"
              wrapMode: Text.WordWrap
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
            Row {
              spacing: Style.space(18)
              Text {
                text: "确认 (Y)"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.confirmToggle() }
              }
              Text {
                text: "取消 (N)"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.confirming = false }
              }
            }
          }
          Row {
            visible: root.available
            width: parent.width
            Text {
              width: parent.width - localCopy.width
              anchors.verticalCenter: parent.verticalCenter
              text: String(root.statusData.name || "本机") + (root.statusData.ip ? "  ·  " + root.statusData.ip : "")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }
            PanelActionButton {
              id: localCopy
              visible: !!root.statusData.ip
              enabled: visible
              iconText: "󰆏"
              tooltipText: "复制本机 IP"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.copyIp(root.statusData.ip)
            }
          }
          PanelSeparator { visible: root.available; foreground: root.foreground }
          PanelSectionHeader { visible: root.available; text: "节点  ·  " + root.peers.length; foreground: root.foreground; fontFamily: root.fontFamily }
          Text {
            visible: root.available && root.peers.length === 0
            width: parent.width
            text: "暂无节点信息"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
          Repeater {
            model: root.peers
            Column {
              required property var modelData
              width: column.width
              spacing: Style.space(2)
              Text {
                width: parent.width
                text: String(modelData.name || "未知节点")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                textFormat: Text.PlainText
                elide: Text.ElideRight
              }
              Row {
                width: parent.width
                Text {
                  width: parent.width - peerCopy.width
                  anchors.verticalCenter: parent.verticalCenter
                  text: [modelData.ip, modelData.latency !== "" && modelData.latency !== "-" ? modelData.latency + " ms" : "", modelData.protocol].filter(function(v) { return v && v !== "null" && v !== "-" }).join("  ·  ")
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                }
                PanelActionButton {
                  id: peerCopy
                  visible: !!modelData.ip
                  enabled: visible
                  iconText: "󰆏"
                  tooltipText: "复制节点 IP"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.copyIp(modelData.ip)
                }
              }
            }
          }
          Text {
            width: parent.width
            text: "C 复制 IP  ·  T 开关  ·  R 刷新  ·  Esc 关闭"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
