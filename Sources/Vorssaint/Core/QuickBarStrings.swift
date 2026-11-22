// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Strings for the quick bar. Same contract as the other FeatureStrings
/// structs: memberwise init with labeled arguments in declaration order, one
/// static per language, all in this file.
struct QuickBarStrings {
    let pageTitle: String
    let hubDescription: String
    let caption: String
    let openNow: String
}

extension FeatureStrings {
    static func quickBar(_ language: AppLanguage) -> QuickBarStrings {
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

extension QuickBarStrings {
    static let enUS = QuickBarStrings(
        pageTitle: "Quick bar",
        hubDescription: "A bar to type something for the person next to you to read. Closing it erases the text.",
        caption: "Type a message to show someone beside you. Press Esc, the shortcut again or click elsewhere to close it. The text is never saved, so the bar opens empty every time.",
        openNow: "Open the quick bar"
    )

    static let ptBR = QuickBarStrings(
        pageTitle: "Barra rápida",
        hubDescription: "Uma barra para digitar algo para a pessoa ao seu lado ler. Fechá-la apaga o texto.",
        caption: "Digite uma mensagem para mostrar a alguém ao seu lado. Pressione Esc, o atalho de novo ou clique fora para fechar. O texto nunca é salvo, então a barra sempre abre vazia.",
        openNow: "Abrir a barra rápida"
    )

    static let tr = QuickBarStrings(
        pageTitle: "Hızlı çubuk",
        hubDescription: "Yanınızdaki kişinin okuması için bir şey yazabileceğiniz bir çubuk. Kapatınca metin silinir.",
        caption: "Yanınızdaki birine göstermek için bir mesaj yazın. Kapatmak için Esc’ye ya da kısayola yeniden basın veya başka bir yere tıklayın. Metin hiç kaydedilmez, bu yüzden çubuk her seferinde boş açılır.",
        openNow: "Hızlı çubuğu aç"
    )

    static let ru = QuickBarStrings(
        pageTitle: "Быстрая строка",
        hubDescription: "Строка, чтобы напечатать что-то для человека рядом с вами. При закрытии текст стирается.",
        caption: "Напечатайте сообщение, чтобы показать его тому, кто рядом. Чтобы закрыть, нажмите Esc или сочетание клавиш еще раз либо щелкните в другом месте. Текст никогда не сохраняется, поэтому строка всегда открывается пустой.",
        openNow: "Открыть быструю строку"
    )

    static let es = QuickBarStrings(
        pageTitle: "Barra rápida",
        hubDescription: "Una barra para escribir algo que lea la persona que tienes al lado. Al cerrarla se borra el texto.",
        caption: "Escribe un mensaje para mostrárselo a alguien a tu lado. Pulsa Esc, el atajo otra vez o haz clic fuera para cerrarla. El texto nunca se guarda, así que la barra siempre se abre vacía.",
        openNow: "Abrir la barra rápida"
    )

    static let sk = QuickBarStrings(
        pageTitle: "Rýchly panel",
        hubDescription: "Panel na napísanie niečoho, čo si prečíta človek vedľa vás. Zatvorením sa text vymaže.",
        caption: "Napíšte správu, ktorú ukážete niekomu vedľa seba. Zatvoríte ho klávesom Esc, opätovným stlačením skratky alebo kliknutím inam. Text sa nikdy neukladá, takže panel sa vždy otvorí prázdny.",
        openNow: "Otvoriť rýchly panel"
    )

    static let de = QuickBarStrings(
        pageTitle: "Schnellleiste",
        hubDescription: "Eine Leiste, um etwas für die Person neben dir zu tippen. Beim Schließen wird der Text gelöscht.",
        caption: "Tippe eine Nachricht, um sie jemandem neben dir zu zeigen. Mit Esc, dem Kurzbefehl oder einem Klick daneben schließt du sie. Der Text wird nie gespeichert, daher öffnet sich die Leiste immer leer.",
        openNow: "Schnellleiste öffnen"
    )

    static let fr = QuickBarStrings(
        pageTitle: "Barre rapide",
        hubDescription: "Une barre pour taper un message à la personne à côté de vous. La fermer efface le texte.",
        caption: "Tapez un message à montrer à quelqu’un à côté de vous. Appuyez sur Échap, de nouveau sur le raccourci ou cliquez ailleurs pour la fermer. Le texte n’est jamais enregistré, la barre s’ouvre donc toujours vide.",
        openNow: "Ouvrir la barre rapide"
    )

    static let it = QuickBarStrings(
        pageTitle: "Barra rapida",
        hubDescription: "Una barra per scrivere qualcosa da far leggere a chi ti sta accanto. Chiuderla cancella il testo.",
        caption: "Scrivi un messaggio da mostrare a chi ti sta accanto. Premi Esc, di nuovo l’abbreviazione o fai clic altrove per chiuderla. Il testo non viene mai salvato, quindi la barra si apre sempre vuota.",
        openNow: "Apri la barra rapida"
    )

    static let ja = QuickBarStrings(
        pageTitle: "クイックバー",
        hubDescription: "隣の人に読んでもらう文字を入力するバーです。閉じるとテキストは消えます。",
        caption: "隣にいる人に見せるメッセージを入力します。Esc キーを押すか、ショートカットをもう一度押すか、ほかの場所をクリックすると閉じます。テキストは保存されないため、バーは毎回空の状態で開きます。",
        openNow: "クイックバーを開く"
    )

    static let ko = QuickBarStrings(
        pageTitle: "빠른 막대",
        hubDescription: "옆 사람이 읽을 내용을 입력하는 막대입니다. 닫으면 텍스트가 지워집니다.",
        caption: "옆 사람에게 보여 줄 메시지를 입력하세요. Esc를 누르거나 단축키를 다시 누르거나 다른 곳을 클릭하면 닫힙니다. 텍스트는 저장되지 않으므로 막대는 항상 빈 상태로 열립니다.",
        openNow: "빠른 막대 열기"
    )

    static let zhHans = QuickBarStrings(
        pageTitle: "快捷栏",
        hubDescription: "输入文字给身边的人看的栏。关闭后文字会被清除。",
        caption: "输入一条消息给身边的人看。按 Esc、再按一次快捷键或点按其他位置即可关闭。文字从不保存，因此每次打开都是空的。",
        openNow: "打开快捷栏"
    )

    static let zhTW = QuickBarStrings(
        pageTitle: "快捷列",
        hubDescription: "輸入文字給身旁的人看的列。關閉後文字會被清除。",
        caption: "輸入一則訊息給身旁的人看。按下 Esc、再按一次快速鍵或按一下其他位置即可關閉。文字從不儲存，因此每次打開都是空的。",
        openNow: "打開快捷列"
    )

    static let zhHK = QuickBarStrings(
        pageTitle: "快捷列",
        hubDescription: "輸入文字給身旁的人看的列。關閉後文字會被清除。",
        caption: "輸入一則訊息給身旁的人看。按下 Esc、再按一次快速鍵或按一下其他位置即可關閉。文字從不儲存，因此每次打開都是空的。",
        openNow: "打開快捷列"
    )

    static let uk = QuickBarStrings(
        pageTitle: "Швидкий рядок",
        hubDescription: "Рядок, щоб надрукувати щось для людини поруч. Після закриття текст стирається.",
        caption: "Надрукуйте повідомлення, щоб показати його тому, хто поруч. Щоб закрити, натисніть Esc або сполучення клавіш ще раз чи клацніть деінде. Текст ніколи не зберігається, тому рядок щоразу відкривається порожнім.",
        openNow: "Відкрити швидкий рядок"
    )
}
