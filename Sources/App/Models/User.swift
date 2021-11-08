/*
 * BSD 3-Clause License
 *
 * Copyright (c) 2021, Brandon Plank
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 
 * 3. Neither the name of the copyright holder nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Vapor
import Fluent
import FluentSQLiteDriver

final class User: Model, Content {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "score")
    var score: Int?
    
    @Field(key: "deaths")
    var deaths: Int?
    
    @Field(key: "passwordHash")
    var passwordHash: String
    
    @Field(key: "jailbroken")
    var jailbroken: Bool?

    @Field(key: "hasHackedTools")
    var hasHackedTools: Bool?

    @Field(key: "ranInEmulator")
    var ranInEmulator: Bool?

    @Field(key: "hasModifiedScore")
    var hasModifiedScore: Bool?
    
    @Field(key: "isBanned")
    var isBanned: Bool?
    
    @Field(key: "banReason")
    var banReason: String?
    
    @Field(key: "admin")
    var admin: Bool?
    
    @Field(key: "owner")
    var owner: Bool?
    
    
    init() { }
    
    init(id: UUID? = UUID(), name: String, score: Int? = 0, deaths: Int? = 0, passwordHash: String, jailbroken: Bool? = false, hasHackedTools: Bool? = false, ranInEmulator: Bool? = false, hasModifiedScore: Bool? = false, isBanned: Bool? = false, banReason: String? = nil, admin: Bool? = false, owner: Bool? = false) {
        self.id = id
        self.name = name
        self.score = score
        self.deaths = deaths
        self.passwordHash = passwordHash
        self.jailbroken = jailbroken
        self.hasHackedTools = hasHackedTools
        self.ranInEmulator = ranInEmulator
        self.hasModifiedScore = hasModifiedScore
        self.isBanned = isBanned
        self.banReason = banReason
        self.admin = admin
        self.owner = owner
    }
}

extension User {
    struct PublicUser: Content {
        var id: UUID?
        var name: String
        var score: Int?
        var deaths: Int?

        init(_ user: User) throws {
            self.id = try user.requireID()
            self.name = user.name
            self.score = user.score
            self.deaths = user.deaths
        }
    }
}

extension User {
    struct Migration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(User.schema)
                .id()
                .field("name", .string)
                .field("score", .int)
                .field("deaths", .int)
                .field("passwordHash", .string)
                .field("jailbroken", .bool)
                .field("hasHackedTools", .bool)
                .field("ranInEmulator", .bool)
                .field("hasModifiedScore", .bool)
                .field("isBanned", .bool)
                .field("banReason", .string)
                .field("admin", .bool)
                .field("owner", .bool)
                .unique(on: "name")
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(User.schema).delete()
        }
    }
}

extension User: Authenticatable { }
