// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

/// The Muse page's own words. Muse is Meta's personal agent, reached through
/// the Muse for Mac app. Everything the agent pages share (Send, Copy, Clear)
/// stays in `NotchHermesChatStrings`; only what names Muse lives here.
/// "MUSE", "Muse" and "Meta" are names and stay as they are in every
/// language.
struct NotchMuseChatStrings {
    let title: String
    let description: String
    let enable: String
    let connecting: String
    let placeholder: String
    let emptyTitle: String
    let emptySubtitle: String
    let reachedOut: String
    /// Why Muse could not answer; `%1$@` is the reason.
    let unreachableFormat: String
    let waiting: String
    let stopped: String
    /// Why the page cannot reach Muse now, one line per `MuseAppSupport.Problem`.
    let notInstalled: String
    let needsAccessibility: String
    let noWindow: String
    let noConversation: String
    let allowAccessibility: String
    let openMuse: String

    func problem(_ problem: MuseAppSupport.Problem) -> String {
        switch problem {
        case .notInstalled: return notInstalled
        case .needsAccessibility: return needsAccessibility
        case .noWindow: return noWindow
        case .noConversation: return noConversation
        }
    }

    /// The shared chat page's words with Muse's in place of VERTUS's.
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
        // Muse has no routines the page could name.
        words.reachedOutFormat = "\(reachedOut) · %1$@"
        return words
    }
}

extension FeatureStrings {
    static func notchMuseChat(_ language: AppLanguage) -> NotchMuseChatStrings {
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

extension NotchMuseChatStrings {
    static let enUS = NotchMuseChatStrings(
        title: "MUSE",
        description: "Meta’s Muse in the island, through the Muse app. Read its replies here, and send it messages and files: Muse comes forward for a moment to take each one, then goes back behind your work. Keep the Muse app open and signed in.",
        enable: "Show MUSE in the island",
        connecting: "Looking for Muse…",
        placeholder: "Message Muse…",
        emptyTitle: "Text Muse",
        emptySubtitle: "The same conversation as the Muse app and your phone.",
        reachedOut: "Muse wrote",
        unreachableFormat: "Muse could not answer: %1$@",
        waiting: "Thinking",
        stopped: "Stopped.",
        notInstalled: "Install the Muse app from Meta to talk to Muse here.",
        needsAccessibility: "Allow Accessibility for this app so it can read and write in the Muse app.",
        noWindow: "Open the Muse app’s window to talk to Muse here.",
        noConversation: "Sign in to the Muse app and open your chat to talk to Muse here.",
        allowAccessibility: "Allow Accessibility",
        openMuse: "Open Muse"
    )

    static let ptBR = NotchMuseChatStrings(
        title: "MUSE",
        description: "O Muse da Meta na ilha, pelo app Muse. Leia as respostas aqui e envie mensagens e arquivos: o Muse vem para a frente por um instante para receber cada um e depois volta para trás do seu trabalho. Mantenha o app Muse aberto e conectado.",
        enable: "Mostrar o MUSE na ilha",
        connecting: "Procurando o Muse…",
        placeholder: "Mensagem para o Muse…",
        emptyTitle: "Converse com o Muse",
        emptySubtitle: "A mesma conversa do app Muse e do seu celular.",
        reachedOut: "O Muse escreveu",
        unreachableFormat: "O Muse não conseguiu responder: %1$@",
        waiting: "Pensando",
        stopped: "Parado.",
        notInstalled: "Instale o app Muse da Meta para conversar com o Muse aqui.",
        needsAccessibility: "Permita a Acessibilidade para este app poder ler e escrever no app Muse.",
        noWindow: "Abra a janela do app Muse para conversar com o Muse aqui.",
        noConversation: "Entre no app Muse e abra sua conversa para falar com o Muse aqui.",
        allowAccessibility: "Permitir Acessibilidade",
        openMuse: "Abrir o Muse"
    )

    static let es = NotchMuseChatStrings(
        title: "MUSE",
        description: "Muse de Meta en la isla, a través de la app Muse. Lee aquí sus respuestas y envíale mensajes y archivos: Muse pasa al frente un momento para recibir cada uno y luego vuelve detrás de tu trabajo. Mantén la app Muse abierta y con la sesión iniciada.",
        enable: "Mostrar MUSE en la isla",
        connecting: "Buscando Muse…",
        placeholder: "Mensaje para Muse…",
        emptyTitle: "Escribe a Muse",
        emptySubtitle: "La misma conversación que en la app Muse y en tu teléfono.",
        reachedOut: "Muse escribió",
        unreachableFormat: "Muse no pudo responder: %1$@",
        waiting: "Pensando",
        stopped: "Detenido.",
        notInstalled: "Instala la app Muse de Meta para hablar con Muse aquí.",
        needsAccessibility: "Permite la Accesibilidad para esta app, para que pueda leer y escribir en la app Muse.",
        noWindow: "Abre la ventana de la app Muse para hablar con Muse aquí.",
        noConversation: "Inicia sesión en la app Muse y abre tu chat para hablar con Muse aquí.",
        allowAccessibility: "Permitir Accesibilidad",
        openMuse: "Abrir Muse"
    )

    static let sk = NotchMuseChatStrings(
        title: "MUSE",
        description: "Muse od Mety v ostrove, cez aplikáciu Muse. Odpovede čítajte tu a posielajte mu správy aj súbory: Muse sa na chvíľu dostane dopredu, aby každú prevzal, a potom sa vráti za vašu prácu. Nechajte aplikáciu Muse otvorenú a prihlásenú.",
        enable: "Zobraziť MUSE v ostrove",
        connecting: "Hľadá sa Muse…",
        placeholder: "Správa pre Muse…",
        emptyTitle: "Napíšte Muse",
        emptySubtitle: "Rovnaká konverzácia ako v aplikácii Muse a v telefóne.",
        reachedOut: "Muse napísal",
        unreachableFormat: "Muse nemohol odpovedať: %1$@",
        waiting: "Premýšľa",
        stopped: "Zastavené.",
        notInstalled: "Nainštalujte aplikáciu Muse od Mety, aby ste s Muse mohli hovoriť tu.",
        needsAccessibility: "Povoľte tejto aplikácii Prístupnosť, aby mohla čítať a písať v aplikácii Muse.",
        noWindow: "Otvorte okno aplikácie Muse, aby ste s Muse mohli hovoriť tu.",
        noConversation: "Prihláste sa do aplikácie Muse a otvorte svoj chat, aby ste s Muse mohli hovoriť tu.",
        allowAccessibility: "Povoliť Prístupnosť",
        openMuse: "Otvoriť Muse"
    )

    static let de = NotchMuseChatStrings(
        title: "MUSE",
        description: "Metas Muse in der Insel, über die Muse-App. Lies seine Antworten hier und schick ihm Nachrichten und Dateien: Muse kommt kurz nach vorn, um jede entgegenzunehmen, und geht dann wieder hinter deine Arbeit zurück. Lass die Muse-App geöffnet und angemeldet.",
        enable: "MUSE in der Insel zeigen",
        connecting: "Muse wird gesucht …",
        placeholder: "Nachricht an Muse …",
        emptyTitle: "Schreib Muse",
        emptySubtitle: "Dieselbe Unterhaltung wie in der Muse-App und auf deinem Telefon.",
        reachedOut: "Muse hat geschrieben",
        unreachableFormat: "Muse konnte nicht antworten: %1$@",
        waiting: "Denkt nach",
        stopped: "Gestoppt.",
        notInstalled: "Installiere die Muse-App von Meta, um hier mit Muse zu sprechen.",
        needsAccessibility: "Erlaube dieser App die Bedienungshilfen, damit sie in der Muse-App lesen und schreiben kann.",
        noWindow: "Öffne das Fenster der Muse-App, um hier mit Muse zu sprechen.",
        noConversation: "Melde dich in der Muse-App an und öffne deinen Chat, um hier mit Muse zu sprechen.",
        allowAccessibility: "Bedienungshilfen erlauben",
        openMuse: "Muse öffnen"
    )

    static let fr = NotchMuseChatStrings(
        title: "MUSE",
        description: "Muse de Meta dans l’îlot, via l’app Muse. Lisez ses réponses ici et envoyez-lui messages et fichiers : Muse passe un instant au premier plan pour recevoir chacun, puis repasse derrière votre travail. Gardez l’app Muse ouverte et connectée.",
        enable: "Afficher MUSE dans l’îlot",
        connecting: "Recherche de Muse…",
        placeholder: "Message pour Muse…",
        emptyTitle: "Écrivez à Muse",
        emptySubtitle: "La même conversation que dans l’app Muse et sur votre téléphone.",
        reachedOut: "Muse a écrit",
        unreachableFormat: "Muse n’a pas pu répondre : %1$@",
        waiting: "Réflexion",
        stopped: "Arrêté.",
        notInstalled: "Installez l’app Muse de Meta pour parler à Muse ici.",
        needsAccessibility: "Autorisez l’Accessibilité pour cette app afin qu’elle puisse lire et écrire dans l’app Muse.",
        noWindow: "Ouvrez la fenêtre de l’app Muse pour parler à Muse ici.",
        noConversation: "Connectez-vous à l’app Muse et ouvrez votre conversation pour parler à Muse ici.",
        allowAccessibility: "Autoriser l’Accessibilité",
        openMuse: "Ouvrir Muse"
    )

    static let it = NotchMuseChatStrings(
        title: "MUSE",
        description: "Muse di Meta nell’isola, tramite l’app Muse. Leggi qui le sue risposte e mandagli messaggi e file: Muse viene in primo piano per un attimo per ricevere ognuno, poi torna dietro il tuo lavoro. Tieni l’app Muse aperta e con l’accesso effettuato.",
        enable: "Mostra MUSE nell’isola",
        connecting: "Ricerca di Muse…",
        placeholder: "Messaggio per Muse…",
        emptyTitle: "Scrivi a Muse",
        emptySubtitle: "La stessa conversazione dell’app Muse e del tuo telefono.",
        reachedOut: "Muse ha scritto",
        unreachableFormat: "Muse non ha potuto rispondere: %1$@",
        waiting: "Sta pensando",
        stopped: "Interrotto.",
        notInstalled: "Installa l’app Muse di Meta per parlare con Muse qui.",
        needsAccessibility: "Consenti l’Accessibilità a questa app perché possa leggere e scrivere nell’app Muse.",
        noWindow: "Apri la finestra dell’app Muse per parlare con Muse qui.",
        noConversation: "Accedi all’app Muse e apri la tua chat per parlare con Muse qui.",
        allowAccessibility: "Consenti Accessibilità",
        openMuse: "Apri Muse"
    )

    static let ru = NotchMuseChatStrings(
        title: "MUSE",
        description: "Muse от Meta в острове, через приложение Muse. Читайте его ответы здесь и отправляйте сообщения и файлы: Muse на мгновение выходит на передний план, чтобы принять каждое, и снова уходит за вашу работу. Держите приложение Muse открытым и со входом.",
        enable: "Показывать MUSE в острове",
        connecting: "Поиск Muse…",
        placeholder: "Сообщение для Muse…",
        emptyTitle: "Напишите Muse",
        emptySubtitle: "Тот же разговор, что в приложении Muse и на телефоне.",
        reachedOut: "Muse написал",
        unreachableFormat: "Muse не смог ответить: %1$@",
        waiting: "Думает",
        stopped: "Остановлено.",
        notInstalled: "Установите приложение Muse от Meta, чтобы говорить с Muse здесь.",
        needsAccessibility: "Разрешите этому приложению Универсальный доступ, чтобы оно могло читать и писать в приложении Muse.",
        noWindow: "Откройте окно приложения Muse, чтобы говорить с Muse здесь.",
        noConversation: "Войдите в приложение Muse и откройте свой чат, чтобы говорить с Muse здесь.",
        allowAccessibility: "Разрешить Универсальный доступ",
        openMuse: "Открыть Muse"
    )

    static let tr = NotchMuseChatStrings(
        title: "MUSE",
        description: "Meta’nın Muse’u adada, Muse uygulaması üzerinden. Yanıtlarını burada okuyun, ona mesaj ve dosya gönderin: Muse her birini almak için bir anlığına öne gelir, sonra işinizin arkasına döner. Muse uygulamasını açık ve oturumu açık tutun.",
        enable: "MUSE’u adada göster",
        connecting: "Muse aranıyor…",
        placeholder: "Muse’a mesaj…",
        emptyTitle: "Muse’a yazın",
        emptySubtitle: "Muse uygulaması ve telefonunuzdaki sohbetin aynısı.",
        reachedOut: "Muse yazdı",
        unreachableFormat: "Muse yanıt veremedi: %1$@",
        waiting: "Düşünüyor",
        stopped: "Durduruldu.",
        notInstalled: "Muse ile burada konuşmak için Meta’nın Muse uygulamasını yükleyin.",
        needsAccessibility: "Muse uygulamasında okuyup yazabilmesi için bu uygulamaya Erişilebilirlik izni verin.",
        noWindow: "Muse ile burada konuşmak için Muse uygulamasının penceresini açın.",
        noConversation: "Muse ile burada konuşmak için Muse uygulamasında oturum açıp sohbetinizi açın.",
        allowAccessibility: "Erişilebilirliğe İzin Ver",
        openMuse: "Muse’u Aç"
    )

    static let ja = NotchMuseChatStrings(
        title: "MUSE",
        description: "MetaのMuseをMuseアプリ経由でアイランドに。返信はここで読み、メッセージやファイルを送れます。送るたびにMuseが一瞬前面に出て受け取り、また作業の後ろに戻ります。Museアプリは開いてサインインしたままにしてください。",
        enable: "アイランドにMUSEを表示",
        connecting: "Museを探しています…",
        placeholder: "Museにメッセージ…",
        emptyTitle: "Museにメッセージを送る",
        emptySubtitle: "Museアプリやスマートフォンと同じ会話です。",
        reachedOut: "Museからのメッセージ",
        unreachableFormat: "Museが応答できませんでした：%1$@",
        waiting: "考え中",
        stopped: "停止しました。",
        notInstalled: "ここでMuseと話すには、MetaのMuseアプリをインストールしてください。",
        needsAccessibility: "Museアプリで読み書きできるよう、このアプリにアクセシビリティを許可してください。",
        noWindow: "ここでMuseと話すには、Museアプリのウインドウを開いてください。",
        noConversation: "ここでMuseと話すには、Museアプリにサインインしてチャットを開いてください。",
        allowAccessibility: "アクセシビリティを許可",
        openMuse: "Museを開く"
    )

    static let ko = NotchMuseChatStrings(
        title: "MUSE",
        description: "Meta의 Muse를 Muse 앱을 통해 아일랜드에서. 답장은 여기서 읽고 메시지와 파일을 보낼 수 있습니다. 보낼 때마다 Muse가 잠깐 앞으로 나와 받은 뒤 다시 작업 뒤로 돌아갑니다. Muse 앱을 열어 두고 로그인 상태로 유지하세요.",
        enable: "아일랜드에 MUSE 표시",
        connecting: "Muse를 찾는 중…",
        placeholder: "Muse에게 메시지…",
        emptyTitle: "Muse에게 메시지 보내기",
        emptySubtitle: "Muse 앱 및 휴대폰과 같은 대화입니다.",
        reachedOut: "Muse가 보낸 메시지",
        unreachableFormat: "Muse가 답하지 못했습니다: %1$@",
        waiting: "생각 중",
        stopped: "중지됨.",
        notInstalled: "여기에서 Muse와 대화하려면 Meta의 Muse 앱을 설치하세요.",
        needsAccessibility: "Muse 앱에서 읽고 쓸 수 있도록 이 앱에 손쉬운 사용을 허용하세요.",
        noWindow: "여기에서 Muse와 대화하려면 Muse 앱의 윈도우를 여세요.",
        noConversation: "여기에서 Muse와 대화하려면 Muse 앱에 로그인하고 채팅을 여세요.",
        allowAccessibility: "손쉬운 사용 허용",
        openMuse: "Muse 열기"
    )

    static let uk = NotchMuseChatStrings(
        title: "MUSE",
        description: "Muse від Meta в острові, через застосунок Muse. Читайте його відповіді тут і надсилайте повідомлення та файли: Muse на мить виходить на передній план, щоб прийняти кожне, і повертається за вашу роботу. Тримайте застосунок Muse відкритим і з виконаним входом.",
        enable: "Показувати MUSE в острові",
        connecting: "Пошук Muse…",
        placeholder: "Повідомлення для Muse…",
        emptyTitle: "Напишіть Muse",
        emptySubtitle: "Та сама розмова, що в застосунку Muse і на телефоні.",
        reachedOut: "Muse написав",
        unreachableFormat: "Muse не зміг відповісти: %1$@",
        waiting: "Думає",
        stopped: "Зупинено.",
        notInstalled: "Установіть застосунок Muse від Meta, щоб говорити з Muse тут.",
        needsAccessibility: "Дозвольте цьому застосунку Універсальний доступ, щоб він міг читати й писати в застосунку Muse.",
        noWindow: "Відкрийте вікно застосунку Muse, щоб говорити з Muse тут.",
        noConversation: "Увійдіть у застосунок Muse і відкрийте свій чат, щоб говорити з Muse тут.",
        allowAccessibility: "Дозволити Універсальний доступ",
        openMuse: "Відкрити Muse"
    )

    static let zhHans = NotchMuseChatStrings(
        title: "MUSE",
        description: "通过 Muse App 在灵动岛中使用 Meta 的 Muse。在这里阅读它的回复，并发送消息和文件：每次发送时 Muse 会短暂来到前台接收，然后回到你的工作之后。请保持 Muse App 打开并已登录。",
        enable: "在灵动岛中显示 MUSE",
        connecting: "正在寻找 Muse…",
        placeholder: "给 Muse 发消息…",
        emptyTitle: "给 Muse 发消息",
        emptySubtitle: "与 Muse App 和你的手机中的对话相同。",
        reachedOut: "Muse 发来消息",
        unreachableFormat: "Muse 无法回答：%1$@",
        waiting: "思考中",
        stopped: "已停止。",
        notInstalled: "安装 Meta 的 Muse App 后即可在这里与 Muse 对话。",
        needsAccessibility: "请为此 App 开启辅助功能权限，以便它在 Muse App 中读写。",
        noWindow: "打开 Muse App 的窗口后即可在这里与 Muse 对话。",
        noConversation: "登录 Muse App 并打开你的聊天后即可在这里与 Muse 对话。",
        allowAccessibility: "允许辅助功能",
        openMuse: "打开 Muse"
    )

    static let zhTW = NotchMuseChatStrings(
        title: "MUSE",
        description: "透過 Muse App 在動態島中使用 Meta 的 Muse。在這裡閱讀它的回覆，並傳送訊息和檔案：每次傳送時 Muse 會短暫來到前景接收，然後回到你的工作後方。請保持 Muse App 開啟並已登入。",
        enable: "在動態島中顯示 MUSE",
        connecting: "正在尋找 Muse…",
        placeholder: "傳訊息給 Muse…",
        emptyTitle: "傳訊息給 Muse",
        emptySubtitle: "與 Muse App 和你的手機中的對話相同。",
        reachedOut: "Muse 傳來訊息",
        unreachableFormat: "Muse 無法回答：%1$@",
        waiting: "思考中",
        stopped: "已停止。",
        notInstalled: "安裝 Meta 的 Muse App 後即可在這裡與 Muse 對話。",
        needsAccessibility: "請允許此 App 使用輔助使用權限，以便它在 Muse App 中讀寫。",
        noWindow: "打開 Muse App 的視窗後即可在這裡與 Muse 對話。",
        noConversation: "登入 Muse App 並打開你的聊天後即可在這裡與 Muse 對話。",
        allowAccessibility: "允許輔助使用",
        openMuse: "打開 Muse"
    )

    static let zhHK = NotchMuseChatStrings(
        title: "MUSE",
        description: "透過 Muse App 在動態島中使用 Meta 的 Muse。在這裡閱讀它的回覆，並傳送訊息和檔案：每次傳送時 Muse 會短暫來到前景接收，然後回到你的工作後方。請保持 Muse App 開啟並已登入。",
        enable: "在動態島中顯示 MUSE",
        connecting: "正在尋找 Muse…",
        placeholder: "傳訊息給 Muse…",
        emptyTitle: "傳訊息給 Muse",
        emptySubtitle: "與 Muse App 和你的手機中的對話相同。",
        reachedOut: "Muse 傳來訊息",
        unreachableFormat: "Muse 無法回答：%1$@",
        waiting: "思考中",
        stopped: "已停止。",
        notInstalled: "安裝 Meta 的 Muse App 後即可在這裡與 Muse 對話。",
        needsAccessibility: "請允許此 App 使用輔助使用權限，以便它在 Muse App 中讀寫。",
        noWindow: "打開 Muse App 的視窗後即可在這裡與 Muse 對話。",
        noConversation: "登入 Muse App 並打開你的聊天後即可在這裡與 Muse 對話。",
        allowAccessibility: "允許輔助使用",
        openMuse: "打開 Muse"
    )
}
