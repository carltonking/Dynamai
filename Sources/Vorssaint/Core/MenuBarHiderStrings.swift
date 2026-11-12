// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Strings for the menu bar hider. Same contract as the other FeatureStrings
/// structs: memberwise init with labeled arguments in declaration order, one
/// static per language, all in this file.
struct MenuBarHiderStrings {
    let pageTitle: String
    let hubDescription: String
    let enable: String
    let enableCaption: String
    let limitsCaption: String
    let hideItems: String
    let showItems: String
    let unsupported: String
}

extension FeatureStrings {
    static func menuBarHider(_ language: AppLanguage) -> MenuBarHiderStrings {
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

extension MenuBarHiderStrings {
    static let enUS = MenuBarHiderStrings(
        pageTitle: "Menu bar hider",
        hubDescription: "Tucks the menu bar icons you rarely use behind an arrow, and brings them back with a click.",
        enable: "Hide menu bar icons behind an arrow",
        enableCaption: "Hold ⌘ and drag icons to the left of the arrow to hide them. Click the arrow to show or hide them.",
        limitsCaption: "Hiding works per app, so an app with several icons hides them together. The first time a macOS icon such as Bluetooth is hidden, the menu bar flickers for a moment while Dynamai learns it. Now Playing cannot be hidden.",
        hideItems: "Hide menu bar icons",
        showItems: "Show hidden menu bar icons",
        unsupported: "Needs macOS 27 or later."
    )

    static let ptBR = MenuBarHiderStrings(
        pageTitle: "Ocultar itens da barra de menus",
        hubDescription: "Guarda atrás de uma seta os ícones da barra de menus que você quase não usa, e os traz de volta com um clique.",
        enable: "Ocultar ícones da barra de menus atrás de uma seta",
        enableCaption: "Segure ⌘ e arraste ícones para a esquerda da seta para ocultá-los. Clique na seta para mostrá-los ou ocultá-los.",
        limitsCaption: "A ocultação vale por app, então um app com vários ícones oculta todos juntos. Na primeira vez que um ícone do macOS, como o Bluetooth, é ocultado, a barra pisca por um instante enquanto o Dynamai o reconhece. Tocando Agora não pode ser ocultado.",
        hideItems: "Ocultar ícones da barra de menus",
        showItems: "Mostrar ícones ocultos da barra de menus",
        unsupported: "Requer macOS 27 ou posterior."
    )

    static let tr = MenuBarHiderStrings(
        pageTitle: "Menü çubuğu gizleyici",
        hubDescription: "Nadiren kullandığınız menü çubuğu simgelerini bir okun arkasına saklar ve tek tıkla geri getirir.",
        enable: "Menü çubuğu simgelerini bir okun arkasına gizle",
        enableCaption: "Gizlemek için ⌘ tuşunu basılı tutup simgeleri okun soluna sürükleyin. Göstermek veya gizlemek için oka tıklayın.",
        limitsCaption: "Gizleme uygulama başınadır, bu yüzden birden fazla simgesi olan bir uygulama hepsini birlikte gizler. Bluetooth gibi bir macOS simgesi ilk kez gizlendiğinde, Dynamai onu tanırken menü çubuğu bir an titrer. Şimdi Çalıyor gizlenemez.",
        hideItems: "Menü çubuğu simgelerini gizle",
        showItems: "Gizli menü çubuğu simgelerini göster",
        unsupported: "macOS 27 veya üstü gerekir."
    )

    static let ru = MenuBarHiderStrings(
        pageTitle: "Скрытие значков строки меню",
        hubDescription: "Прячет редко используемые значки строки меню за стрелкой и возвращает их одним щелчком.",
        enable: "Скрывать значки строки меню за стрелкой",
        enableCaption: "Удерживая ⌘, перетащите значки левее стрелки, чтобы скрыть их. Щелкните стрелку, чтобы показать или скрыть их.",
        limitsCaption: "Скрытие работает для приложения целиком, поэтому приложение с несколькими значками скрывает их все. Когда значок macOS, например Bluetooth, скрывается впервые, строка меню на мгновение мерцает, пока Dynamai его распознает. «Исполняется» скрыть нельзя.",
        hideItems: "Скрыть значки строки меню",
        showItems: "Показать скрытые значки строки меню",
        unsupported: "Требуется macOS 27 или новее."
    )

    static let es = MenuBarHiderStrings(
        pageTitle: "Ocultar iconos de la barra de menús",
        hubDescription: "Guarda tras una flecha los iconos de la barra de menús que casi no usas y los recupera con un clic.",
        enable: "Ocultar iconos de la barra de menús tras una flecha",
        enableCaption: "Mantén pulsada ⌘ y arrastra iconos a la izquierda de la flecha para ocultarlos. Haz clic en la flecha para mostrarlos u ocultarlos.",
        limitsCaption: "La ocultación es por app, así que una app con varios iconos los oculta todos a la vez. La primera vez que se oculta un icono de macOS como Bluetooth, la barra parpadea un momento mientras Dynamai lo reconoce. Ahora suena no se puede ocultar.",
        hideItems: "Ocultar iconos de la barra de menús",
        showItems: "Mostrar iconos ocultos de la barra de menús",
        unsupported: "Requiere macOS 27 o posterior."
    )

    static let sk = MenuBarHiderStrings(
        pageTitle: "Skrývanie ikon na lište menu",
        hubDescription: "Schová ikony na lište menu, ktoré používate zriedka, za šípku a jedným kliknutím ich vráti.",
        enable: "Skrývať ikony na lište menu za šípku",
        enableCaption: "Podržte ⌘ a presuňte ikony naľavo od šípky, aby sa skryli. Kliknutím na šípku ich zobrazíte alebo skryjete.",
        limitsCaption: "Skrývanie platí pre celú aplikáciu, takže aplikácia s viacerými ikonami ich skryje všetky naraz. Keď sa ikona macOS, napríklad Bluetooth, skryje prvýkrát, lišta na okamih zabliká, kým ju Dynamai rozpozná. Práve hrá sa skryť nedá.",
        hideItems: "Skryť ikony na lište menu",
        showItems: "Zobraziť skryté ikony na lište menu",
        unsupported: "Vyžaduje macOS 27 alebo novší."
    )

    static let de = MenuBarHiderStrings(
        pageTitle: "Menüleistensymbole ausblenden",
        hubDescription: "Versteckt selten genutzte Menüleistensymbole hinter einem Pfeil und holt sie mit einem Klick zurück.",
        enable: "Menüleistensymbole hinter einem Pfeil ausblenden",
        enableCaption: "Halte ⌘ gedrückt und ziehe Symbole links neben den Pfeil, um sie auszublenden. Klicke auf den Pfeil, um sie ein- oder auszublenden.",
        limitsCaption: "Ausgeblendet wird pro App, eine App mit mehreren Symbolen blendet also alle zusammen aus. Wenn ein macOS-Symbol wie Bluetooth zum ersten Mal ausgeblendet wird, flackert die Menüleiste kurz, während Dynamai es erkennt. „Läuft gerade“ lässt sich nicht ausblenden.",
        hideItems: "Menüleistensymbole ausblenden",
        showItems: "Ausgeblendete Menüleistensymbole anzeigen",
        unsupported: "Erfordert macOS 27 oder neuer."
    )

    static let fr = MenuBarHiderStrings(
        pageTitle: "Masquer des icônes de la barre des menus",
        hubDescription: "Range derrière une flèche les icônes de la barre des menus que vous utilisez peu, et les ramène d’un clic.",
        enable: "Masquer des icônes de la barre des menus derrière une flèche",
        enableCaption: "Maintenez ⌘ et faites glisser des icônes à gauche de la flèche pour les masquer. Cliquez sur la flèche pour les afficher ou les masquer.",
        limitsCaption: "Le masquage se fait par app : une app avec plusieurs icônes les masque toutes ensemble. La première fois qu’une icône de macOS comme Bluetooth est masquée, la barre clignote un instant pendant que Dynamai la reconnaît. À l’écoute ne peut pas être masqué.",
        hideItems: "Masquer les icônes de la barre des menus",
        showItems: "Afficher les icônes masquées de la barre des menus",
        unsupported: "Nécessite macOS 27 ou version ultérieure."
    )

    static let it = MenuBarHiderStrings(
        pageTitle: "Nascondi icone della barra dei menu",
        hubDescription: "Raccoglie dietro una freccia le icone della barra dei menu che usi poco e le riporta con un clic.",
        enable: "Nascondi le icone della barra dei menu dietro una freccia",
        enableCaption: "Tieni premuto ⌘ e trascina le icone a sinistra della freccia per nasconderle. Fai clic sulla freccia per mostrarle o nasconderle.",
        limitsCaption: "Le icone si nascondono per app, quindi un’app con più icone le nasconde tutte insieme. La prima volta che un’icona di macOS come Bluetooth viene nascosta, la barra lampeggia per un attimo mentre Dynamai la riconosce. In riproduzione non può essere nascosto.",
        hideItems: "Nascondi icone della barra dei menu",
        showItems: "Mostra icone nascoste della barra dei menu",
        unsupported: "Richiede macOS 27 o versioni successive."
    )

    static let ja = MenuBarHiderStrings(
        pageTitle: "メニューバーアイコンを隠す",
        hubDescription: "あまり使わないメニューバーのアイコンを矢印の後ろにしまい、クリックひとつで戻します。",
        enable: "メニューバーのアイコンを矢印の後ろに隠す",
        enableCaption: "⌘キーを押しながらアイコンを矢印の左へドラッグすると隠れます。矢印をクリックすると表示と非表示を切り替えます。",
        limitsCaption: "非表示はアプリ単位なので、複数のアイコンを持つアプリはまとめて隠れます。Bluetooth などの macOS のアイコンを初めて隠すときは、Dynamai が認識する間メニューバーが一瞬ちらつきます。「再生中」は隠せません。",
        hideItems: "メニューバーのアイコンを隠す",
        showItems: "隠したメニューバーのアイコンを表示",
        unsupported: "macOS 27 以降が必要です。"
    )

    static let ko = MenuBarHiderStrings(
        pageTitle: "메뉴 막대 아이콘 숨기기",
        hubDescription: "잘 쓰지 않는 메뉴 막대 아이콘을 화살표 뒤에 숨기고 클릭 한 번으로 다시 보여 줍니다.",
        enable: "메뉴 막대 아이콘을 화살표 뒤에 숨기기",
        enableCaption: "⌘ 키를 누른 채 아이콘을 화살표 왼쪽으로 드래그하면 숨겨집니다. 화살표를 클릭해 보이거나 숨기세요.",
        limitsCaption: "숨기기는 앱 단위로 적용되므로 아이콘이 여러 개인 앱은 모두 함께 숨겨집니다. Bluetooth 같은 macOS 아이콘을 처음 숨길 때는 Dynamai가 인식하는 동안 메뉴 막대가 잠깐 깜박입니다. 지금 재생 중은 숨길 수 없습니다.",
        hideItems: "메뉴 막대 아이콘 숨기기",
        showItems: "숨긴 메뉴 막대 아이콘 보기",
        unsupported: "macOS 27 이상이 필요합니다."
    )

    static let zhHans = MenuBarHiderStrings(
        pageTitle: "菜单栏图标隐藏",
        hubDescription: "把不常用的菜单栏图标收到箭头后面，点一下就能找回来。",
        enable: "将菜单栏图标隐藏在箭头后面",
        enableCaption: "按住 ⌘ 将图标拖到箭头左侧即可隐藏。点按箭头可显示或隐藏它们。",
        limitsCaption: "隐藏以 App 为单位，有多个图标的 App 会一起隐藏。首次隐藏蓝牙等 macOS 图标时，菜单栏会在 Dynamai 识别它的过程中闪烁片刻。“正在播放”无法隐藏。",
        hideItems: "隐藏菜单栏图标",
        showItems: "显示已隐藏的菜单栏图标",
        unsupported: "需要 macOS 27 或更高版本。"
    )

    static let zhTW = MenuBarHiderStrings(
        pageTitle: "選單列圖像隱藏",
        hubDescription: "把不常用的選單列圖像收到箭頭後面，按一下就能找回來。",
        enable: "將選單列圖像隱藏在箭頭後面",
        enableCaption: "按住 ⌘ 將圖像拖到箭頭左側即可隱藏。按一下箭頭可顯示或隱藏它們。",
        limitsCaption: "隱藏以 App 為單位，有多個圖像的 App 會一起隱藏。第一次隱藏藍牙等 macOS 圖像時，選單列會在 Dynamai 辨識的過程中閃爍片刻。「正在播放」無法隱藏。",
        hideItems: "隱藏選單列圖像",
        showItems: "顯示已隱藏的選單列圖像",
        unsupported: "需要 macOS 27 或以上版本。"
    )

    static let zhHK = MenuBarHiderStrings(
        pageTitle: "選單列圖像隱藏",
        hubDescription: "把不常用的選單列圖像收到箭咀後面，按一下就能找回來。",
        enable: "將選單列圖像隱藏在箭咀後面",
        enableCaption: "按住 ⌘ 將圖像拖到箭咀左側即可隱藏。按一下箭咀可顯示或隱藏它們。",
        limitsCaption: "隱藏以 App 為單位，有多個圖像的 App 會一起隱藏。第一次隱藏藍牙等 macOS 圖像時，選單列會在 Dynamai 辨識的過程中閃爍片刻。「正在播放」無法隱藏。",
        hideItems: "隱藏選單列圖像",
        showItems: "顯示已隱藏的選單列圖像",
        unsupported: "需要 macOS 27 或以上版本。"
    )

    static let uk = MenuBarHiderStrings(
        pageTitle: "Приховування значків смуги меню",
        hubDescription: "Ховає рідко вживані значки смуги меню за стрілкою і повертає їх одним клацанням.",
        enable: "Ховати значки смуги меню за стрілкою",
        enableCaption: "Утримуючи ⌘, перетягніть значки ліворуч від стрілки, щоб приховати їх. Клацніть стрілку, щоб показати або приховати їх.",
        limitsCaption: "Приховування діє для всієї програми, тож програма з кількома значками ховає їх разом. Коли значок macOS, як-от Bluetooth, приховується вперше, смуга меню на мить блимає, поки Dynamai його розпізнає. «Зараз грає» приховати не можна.",
        hideItems: "Приховати значки смуги меню",
        showItems: "Показати приховані значки смуги меню",
        unsupported: "Потрібна macOS 27 або новіша."
    )
}
