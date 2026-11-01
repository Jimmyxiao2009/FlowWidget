import QtQuick
import QtQuick.Layouts
import RinUI

Item {
    id: weather

    function iconForCode(code) {
        if (code === 0) return "ic_fluent_weather_sunny_20_regular"
        if (code === 1 || code === 2) return "ic_fluent_weather_partly_cloudy_day_20_regular"
        if (code === 3) return "ic_fluent_weather_cloudy_20_regular"
        if (code === 45 || code === 48) return "ic_fluent_weather_fog_20_regular"
        if (code >= 51 && code <= 67) return "ic_fluent_weather_drizzle_20_regular"
        if (code >= 71 && code <= 86) return "ic_fluent_weather_snow_20_regular"
        if (code >= 95) return "ic_fluent_weather_thunderstorm_20_regular"
        if (code >= 61) return "ic_fluent_weather_rain_20_regular"
        return "ic_fluent_weather_cloudy_20_regular"
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.currentTheme.isDark
            ? Qt.rgba(0.12, 0.28, 0.42, 0.22)
            : Qt.rgba(0.20, 0.48, 0.78, 0.10)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: weatherBackend.updatedText.length === 0
                    ? "--°"
                    : weatherBackend.temperatureText(appSettings.temperatureUnit)
                font.pixelSize: weather.height > 140 ? 56 : 44
                font.bold: true
                color: Theme.currentTheme.colors.textColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: weatherBackend.updatedText.length === 0 ? "正在更新" : weatherBackend.condition
                    font.pixelSize: 18
                    font.bold: true
                    color: Theme.currentTheme.colors.textColor
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: weatherBackend.locationName || appSettings.weatherCity
                    color: Theme.currentTheme.colors.textSecondaryColor
                    elide: Text.ElideRight
                }
            }

            Icon {
                name: weather.iconForCode(weatherBackend.weatherCode)
                size: 42
                color: Theme.currentTheme.colors.primaryColor
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.fillWidth: true
            text: weatherBackend.updatedText.length === 0
                ? "正在加载天气..."
                : weatherBackend.rangeText(appSettings.temperatureUnit)
            color: Theme.currentTheme.colors.textSecondaryColor
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            visible: weatherBackend.errorMessage.length > 0
            text: weatherBackend.errorMessage
            color: Theme.currentTheme.colors.systemCriticalColor
            elide: Text.ElideRight
        }
    }
}
