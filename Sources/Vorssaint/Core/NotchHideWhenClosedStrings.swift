// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Strings for hiding the closed island. Same contract as the other
/// FeatureStrings structs: memberwise init with labeled arguments in
/// declaration order, one static per language, all in this file.
struct NotchHideWhenClosedStrings {
    let toggle: String
    let caption: String
}

extension FeatureStrings {
    static func notchHideWhenClosed(_ language: AppLanguage) -> NotchHideWhenClosedStrings {
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

extension NotchHideWhenClosedStrings {
    static let enUS = NotchHideWhenClosedStrings(
        toggle: "Hide the island while it is closed",
        caption: "Nothing stays at the top of the screen. The island slides down from the top edge for activities such as volume or music, and when you open it with its shortcut, then folds back up into nothing."
    )

    static let ptBR = NotchHideWhenClosedStrings(
        toggle: "Ocultar a ilha enquanto estiver fechada",
        caption: "Nada fica no topo da tela. A ilha desce da borda superior para atividades como volume ou música, e quando você a abre pelo atalho, depois se recolhe até sumir."
    )

    static let tr = NotchHideWhenClosedStrings(
        toggle: "Ada kapalıyken gizle",
        caption: "Ekranın üstünde hiçbir şey kalmaz. Ada, ses veya müzik gibi etkinlikler için ve kısayoluyla açtığınızda üst kenardan aşağı kayar, sonra yukarı katlanıp kaybolur."
    )

    static let ru = NotchHideWhenClosedStrings(
        toggle: "Скрывать остров, когда он закрыт",
        caption: "Вверху экрана ничего не остается. Остров выезжает из верхнего края для событий вроде громкости или музыки и когда вы открываете его сочетанием клавиш, а затем сворачивается вверх и исчезает."
    )

    static let es = NotchHideWhenClosedStrings(
        toggle: "Ocultar la isla mientras está cerrada",
        caption: "No queda nada en la parte superior de la pantalla. La isla baja desde el borde superior para actividades como el volumen o la música, y cuando la abres con su atajo, y luego se recoge hasta desaparecer."
    )

    static let sk = NotchHideWhenClosedStrings(
        toggle: "Skryť ostrov, keď je zatvorený",
        caption: "Na vrchu obrazovky nič nezostane. Ostrov sa vysunie z horného okraja pri aktivitách, ako je hlasitosť či hudba, a keď ho otvoríte skratkou, potom sa zloží nahor a zmizne."
    )

    static let de = NotchHideWhenClosedStrings(
        toggle: "Insel ausblenden, solange sie geschlossen ist",
        caption: "Oben am Bildschirm bleibt nichts stehen. Die Insel gleitet für Aktivitäten wie Lautstärke oder Musik und beim Öffnen per Kurzbefehl vom oberen Rand herab und faltet sich danach wieder nach oben, bis sie verschwindet."
    )

    static let fr = NotchHideWhenClosedStrings(
        toggle: "Masquer l’îlot quand il est fermé",
        caption: "Rien ne reste en haut de l’écran. L’îlot descend du bord supérieur pour les activités comme le volume ou la musique, et quand vous l’ouvrez avec son raccourci, puis se replie vers le haut jusqu’à disparaître."
    )

    static let it = NotchHideWhenClosedStrings(
        toggle: "Nascondi l’isola quando è chiusa",
        caption: "In cima allo schermo non resta nulla. L’isola scende dal bordo superiore per attività come volume o musica e quando la apri con la sua abbreviazione, poi si richiude verso l’alto fino a sparire."
    )

    static let ja = NotchHideWhenClosedStrings(
        toggle: "閉じているあいだアイランドを隠す",
        caption: "画面上部には何も残りません。音量や音楽などのアクティビティや、ショートカットで開いたときに上端から現れ、閉じると上へたたまれて消えます。"
    )

    static let ko = NotchHideWhenClosedStrings(
        toggle: "닫혀 있을 때 아일랜드 숨기기",
        caption: "화면 위쪽에 아무것도 남지 않습니다. 음량이나 음악 같은 활동이 있거나 단축키로 열 때 위쪽 가장자리에서 내려오고, 닫히면 위로 접히며 사라집니다."
    )

    static let zhHans = NotchHideWhenClosedStrings(
        toggle: "关闭时隐藏岛",
        caption: "屏幕顶部不留任何东西。音量、音乐等活动出现时，或用快捷键打开时，岛会从顶部边缘滑下，之后向上收起直至消失。"
    )

    static let zhTW = NotchHideWhenClosedStrings(
        toggle: "關閉時隱藏島",
        caption: "螢幕頂端不留任何東西。音量、音樂等活動出現時，或用快速鍵打開時，島會從頂端邊緣滑下，之後向上收起直到消失。"
    )

    static let zhHK = NotchHideWhenClosedStrings(
        toggle: "關閉時隱藏島",
        caption: "螢幕頂端不留任何東西。音量、音樂等活動出現時，或用快速鍵打開時，島會從頂端邊緣滑下，之後向上收起直到消失。"
    )

    static let uk = NotchHideWhenClosedStrings(
        toggle: "Ховати острів, коли він закритий",
        caption: "Угорі екрана нічого не лишається. Острів виїжджає з верхнього краю для подій, як-от гучність чи музика, і коли ви відкриваєте його сполученням клавіш, а потім згортається вгору й зникає."
    )
}
