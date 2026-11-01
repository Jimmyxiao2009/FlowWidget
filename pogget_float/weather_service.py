from __future__ import annotations

import json
from urllib.parse import urlencode

from PySide6.QtCore import QObject, Property, QTimer, QUrl, Signal, Slot
from PySide6.QtNetwork import QNetworkAccessManager, QNetworkReply, QNetworkRequest


class WeatherService(QObject):
    """Fetches current weather from Open-Meteo without requiring an API key."""

    dataChanged = Signal()
    loadingChanged = Signal()
    errorChanged = Signal()

    def __init__(self, settings: QObject, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._settings = settings
        self._manager = QNetworkAccessManager(self)
        self._loading = False
        self._error_message = ""
        self._location_name = settings.weatherCity
        self._condition = "等待刷新"
        self._temperature_c = 0.0
        self._apparent_c = 0.0
        self._minimum_c = 0.0
        self._maximum_c = 0.0
        self._precipitation_probability = 0
        self._updated_text = ""
        self._weather_code = -1
        self._request_serial = 0

        self._refresh_timer = QTimer(self)
        self._refresh_timer.setInterval(20 * 60 * 1000)
        self._refresh_timer.timeout.connect(self.refresh)
        self._refresh_timer.start()
        settings.weatherCityChanged.connect(self._schedule_refresh)
        QTimer.singleShot(0, self.refresh)

    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        return self._loading

    @Property(str, notify=errorChanged)
    def errorMessage(self) -> str:
        return self._error_message

    @Property(str, notify=dataChanged)
    def locationName(self) -> str:
        return self._location_name

    @Property(str, notify=dataChanged)
    def condition(self) -> str:
        return self._condition

    @Property(float, notify=dataChanged)
    def temperatureC(self) -> float:
        return self._temperature_c

    @Property(float, notify=dataChanged)
    def apparentC(self) -> float:
        return self._apparent_c

    @Property(float, notify=dataChanged)
    def minimumC(self) -> float:
        return self._minimum_c

    @Property(float, notify=dataChanged)
    def maximumC(self) -> float:
        return self._maximum_c

    @Property(int, notify=dataChanged)
    def precipitationProbability(self) -> int:
        return self._precipitation_probability

    @Property(str, notify=dataChanged)
    def updatedText(self) -> str:
        return self._updated_text

    @Property(int, notify=dataChanged)
    def weatherCode(self) -> int:
        return self._weather_code

    def _set_loading(self, value: bool) -> None:
        if self._loading == value:
            return
        self._loading = value
        self.loadingChanged.emit()

    def _set_error(self, message: str) -> None:
        if self._error_message == message:
            return
        self._error_message = message
        self.errorChanged.emit()

    @Slot()
    def _schedule_refresh(self) -> None:
        QTimer.singleShot(250, self.refresh)

    @Slot()
    def refresh(self) -> None:
        city = self._settings.weatherCity.strip()
        if not city:
            self._set_error("请先输入城市名称")
            return
        # Open-Meteo indexes Wuhan as "武汉", while users commonly enter
        # "武汉市".  Remove a Chinese administrative suffix for lookup only.
        if len(city) > 2 and city[-1] in "市县区州盟":
            city = city[:-1]

        self._request_serial += 1
        serial = self._request_serial
        self._set_loading(True)
        self._set_error("")
        query = urlencode(
            {"name": city, "count": 1, "language": "zh", "format": "json"}
        )
        reply = self._manager.get(
            QNetworkRequest(QUrl(f"https://geocoding-api.open-meteo.com/v1/search?{query}"))
        )
        reply.finished.connect(lambda r=reply, s=serial: self._handle_geocode(r, s))

    def _handle_geocode(self, reply: QNetworkReply, serial: int) -> None:
        try:
            if serial != self._request_serial:
                return
            if reply.error() != QNetworkReply.NetworkError.NoError:
                self._fail(f"城市查询失败：{reply.errorString()}")
                return
            payload = json.loads(bytes(reply.readAll()).decode("utf-8"))
            results = payload.get("results") or []
            if not results:
                self._fail("没有找到这个城市，请检查名称")
                return
            place = results[0]
            self._location_name = place.get("name") or self._settings.weatherCity
            admin = place.get("admin1") or ""
            if admin and admin not in self._location_name:
                self._location_name = f"{self._location_name} · {admin}"
            query = urlencode(
                {
                    "latitude": place["latitude"],
                    "longitude": place["longitude"],
                    "current": "temperature_2m,apparent_temperature,weather_code,precipitation",
                    "daily": "temperature_2m_max,temperature_2m_min,precipitation_probability_max",
                    "timezone": "auto",
                    "forecast_days": 1,
                }
            )
            forecast_reply = self._manager.get(
                QNetworkRequest(QUrl(f"https://api.open-meteo.com/v1/forecast?{query}"))
            )
            forecast_reply.finished.connect(
                lambda r=forecast_reply, s=serial: self._handle_forecast(r, s)
            )
        except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
            self._fail(f"城市数据解析失败：{error}")
        finally:
            reply.deleteLater()

    def _handle_forecast(self, reply: QNetworkReply, serial: int) -> None:
        try:
            if serial != self._request_serial:
                return
            if reply.error() != QNetworkReply.NetworkError.NoError:
                self._fail(f"天气刷新失败：{reply.errorString()}")
                return
            payload = json.loads(bytes(reply.readAll()).decode("utf-8"))
            current = payload["current"]
            daily = payload["daily"]
            self._temperature_c = float(current["temperature_2m"])
            self._apparent_c = float(current["apparent_temperature"])
            self._minimum_c = float(daily["temperature_2m_min"][0])
            self._maximum_c = float(daily["temperature_2m_max"][0])
            self._precipitation_probability = int(
                daily.get("precipitation_probability_max", [0])[0] or 0
            )
            self._weather_code = int(current["weather_code"])
            self._condition = self._weather_description(self._weather_code)
            time_text = str(current.get("time", ""))
            self._updated_text = time_text[11:16] if len(time_text) >= 16 else "刚刚"
            self._set_loading(False)
            self._set_error("")
            self.dataChanged.emit()
        except (KeyError, IndexError, TypeError, ValueError, json.JSONDecodeError) as error:
            self._fail(f"天气数据解析失败：{error}")
        finally:
            reply.deleteLater()

    def _fail(self, message: str) -> None:
        self._set_loading(False)
        self._set_error(message)

    @staticmethod
    def _fahrenheit(celsius: float) -> float:
        return celsius * 9.0 / 5.0 + 32.0

    @Slot(str, result=str)
    def temperatureText(self, unit: str) -> str:
        value = self._fahrenheit(self._temperature_c) if unit == "F" else self._temperature_c
        return f"{round(value)}°"

    @Slot(str, result=str)
    def apparentText(self, unit: str) -> str:
        value = self._fahrenheit(self._apparent_c) if unit == "F" else self._apparent_c
        return f"体感 {round(value)}°"

    @Slot(str, result=str)
    def rangeText(self, unit: str) -> str:
        low = self._fahrenheit(self._minimum_c) if unit == "F" else self._minimum_c
        high = self._fahrenheit(self._maximum_c) if unit == "F" else self._maximum_c
        return f"今日 {round(low)}° / {round(high)}°    降水概率 {self._precipitation_probability}%"

    @staticmethod
    def _weather_description(code: int) -> str:
        if code == 0:
            return "晴"
        if code in {1, 2, 3}:
            return "多云"
        if code in {45, 48}:
            return "有雾"
        if code in {51, 53, 55, 56, 57}:
            return "毛毛雨"
        if code in {61, 63, 65, 66, 67, 80, 81, 82}:
            return "有雨"
        if code in {71, 73, 75, 77, 85, 86}:
            return "有雪"
        if code in {95, 96, 99}:
            return "雷雨"
        return "天气未知"
