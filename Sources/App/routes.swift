import Vapor
import FluentSQL
import Fluent

func routes(_ app: Application) throws {
    app.get { req in
        return "Flappy Bird User API"
    }
    
//    let userController = UserController()
//    try app.register(collection: userController)
    
    app.get("users") { req in
        return User.query(on: req.db).all().flatMapThrowing { users in
            return try users.map(User.PublicUser.init)
        }
    }
    
    app.get("user", ":name") { req -> EventLoopFuture<User.PublicUser>in
        let name = req.parameters.get("name")
        return User.query(on: req.db)
            .filter(\.$name == name!)
            .first()
            .flatMapThrowing {
                guard let user = $0 else { throw Abort(.notFound) }
                return try User.PublicUser(user)
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
    
    app.get("globalDeaths") { req -> String in
        return "Not implemented"
    }
    
    app.get("userCount") { req -> EventLoopFuture<Int> in
        return User.query(on: req.db)
            .count()
    }
    
    app.post("registerUser") { req -> EventLoopFuture<User> in
        try User.Create.validate(content: req)
        let create = try req.content.decode(User.Create.self)
        guard create.password == create.confirmPassword else {
            throw Abort(.badRequest, reason: "Passwords did not match")
        }
        let user = try User(
            name: create.name,
            passwordHash: Bcrypt.hash(create.password)
        )
        return user.save(on: req.db)
            .map { user }
    }
    
    app.get("internal_users") { req in
        User.query(on: req.db).all()
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
    
    passwordProtected.post("submitScore") { req -> String in
        let user = try req.auth.require(User.self)
        if !user.isBanned! {
            let score = try req.content.decode(User.SubmitScore.self)
            print("User: \(user.name.description)[\(user.id!.description)] submitted score: \(score.score), took \(score.time) seconds.")
            if score.score > score.time + 10 {
                user.isBanned = true
                let _ = user.update(on: req.db) .map { user }
                return "You have been banned. If your beleive this is an error, please contact the FlappyBird Revision Team"
            }
            if score.score > user.score! {
                user.score = score.score
                let _ = user.update(on: req.db) .map { user }
                print("Submitted score for \(user.name.description)")
                return "submitted"
            }
        } else {
            return "failed"
        }
        return "ok"
    }
    
    // Admin Things
    
    passwordProtected.get("unban", ":userID") { req -> String in
        let user = try req.auth.require(User.self)
        if user.admin! {
            let id = req.parameters.get("userID")!
            let uuid = UUID(uuidString: id)
            _ = User.find(uuid!, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { user -> EventLoopFuture<Void> in
                user.isBanned = false
                return user.save(on: req.db)
            }
            
            return "User has been unbanned"
        }
        return "Unauthorized"
    }
    
    passwordProtected.get("ban", ":userID") { req -> String in
        let user = try req.auth.require(User.self)
        if user.admin! {
            let id = req.parameters.get("userID")!
            let uuid = UUID(uuidString: id)
            
            _ = User.find(uuid!, on: req.db)
                .unwrap(or: Abort(.notFound))
                .flatMap { user -> EventLoopFuture<Void> in
                    user.isBanned = true
                    return user.save(on: req.db)
                }
            return "User has been banned"
        }
        return "Unauthorized"
    }
    
    passwordProtected.get("delete", ":userID") { req -> String in
        let user = try req.auth.require(User.self)
        if user.admin! {
            let id = req.parameters.get("userID")!
            let uuid = UUID(uuidString: id)
            _ = User.query(on: req.db)
                .filter(\.$id == uuid!)
                .delete()
            
            return "User has been removed"
        }
        return "Unauthorized"
    }
}
