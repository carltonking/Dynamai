// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

/// The Siri page's own words. Siri is the island's own assistant on Apple's
/// language models (Apple Intelligence), separate from Apple's Siri AI app.
/// Everything the agent pages share (Send, Copy, Clear) stays in
/// `NotchHermesChatStrings`; only what names Siri lives here. "SIRI" and
/// "Apple Intelligence" are names and stay as they are in every language.
struct NotchSiriChatStrings {
    let title: String
    let description: String
    let enable: String
    let connecting: String
    let placeholder: String
    let emptyTitle: String
    let emptySubtitle: String
    /// Why Siri cannot answer now; `%1$@` is the reason, in English, from
    /// Apple's availability check.
    let unavailableFormat: String
    let reachedOut: String
    let unreachableFormat: String
    let waiting: String
    let stopped: String

    /// The shared chat page's words with Siri's in place of VERTUS's.
    func chat(_ base: NotchHermesChatStrings) -> NotchHermesChatStrings {
        var words = base
        words.title = title
        words.description = description
        words.enable = enable
        words.connecting = connecting
        words.placeholder = placeholder
        words.emptyTitle = emptyTitle
        words.emptySubtitle = emptySubtitle
        words.thinking = waiting
        words.stopped = stopped
        words.unreachableFormat = unreachableFormat
        words.reachedOut = reachedOut
        // Siri has no routines the page could name.
        words.reachedOutFormat = "\(reachedOut) · %1$@"
        return words
    }
}

extension FeatureStrings {
    static func notchSiriChat(_ language: AppLanguage) -> NotchSiriChatStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ru: return .ru
        case .tr: return .tr
        case .ja: return .ja
        case .ko: return .ko
        case .uk: return .uk
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension NotchSiriChatStrings {
    static let enUS = NotchSiriChatStrings(
        title: "SIRI",
        description: "Your own assistant in the island, on Apple Intelligence. SIRI checks your calendar and reminders, the weather, sets timers and the volume, opens apps and links, and runs your shortcuts.",
        enable: "Show SIRI in the island",
        connecting: "Starting SIRI…",
        placeholder: "Ask SIRI…",
        emptyTitle: "Ask SIRI anything",
        emptySubtitle: "SIRI runs on Apple Intelligence, privately.",
        unavailableFormat: "SIRI needs Apple Intelligence (%1$@).",
        reachedOut: "SIRI wrote",
        unreachableFormat: "SIRI could not answer: %1$@",
        waiting: "Thinking",
        stopped: "Stopped."
    )

    static let ptBR = NotchSiriChatStrings(
        title: "SIRI",
        description: "Seu próprio assistente na ilha, com a Apple Intelligence. A SIRI consulta seu calendário e lembretes, o tempo, define timers e o volume, abre apps e links e executa seus atalhos.",
        enable: "Mostrar a SIRI na ilha",
        connecting: "Iniciando a SIRI…",
        placeholder: "Pergunte à SIRI…",
        emptyTitle: "Pergunte qualquer coisa à SIRI",
        emptySubtitle: "A SIRI funciona com a Apple Intelligence, com privacidade.",
        unavailableFormat: "A SIRI precisa da Apple Intelligence (%1$@).",
        reachedOut: "A SIRI escreveu",
        unreachableFormat: "A SIRI não conseguiu responder: %1$@",
        waiting: "Pensando",
        stopped: "Parado."
    )

    static let es = NotchSiriChatStrings(
        title: "SIRI",
        description: "Tu propio asistente en la isla, con Apple Intelligence. SIRI consulta tu calendario y recordatorios, el tiempo, pone temporizadores y el volumen, abre apps y enlaces y ejecuta tus atajos.",
        enable: "Mostrar SIRI en la isla",
        connecting: "Iniciando SIRI…",
        placeholder: "Pregunta a SIRI…",
        emptyTitle: "Pregunta a SIRI lo que quieras",
        emptySubtitle: "SIRI funciona con Apple Intelligence, de forma privada.",
        unavailableFormat: "SIRI necesita Apple Intelligence (%1$@).",
        reachedOut: "SIRI escribió",
        unreachableFormat: "SIRI no pudo responder: %1$@",
        waiting: "Pensando",
        stopped: "Detenido."
    )

    static let sk = NotchSiriChatStrings(
        title: "SIRI",
        description: "Váš vlastný asistent na ostrove s Apple Intelligence. SIRI pozrie kalendár a pripomienky, počasie, nastaví časovače a hlasitosť, otvorí aplikácie a odkazy a spustí vaše skratky.",
        enable: "Zobraziť SIRI na ostrove",
        connecting: "Spúšťa sa SIRI…",
        placeholder: "Opýtajte sa SIRI…",
        emptyTitle: "Opýtajte sa SIRI čokoľvek",
        emptySubtitle: "SIRI beží na Apple Intelligence, súkromne.",
        unavailableFormat: "SIRI potrebuje Apple Intelligence (%1$@).",
        reachedOut: "SIRI napísala",
        unreachableFormat: "SIRI nemohla odpovedať: %1$@",
        waiting: "Premýšľa",
        stopped: "Zastavené."
    )

    static let de = NotchSiriChatStrings(
        title: "SIRI",
        description: "Dein eigener Assistent in der Insel, mit Apple Intelligence. SIRI sieht in Kalender und Erinnerungen, prüft das Wetter, stellt Timer und Lautstärke, öffnet Apps und Links und führt deine Kurzbefehle aus.",
        enable: "SIRI in der Insel zeigen",
        connecting: "SIRI wird gestartet …",
        placeholder: "SIRI fragen …",
        emptyTitle: "Frag SIRI, was du willst",
        emptySubtitle: "SIRI läuft mit Apple Intelligence, privat.",
        unavailableFormat: "SIRI braucht Apple Intelligence (%1$@).",
        reachedOut: "SIRI hat geschrieben",
        unreachableFormat: "SIRI konnte nicht antworten: %1$@",
        waiting: "Denkt nach",
        stopped: "Gestoppt."
    )

    static let fr = NotchSiriChatStrings(
        title: "SIRI",
        description: "Votre propre assistant dans l’île, avec Apple Intelligence. SIRI consulte votre calendrier et vos rappels, la météo, règle des minuteurs et le volume, ouvre des apps et des liens et lance vos raccourcis.",
        enable: "Afficher SIRI dans l’île",
        connecting: "Démarrage de SIRI…",
        placeholder: "Demander à SIRI…",
        emptyTitle: "Demandez n’importe quoi à SIRI",
        emptySubtitle: "SIRI fonctionne avec Apple Intelligence, en toute confidentialité.",
        unavailableFormat: "SIRI nécessite Apple Intelligence (%1$@).",
        reachedOut: "SIRI a écrit",
        unreachableFormat: "SIRI n’a pas pu répondre\u{00A0}: %1$@",
        waiting: "Réflexion",
        stopped: "Arrêté."
    )

    static let it = NotchSiriChatStrings(
        title: "SIRI",
        description: "Il tuo assistente personale nell’isola, con Apple Intelligence. SIRI controlla calendario e promemoria, il meteo, imposta timer e volume, apre app e link ed esegue i tuoi comandi rapidi.",
        enable: "Mostra SIRI nell’isola",
        connecting: "Avvio di SIRI…",
        placeholder: "Chiedi a SIRI…",
        emptyTitle: "Chiedi qualsiasi cosa a SIRI",
        emptySubtitle: "SIRI funziona con Apple Intelligence, in modo privato.",
        unavailableFormat: "SIRI richiede Apple Intelligence (%1$@).",
        reachedOut: "SIRI ha scritto",
        unreachableFormat: "SIRI non ha potuto rispondere: %1$@",
        waiting: "Sta pensando",
        stopped: "Interrotto."
    )

    static let ru = NotchSiriChatStrings(
        title: "SIRI",
        description: "Ваш собственный ассистент на острове, на Apple Intelligence. SIRI смотрит календарь и напоминания, погоду, ставит таймеры и громкость, открывает приложения и ссылки и запускает ваши быстрые команды.",
        enable: "Показывать SIRI на острове",
        connecting: "SIRI запускается…",
        placeholder: "Спросите SIRI…",
        emptyTitle: "Спросите SIRI о чём угодно",
        emptySubtitle: "SIRI работает на Apple Intelligence, конфиденциально.",
        unavailableFormat: "SIRI нужна Apple Intelligence (%1$@).",
        reachedOut: "SIRI написала",
        unreachableFormat: "SIRI не смогла ответить: %1$@",
        waiting: "Думает",
        stopped: "Остановлено."
    )

    static let tr = NotchSiriChatStrings(
        title: "SIRI",
        description: "Adada kendi asistanınız, Apple Intelligence ile. SIRI takviminize ve anımsatıcılarınıza, hava durumuna bakar; zamanlayıcı ve ses ayarlar, uygulama ve bağlantı açar, kestirmelerinizi çalıştırır.",
        enable: "SIRI’yi adada göster",
        connecting: "SIRI başlatılıyor…",
        placeholder: "SIRI’ye sorun…",
        emptyTitle: "SIRI’ye her şeyi sorun",
        emptySubtitle: "SIRI, Apple Intelligence ile gizli şekilde çalışır.",
        unavailableFormat: "SIRI için Apple Intelligence gerekir (%1$@).",
        reachedOut: "SIRI yazdı",
        unreachableFormat: "SIRI yanıt veremedi: %1$@",
        waiting: "Düşünüyor",
        stopped: "Durduruldu."
    )

    static let ja = NotchSiriChatStrings(
        title: "SIRI",
        description: "アイランドにいる、Apple Intelligenceで動くあなた専用のアシスタント。SIRIはカレンダーやリマインダー、天気を確認し、タイマーや音量を設定し、アプリやリンクを開き、ショートカットを実行します。",
        enable: "アイランドにSIRIを表示",
        connecting: "SIRIを起動しています…",
        placeholder: "SIRIに質問…",
        emptyTitle: "SIRIに何でも聞いてみましょう",
        emptySubtitle: "SIRIはApple Intelligenceでプライベートに動作します。",
        unavailableFormat: "SIRIにはApple Intelligenceが必要です（%1$@）。",
        reachedOut: "SIRIからのメッセージ",
        unreachableFormat: "SIRIが応答できませんでした: %1$@",
        waiting: "考えています",
        stopped: "停止しました。"
    )

    static let ko = NotchSiriChatStrings(
        title: "SIRI",
        description: "아일랜드에 있는 Apple Intelligence 기반의 나만의 비서. SIRI는 캘린더와 미리 알림, 날씨를 확인하고, 타이머와 음량을 설정하며, 앱과 링크를 열고 단축어를 실행합니다.",
        enable: "아일랜드에 SIRI 표시",
        connecting: "SIRI 시작 중…",
        placeholder: "SIRI에게 물어보기…",
        emptyTitle: "SIRI에게 무엇이든 물어보세요",
        emptySubtitle: "SIRI는 Apple Intelligence로 비공개로 작동합니다.",
        unavailableFormat: "SIRI에는 Apple Intelligence가 필요합니다(%1$@).",
        reachedOut: "SIRI가 보낸 메시지",
        unreachableFormat: "SIRI가 응답하지 못했습니다: %1$@",
        waiting: "생각 중",
        stopped: "중지되었습니다."
    )

    static let uk = NotchSiriChatStrings(
        title: "SIRI",
        description: "Ваш власний асистент на острові, на Apple Intelligence. SIRI переглядає календар і нагадування, погоду, ставить таймери й гучність, відкриває застосунки й посилання та запускає ваші швидкі команди.",
        enable: "Показувати SIRI на острові",
        connecting: "SIRI запускається…",
        placeholder: "Запитайте SIRI…",
        emptyTitle: "Запитайте SIRI про будь-що",
        emptySubtitle: "SIRI працює на Apple Intelligence, конфіденційно.",
        unavailableFormat: "SIRI потрібна Apple Intelligence (%1$@).",
        reachedOut: "SIRI написала",
        unreachableFormat: "SIRI не змогла відповісти: %1$@",
        waiting: "Думає",
        stopped: "Зупинено."
    )

    static let zhHans = NotchSiriChatStrings(
        title: "SIRI",
        description: "岛中你自己的助理，由 Apple Intelligence 驱动。SIRI 可以查看日历和提醒事项、天气，设置计时器和音量，打开 App 和链接，并运行你的快捷指令。",
        enable: "在岛中显示 SIRI",
        connecting: "正在启动 SIRI…",
        placeholder: "问问 SIRI…",
        emptyTitle: "问 SIRI 任何问题",
        emptySubtitle: "SIRI 由 Apple Intelligence 私密运行。",
        unavailableFormat: "SIRI 需要 Apple Intelligence（%1$@）。",
        reachedOut: "SIRI 发来消息",
        unreachableFormat: "SIRI 无法回答：%1$@",
        waiting: "正在思考",
        stopped: "已停止。"
    )

    static let zhTW = NotchSiriChatStrings(
        title: "SIRI",
        description: "島中你自己的助理，由 Apple Intelligence 驅動。SIRI 可以查看行事曆和提醒事項、天氣，設定計時器和音量，打開 App 和連結，並執行你的捷徑。",
        enable: "在島中顯示 SIRI",
        connecting: "正在啟動 SIRI…",
        placeholder: "問問 SIRI…",
        emptyTitle: "問 SIRI 任何問題",
        emptySubtitle: "SIRI 由 Apple Intelligence 私密運作。",
        unavailableFormat: "SIRI 需要 Apple Intelligence（%1$@）。",
        reachedOut: "SIRI 傳來訊息",
        unreachableFormat: "SIRI 無法回答：%1$@",
        waiting: "正在思考",
        stopped: "已停止。"
    )

    static let zhHK = NotchSiriChatStrings(
        title: "SIRI",
        description: "島中你自己的助理，由 Apple Intelligence 驅動。SIRI 可以查看日曆和提醒事項、天氣，設定計時器和音量，開啟 App 和連結，並執行你的捷徑。",
        enable: "在島中顯示 SIRI",
        connecting: "正在啟動 SIRI…",
        placeholder: "問問 SIRI…",
        emptyTitle: "問 SIRI 任何問題",
        emptySubtitle: "SIRI 由 Apple Intelligence 私密運作。",
        unavailableFormat: "SIRI 需要 Apple Intelligence（%1$@）。",
        reachedOut: "SIRI 傳來訊息",
        unreachableFormat: "SIRI 無法回答：%1$@",
        waiting: "正在思考",
        stopped: "已停止。"
    )
}
