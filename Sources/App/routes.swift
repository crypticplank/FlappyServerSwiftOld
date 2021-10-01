import Vapor
import FluentSQL
import Fluent
import Leaf
import Gatekeeper
import FlappyEncryption

struct mainVars: Codable {
    let users: [User]
    let players: Int
    let deaths: Int
}

func routes(_ app: Application) throws {
    app.get { req -> EventLoopFuture<View> in
        return User.query(on: req.db)
            .sort(\.$score, .descending)
            .filter(\.$isBanned == false)
            .range(..<25)
            .all()
            .flatMap{ users -> EventLoopFuture<View> in
                return User.query(on: req.db).filter(\.$isBanned == false).count().flatMap { playerCount -> EventLoopFuture<View> in
                    return User.query(on: req.db).sum(\.$deaths).flatMap { deaths -> EventLoopFuture<View> in
                        let vars = mainVars(users: users, players: playerCount, deaths: deaths!)
                        return req.view.render("main", vars)
                    }
                }
            }
    }
    
    app.get("users") { req in
        return User.query(on: req.db).all().flatMapThrowing { users in
            return try users.map(User.PublicUser.init)
        }
    }
    
    app.get("bans") { req -> EventLoopFuture<View> in
        return User.query(on: req.db)
            .filter(\.$isBanned == true)
            .all()
            .flatMap{ users in
                return req.view.render("bans", ["users": users])
            }
    }
    
    app.get("user", ":name") { req -> EventLoopFuture<View> in
        let name = req.parameters.get("name")
        return User.query(on: req.db)
            .filter(\.$name == name!)
            .first()
            .flatMap { user -> EventLoopFuture<View> in
                return req.view.render("user", ["user": user])
            }
    }
    
    app.get("leaderboard", ":amount") { req -> EventLoopFuture<[User.PublicUser]> in
        let amount: Int = req.parameters.get("amount") ?? 100
        return User.query(on: req.db)
            .sort(\.$score, .descending)
            .filter(\.$isBanned == false)
            .range(..<amount)
            .all()
            .flatMapThrowing { users in
                return try users.map(User.PublicUser.init)
            }
    }
    
    app.get("globalDeaths") { req -> EventLoopFuture<Int> in
        return User.query(on: req.db)
            .sum(\.$deaths)
            .map { deaths -> Int in
                return deaths!
            }
    }
    
    app.get("userCount") { req -> EventLoopFuture<Int> in
        return User.query(on: req.db)
            .filter(\.$isBanned == false)
            .count()
    }
    
    let rateLimitedRoute = app.grouped(GatekeeperMiddleware())
    
    rateLimitedRoute.post("registerUser") { req -> User.PublicUser in
        try User.Create.validate(content: req)
        let create = try req.content.decode(User.Create.self)
                              
        if create.name.count > 15 {
            throw Abort(.badRequest, reason: "Your name may not be longer that 15 characters.")
        }
                              
        guard create.password == create.confirmPassword else {
            throw Abort(.badRequest, reason: "Passwords did not match")
        }
        let user = try User(
            name: create.name,
            passwordHash: Bcrypt.hash(create.password)
        )
        let _ = user.save(on: req.db)
            .map { user }
        return try User.PublicUser(user)
    }
    
    let passwordProtected = app.grouped(User.authenticator())
    
    passwordProtected.post("login") { req -> User in
        try req.auth.require(User.self)
    }
    
    passwordProtected.post("submitDeath") { req -> String in
        let user = try req.auth.require(User.self)
        user.deaths! += 1
        let _ = user.update(on: req.db) .map { user }
        return "ok"
    }
    
    passwordProtected.post("submitScore") { req -> EventLoopFuture<String> in
        let user = try req.auth.require(User.self)
        if !user.isBanned! {
            let scoreEncrypted = try req.content.decode(User.SubmitScore.self)
            guard let score = FlappyEncryption.decryptInt(base64: scoreEncrypted.score) else {
                throw Abort(.badRequest, reason:"Error decrypting score")
            }
            
            guard let time = FlappyEncryption.decryptInt(base64: scoreEncrypted.time) else {
                throw Abort(.badRequest, reason:"Error decrypting time")
            }
            
            print("User: \(user.name.description)[\(user.id!.description)] submitted score: \(score), took \(time) seconds.")
            
            /*
                Time = 100, score 101
                200 < 101 == false 0 > 101 == false, 200 window
            */

            if (time + 100 < score || time - 100 > score) && score > 1000 {
                user.isBanned = true
                user.banReason = "Cheating (Anticheat)"
                let _ = user.update(on: req.db) .map { user }
                throw Abort(.notAcceptable, reason: "You have been banned. If your believe this is an error, please contact the FlappyBird Revision Team")
            }
            if score > user.score! {
                user.score = score
                let _ = user.update(on: req.db) .map { user }
                print("Submitted score for \(user.name.description)")
            }
            throw Abort(.accepted)
        } else {
            print("Cannot submit score, \(user.name.description) is banned")
            throw Abort(.badRequest)
        }
    }
    
    // Admin Things
    
    passwordProtected.get("internal_users") { req -> EventLoopFuture<[User]> in
        let user = try req.auth.require(User.self)
        if user.admin! {
            return User.query(on: req.db).all()
        } else {
            throw Abort(.unauthorized)
        }
    }
    
    passwordProtected.get("unban", ":userID") { req -> String in
        let user = try req.auth.require(User.self)
        if user.admin! {
            let id = req.parameters.get("userID")!
            
            guard let uuid = UUID(uuidString: id) else {
                throw Abort(.badRequest, reason: "Not a valid uuid")
            }
            
            _ = User.find(uuid, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { user -> EventLoopFuture<Void> in
                user.isBanned = false
                return user.save(on: req.db)
            }
            
            return "User has been unbanned"
        } else {
            throw Abort(.unauthorized)
        }
    }
    
    passwordProtected.get("ban", ":userID") { req -> String in
        let user = try req.auth.require(User.self)
        if user.admin! {
            let id = req.parameters.get("userID")!
            
            guard let uuid = UUID(uuidString: id) else {
                throw Abort(.badRequest, reason: "Not a valid uuid")
            }
            
            _ = User.find(uuid, on: req.db)
                .unwrap(or: Abort(.notFound))
                .flatMap { user -> EventLoopFuture<Void> in
                    user.isBanned = true
                    user.banReason = "Not specified"
                    return user.save(on: req.db)
                }
            return "User has been banned"
        } else {
            throw Abort(.unauthorized)
        }
    }
    
    passwordProtected.get("delete", ":userID") { req -> String in
        let user = try req.auth.require(User.self)
        if user.admin! {
            let id = req.parameters.get("userID")!
            
            guard let uuid = UUID(uuidString: id) else {
                throw Abort(.badRequest, reason: "Not a valid uuid")
            }
            
            _ = User.query(on: req.db)
                .filter(\.$id == uuid)
                .delete()
            
            return "User has been removed"
        } else {
            throw Abort(.unauthorized)
        }
    }
}
