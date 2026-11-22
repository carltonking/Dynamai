// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

/// The Muse page's own words. Muse is Meta's personal agent, reached through
/// its website inside this app. Everything the agent pages share (Send, Copy, Clear)
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
        description: "Meta’s Muse in the island, through Muse’s website running inside this app. Read its replies here and send it messages and files; the Muse app never opens. Sign in once with Open Muse, where Muse’s own questions are answered too.",
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
        noWindow: "Muse’s page could not load. Check your internet connection.",
        noConversation: "Click Open Muse and sign in to talk to Muse here.",
        allowAccessibility: "Allow Accessibility",
        openMuse: "Open Muse"
    )

    static let ptBR = NotchMuseChatStrings(
        title: "MUSE",
        description: "O Muse da Meta na ilha, pelo site do Muse rodando dentro deste app. Leia as respostas aqui e envie mensagens e arquivos; o app Muse nunca abre. Entre uma vez em Abrir o Muse, onde também se respondem as perguntas do próprio Muse.",
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
        noWindow: "A página do Muse não carregou. Verifique sua conexão com a internet.",
        noConversation: "Clique em Abrir o Muse e entre na sua conta para conversar com o Muse aqui.",
        allowAccessibility: "Permitir Acessibilidade",
        openMuse: "Abrir o Muse"
    )

    static let es = NotchMuseChatStrings(
        title: "MUSE",
        description: "Muse de Meta en la isla, a través del sitio web de Muse dentro de esta app. Lee aquí sus respuestas y envíale mensajes y archivos; la app Muse nunca se abre. Inicia sesión una vez con Abrir Muse, donde también respondes a las preguntas de Muse.",
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
        noWindow: "La página de Muse no se pudo cargar. Revisa tu conexión a internet.",
        noConversation: "Haz clic en Abrir Muse e inicia sesión para hablar con Muse aquí.",
        allowAccessibility: "Permitir Accesibilidad",
        openMuse: "Abrir Muse"
    )

    static let sk = NotchMuseChatStrings(
        title: "MUSE",
        description: "Muse od Mety v ostrove, cez webovú stránku Muse spustenú v tejto aplikácii. Odpovede čítajte tu a posielajte mu správy aj súbory; aplikácia Muse sa nikdy neotvorí. Prihláste sa raz cez Otvoriť Muse, kde odpovedáte aj na otázky samotného Muse.",
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
        noWindow: "Stránku Muse sa nepodarilo načítať. Skontrolujte pripojenie na internet.",
        noConversation: "Kliknite na Otvoriť Muse a prihláste sa, aby ste s Muse mohli hovoriť tu.",
        allowAccessibility: "Povoliť Prístupnosť",
        openMuse: "Otvoriť Muse"
    )

    static let de = NotchMuseChatStrings(
        title: "MUSE",
        description: "Metas Muse in der Insel, über die Muse-Website, die in dieser App läuft. Lies seine Antworten hier und schick ihm Nachrichten und Dateien; die Muse-App öffnet sich nie. Melde dich einmal über „Muse öffnen“ an, wo du auch die Fragen von Muse beantwortest.",
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
        noWindow: "Die Seite von Muse konnte nicht geladen werden. Prüfe deine Internetverbindung.",
        noConversation: "Klicke auf „Muse öffnen“ und melde dich an, um hier mit Muse zu sprechen.",
        allowAccessibility: "Bedienungshilfen erlauben",
        openMuse: "Muse öffnen"
    )

    static let fr = NotchMuseChatStrings(
        title: "MUSE",
        description: "Muse de Meta dans l’îlot, via le site web de Muse qui tourne dans cette app. Lisez ses réponses ici et envoyez-lui messages et fichiers ; l’app Muse ne s’ouvre jamais. Connectez-vous une fois avec Ouvrir Muse, où vous répondez aussi aux questions de Muse.",
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
        noWindow: "La page de Muse n’a pas pu se charger. Vérifiez votre connexion internet.",
        noConversation: "Cliquez sur Ouvrir Muse et connectez-vous pour parler à Muse ici.",
        allowAccessibility: "Autoriser l’Accessibilité",
        openMuse: "Ouvrir Muse"
    )

    static let it = NotchMuseChatStrings(
        title: "MUSE",
        description: "Muse di Meta nell’isola, tramite il sito web di Muse in esecuzione in questa app. Leggi qui le sue risposte e mandagli messaggi e file; l’app Muse non si apre mai. Accedi una volta con Apri Muse, dove rispondi anche alle domande di Muse.",
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
        noWindow: "Non è stato possibile caricare la pagina di Muse. Controlla la connessione a internet.",
        noConversation: "Fai clic su Apri Muse e accedi per parlare con Muse qui.",
        allowAccessibility: "Consenti Accessibilità",
        openMuse: "Apri Muse"
    )

    static let ru = NotchMuseChatStrings(
        title: "MUSE",
        description: "Muse от Meta в острове, через сайт Muse, работающий внутри этого приложения. Читайте его ответы здесь и отправляйте сообщения и файлы; приложение Muse никогда не открывается. Войдите один раз через «Открыть Muse», там же отвечайте на вопросы Muse.",
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
        noWindow: "Не удалось загрузить страницу Muse. Проверьте подключение к интернету.",
        noConversation: "Нажмите «Открыть Muse» и войдите, чтобы говорить с Muse здесь.",
        allowAccessibility: "Разрешить Универсальный доступ",
        openMuse: "Открыть Muse"
    )

    static let tr = NotchMuseChatStrings(
        title: "MUSE",
        description: "Meta’nın Muse’u adada, bu uygulamanın içinde çalışan Muse web sitesi üzerinden. Yanıtlarını burada okuyun, ona mesaj ve dosya gönderin; Muse uygulaması hiç açılmaz. Muse’u Aç ile bir kez oturum açın; Muse’un sorularını da orada yanıtlarsınız.",
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
        noWindow: "Muse sayfası yüklenemedi. İnternet bağlantınızı kontrol edin.",
        noConversation: "Muse ile burada konuşmak için Muse’u Aç’a tıklayıp oturum açın.",
        allowAccessibility: "Erişilebilirliğe İzin Ver",
        openMuse: "Muse’u Aç"
    )

    static let ja = NotchMuseChatStrings(
        title: "MUSE",
        description: "MetaのMuseを、このアプリ内で動くMuseのWebサイト経由でアイランドに。返信はここで読み、メッセージやファイルを送れます。Museアプリは開きません。「Museを開く」で一度サインインしてください。Museからの質問にもそこで答えられます。",
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
        noWindow: "Museのページを読み込めませんでした。インターネット接続を確認してください。",
        noConversation: "ここでMuseと話すには、「Museを開く」をクリックしてサインインしてください。",
        allowAccessibility: "アクセシビリティを許可",
        openMuse: "Museを開く"
    )

    static let ko = NotchMuseChatStrings(
        title: "MUSE",
        description: "Meta의 Muse를 이 앱 안에서 실행되는 Muse 웹사이트를 통해 아일랜드에서. 답장은 여기서 읽고 메시지와 파일을 보낼 수 있으며 Muse 앱은 열리지 않습니다. ‘Muse 열기’에서 한 번 로그인하세요. Muse의 질문에도 그곳에서 답할 수 있습니다.",
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
        noWindow: "Muse 페이지를 불러오지 못했습니다. 인터넷 연결을 확인하세요.",
        noConversation: "여기에서 Muse와 대화하려면 ‘Muse 열기’를 클릭하고 로그인하세요.",
        allowAccessibility: "손쉬운 사용 허용",
        openMuse: "Muse 열기"
    )

    static let uk = NotchMuseChatStrings(
        title: "MUSE",
        description: "Muse від Meta в острові, через вебсайт Muse, що працює в цьому застосунку. Читайте його відповіді тут і надсилайте повідомлення та файли; застосунок Muse ніколи не відкривається. Увійдіть один раз через «Відкрити Muse», там же відповідайте на запитання Muse.",
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
        noWindow: "Не вдалося завантажити сторінку Muse. Перевірте підключення до інтернету.",
        noConversation: "Натисніть «Відкрити Muse» й увійдіть, щоб говорити з Muse тут.",
        allowAccessibility: "Дозволити Універсальний доступ",
        openMuse: "Відкрити Muse"
    )

    static let zhHans = NotchMuseChatStrings(
        title: "MUSE",
        description: "通过在此 App 内运行的 Muse 网站，在灵动岛中使用 Meta 的 Muse。在这里阅读它的回复，并发送消息和文件；Muse App 不会打开。请通过“打开 Muse”登录一次，Muse 提出的问题也在那里回答。",
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
        noWindow: "无法载入 Muse 的页面。请检查你的互联网连接。",
        noConversation: "点按“打开 Muse”并登录，即可在这里与 Muse 对话。",
        allowAccessibility: "允许辅助功能",
        openMuse: "打开 Muse"
    )

    static let zhTW = NotchMuseChatStrings(
        title: "MUSE",
        description: "透過在此 App 內執行的 Muse 網站，在動態島中使用 Meta 的 Muse。在這裡閱讀它的回覆，並傳送訊息和檔案；Muse App 不會打開。請透過「打開 Muse」登入一次，Muse 提出的問題也在那裡回答。",
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
        noWindow: "無法載入 Muse 的頁面。請檢查你的網際網路連線。",
        noConversation: "按一下「打開 Muse」並登入，即可在這裡與 Muse 對話。",
        allowAccessibility: "允許輔助使用",
        openMuse: "打開 Muse"
    )

    static let zhHK = NotchMuseChatStrings(
        title: "MUSE",
        description: "透過在此 App 內執行的 Muse 網站，在動態島中使用 Meta 的 Muse。在這裡閱讀它的回覆，並傳送訊息和檔案；Muse App 不會打開。請透過「打開 Muse」登入一次，Muse 提出的問題也在那裡回答。",
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
        noWindow: "無法載入 Muse 的頁面。請檢查你的互聯網連線。",
        noConversation: "按一下「打開 Muse」並登入，即可在這裡與 Muse 對話。",
        allowAccessibility: "允許輔助使用",
        openMuse: "打開 Muse"
    )
}
