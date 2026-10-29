// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// Circular progress with a spinning arc while the total is unknown.
Item {
    id: ring

    property real value: 0            // 0…1
    property bool indeterminate: false
    property color color: Kirigami.Theme.highlightColor
    property real thickness: Kirigami.Units.gridUnit * 0.6

    implicitWidth: Kirigami.Units.gridUnit * 10
    implicitHeight: implicitWidth

    readonly property real radius: Math.min(width, height) / 2 - thickness / 2
    property real animatedValue: value

    Behavior on animatedValue {
        enabled: !ring.indeterminate
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutCubic
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(Kirigami.Theme.textColor, 0.1)
            strokeWidth: ring.thickness
            capStyle: ShapePath.FlatCap

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    Shape {
        id: arc
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        RotationAnimator on rotation {
            running: ring.indeterminate && ring.visible
            from: 0
            to: 360
            duration: 1400
            loops: Animation.Infinite
        }
        rotation: 0

        ShapePath {
            fillColor: "transparent"
            strokeColor: ring.color
            strokeWidth: ring.thickness
            capStyle: ShapePath.RoundCap

            Behavior on strokeColor {
                ColorAnimation {
                    duration: Kirigami.Units.longDuration
                }
            }

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: -90
                sweepAngle: ring.indeterminate ? 90 : Math.max(0.01, Math.min(1, ring.animatedValue)) * 360
            }
        }
    }
}
