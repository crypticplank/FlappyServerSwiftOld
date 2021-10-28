/*
BSD 3-Clause License

Copyright (c) 2021, Brandon Plank
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

//
//  Token.swift
//  
//
//  Created by Brandon Plank on 10/16/21.
//

import Foundation
import Vapor
import Fluent

enum SessionSource: Int, Content {
  case signup
  case login
}

final class Token: Model {
    static let schema = "tokens"
  
    @ID(key: "id")
    var id: UUID?
  
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "value")
    var value: String
  
    @Field(key: "source")
    var source: SessionSource
    
    @Field(key: "expires_at")
    var expiresAt: Date?
  
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
  
    init() {}
    
    init(id: UUID? = nil, userId: User.IDValue, token: String,
      source: SessionSource, expiresAt: Date?) {
      self.id = id
      self.$user.id = userId
      self.value = token
      self.source = source
      self.expiresAt = expiresAt
    }
}

extension Token {
    struct Migration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(Token.schema)
                .id()
                .field("user_id", .uuid, .references("users", "id"))
                .field("value", .string, .required)
                .unique(on: "value")
                .field("source", .int, .required)
                .field("created_at", .datetime, .required)
                .field("expires_at", .datetime)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(Token.schema).delete()
        }
    }
}
