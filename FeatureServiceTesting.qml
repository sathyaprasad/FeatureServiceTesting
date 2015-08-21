
//------------------------------------------------------------------------------
// FeatureServiceTesting.qml
// Created 2015-06-29 21:17:18
//------------------------------------------------------------------------------
import QtQuick 2.3
import QtQuick.Controls 1.2
import QtPositioning 5.3

import ArcGIS.AppFramework 1.0
import ArcGIS.AppFramework.Controls 1.0
import ArcGIS.AppFramework.Runtime 1.0
import ArcGIS.AppFramework.Runtime.Controls 1.0

App {
    id: app
    width: 800
    height: 532


    //    property var chartLineData: ({
    //        labels: [],
    //        datasets: [{
    //            fillColor : "rgba(220,220,220,0.2)",
    //            strokeColor : "rgba(220,220,220,1)",
    //            pointColor : "rgba(220,220,220,1)",
    //            pointStrokeColor : "#fff",
    //            pointHighlightFill : "#fff",
    //            pointHighlightStroke : "rgba(220,220,220,1)",
    //            data: []
    //        }]
    //    })
    property var chartLineData

    onWidthChanged: {
        chartLine.requestInitPaint()
    }

    onChartLineDataChanged: {
        console.log("Data changed")
        chartLine.chartData = chartLineData
        chartLine.update()
        chartLine.requestPaint()
        console.log(chartLine.chartRenderHandler)
    }

    Map {
        id: map
        width: parent.width
        height: parent.height * 2 / 3

        wrapAroundEnabled: true
        rotationByPinchingEnabled: false
        magnifierOnPressAndHoldEnabled: false
        mapPanningByMagnifierEnabled: false
        zoomByPinchingEnabled: true
        esriLogoVisible: false

        positionDisplay {
            id: posDisplay
            positionSource: PositionSource {
                id: posSource
                onPositionChanged: {
                    txtCurrentPos.text = posDisplay.mapPoint.toDecimalDegrees(
                                10)
                }
            }
        }

        ArcGISTiledMapServiceLayer {
            url: "http://services.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer"
        }

        ArcGISFeatureLayer {
            id: fLayer
            // Line
            url: "http://services1.arcgis.com/g2TonOxuRkIqSOFx/arcgis/rest/services/Trails/FeatureServer/0"
            maxAllowableOffset: map.resolution

            onSelectFeaturesStatusChanged: {
                // Set selection color to yellow
                selectionColor = "#FFFF00"

                // Get geometry of selected feature to pass to GP service param
                if (selectFeaturesStatus == Enums.SelectFeaturesStatusCompleted) {
                    //console.log(selectFeaturesResult.count)
                    for (var count = 0; count < selectFeaturesResult.graphics.length; count++) {
                        // Get the length of the trail to determine the Maximum Sample Distance
                        var trailLength = selectFeaturesResult.graphics[count].geometry.calculateLength2D()
                        console.log(trailLength)

                        // Calculate the Maximum Sample Distance
                        var maxSampleDistance = trailLength / 40
                        console.log(maxSampleDistance)

                        //console.log(selectFeaturesResult.graphics[count].attributes["OBJECTID"].toString())
                        //console.log(JSON.stringify(selectFeaturesResult.graphics[count].json))
                        //console.log(JSON.stringify(selectFeaturesResult.graphics[count].geometry.json))

                        // Construct url for Elevation Profile GP service
                        var inputLineFeatures = {
                            fields: [{
                                    name: "OID",
                                    type: "esriFieldTypeObjectID",
                                    alias: "OID"
                                }],
                            geometryType: "esriGeometryPolyline",
                            sr: {
                                wkid: 102100,
                                latestWkid: 3857
                            }
                        }
                        inputLineFeatures.features = [{
                                                          geometry: selectFeaturesResult.graphics[count].geometry.json
                                                      }]
                        var executeURL = "http://elevation.arcgis.com/arcgis/rest/services/Tools/ElevationSync/GPServer/Profile/execute?"
                        executeURL += "InputLineFeatures=" + JSON.stringify(
                                    inputLineFeatures)
                                + "&ProfileIDField=OID&DEMResolution=FINEST&MaximumSampleDistance="
                                + maxSampleDistance.toString(
                                    ) + "&&MaximumSampleDistanceUnits=Meters&returnZ=true&returnM=true&f=json"

                        // Set Elevation Profile GP service url and execute
                        elevGPService.url = executeURL
                        elevGPService.send()
                    }
                }
            }
        }

        NetworkRequest {
            id: elevGPService
            method: "POST"

            onReadyStateChanged: {
                if (readyState == NetworkRequest.DONE) {
                    var jsonResponse = JSON.parse(responseText)

                    //console.log(JSON.stringify(jsonResponse))
                    var xyzm
                    var mValueList = ([])
                    var zValueList = ([])
                    for (var i in jsonResponse.results[0].value.features[0].geometry.paths) {
                        // Get multi-part features
                        for (var j in jsonResponse.results[0].value.features[0].geometry.paths[i]) {
                            xyzm = jsonResponse.results[0].value.features[0].geometry.paths[i][j]
                            //console.log(JSON.stringify(xyzm))
                            mValueList.push(Math.round(xyzm[3], 2))
                            zValueList.push(Math.round(xyzm[2], 2))
                        }
                    }

                    console.log(mValueList.length)
                    console.log(zValueList.length)

                    // Define data for chart
                    chartLineData = {
                        labels: mValueList,
                        datasets: [{
                                fillColor: "rgba(220,220,220,0.2)",
                                strokeColor: "rgba(220,220,220,1)",
                                pointColor: "rgba(220,220,220,1)",
                                pointStrokeColor: "#fff",
                                pointHighlightFill: "#fff",
                                pointHighlightStroke: "rgba(220,220,220,1)",
                                data: zValueList
                            }]
                    }
                }
            }
        }

        NorthArrow {
            anchors {
                right: parent.right
                top: parent.top
                margins: 10
            }

            visible: map.mapRotation != 0
        }

        ZoomButtons {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                margins: 10
            }
        }

        Query {
            id: query
            spatialRelationship: Enums.SpatialRelationshipIntersects
            returnGeometry: true
            maxFeatures: 1
        }

        extent: extent

        Envelope {
            id: extent
            xMin: -8613196
            yMin: 4688288
            xMax: -8539073
            yMax: 4726083
        }

        onMouseClicked: {
            console.log("clicked!")
            var env = mouse.mapPoint.queryEnvelope()
            query.geometry = env.inflate(500, 500)

            fLayer.selectFeatures(query, Enums.SelectionMethodNew)
        }


        //        onMousePositionChanged: {
        //            console.log(mouse.mapX, mouse.mapY)
        //        }
        Rectangle {
            width: txtCurrentPos.implicitWidth + 10
            height: 40
            anchors {
                left: parent.left
                leftMargin: 10
                top: parent.top
                topMargin: 10
            }
            Text {
                id: txtCurrentPos
                color: "red"
                font.pointSize: 16
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Rectangle {
        width: parent.width
        height: parent.height / 3
        anchors {
            bottom: parent.bottom
            left: parent.left
        }

        QChartJs {
            id: chartLine
            width: parent.width
            height: parent.height
            chartType: "Line"
            //chartData: chartLineData
            animation: true
            chartAnimationEasing: Easing.InOutElastic
            chartAnimationDuration: 2000
        }
    }
}
