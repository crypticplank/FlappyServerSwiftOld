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
