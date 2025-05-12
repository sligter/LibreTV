// Copyright (C) 2023 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR BSD-3-Clause

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Fusion
import QtMultimedia
import Config
import DanmakuManager 1.0  // 导入 DanmakuLoader 模块
import QtQuick.Dialogs

Rectangle {
    id: root
    implicitWidth: 380
    color: Config.mainColor
    border.color: "lightgrey"
    radius: 10

    property alias tracksInfo: tracksInfo
    property alias metadataInfo: metadataInfo
    required property MediaPlayer mediaPlayer
    required property int selectedAudioTrack
    required property int selectedVideoTrack
    required property int selectedSubtitleTrack
    property string currentVideoName: ""

    MouseArea {
        anchors.fill: root
        preventStealing: true
    }

    TabBar {
        id: bar
        width: root.width
        contentHeight: 60

        Repeater {
            model: [qsTr("弹幕"), qsTr("视频"), qsTr("播放"), qsTr("主题")]

            TabButton {
                id: tab
                required property int index
                required property string modelData
                property color shadowColor: bar.currentIndex === index ? Config.highlightColor : "black"
                property color textColor: bar.currentIndex === index ? Config.highlightColor : Config.secondaryColor

                background: Rectangle {
                    opacity: 0.15
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: "transparent" }
                        GradientStop { position: 1.0; color: tab.shadowColor }
                    }
                }

                contentItem: Label {
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: tab.modelData
                    font.pixelSize: 20
                    color: tab.textColor
                }
            }
        }
    }

    StackLayout {
        width: root.width
        anchors.top: bar.bottom
        anchors.bottom: root.bottom
        currentIndex: bar.currentIndex

        // 弹幕设置页面
        ScrollView {
            width: parent.width
            contentWidth: width
            clip: true

            Column {
                width: parent.width
                spacing: 15
                padding: 20

                // 弹幕开关
                RowLayout {
                    width: parent.width - 40
                    spacing: 10
                    Label {
                        text: qsTr("显示弹幕")
                        color: Config.secondaryColor
                    }
                    Item { Layout.fillWidth: true }
                    Switch {
                        checked: true
                        onCheckedChanged: {
                            danmakuOverlay.visible = checked
                        }
                    }
                }

                // 轨道数量
                RowLayout {
                    width: parent.width - 40
                    spacing: 10
                    Label {
                        text: qsTr("轨道数量")
                        color: Config.secondaryColor
                    }
                    Item { Layout.fillWidth: true }
                    SpinBox {
                        id: spinBox
                        from: 1
                        to: 20
                        value: danmakuOverlay.trackCount
                        editable: true // 允许编辑
                        wrap: false // 不换行
                        stepSize: 1 

                        onValueChanged: {
                            danmakuOverlay.trackCount = value
                            danmakuOverlay.initTrackStatus()
                        }

                        // 提示用户当前的编辑范围
                        ToolTip.visible: hovered
                        ToolTip.text: "请输入1到20之间的值"
                    }
                }

                // 透明度
                ColumnLayout {
                    width: parent.width - 40
                    spacing: 5
                    Label {
                        text: qsTr("弹幕透明度: ") + Math.round(opacitySlider.value * 100) + "%"
                        color: Config.secondaryColor
                    }
                    Slider {
                        id: opacitySlider
                        Layout.fillWidth: true
                        from: 0.1
                        to: 1.0
                        value: 0.8
                        onValueChanged: {
                            danmakuOverlay.opacity = value
                        }
                    }
                }

                // 滚动速度
                ColumnLayout {
                    width: parent.width - 40
                    spacing: 5
                    Label {
                        text: qsTr("滚动速度: ") + Math.round(speedSlider.value * 100) + "%"
                        color: Config.secondaryColor
                    }
                    Slider {
                        id: speedSlider
                        Layout.fillWidth: true
                        from: 0.1
                        to: 5.0
                        value: 1.0
                        onValueChanged: {
                            danmakuOverlay.children.forEach(function(child) {
                                if (child.duration !== undefined) {
                                    child.duration = 8000 / value
                                }
                            })
                        }
                    }
                }

                // 字体颜色
                RowLayout {
                    width: parent.width - 40
                    spacing: 10
                    Label {
                        text: qsTr("字体颜色")
                        color: Config.secondaryColor
                    }
                    Item { Layout.fillWidth: true }
                    ComboBox {
                        model: ["黄色", "红色", "蓝色", "绿色", "白色"]
                        onCurrentTextChanged: {
                            var color
                            switch(currentText) {
                                case "白色": color = "white"; break
                                case "红色": color = "red"; break
                                case "蓝色": color = "blue"; break
                                case "绿色": color = "green"; break
                                case "黄色": color = "yellow"; break
                            }
                            danmakuOverlay.defaultTextColor = "yellow"
                        }
                    }
                }

                // 字体样式
                ColumnLayout {
                    width: parent.width - 40
                    spacing: 10                   
                    CheckBox {
                        text: qsTr("字体加粗")
                        checked: true
                        contentItem: Text {
                            text: parent.text
                            color: Config.secondaryColor
                            leftPadding: parent.indicator.width + parent.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                        onCheckedChanged: {
                            danmakuOverlay.defaultFontBold = checked
                            danmakuOverlay.updateDanmakuStyle()  // 更新所有弹幕样式
                        }
                    }

                    CheckBox {
                        text: qsTr("字体描边")
                        checked: true
                        contentItem: Text {
                            text: parent.text
                            color: Config.secondaryColor
                            leftPadding: parent.indicator.width + parent.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                        onCheckedChanged: {
                            danmakuOverlay.defaultTextStroke = checked
                            danmakuOverlay.updateDanmakuStyle()  // 更新所有弹幕样式
                        }
                    }

                    // 字体大小设置
                    RowLayout {
                        width: parent.width
                        spacing: 10
                        Label {
                            text: qsTr("字体大小")
                            color: Config.secondaryColor
                        }
                        Item { Layout.fillWidth: true }
                        SpinBox {
                            id: fontSizeSpinBox
                            from: 12
                            to: 48
                            value: 23  // 设置默认值
                            editable: true
                            stepSize: 2
                            
                            onValueChanged: {
                                danmakuOverlay.defaultFontSize = value
                                danmakuOverlay.updateDanmakuStyle()  // 更新所有弹幕的样式
                            }

                            // 提示用户当前的编辑范围
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("请输入12到48之间的值")
                            
                            // 显示单位
                            textFromValue: function(value, locale) {
                                return value + " px"
                            }
                        }
                    }

                    // 弹幕时间微调
                    ColumnLayout {
                        width: parent.width - 40
                        spacing: 5
                        
                        Label {
                            text: qsTr("弹幕时间调整: ") + (timeOffsetSpinBox.value >= 0 ? "+" : "") + timeOffsetSpinBox.value + " 秒"
                            color: Config.secondaryColor
                        }
                        
                        RowLayout {
                            width: parent.width
                            spacing: 5
                            
                            SpinBox {
                                id: timeOffsetSpinBox
                                from: -300  // 最大负偏移5分钟
                                to: 300     // 最大正偏移5分钟
                                value: 0
                                stepSize: 1
                                editable: true
                                
                                onValueChanged: {
                                    danmakuOverlay.setTimeOffset(value)
                                }
                                
                                // 提示用户当前的编辑范围
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("可调整范围：-300秒 到 +300秒")
                                
                                // 显示单位
                                textFromValue: function(value, locale) {
                                    return value + " s"
                                }
                            }
                            
                            // 快速调整按钮
                            Row {
                                spacing: 5
                                
                                Button {
                                    text: "-1s"
                                    onClicked: timeOffsetSpinBox.value--
                                }
                                
                                Button {
                                    text: "+1s"
                                    onClicked: timeOffsetSpinBox.value++
                                }
                                
                                Button {
                                    text: qsTr("重置")
                                    onClicked: timeOffsetSpinBox.value = 0
                                }
                            }
                        }
                        
                        // 添加说明文本
                        Label {
                            text: qsTr("提示：正值使弹幕提前显示，负值使弹幕延后显示")
                            color: Config.secondaryColor
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                // 弹幕加载组件
                GroupBox {
                    width: parent.width - 40
                    title: qsTr("弹幕加载")
                    Column {
                        spacing: 10
                        width: parent ? parent.width : 0  // 添加空值检查
                        
                        // 添加本地弹幕加载按钮
                        Button {
                            text: qsTr("加载本地弹幕")
                            onClicked: localDanmakuDialog.open()
                        }
                        Label {
                            color: "white"
                        }
                        // 搜索源选择
                        ComboBox {
                            id: sourceComboBox
                            width: parent ? parent.width : 0
                            model: ["企鹅", "奇异", "阿B", "阿酷", "阿芒"]
                            currentIndex: 0
                            onCurrentTextChanged: {
                                DanmakuLoader.setSource(currentText)
                                // 清空之前的搜索结果
                                videoListView.model = []
                                episodeListView.model = []
                                statusLabel.text = ""
                            }
                        }
                        
                        // 搜索栏
                        RowLayout {
                            width: parent ? parent.width : 0
                            spacing: 10
                            
                            TextField {
                                id: searchField
                                Layout.fillWidth: true
                                placeholderText: qsTr("输入视频名称")
                                text: root.currentVideoName
                                onAccepted: {
                                    if (text) {
                                        DanmakuLoader.searchVideo(text)
                                    }
                                }
                            }
                            
                            Button {
                                text: qsTr("搜索")
                                onClicked: {
                                    if (searchField.text) {
                                        DanmakuLoader.searchVideo(searchField.text)
                                    }
                                }
                            }
                        }
                        
                        // 视频列表
                        ListView {
                            id: videoListView
                            width: parent ? parent.width : 0
                            height: 120
                            clip: true
                            visible: count > 0
                            model: []
                            
                            delegate: ItemDelegate {
                                required property var modelData
                                width: parent ? parent.width : 0
                                text: modelData.title
                                onClicked: {
                                    episodeListView.model = []
                                    // 根据不同视频源处理不同的ID
                                    if (sourceComboBox.currentText === "企鹅") {
                                        console.log("Selected Tencent video:", modelData.id)
                                        DanmakuLoader.getEpisodeList(modelData.id)
                                    } else if (sourceComboBox.currentText === "奇异") {
                                        console.log("Selected iQiyi video:", modelData.qipuId)  // 使用qipuId而不是pageUrl
                                        DanmakuLoader.getEpisodeList(modelData.qipuId)
                                    } else if (sourceComboBox.currentText === "阿B") {
                                        console.log("Selected Bilibili video:", modelData.id)
                                        DanmakuLoader.getEpisodeList(modelData.id)
                                    } else if (sourceComboBox.currentText === "阿酷") {
                                        console.log("Selected Youku video:", modelData.title)
                                        DanmakuLoader.getEpisodeList(modelData.title)
                                    } else if (sourceComboBox.currentText === "阿芒") {
                                        console.log("Selected Mango video:", modelData.id)
                                        DanmakuLoader.getEpisodeList(modelData.id)
                                    }
                                }
                            }
                            
                            ScrollBar.vertical: ScrollBar {}
                        }
                        
                        // 集数列表
                        ListView {
                            id: episodeListView
                            width: parent ? parent.width : 0
                            height: 120
                            clip: true
                            visible: count > 0
                            model: []
                            
                            delegate: ItemDelegate {
                                required property var modelData
                                width: parent ? parent.width : 0
                                text: {
                                    if (sourceComboBox.currentText === "企鹅") {
                                        return modelData.playTitle
                                    } else if (sourceComboBox.currentText === "奇异") {
                                        // 为爱奇艺返回直接使用标题
                                        return modelData.title || "第" + (index + 1) + "集"
                                    } else if (sourceComboBox.currentText === "阿酷") {
                                        return modelData.title
                                    } else if (sourceComboBox.currentText === "阿芒") {
                                        return modelData.title
                                    } else if (sourceComboBox.currentText === "阿B") {
                                        return modelData.title
                                    } else {
                                        return modelData.title
                                    }
                                }
                                onClicked: {
                                    if (sourceComboBox.currentText === "企鹅") {
                                        DanmakuLoader.downloadDanmaku(modelData.vid)
                                    } else if (sourceComboBox.currentText === "奇异") {
                                        // 对于爱奇艺，直接使用qipuId而不是playUrl
                                        let vid = modelData.qipuId || modelData.playUrl
                                        if (vid) {
                                            console.log("下载爱奇艺弹幕:", vid)
                                            DanmakuLoader.downloadDanmaku(vid)
                                        }
                                    } else if (sourceComboBox.currentText === "阿B") {
                                        DanmakuLoader.downloadDanmaku(modelData.playUrl)
                                    } else if (sourceComboBox.currentText === "阿酷") {
                                        DanmakuLoader.downloadDanmaku(modelData.playUrl)
                                    } else if (sourceComboBox.currentText === "阿芒") {
                                        console.log("Selected Mango video episode:", modelData.playUrl)
                                        DanmakuLoader.downloadDanmaku(modelData.playUrl)
                                    }
                                }
                            }
                            
                            ScrollBar.vertical: ScrollBar {}
                        }
                        
                        // 状态信息
                        Label {
                            id: statusLabel
                            width: parent ? parent.width : 0  // 添加空值检查
                            wrapMode: Text.WordWrap
                            color: Config.secondaryColor
                            visible: text !== ""
                        }
                    }
                }
            }
        }

        MetadataInfo { id: metadataInfo }

        TracksInfo {
            id: tracksInfo
            mediaPlayer: root.mediaPlayer
            selectedAudioTrack: root.selectedAudioTrack
            selectedVideoTrack: root.selectedVideoTrack
            selectedSubtitleTrack: root.selectedSubtitleTrack
        }

        ThemeInfo { id: themeInfo }
    }

    // 添加 Connections 来处理信号
    Connections {
        target: DanmakuLoader
        
        function onVideoListLoaded(videoList) {
            console.log("Video list loaded:", JSON.stringify(videoList))
            console.log("Video list length:", videoList.length)
            console.log("Video list:", Array.isArray(videoList))

            // 强制将 videoList 转换为标准数组
            const videos = Array.isArray(videoList) ? videoList : Array.from(videoList);
            // 确保数据是有效的
            if (Array.isArray(videos) && videos.length > 0) {
                videoListView.model = videos
                statusLabel.text = qsTr("找到 %1 个视频").arg(videos.length)
            } else {
                statusLabel.text = qsTr("未找到视频")
            }
        }
        
        function onEpisodeListLoaded(episodeList) {
            // console.log("Episode list loaded:", JSON.stringify(episodeList))
            // 强制将 episodeList 转换为标准数组
            const episodes = Array.isArray(episodeList) ? episodeList : Array.from(episodeList);
            // 确保数据是有效的
            if (Array.isArray(episodes) && episodes.length > 0) {
                episodeListView.model = episodes
                statusLabel.text = qsTr("找到 %1 个剧集").arg(episodes.length)
            } else {
                statusLabel.text = qsTr("未找到剧集")
            }
        }
        
        function onDownloadProgress(message) {
            console.log("Download progress:", message)
            statusLabel.text = message
        }
        
        function onDownloadError(message) {
            console.log("Download error:", message)
            statusLabel.text = message
            statusLabel.color = "red"
        }
        
        function onDanmakuLoaded(danmakuList) {
            console.log("Danmaku loaded:", danmakuList.length)
            statusLabel.text = qsTr("成功加载 %1 条弹幕").arg(danmakuList.length)
            statusLabel.color = Config.secondaryColor
        }
    }

    Component.onCompleted: {
        console.log("SettingsInfo completed")
    }

    onCurrentVideoNameChanged: {
        if (currentVideoName) {
            // 确保搜索框存在
            if (searchField) {
                searchField.text = currentVideoName
                // 移除自动搜索
                // DanmakuLoader.searchVideo(currentVideoName)
            }
        }
    }

    // 添加文件对话框组件
    FileDialog {
        id: localDanmakuDialog
        title: qsTr("选择弹幕文件")
        nameFilters: ["CSV files (*.csv)", "XML files (*.xml)", "All files (*.*)"]
        
        onAccepted: {
            // 获取选中文件的路径
            var filePath = selectedFile.toString()
            // 移除 "file:///" 前缀
            filePath = filePath.replace(/^(file:\/{3})/,"")
            // 解码 URL 编码的路径
            filePath = decodeURIComponent(filePath)
            
            // 调用 DanmakuLoader 加载本地弹幕
            DanmakuLoader.loadDanmaku(filePath)
        }
    }
}
