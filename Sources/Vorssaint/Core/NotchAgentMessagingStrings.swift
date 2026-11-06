// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The agents' pages as Messages: replying to a message, files sent with
/// one, and how a notification names what has no words.
struct NotchAgentMessagingStrings {
    let reply: String
    let replyingTo: String
    let cancelReply: String
    let attach: String
    let removeAttachment: String
    let image: String
    let attachment: String
    let open: String
    let openInMessages: String
    let interactiveMessage: String
    let answerInMessages: String
    let poll: String
    let voteInMessages: String
    let voiceMemo: String
    let play: String
    let pause: String
    let contactCard: String
    let react: String
}

extension FeatureStrings {
    static func notchAgentMessaging(_ language: AppLanguage) -> NotchAgentMessagingStrings {
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

extension NotchAgentMessagingStrings {
    static let enUS = NotchAgentMessagingStrings(
        reply: "Reply",
        replyingTo: "Replying to",
        cancelReply: "Cancel Reply",
        attach: "Add Attachment",
        removeAttachment: "Remove",
        image: "Image",
        attachment: "Attachment",
        open: "Open",
        openInMessages: "Open in Messages",
        interactiveMessage: "Interactive Message",
        answerInMessages: "Answer in Messages",
        poll: "Poll",
        voteInMessages: "Vote in Messages",
        voiceMemo: "Voice Memo",
        play: "Play",
        pause: "Pause",
        contactCard: "Contact Card",
        react: "React"
    )

    static let ptBR = NotchAgentMessagingStrings(
        reply: "Responder",
        replyingTo: "Respondendo a",
        cancelReply: "Cancelar resposta",
        attach: "Adicionar anexo",
        removeAttachment: "Remover",
        image: "Imagem",
        attachment: "Anexo",
        open: "Abrir",
        openInMessages: "Abrir no Mensagens",
        interactiveMessage: "Mensagem interativa",
        answerInMessages: "Responder no Mensagens",
        poll: "Enquete",
        voteInMessages: "Votar no Mensagens",
        voiceMemo: "Memorando de voz",
        play: "Reproduzir",
        pause: "Pausar",
        contactCard: "Cartão de contato",
        react: "Reagir"
    )

    static let es = NotchAgentMessagingStrings(
        reply: "Responder",
        replyingTo: "Respondiendo a",
        cancelReply: "Cancelar respuesta",
        attach: "Añadir archivo adjunto",
        removeAttachment: "Quitar",
        image: "Imagen",
        attachment: "Archivo adjunto",
        open: "Abrir",
        openInMessages: "Abrir en Mensajes",
        interactiveMessage: "Mensaje interactivo",
        answerInMessages: "Responder en Mensajes",
        poll: "Encuesta",
        voteInMessages: "Votar en Mensajes",
        voiceMemo: "Nota de voz",
        play: "Reproducir",
        pause: "Pausar",
        contactCard: "Tarjeta de contacto",
        react: "Reaccionar"
    )

    static let sk = NotchAgentMessagingStrings(
        reply: "Odpovedať",
        replyingTo: "Odpoveď na",
        cancelReply: "Zrušiť odpoveď",
        attach: "Pridať prílohu",
        removeAttachment: "Odstrániť",
        image: "Obrázok",
        attachment: "Príloha",
        open: "Otvoriť",
        openInMessages: "Otvoriť v Správach",
        interactiveMessage: "Interaktívna správa",
        answerInMessages: "Odpovedať v Správach",
        poll: "Anketa",
        voteInMessages: "Hlasovať v Správach",
        voiceMemo: "Hlasová poznámka",
        play: "Prehrať",
        pause: "Pozastaviť",
        contactCard: "Kontaktná karta",
        react: "Reagovať"
    )

    static let de = NotchAgentMessagingStrings(
        reply: "Antworten",
        replyingTo: "Antwort auf",
        cancelReply: "Antwort abbrechen",
        attach: "Anhang hinzufügen",
        removeAttachment: "Entfernen",
        image: "Bild",
        attachment: "Anhang",
        open: "Öffnen",
        openInMessages: "In Nachrichten öffnen",
        interactiveMessage: "Interaktive Nachricht",
        answerInMessages: "In Nachrichten antworten",
        poll: "Umfrage",
        voteInMessages: "In Nachrichten abstimmen",
        voiceMemo: "Sprachmemo",
        play: "Abspielen",
        pause: "Pausieren",
        contactCard: "Kontaktkarte",
        react: "Reagieren"
    )

    static let fr = NotchAgentMessagingStrings(
        reply: "Répondre",
        replyingTo: "Réponse à",
        cancelReply: "Annuler la réponse",
        attach: "Ajouter une pièce jointe",
        removeAttachment: "Retirer",
        image: "Image",
        attachment: "Pièce jointe",
        open: "Ouvrir",
        openInMessages: "Ouvrir dans Messages",
        interactiveMessage: "Message interactif",
        answerInMessages: "Répondre dans Messages",
        poll: "Sondage",
        voteInMessages: "Voter dans Messages",
        voiceMemo: "Mémo vocal",
        play: "Lire",
        pause: "Pause",
        contactCard: "Fiche de contact",
        react: "Réagir"
    )

    static let it = NotchAgentMessagingStrings(
        reply: "Rispondi",
        replyingTo: "Risposta a",
        cancelReply: "Annulla risposta",
        attach: "Aggiungi allegato",
        removeAttachment: "Rimuovi",
        image: "Immagine",
        attachment: "Allegato",
        open: "Apri",
        openInMessages: "Apri in Messaggi",
        interactiveMessage: "Messaggio interattivo",
        answerInMessages: "Rispondi in Messaggi",
        poll: "Sondaggio",
        voteInMessages: "Vota in Messaggi",
        voiceMemo: "Memo vocale",
        play: "Riproduci",
        pause: "Pausa",
        contactCard: "Scheda contatto",
        react: "Reagisci"
    )

    static let ru = NotchAgentMessagingStrings(
        reply: "Ответить",
        replyingTo: "Ответ на",
        cancelReply: "Отменить ответ",
        attach: "Добавить вложение",
        removeAttachment: "Удалить",
        image: "Изображение",
        attachment: "Вложение",
        open: "Открыть",
        openInMessages: "Открыть в Сообщениях",
        interactiveMessage: "Интерактивное сообщение",
        answerInMessages: "Ответить в Сообщениях",
        poll: "Опрос",
        voteInMessages: "Голосовать в Сообщениях",
        voiceMemo: "Голосовая заметка",
        play: "Воспроизвести",
        pause: "Пауза",
        contactCard: "Карточка контакта",
        react: "Отреагировать"
    )

    static let tr = NotchAgentMessagingStrings(
        reply: "Yanıtla",
        replyingTo: "Yanıtlanan",
        cancelReply: "Yanıtı iptal et",
        attach: "Ek ekle",
        removeAttachment: "Kaldır",
        image: "Görüntü",
        attachment: "Ek",
        open: "Aç",
        openInMessages: "Mesajlar’da Aç",
        interactiveMessage: "Etkileşimli ileti",
        answerInMessages: "Mesajlar’da yanıtla",
        poll: "Anket",
        voteInMessages: "Mesajlar’da oy ver",
        voiceMemo: "Sesli not",
        play: "Oynat",
        pause: "Duraklat",
        contactCard: "Kişi kartı",
        react: "Tepki ver"
    )

    static let ja = NotchAgentMessagingStrings(
        reply: "返信",
        replyingTo: "返信先",
        cancelReply: "返信をキャンセル",
        attach: "添付ファイルを追加",
        removeAttachment: "削除",
        image: "画像",
        attachment: "添付ファイル",
        open: "開く",
        openInMessages: "メッセージで開く",
        interactiveMessage: "インタラクティブメッセージ",
        answerInMessages: "メッセージで応答",
        poll: "投票",
        voteInMessages: "メッセージで投票",
        voiceMemo: "ボイスメモ",
        play: "再生",
        pause: "一時停止",
        contactCard: "連絡先カード",
        react: "リアクション"
    )

    static let ko = NotchAgentMessagingStrings(
        reply: "답장",
        replyingTo: "답장 대상",
        cancelReply: "답장 취소",
        attach: "첨부 파일 추가",
        removeAttachment: "제거",
        image: "이미지",
        attachment: "첨부 파일",
        open: "열기",
        openInMessages: "메시지에서 열기",
        interactiveMessage: "대화형 메시지",
        answerInMessages: "메시지에서 답하기",
        poll: "투표",
        voteInMessages: "메시지에서 투표",
        voiceMemo: "음성 메모",
        play: "재생",
        pause: "일시 정지",
        contactCard: "연락처 카드",
        react: "반응하기"
    )

    static let uk = NotchAgentMessagingStrings(
        reply: "Відповісти",
        replyingTo: "Відповідь на",
        cancelReply: "Скасувати відповідь",
        attach: "Додати вкладення",
        removeAttachment: "Вилучити",
        image: "Зображення",
        attachment: "Вкладення",
        open: "Відкрити",
        openInMessages: "Відкрити в Повідомленнях",
        interactiveMessage: "Інтерактивне повідомлення",
        answerInMessages: "Відповісти в Повідомленнях",
        poll: "Опитування",
        voteInMessages: "Голосувати в Повідомленнях",
        voiceMemo: "Голосова нотатка",
        play: "Відтворити",
        pause: "Пауза",
        contactCard: "Картка контакту",
        react: "Відреагувати"
    )

    static let zhHans = NotchAgentMessagingStrings(
        reply: "回复",
        replyingTo: "回复",
        cancelReply: "取消回复",
        attach: "添加附件",
        removeAttachment: "移除",
        image: "图像",
        attachment: "附件",
        open: "打开",
        openInMessages: "在“信息”中打开",
        interactiveMessage: "互动信息",
        answerInMessages: "在“信息”中回复",
        poll: "投票",
        voteInMessages: "在“信息”中投票",
        voiceMemo: "语音备忘录",
        play: "播放",
        pause: "暂停",
        contactCard: "联系人名片",
        react: "回应"
    )

    static let zhTW = NotchAgentMessagingStrings(
        reply: "回覆",
        replyingTo: "回覆",
        cancelReply: "取消回覆",
        attach: "加入附件",
        removeAttachment: "移除",
        image: "影像",
        attachment: "附件",
        open: "打開",
        openInMessages: "在「訊息」中打開",
        interactiveMessage: "互動式訊息",
        answerInMessages: "在「訊息」中回覆",
        poll: "投票",
        voteInMessages: "在「訊息」中投票",
        voiceMemo: "語音備忘錄",
        play: "播放",
        pause: "暫停",
        contactCard: "聯絡人名片",
        react: "回應"
    )

    static let zhHK = NotchAgentMessagingStrings(
        reply: "回覆",
        replyingTo: "回覆",
        cancelReply: "取消回覆",
        attach: "加入附件",
        removeAttachment: "移除",
        image: "影像",
        attachment: "附件",
        open: "打開",
        openInMessages: "在「訊息」中打開",
        interactiveMessage: "互動訊息",
        answerInMessages: "在「訊息」中回覆",
        poll: "投票",
        voteInMessages: "在「訊息」中投票",
        voiceMemo: "語音備忘錄",
        play: "播放",
        pause: "暫停",
        contactCard: "聯絡人名片",
        react: "回應"
    )
}
