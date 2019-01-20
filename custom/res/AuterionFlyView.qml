/****************************************************************************
 *
 * (c) 2009-2018 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick              2.3
import QtQuick.Layouts      1.2
import QtQuick.Controls     1.2
import QtQuick.Dialogs      1.2
import QtPositioning        5.2
import QtGraphicalEffects   1.0

import QGroundControl                       1.0
import QGroundControl.Controllers           1.0
import QGroundControl.Controls              1.0
import QGroundControl.FlightMap             1.0
import QGroundControl.MultiVehicleManager   1.0
import QGroundControl.Palette               1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.Vehicle               1.0
import QGroundControl.QGCPositionManager    1.0

import AuterionQuickInterface               1.0
import Auterion.Widgets                     1.0

Item {
    anchors.fill: parent
    visible:    !QGroundControl.videoManager.fullScreen

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property string scaleState:            "topMode"
    readonly property string noGPS:                 qsTr("NO GPS")
    readonly property real   indicatorValueWidth:   ScreenTools.defaultFontPixelWidth * 7

    property real   _indicatorDiameter:     ScreenTools.defaultFontPixelWidth * 18
    property var    _sepColor:              qgcPal.globalTheme === QGCPalette.Light ? Qt.rgba(0,0,0,0.5) : Qt.rgba(1,1,1,0.5)
    property color  _indicatorsColor:       AuterionQuickInterface.colorIndicators

    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property bool   _communicationLost:     _activeVehicle ? _activeVehicle.connectionLost : false
    property var    _dynamicCameras:        _activeVehicle ? _activeVehicle.dynamicCameras : null
    property bool   _isCamera:              _dynamicCameras ? _dynamicCameras.cameras.count > 0 : false
    property int    _curCameraIndex:        _dynamicCameras ? _dynamicCameras.currentCamera : 0
    property var    _camera:                _isCamera ? _dynamicCameras.cameras.get(_curCameraIndex) : null
    property bool   _cameraVideoMode:       _camera ?  _camera.cameraMode === QGCCameraControl.CAM_MODE_VIDEO : false
    property bool   _cameraPhotoMode:       _camera ?  (_camera.cameraMode === QGCCameraControl.CAM_MODE_PHOTO || _camera.cameraMode === QGCCameraControl.CAM_MODE_SURVEY) : false
    property bool   _cameraPresent:         _camera && _camera.cameraMode !== QGCCameraControl.CAM_MODE_UNDEFINED
    property bool   _noSdCard:              _camera && _camera.storageTotal === 0
    property bool   _fullSD:                _camera && _camera.storageTotal !== 0 && _camera.storageFree > 0 && _camera.storageFree < 250 // We get kiB from the camera
    property bool   _isVehicleGps:          _activeVehicle && _activeVehicle.gps && _activeVehicle.gps.count.rawValue > 1 && activeVehicle.gps.hdop.rawValue < 1.4
    property bool   _recordingVideo:        _cameraVideoMode && _camera.videoStatus === QGCCameraControl.VIDEO_CAPTURE_STATUS_RUNNING
    property bool   _cameraIdle:            !_cameraPhotoMode || _camera.photoStatus === QGCCameraControl.PHOTO_CAPTURE_IDLE
    property real   _gimbalPitch:           _camera ? -_camera.gimbalPitch : 0
    property real   _gimbalYaw:             _camera ? _camera.gimbalYaw : 0
    property bool   _gimbalVisible:         _camera ? _camera.gimbalData && camControlLoader.visible : false

    property var    _expModeFact:           _camera && _camera.exposureMode ? _camera.exposureMode : null
    property var    _evFact:                _camera && _camera.ev ? _camera.ev : null
    property var    _isoFact:               _camera && _camera.iso ? _camera.iso : null
    property var    _shutterFact:           _camera && _camera.shutter ? _camera.shutter : null
    property var    _apertureFact:          _camera && _camera.aperture ? _camera.aperture : null
    property var    _wbFact:                _camera && _camera.wb ? _camera.wb : null
    property var    _meteringFact:          _camera && _camera.meteringMode ? _camera.meteringMode : null
    property var    _videoResFact:          _camera && _camera.videoRes ? _camera.videoRes : null

    property string _altitude:              _activeVehicle ? (isNaN(_activeVehicle.altitudeRelative.value) ? "0.0" : _activeVehicle.altitudeRelative.value.toFixed(1)) + ' ' + _activeVehicle.altitudeRelative.units : "0.0"
    property string _distanceStr:           isNaN(_distance) ? "0" : _distance.toFixed(0) + ' ' + (_activeVehicle ? _activeVehicle.altitudeRelative.units : "")
    property real   _heading:               _activeVehicle   ? _activeVehicle.heading.rawValue : 0

    property real   _distance:              0.0
    property string _messageTitle:          ""
    property string _messageText:           ""

    function indicatorClicked() {
        vehicleStatus.visible = !vehicleStatus.visible
    }

    Timer {
        id:        connectionTimer
        interval:  5000
        running:   false;
        repeat:    false;
        onTriggered: {
            //-- Vehicle is gone
            if(_activeVehicle) {
                //-- Let video stream close
                QGroundControl.settingsManager.videoSettings.rtspTimeout.rawValue = 1
                if(!_activeVehicle.armed) {
                    //-- If it wasn't already set to auto-disconnect
                    if(!_activeVehicle.autoDisconnect) {
                        //-- Vehicle is not armed. Close connection and tell user.
                        _activeVehicle.disconnectInactiveVehicle()
                        connectionLostDisarmedDialog.open()
                    }
                } else {
                    //-- Vehicle is armed. Show doom dialog.
                    rootLoader.sourceComponent = connectionLostArmed
                    mainWindow.disableToolbar()
                }
            }
        }
    }

    Connections {
        target: QGroundControl.qgcPositionManger
        onGcsPositionChanged: {
            if (_activeVehicle && gcsPosition.latitude && Math.abs(gcsPosition.latitude)  > 0.001 && gcsPosition.longitude && Math.abs(gcsPosition.longitude)  > 0.001) {
                var gcs = QtPositioning.coordinate(gcsPosition.latitude, gcsPosition.longitude)
                var veh = _activeVehicle.coordinate;
                _distance = QGroundControl.metersToAppSettingsDistanceUnits(gcs.distanceTo(veh));
                //-- Ignore absurd values
                if(_distance > 99999)
                    _distance = 0;
                if(_distance < 0)
                    _distance = 0;
            } else {
                _distance = 0;
            }
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager.activeVehicle
        onConnectionLostChanged: {
            if(!_communicationLost) {
                //-- Communication regained
                connectionTimer.stop();
                mainWindow.enableToolbar()
                rootLoader.sourceComponent = null
                //-- Reset stream timeout
                QGroundControl.settingsManager.videoSettings.rtspTimeout.rawValue = 60
            } else {
                if(_activeVehicle && !_activeVehicle.autoDisconnect) {
                    //-- Communication lost
                    connectionTimer.start();
                }
            }
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        onVehicleAdded: {
            //-- Dismiss comm lost dialog if open
            connectionLostDisarmedDialog.close()
        }
    }

    MessageDialog {
        id:                 connectionLostDisarmedDialog
        title:              qsTr("Communication Lost")
        text:               qsTr("Connection to vehicle has been lost and closed.")
        standardButtons:    StandardButton.Ok
        onAccepted: {
            connectionLostDisarmedDialog.close()
        }
    }

    //-- Camera Status
    Row {
        spacing:        ScreenTools.defaultFontPixelWidth * 0.75
        visible:        !_mainIsMap && _cameraPresent && _camera.paramComplete
        height:         ScreenTools.defaultFontPixelHeight
        anchors.top:    parent.top
        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.5
        anchors.horizontalCenter: parent.horizontalCenter
        //-- AE
        AuterionFactCombo {
            text:       qsTr("AE:")
            visible:    _expModeFact
            indexModel: false
            fact:       _expModeFact
            enabled:    _cameraIdle
        }
        //-- EV
        AuterionFactCombo {
            text:       qsTr("EV:")
            visible:    _evFact;
            indexModel: false
            fact:       _evFact
            enabled:    _cameraIdle
        }
        //-- ISO
        AuterionFactCombo {
            text:       qsTr("ISO:")
            visible:    _isoFact;
            indexModel: false
            fact:       _isoFact
            enabled:    _cameraIdle
        }
        //-- Shutter Speed
        AuterionFactCombo {
            text:       qsTr("Shutter:")
            visible:    _shutterFact;
            indexModel: false
            fact:       _shutterFact
            enabled:    _cameraIdle
        }
        //-- Aperture
        AuterionFactCombo {
            text:       qsTr("Aperture:")
            visible:    _apertureFact;
            indexModel: false
            fact:       _apertureFact
            enabled:    _cameraIdle
        }
        //-- WB
        AuterionFactCombo {
            text:       qsTr("WB:")
            indexModel: false
            fact:       _wbFact
            enabled:    _cameraIdle
            visible:    _wbFact
        }
        //-- Metering
        AuterionFactCombo {
            text:       qsTr("Metering:")
            visible:    _meteringFact;
            indexModel: false
            fact:       _meteringFact
            enabled:    _cameraIdle
        }
        //-- Video Res
        AuterionFactCombo {
            visible:    _cameraVideoMode && _videoResFact;
            indexModel: false
            enabled:    !_recordingVideo
            fact:       _videoResFact
        }
        //-- SD Card
        AuterionLabel {
            title:      qsTr("SD:")
            level:      0.5
            pointSize:  ScreenTools.smallFontPointSize
            color:      (_noSdCard || _fullSD) ? qgcPal.colorOrange : "#FFF"
            text: {
                if(_noSdCard) return qsTr("NONE")
                if(_fullSD) return qsTr("FULL")
                return _camera ? _camera.storageFreeStr : ""
            }
        }
    }

    //-- Camera Control
    Loader {
        id:                     camControlLoader
        visible:                !_mainIsMap && _cameraPresent && _camera.paramComplete
        source:                 visible ? "/auterion/AuterionCameraControl.qml" : ""
        anchors.right:          parent.right
        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
        anchors.top:            parent.top
        anchors.topMargin:      ScreenTools.defaultFontPixelHeight * 4
    }

    //-- Gimbal Indicator
    Rectangle {
        width:                  ScreenTools.defaultFontPixelWidth * 6
        height:                 gimbalCol.height + (ScreenTools.defaultFontPixelHeight * 2)
        visible:                _gimbalVisible
        color:                  Qt.rgba(0,0,0,0.5)
        radius:                 ScreenTools.defaultFontPixelWidth * 0.5
        anchors.right:          camControlLoader.left
        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
        anchors.verticalCenter: camControlLoader.verticalCenter
        Column {
            id:                 gimbalCol
            spacing:            ScreenTools.defaultFontPixelHeight * 0.75
            anchors.centerIn:   parent
            Image {
                source:         "/auterion/img/gimbal_icon.svg"
                width:          ScreenTools.defaultFontPixelWidth * 2
                height:         width
                smooth:         true
                mipmap:         true
                antialiasing:   true
                fillMode:       Image.PreserveAspectFit
                sourceSize.width: width
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Image {
                id:                 pitchScale
                height:             camControlLoader.height * 0.65
                source:             "/auterion/img/gimbal_pitch.svg"
                fillMode:           Image.PreserveAspectFit
                sourceSize.height:  height
                smooth:             true
                mipmap:             true
                antialiasing:       true
                anchors.horizontalCenter: parent.horizontalCenter
                Image {
                    id:                 yawIndicator
                    width:              ScreenTools.defaultFontPixelWidth * 4
                    source:             "/auterion/img/gimbal_position.svg"
                    fillMode:           Image.PreserveAspectFit
                    sourceSize.width:   width
                    y:                  (parent.height * _pitch / 105)
                    smooth:             true
                    mipmap:             true
                    anchors.horizontalCenter: parent.horizontalCenter
                    transform: Rotation {
                        origin.x:       yawIndicator.width  / 2
                        origin.y:       yawIndicator.height / 2
                        angle:          _gimbalYaw
                    }
                    property real _pitch: _gimbalPitch < -15 ? -15  : (_gimbalPitch > 90 ? 90 : _gimbalPitch)
                }
            }
            QGCLabel {
                id:             gimbalLabel
                text:           _gimbalPitch ? _gimbalPitch.toFixed(0) : 0
                color:          "#FFF"
                font.pointSize:  ScreenTools.smallFontPointSize
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }


    //-- Vehicle Status
    Image {
        id:                     vehicleStatusEdge
        source:                 "/auterion/img/label_left_edge.svg"
        height:                 Math.round(vehicleStatus.height)
        width:                  Math.round(height * 0.5)
        antialiasing:           true
        sourceSize.height:      height
        anchors.top:            vehicleStatus.top
        anchors.right:          vehicleStatus.left
        fillMode:               Image.PreserveAspectFit
        opacity:                0.75
        visible:                vehicleStatus.visible
        Image {
            source:                 "/auterion/img/chevron_right.svg"
            height:                 ScreenTools.defaultFontPixelHeight * 0.75
            width:                  height
            antialiasing:           true
            sourceSize.height:      height
            anchors.verticalCenter: parent.verticalCenter
            anchors.right:          parent.right
            anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 2
            fillMode:               Image.PreserveAspectFit
            opacity:                0.75
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                indicatorClicked()
            }
        }
    }
    Rectangle {
        id:                     vehicleStatus
        width:                  Math.round(vehicleStatusGrid.width  + (ScreenTools.defaultFontPixelWidth * 4))
        height:                 Math.round(vehicleStatusGrid.height + ScreenTools.defaultFontPixelHeight * 0.75)
        color:                  Qt.rgba(0,0,0,0.75)
        anchors.bottom:         parent.bottom
        anchors.right:          parent.right
        anchors.rightMargin:    _indicatorDiameter * 0.5
        anchors.bottomMargin:   ScreenTools.defaultFontPixelHeight
        anchors.topMargin:      ScreenTools.defaultFontPixelHeight * 0.5
        DeadMouseArea {
            anchors.fill:   parent
        }
    }
    GridLayout {
        id:                     vehicleStatusGrid
        columnSpacing:          ScreenTools.defaultFontPixelWidth  * 1.5
        rowSpacing:             ScreenTools.defaultFontPixelHeight * 0.25
        columns:                5
        anchors.verticalCenter: vehicleStatus.verticalCenter
        x:                      vehicleStatusEdge.x + vehicleStatusEdge.width
        visible:                vehicleStatus.visible
        //-- Odometer
        QGCLabel {
            text:                   qsTr("Odom:")
            color:                  "#FFF"
            font.pointSize:         ScreenTools.smallFontPointSize
        }
        QGCLabel {
            text:                   _activeVehicle ? ('00000' + _activeVehicle.flightDistance.value.toFixed(0)).slice(-5) + ' ' + _activeVehicle.flightDistance.units : "00000"
            color:                  _indicatorsColor
            font.pointSize:         ScreenTools.smallFontPointSize
            Layout.fillWidth:       true
            Layout.minimumWidth:    indicatorValueWidth
            horizontalAlignment:    Text.AlignRight
        }
        //-- Chronometer
        QGCLabel {
            text:                   qsTr("Elap:")
            color:                  "#FFF"
            font.pointSize:         ScreenTools.smallFontPointSize
        }
        QGCLabel {
            text:                   _activeVehicle ? _activeVehicle.getFact("flightTime").value : "00:00:00"
            color:                  _indicatorsColor
            font.pointSize:         ScreenTools.smallFontPointSize
            Layout.fillWidth:       true
            Layout.minimumWidth:    indicatorValueWidth
            horizontalAlignment:    Text.AlignRight
        }
        Item { width: 1; height: 1; }
        //-- Latitude
        QGCLabel {
            text:                   qsTr("Lat:")
            color:                  "#FFF"
            font.pointSize:         ScreenTools.smallFontPointSize
        }
        QGCLabel {
            text:                   _isVehicleGps ? _activeVehicle.latitude.toFixed(6) : noGPS
            color:                  _isVehicleGps ? _indicatorsColor : qgcPal.colorOrange
            font.pointSize:         ScreenTools.smallFontPointSize
            Layout.fillWidth:       true
            Layout.minimumWidth:    indicatorValueWidth
            horizontalAlignment:    Text.AlignRight
        }
        //-- Longitude
        QGCLabel {
            text:                   qsTr("Lon:")
            color:                  "#FFF"
            font.pointSize:         ScreenTools.smallFontPointSize
        }
        QGCLabel {
            text:                   _isVehicleGps ? _activeVehicle.longitude.toFixed(6) : noGPS
            color:                  _isVehicleGps ? _indicatorsColor : qgcPal.colorOrange
            font.pointSize:         ScreenTools.smallFontPointSize
            Layout.fillWidth:       true
            Layout.minimumWidth:    indicatorValueWidth
            horizontalAlignment:    Text.AlignRight
        }
        Item { width: 1; height: 1; }
        //-- Altitude
        QGCLabel {
            text:                   qsTr("H:")
            color:                  "#FFF"
            font.pointSize:         ScreenTools.smallFontPointSize
        }
        QGCLabel {
            text:                   _altitude
            color:                  _indicatorsColor
            font.pointSize:         ScreenTools.smallFontPointSize
            Layout.fillWidth:       true
            Layout.minimumWidth:    indicatorValueWidth
            horizontalAlignment:    Text.AlignRight
        }
        //-- Ground Speed
        QGCLabel {
            text:                   qsTr("H.S:")
            color:                  "#FFF"
            font.pointSize:         ScreenTools.smallFontPointSize
        }
        QGCLabel {
            text:                   _activeVehicle ? _activeVehicle.groundSpeed.rawValue.toFixed(1) + ' ' + _activeVehicle.groundSpeed.units : "0.0"
            color:                  _indicatorsColor
            font.pointSize:         ScreenTools.smallFontPointSize
            Layout.fillWidth:       true
            Layout.minimumWidth:    indicatorValueWidth
            horizontalAlignment:    Text.AlignRight
        }
        Item { width: 1; height: 1; }
        //-- Distance
        QGCLabel {
            text:                   qsTr("D:")
            color:                  "#FFF"
            font.pointSize:         ScreenTools.smallFontPointSize
        }
        QGCLabel {
            text:                   _distance ? _distanceStr : noGPS
            color:                  _distance ? _indicatorsColor : qgcPal.colorOrange
            font.pointSize:         ScreenTools.smallFontPointSize
            Layout.fillWidth:       true
            Layout.minimumWidth:    indicatorValueWidth
            horizontalAlignment:    Text.AlignRight
        }
        //-- Vertical Speed
        QGCLabel {
            text:                   qsTr("V.S:")
            color:                  "#FFF"
            font.pointSize:         ScreenTools.smallFontPointSize
        }
        QGCLabel {
            text:                   _activeVehicle ? _activeVehicle.climbRate.value.toFixed(1) + ' ' + _activeVehicle.climbRate.units : "0.0"
            color:                  _indicatorsColor
            font.pointSize:         ScreenTools.smallFontPointSize
            Layout.fillWidth:       true
            Layout.minimumWidth:    indicatorValueWidth
            horizontalAlignment:    Text.AlignRight
        }
        Item { width: 1; height: 1; }
        //-- Right edge, under indicator thingy
        Item {
            width:          1
            height:         1
            Layout.columnSpan: 4
        }
        Item {
            width:          _indicatorDiameter * 0.4
            height:         1
        }
    }


    //-- Heading
    Rectangle {
        width:   headingCol.width  * 1.5
        height:  headingCol.height * 1.25
        radius:  ScreenTools.defaultFontPixelWidth * 0.5
        color:   "#000"
        anchors.bottom:             compassAttitudeComboAlt.top
        anchors.bottomMargin:       -ScreenTools.defaultFontPixelHeight
        anchors.horizontalCenter:   compassAttitudeComboAlt.horizontalCenter
        Column {
            id: headingCol
            anchors.centerIn: parent
            QGCLabel {
                text:           ('000' + _heading.toFixed(0)).slice(-3)
                color:          "white"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Item {
                width:  1
                height: ScreenTools.defaultFontPixelHeight
            }
        }
    }
    //-- Indicator thingy
    Item {
        id:             compassAttitudeComboAlt
        width:          _indicatorDiameter
        height:         outerCompassAlt.height
        anchors.bottom: vehicleStatus.bottom
        anchors.right:  parent.right
        anchors.rightMargin:  ScreenTools.defaultFontPixelWidth
        AuterionCompassRing {
            id:             outerCompassAlt
            size:           parent.width * 1.05
            vehicle:        _activeVehicle
            anchors.horizontalCenter: parent.horizontalCenter
            AuterionAttitudeWidget {
                id:                 attitudeWidget
                size:               parent.width * 0.8
                vehicle:            _activeVehicle
                showHeading:        false
                anchors.centerIn:   outerCompassAlt
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                indicatorClicked()
            }
        }
    }

    //-- Connection Lost While Armed
    Component {
        id:         connectionLostArmed
        Item {
            id:         connectionLostArmedItem
            z:          1000000
            width:      mainWindow.width
            height:     mainWindow.height
            Rectangle {
                id:             connectionLostArmedShadow
                anchors.fill:   connectionLostArmedRect
                radius:         connectionLostArmedRect.radius
                color:          qgcPal.window
                visible:        false
            }
            DropShadow {
                anchors.fill:       connectionLostArmedShadow
                visible:            connectionLostArmedRect.visible
                horizontalOffset:   4
                verticalOffset:     4
                radius:             32.0
                samples:            65
                color:              Qt.rgba(0,0,0,0.75)
                source:             connectionLostArmedShadow
            }
            Rectangle {
                id:                 connectionLostArmedRect
                width:              mainWindow.width   * 0.65
                height:             connectionLostArmedCol.height * 1.5
                radius:             ScreenTools.defaultFontPixelWidth
                color:              qgcPal.alertBackground
                border.color:       qgcPal.alertBorder
                border.width:       2
                anchors.centerIn:   parent
                Column {
                    id:                 connectionLostArmedCol
                    width:              connectionLostArmedRect.width
                    spacing:            ScreenTools.defaultFontPixelHeight * 3
                    anchors.margins:    ScreenTools.defaultFontPixelHeight
                    anchors.centerIn:   parent
                    QGCLabel {
                        text:           qsTr("Communication Lost")
                        font.family:    ScreenTools.demiboldFontFamily
                        font.pointSize: ScreenTools.largeFontPointSize
                        color:          qgcPal.alertText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    QGCLabel {
                        text:           qsTr("Warning: Connection to vehicle lost.")
                        color:          qgcPal.alertText
                        font.family:    ScreenTools.demiboldFontFamily
                        font.pointSize: ScreenTools.mediumFontPointSize
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    QGCLabel {
                        text:           qsTr("The vehicle will automatically cancel the flight and return to land. Ensure a clear line of sight between transmitter and vehicle. Ensure the takeoff location is clear.")
                        width:          connectionLostArmedRect.width * 0.75
                        wrapMode:       Text.WordWrap
                        color:          qgcPal.alertText
                        font.family:    ScreenTools.demiboldFontFamily
                        font.pointSize: ScreenTools.mediumFontPointSize
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
            DeadMouseArea {
                anchors.fill:   parent
            }
            Component.onCompleted: {
                rootLoader.width  = connectionLostArmedItem.width
                rootLoader.height = connectionLostArmedItem.height
                mainWindow.disableToolbar()
            }
        }
    }
}