// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Strings for the menu bar hider (Hidden Bar, built in). Same contract as the other FeatureStrings
/// structs: memberwise init with labeled arguments in declaration order, one
/// static per language, all in this file.
struct MenuBarHiderStrings {
    let pageTitle: String
    let hubDescription: String
    let enable: String
    let enableCaption: String
    /// Opens Hidden Bar's own settings window.
    let openSettings: String
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
        openSettings: "Hidden Bar Settings…"
    )

    static let ptBR = MenuBarHiderStrings(
        pageTitle: "Ocultar itens da barra de menus",
        hubDescription: "Guarda atrás de uma seta os ícones da barra de menus que você quase não usa, e os traz de volta com um clique.",
        enable: "Ocultar ícones da barra de menus atrás de uma seta",
        enableCaption: "Segure ⌘ e arraste ícones para a esquerda da seta para ocultá-los. Clique na seta para mostrá-los ou ocultá-los.",
        openSettings: "Ajustes do Hidden Bar…"
    )

    static let tr = MenuBarHiderStrings(
        pageTitle: "Menü çubuğu gizleyici",
        hubDescription: "Nadiren kullandığınız menü çubuğu simgelerini bir okun arkasına saklar ve tek tıkla geri getirir.",
        enable: "Menü çubuğu simgelerini bir okun arkasına gizle",
        enableCaption: "Gizlemek için ⌘ tuşunu basılı tutup simgeleri okun soluna sürükleyin. Göstermek veya gizlemek için oka tıklayın.",
        openSettings: "Hidden Bar Ayarları…"
    )

    static let ru = MenuBarHiderStrings(
        pageTitle: "Скрытие значков строки меню",
        hubDescription: "Прячет редко используемые значки строки меню за стрелкой и возвращает их одним щелчком.",
        enable: "Скрывать значки строки меню за стрелкой",
        enableCaption: "Удерживая ⌘, перетащите значки левее стрелки, чтобы скрыть их. Щелкните стрелку, чтобы показать или скрыть их.",
        openSettings: "Настройки Hidden Bar…"
    )

    static let es = MenuBarHiderStrings(
        pageTitle: "Ocultar iconos de la barra de menús",
        hubDescription: "Guarda tras una flecha los iconos de la barra de menús que casi no usas y los recupera con un clic.",
        enable: "Ocultar iconos de la barra de menús tras una flecha",
        enableCaption: "Mantén pulsada ⌘ y arrastra iconos a la izquierda de la flecha para ocultarlos. Haz clic en la flecha para mostrarlos u ocultarlos.",
        openSettings: "Ajustes de Hidden Bar…"
    )

    static let sk = MenuBarHiderStrings(
        pageTitle: "Skrývanie ikon na lište menu",
        hubDescription: "Schová ikony na lište menu, ktoré používate zriedka, za šípku a jedným kliknutím ich vráti.",
        enable: "Skrývať ikony na lište menu za šípku",
        enableCaption: "Podržte ⌘ a presuňte ikony naľavo od šípky, aby sa skryli. Kliknutím na šípku ich zobrazíte alebo skryjete.",
        openSettings: "Nastavenia Hidden Bar…"
    )

    static let de = MenuBarHiderStrings(
        pageTitle: "Menüleistensymbole ausblenden",
        hubDescription: "Versteckt selten genutzte Menüleistensymbole hinter einem Pfeil und holt sie mit einem Klick zurück.",
        enable: "Menüleistensymbole hinter einem Pfeil ausblenden",
        enableCaption: "Halte ⌘ gedrückt und ziehe Symbole links neben den Pfeil, um sie auszublenden. Klicke auf den Pfeil, um sie ein- oder auszublenden.",
        openSettings: "Hidden Bar-Einstellungen…"
    )

    static let fr = MenuBarHiderStrings(
        pageTitle: "Masquer des icônes de la barre des menus",
        hubDescription: "Range derrière une flèche les icônes de la barre des menus que vous utilisez peu, et les ramène d’un clic.",
        enable: "Masquer des icônes de la barre des menus derrière une flèche",
        enableCaption: "Maintenez ⌘ et faites glisser des icônes à gauche de la flèche pour les masquer. Cliquez sur la flèche pour les afficher ou les masquer.",
        openSettings: "Réglages de Hidden Bar…"
    )

    static let it = MenuBarHiderStrings(
        pageTitle: "Nascondi icone della barra dei menu",
        hubDescription: "Raccoglie dietro una freccia le icone della barra dei menu che usi poco e le riporta con un clic.",
        enable: "Nascondi le icone della barra dei menu dietro una freccia",
        enableCaption: "Tieni premuto ⌘ e trascina le icone a sinistra della freccia per nasconderle. Fai clic sulla freccia per mostrarle o nasconderle.",
        openSettings: "Impostazioni di Hidden Bar…"
    )

    static let ja = MenuBarHiderStrings(
        pageTitle: "メニューバーアイコンを隠す",
        hubDescription: "あまり使わないメニューバーのアイコンを矢印の後ろにしまい、クリックひとつで戻します。",
        enable: "メニューバーのアイコンを矢印の後ろに隠す",
        enableCaption: "⌘キーを押しながらアイコンを矢印の左へドラッグすると隠れます。矢印をクリックすると表示と非表示を切り替えます。",
        openSettings: "Hidden Barの設定…"
    )

    static let ko = MenuBarHiderStrings(
        pageTitle: "메뉴 막대 아이콘 숨기기",
        hubDescription: "잘 쓰지 않는 메뉴 막대 아이콘을 화살표 뒤에 숨기고 클릭 한 번으로 다시 보여 줍니다.",
        enable: "메뉴 막대 아이콘을 화살표 뒤에 숨기기",
        enableCaption: "⌘ 키를 누른 채 아이콘을 화살표 왼쪽으로 드래그하면 숨겨집니다. 화살표를 클릭해 보이거나 숨기세요.",
        openSettings: "Hidden Bar 설정…"
    )

    static let zhHans = MenuBarHiderStrings(
        pageTitle: "菜单栏图标隐藏",
        hubDescription: "把不常用的菜单栏图标收到箭头后面，点一下就能找回来。",
        enable: "将菜单栏图标隐藏在箭头后面",
        enableCaption: "按住 ⌘ 将图标拖到箭头左侧即可隐藏。点按箭头可显示或隐藏它们。",
        openSettings: "Hidden Bar 设置…"
    )

    static let zhTW = MenuBarHiderStrings(
        pageTitle: "選單列圖像隱藏",
        hubDescription: "把不常用的選單列圖像收到箭頭後面，按一下就能找回來。",
        enable: "將選單列圖像隱藏在箭頭後面",
        enableCaption: "按住 ⌘ 將圖像拖到箭頭左側即可隱藏。按一下箭頭可顯示或隱藏它們。",
        openSettings: "Hidden Bar 設定…"
    )

    static let zhHK = MenuBarHiderStrings(
        pageTitle: "選單列圖像隱藏",
        hubDescription: "把不常用的選單列圖像收到箭咀後面，按一下就能找回來。",
        enable: "將選單列圖像隱藏在箭咀後面",
        enableCaption: "按住 ⌘ 將圖像拖到箭咀左側即可隱藏。按一下箭咀可顯示或隱藏它們。",
        openSettings: "Hidden Bar 設定…"
    )

    static let uk = MenuBarHiderStrings(
        pageTitle: "Приховування значків смуги меню",
        hubDescription: "Ховає рідко вживані значки смуги меню за стрілкою і повертає їх одним клацанням.",
        enable: "Ховати значки смуги меню за стрілкою",
        enableCaption: "Утримуючи ⌘, перетягніть значки ліворуч від стрілки, щоб приховати їх. Клацніть стрілку, щоб показати або приховати їх.",
        openSettings: "Налаштування Hidden Bar…"
    )
}
