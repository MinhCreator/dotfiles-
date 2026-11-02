pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs

TextArea {
    id: root
    leftPadding: 0
    rightPadding: 0
    renderType: Text.QtRendering
    selectedTextColor: Theme.colors.color16
    selectionColor: Theme.colors.color6
    placeholderTextColor: Theme.colors.textMuted
    color: activeFocus ? Theme.colors.textBright : Theme.colors.textPrimary
    font.pixelSize: Theme.fontPixelSizes.normal
    font.family: Theme.fontFamilies.text
    font.weight: Font.Normal
    background: Item {}
    clip: true

    Behavior on color {
        enabled: root.activeFocus
        ColorAnimation {
            duration: Theme.animations.duration.slower
        }
    }

    cursorDelegate: Item {
        width: 1
        visible: root.activeFocus

        StyledRectangle {
            id: cursor
            color: Theme.colors.white
            height: parent.height
            width: 1
            baseRadius: width / 2
            opacity: 0.85

            property bool cursorMoving: false

            SequentialAnimation on opacity {
                id: blinkAnim
                loops: Animation.Infinite
                running: root.activeFocus && !root.readOnly && root.selectedText.length === 0 && !cursor.cursorMoving
                alwaysRunToEnd: false

                onRunningChanged: {
                    if (!running) {
                        cursor.opacity = 0.85;
                    }
                }

                PropertyAnimation {
                    to: 0
                    duration: Theme.animations.duration.verySlow
                }
                PauseAnimation {
                    duration: Theme.animations.duration.verySlow
                }
                PropertyAnimation {
                    to: 0.85
                    duration: Theme.animations.duration.slowest
                }
            }

            Timer {
                id: moveTimer
                interval: 500
                onTriggered: cursor.cursorMoving = false
            }

            Connections {
                target: root
                function onCursorPositionChanged() {
                    cursor.cursorMoving = true;
                    cursor.opacity = 0.85;
                    moveTimer.restart();
                }
            }
        }
    }
}
