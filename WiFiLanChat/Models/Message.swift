//
//  Message.swift
//  WiFiLanChat
//
//  Created by Bilol Mamadjanov on 27/11/21.
//

import Foundation

struct Message {
    let text: String
    let username: String
    let owner: MessageOwner
    
    init(text: String, username: String = String(), owner: MessageOwner = .server) {
        self.text = text.withoutWhitespace()
        self.owner = owner
        self.username = username
    }
}
