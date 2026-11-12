// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Strings for the menu bar weather. Same contract as the other
/// FeatureStrings structs: memberwise init with labeled arguments in
/// declaration order, one static per language, all in this file.
struct MenuBarWeatherStrings {
    let pageTitle: String
    let hubDescription: String
    let enable: String
    let enableCaption: String
    let cityLabel: String
    let cityCaption: String
    let unavailable: String
}

extension FeatureStrings {
    static func menuBarWeather(_ language: AppLanguage) -> MenuBarWeatherStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension MenuBarWeatherStrings {
    static let enUS = MenuBarWeatherStrings(
        pageTitle: "Menu bar weather",
        hubDescription: "Shows the temperature in the menu bar in Fahrenheit and Celsius at once.",
        enable: "Show the weather in °F and °C",
        enableCaption: "Every 15 minutes, Dynamai asks Open-Meteo for the current weather in one city. Only the city’s name and coordinates are sent. Click the temperature to open Weather.",
        cityLabel: "City",
        cityCaption: "Leave empty to use the city of your time zone.",
        unavailable: "The weather could not be loaded. Check the city name and your connection."
    )

    static let ptBR = MenuBarWeatherStrings(
        pageTitle: "Clima na barra de menus",
        hubDescription: "Mostra a temperatura na barra de menus em Fahrenheit e Celsius ao mesmo tempo.",
        enable: "Mostrar o clima em °F e °C",
        enableCaption: "A cada 15 minutos, o Dynamai pede ao Open-Meteo o clima atual de uma cidade. Só o nome e as coordenadas da cidade são enviados. Clique na temperatura para abrir o Tempo.",
        cityLabel: "Cidade",
        cityCaption: "Deixe vazio para usar a cidade do seu fuso horário.",
        unavailable: "Não foi possível carregar o clima. Confira o nome da cidade e a sua conexão."
    )

    static let tr = MenuBarWeatherStrings(
        pageTitle: "Menü çubuğunda hava durumu",
        hubDescription: "Sıcaklığı menü çubuğunda aynı anda Fahrenheit ve Celsius olarak gösterir.",
        enable: "Hava durumunu °F ve °C olarak göster",
        enableCaption: "Dynamai her 15 dakikada bir Open-Meteo’dan tek bir şehrin güncel hava durumunu ister. Yalnızca şehrin adı ve koordinatları gönderilir. Hava Durumu’nu açmak için sıcaklığa tıklayın.",
        cityLabel: "Şehir",
        cityCaption: "Saat diliminizin şehrini kullanmak için boş bırakın.",
        unavailable: "Hava durumu yüklenemedi. Şehir adını ve bağlantınızı kontrol edin."
    )

    static let ru = MenuBarWeatherStrings(
        pageTitle: "Погода в строке меню",
        hubDescription: "Показывает температуру в строке меню сразу в градусах Фаренгейта и Цельсия.",
        enable: "Показывать погоду в °F и °C",
        enableCaption: "Каждые 15 минут Dynamai запрашивает у Open-Meteo текущую погоду в одном городе. Отправляются только название города и его координаты. Щелкните температуру, чтобы открыть «Погоду».",
        cityLabel: "Город",
        cityCaption: "Оставьте пустым, чтобы использовать город вашего часового пояса.",
        unavailable: "Не удалось загрузить погоду. Проверьте название города и подключение."
    )

    static let es = MenuBarWeatherStrings(
        pageTitle: "El tiempo en la barra de menús",
        hubDescription: "Muestra la temperatura en la barra de menús en Fahrenheit y Celsius a la vez.",
        enable: "Mostrar el tiempo en °F y °C",
        enableCaption: "Cada 15 minutos, Dynamai pide a Open-Meteo el tiempo actual de una ciudad. Solo se envían el nombre y las coordenadas de la ciudad. Haz clic en la temperatura para abrir Tiempo.",
        cityLabel: "Ciudad",
        cityCaption: "Déjalo vacío para usar la ciudad de tu zona horaria.",
        unavailable: "No se pudo cargar el tiempo. Revisa el nombre de la ciudad y tu conexión."
    )

    static let sk = MenuBarWeatherStrings(
        pageTitle: "Počasie na lište menu",
        hubDescription: "Zobrazuje teplotu na lište menu naraz vo Fahrenheitoch aj v Celziách.",
        enable: "Zobrazovať počasie v °F a °C",
        enableCaption: "Každých 15 minút si Dynamai vyžiada od Open-Meteo aktuálne počasie v jednom meste. Odosiela sa len názov mesta a jeho súradnice. Kliknutím na teplotu otvoríte Počasie.",
        cityLabel: "Mesto",
        cityCaption: "Nechajte prázdne, ak chcete použiť mesto vášho časového pásma.",
        unavailable: "Počasie sa nepodarilo načítať. Skontrolujte názov mesta a pripojenie."
    )

    static let de = MenuBarWeatherStrings(
        pageTitle: "Wetter in der Menüleiste",
        hubDescription: "Zeigt die Temperatur in der Menüleiste gleichzeitig in Fahrenheit und Celsius.",
        enable: "Wetter in °F und °C anzeigen",
        enableCaption: "Alle 15 Minuten fragt Dynamai bei Open-Meteo das aktuelle Wetter einer Stadt ab. Gesendet werden nur der Name und die Koordinaten der Stadt. Klicke auf die Temperatur, um Wetter zu öffnen.",
        cityLabel: "Stadt",
        cityCaption: "Leer lassen, um die Stadt deiner Zeitzone zu verwenden.",
        unavailable: "Das Wetter konnte nicht geladen werden. Prüfe den Stadtnamen und deine Verbindung."
    )

    static let fr = MenuBarWeatherStrings(
        pageTitle: "Météo dans la barre des menus",
        hubDescription: "Affiche la température dans la barre des menus en Fahrenheit et en Celsius à la fois.",
        enable: "Afficher la météo en °F et °C",
        enableCaption: "Toutes les 15 minutes, Dynamai demande à Open-Meteo la météo actuelle d’une ville. Seuls le nom de la ville et ses coordonnées sont envoyés. Cliquez sur la température pour ouvrir Météo.",
        cityLabel: "Ville",
        cityCaption: "Laissez vide pour utiliser la ville de votre fuseau horaire.",
        unavailable: "Impossible de charger la météo. Vérifiez le nom de la ville et votre connexion."
    )

    static let it = MenuBarWeatherStrings(
        pageTitle: "Meteo nella barra dei menu",
        hubDescription: "Mostra la temperatura nella barra dei menu in Fahrenheit e Celsius insieme.",
        enable: "Mostra il meteo in °F e °C",
        enableCaption: "Ogni 15 minuti Dynamai chiede a Open-Meteo il meteo attuale di una città. Vengono inviati solo il nome della città e le sue coordinate. Fai clic sulla temperatura per aprire Meteo.",
        cityLabel: "Città",
        cityCaption: "Lascia vuoto per usare la città del tuo fuso orario.",
        unavailable: "Impossibile caricare il meteo. Controlla il nome della città e la connessione."
    )

    static let ja = MenuBarWeatherStrings(
        pageTitle: "メニューバーの天気",
        hubDescription: "メニューバーに気温を華氏と摂氏の両方で表示します。",
        enable: "天気を °F と °C で表示",
        enableCaption: "Dynamai は 15 分ごとに Open-Meteo に 1 つの都市の現在の天気を問い合わせます。送信されるのは都市名と座標だけです。気温をクリックすると天気アプリが開きます。",
        cityLabel: "都市",
        cityCaption: "空欄にすると、タイムゾーンの都市を使います。",
        unavailable: "天気を読み込めませんでした。都市名と接続を確認してください。"
    )

    static let ko = MenuBarWeatherStrings(
        pageTitle: "메뉴 막대 날씨",
        hubDescription: "메뉴 막대에 기온을 화씨와 섭씨로 함께 보여 줍니다.",
        enable: "날씨를 °F와 °C로 보기",
        enableCaption: "Dynamai는 15분마다 Open-Meteo에 한 도시의 현재 날씨를 요청합니다. 도시 이름과 좌표만 전송됩니다. 기온을 클릭하면 날씨 앱이 열립니다.",
        cityLabel: "도시",
        cityCaption: "비워 두면 시간대의 도시를 사용합니다.",
        unavailable: "날씨를 불러오지 못했습니다. 도시 이름과 연결을 확인하세요."
    )

    static let zhHans = MenuBarWeatherStrings(
        pageTitle: "菜单栏天气",
        hubDescription: "在菜单栏同时以华氏度和摄氏度显示气温。",
        enable: "以 °F 和 °C 显示天气",
        enableCaption: "Dynamai 每 15 分钟向 Open-Meteo 获取一个城市的当前天气，只发送城市名称和坐标。点按气温可打开“天气”。",
        cityLabel: "城市",
        cityCaption: "留空则使用你所在时区的城市。",
        unavailable: "无法载入天气。请检查城市名称和网络连接。"
    )

    static let zhTW = MenuBarWeatherStrings(
        pageTitle: "選單列天氣",
        hubDescription: "在選單列同時以華氏和攝氏顯示氣溫。",
        enable: "以 °F 和 °C 顯示天氣",
        enableCaption: "Dynamai 每 15 分鐘向 Open-Meteo 取得一個城市的目前天氣，只傳送城市名稱和座標。按一下氣溫可打開「天氣」。",
        cityLabel: "城市",
        cityCaption: "留空則使用你所在時區的城市。",
        unavailable: "無法載入天氣。請檢查城市名稱和網路連線。"
    )

    static let zhHK = MenuBarWeatherStrings(
        pageTitle: "選單列天氣",
        hubDescription: "在選單列同時以華氏和攝氏顯示氣溫。",
        enable: "以 °F 和 °C 顯示天氣",
        enableCaption: "Dynamai 每 15 分鐘向 Open-Meteo 取得一個城市的目前天氣，只傳送城市名稱和座標。按一下氣溫可打開「天氣」。",
        cityLabel: "城市",
        cityCaption: "留空則使用你所在時區的城市。",
        unavailable: "無法載入天氣。請檢查城市名稱和網絡連線。"
    )

    static let uk = MenuBarWeatherStrings(
        pageTitle: "Погода на смузі меню",
        hubDescription: "Показує температуру на смузі меню одночасно за Фаренгейтом і Цельсієм.",
        enable: "Показувати погоду в °F і °C",
        enableCaption: "Кожні 15 хвилин Dynamai запитує в Open-Meteo поточну погоду в одному місті. Надсилаються лише назва міста та його координати. Клацніть температуру, щоб відкрити «Погоду».",
        cityLabel: "Місто",
        cityCaption: "Залиште порожнім, щоб використати місто вашого часового поясу.",
        unavailable: "Не вдалося завантажити погоду. Перевірте назву міста й підключення."
    )
}
