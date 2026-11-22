// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Strings for the Keep Awake badge beside the Dynamic Island. Same contract
/// as the other FeatureStrings structs: memberwise init with labeled
/// arguments in declaration order, one static per language, all in this file.
struct KeepAwakeIslandBadgeStrings {
    let toggle: String
    let caption: String
    let accessibilityLabel: String
}

extension FeatureStrings {
    static func keepAwakeIslandBadge(_ language: AppLanguage) -> KeepAwakeIslandBadgeStrings {
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

extension KeepAwakeIslandBadgeStrings {
    static let enUS = KeepAwakeIslandBadgeStrings(
        toggle: "Show an icon beside the Dynamic Island",
        caption: "While Keep Awake is on, a bolt sits to the right of the camera, like the padlock of Cleaning Mode, and the menu bar icon stays as it is.",
        accessibilityLabel: "Keep Awake is on"
    )

    static let ptBR = KeepAwakeIslandBadgeStrings(
        toggle: "Mostrar um ícone ao lado da Dynamic Island",
        caption: "Enquanto o Manter acordado está ativo, um raio fica à direita da câmera, como o cadeado do Modo de limpeza, e o ícone da barra de menus não muda.",
        accessibilityLabel: "Manter acordado está ativo"
    )

    static let tr = KeepAwakeIslandBadgeStrings(
        toggle: "Dynamic Island’ın yanında bir simge göster",
        caption: "Uyanık tut açıkken, Temizleme Modu’nun kilidi gibi kameranın sağında bir şimşek durur ve menü çubuğu simgesi değişmez.",
        accessibilityLabel: "Uyanık tut açık"
    )

    static let ru = KeepAwakeIslandBadgeStrings(
        toggle: "Показывать значок рядом с Dynamic Island",
        caption: "Пока включен режим «Не давать Mac уснуть», справа от камеры видна молния, как замок режима очистки, а значок в строке меню не меняется.",
        accessibilityLabel: "Режим «Не давать Mac уснуть» включен"
    )

    static let es = KeepAwakeIslandBadgeStrings(
        toggle: "Mostrar un icono junto a la Dynamic Island",
        caption: "Mientras Mantener activo está encendido, un rayo queda a la derecha de la cámara, como el candado del Modo de limpieza, y el icono de la barra de menús no cambia.",
        accessibilityLabel: "Mantener activo está encendido"
    )

    static let sk = KeepAwakeIslandBadgeStrings(
        toggle: "Zobraziť ikonu vedľa Dynamic Island",
        caption: "Kým je zapnutý Bdelý režim, napravo od kamery je blesk, ako zámok Režimu čistenia, a ikona na lište menu sa nemení.",
        accessibilityLabel: "Bdelý režim je zapnutý"
    )

    static let de = KeepAwakeIslandBadgeStrings(
        toggle: "Symbol neben der Dynamic Island anzeigen",
        caption: "Solange Wachhalten aktiv ist, sitzt rechts neben der Kamera ein Blitz, wie das Schloss des Reinigungsmodus, und das Menüleistensymbol bleibt unverändert.",
        accessibilityLabel: "Wachhalten ist aktiv"
    )

    static let fr = KeepAwakeIslandBadgeStrings(
        toggle: "Afficher une icône à côté de la Dynamic Island",
        caption: "Tant que Garder éveillé est actif, un éclair se place à droite de la caméra, comme le cadenas du Mode nettoyage, et l’icône de la barre des menus ne change pas.",
        accessibilityLabel: "Garder éveillé est actif"
    )

    static let it = KeepAwakeIslandBadgeStrings(
        toggle: "Mostra un’icona accanto alla Dynamic Island",
        caption: "Finché Mantieni attivo è acceso, un fulmine sta a destra della fotocamera, come il lucchetto della Modalità pulizia, e l’icona della barra dei menu non cambia.",
        accessibilityLabel: "Mantieni attivo è acceso"
    )

    static let ja = KeepAwakeIslandBadgeStrings(
        toggle: "Dynamic Island の横にアイコンを表示",
        caption: "スリープ防止がオンの間、クリーニングモードの南京錠のようにカメラの右に稲妻が表示され、メニューバーのアイコンは変わりません。",
        accessibilityLabel: "スリープ防止はオンです"
    )

    static let ko = KeepAwakeIslandBadgeStrings(
        toggle: "Dynamic Island 옆에 아이콘 표시",
        caption: "절전 방지가 켜져 있는 동안 청소 모드의 자물쇠처럼 카메라 오른쪽에 번개가 표시되고, 메뉴 막대 아이콘은 그대로입니다.",
        accessibilityLabel: "절전 방지가 켜져 있음"
    )

    static let zhHans = KeepAwakeIslandBadgeStrings(
        toggle: "在 Dynamic Island 旁显示图标",
        caption: "保持唤醒开启时，摄像头右侧会显示一道闪电，就像清洁模式的锁一样，菜单栏图标保持不变。",
        accessibilityLabel: "保持唤醒已开启"
    )

    static let zhTW = KeepAwakeIslandBadgeStrings(
        toggle: "在 Dynamic Island 旁顯示圖像",
        caption: "保持喚醒開啟時，相機右側會顯示一道閃電，就像清潔模式的鎖一樣，選單列圖像保持不變。",
        accessibilityLabel: "保持喚醒已開啟"
    )

    static let zhHK = KeepAwakeIslandBadgeStrings(
        toggle: "在 Dynamic Island 旁顯示圖像",
        caption: "保持喚醒開啟時，相機右側會顯示一道閃電，就像清潔模式的鎖一樣，選單列圖像保持不變。",
        accessibilityLabel: "保持喚醒已開啟"
    )

    static let uk = KeepAwakeIslandBadgeStrings(
        toggle: "Показувати значок поруч із Dynamic Island",
        caption: "Поки ввімкнено «Не давати Mac заснути», праворуч від камери видно блискавку, як замок режиму очищення, а значок на смузі меню не змінюється.",
        accessibilityLabel: "«Не давати Mac заснути» ввімкнено"
    )
}
