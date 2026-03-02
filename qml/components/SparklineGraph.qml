import QtQuick
import org.kde.kirigami as Kirigami

Canvas {
    id: root

    property var values: []
    property color lineColor: Kirigami.Theme.highlightColor
    property color fillColor: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.2)
    // When autoScale is true the graph scales to max(values); when false values are already 0.0-1.0
    property bool autoScale: false

    onValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onFillColorChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        if (!values || values.length < 2) return

        var n = values.length
        var maxVal = 1.0

        if (autoScale) {
            maxVal = 0
            for (var k = 0; k < n; k++) {
                if (values[k] > maxVal) maxVal = values[k]
            }
            if (maxVal <= 0) maxVal = 1
        }

        var step = width / (n - 1)

        function yFor(v) {
            return height - (v / maxVal) * height * 0.92  // 0.92 leaves a small top margin
        }

        // Filled area
        ctx.beginPath()
        ctx.moveTo(0, height)
        ctx.lineTo(0, yFor(values[0]))
        for (var i = 1; i < n; i++) {
            ctx.lineTo(i * step, yFor(values[i]))
        }
        ctx.lineTo((n - 1) * step, height)
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(fillColor.r, fillColor.g, fillColor.b, fillColor.a)
        ctx.fill()

        // Top line
        ctx.beginPath()
        ctx.moveTo(0, yFor(values[0]))
        for (var j = 1; j < n; j++) {
            ctx.lineTo(j * step, yFor(values[j]))
        }
        ctx.strokeStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, lineColor.a)
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.stroke()
    }
}
