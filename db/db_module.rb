module DB
    def get_db()
		db = SQLite3::Database::new("./db/database.db")
		db.results_as_hash = true
		return db
    end
    
    # Go through a list of posts and add a list to each that contains every user who liked the post.
	def get_likes(posts)
		db = get_db()
		posts.each do |post|
			likes = db.execute("SELECT * FROM users WHERE id IN (SELECT user_id FROM user_likes_post WHERE post_id=?)", post["id"])
			post["likes"] = likes
		end
		return posts
    end
    
    def get_name_of_user(user_id)
		name = get_db().execute("SELECT name FROM users WHERE id=?", user_id)[0]["name"]
		return name
    end
    
	def get_following(user_id)
		users = get_db().execute("SELECT * FROM users WHERE id IN (SELECT followed_id FROM user_follows_user WHERE following_id=?)", user_id)
		return users
    end

    # Returns if a user liked a specific post
	def liked(user_id, post_id)
		existing = get_db().execute("SELECT * FROM user_likes_post WHERE user_id=? AND post_id=?", [user_id, post_id])
		!existing.empty?
    end

	def following(following, followed)
		existing = get_db().execute("SELECT * FROM user_follows_user WHERE following_id=? AND followed_id=?", [following, followed])
		!existing.empty?
    end
    
    def get_posts_liked_by(user_id)
        posts = get_db().execute("SELECT * FROM posts WHERE id IN (SELECT post_id FROM user_likes_post WHERE user_id=?)", session[:user_id])
        posts = get_likes(posts)
        posts.each do |post| 
            post["author"] = get_name_of_user(post["author_id"])
        end
        posts
    end
    
    # Get all posts from the users `user_id` follow, sorted by when the posts were created.
    def get_posts_of_users_followed_by(user_id)
        posts = get_db().execute("SELECT * from posts WHERE author_id IN (
            SELECT followed_id FROM user_follows_user WHERE following_id=?
        ) ORDER BY created DESC", session[:user_id])
        get_likes(posts)
    end

    def user_exists(name)
        taken_name = get_db().execute("SELECT * FROM users WHERE name IS ?", name)
        taken_name != []
    end

    def create_user(name, password)
        hashed_password = BCrypt::Password.create(password)
        get_db().execute("INSERT INTO users (name, password) VALUES (?,?)", [name, hashed_password])
    end

    def get_author_of_post(post_id)
        get_db().execute("SELECT name FROM users WHERE id IN (SELECT author_id FROM posts WHERE id=?)", post_id)[0][0]
    end

    def add_like(user, post)
        get_db().execute("INSERT INTO user_likes_post (user_id, post_id) VALUES (?, ?)", [user, post])
    end

    def remove_like(user, post)
        get_db().execute("DELETE FROM user_likes_post WHERE user_id=? AND post_id=?", [user, post])
    end

    def password_is_correct(username, input_password)
        real_password = get_db().execute("SELECT password FROM users WHERE name=?", username)
        real_password != [] && BCrypt::Password.new(real_password[0][0]) == input_password
    end

    def add_follow(following_id, followed_id)
        get_db().execute("INSERT INTO user_follows_user (following_id, followed_id) VALUES (?, ?)", [following_id, followed_id])
    end

    def remove_follow(following_id, followed_id)
        get_db().execute("DELETE FROM user_follows_user WHERE following_id=? AND followed_id=?", [following_id, followed_id])
    end

    def get_posts_authored_by(username)
        posts = get_db().execute("SELECT * FROM posts WHERE author_id IN (SELECT id FROM users WHERE name=?) ORDER BY created DESC", params[:user])
        posts = get_likes(posts)
    end

    def get_user_id(name)
        get_db().execute("SELECT id FROM users WHERE name=?", name)[0][0]
    end

    def all_users()
        get_db().execute("SELECT name FROM users")
    end

    def is_author(user_id, post_id)
        author = get_db().execute("SELECT author_id FROM posts WHERE id=?", post_id)
        !author.empty? && user_id == author[0]['author_id']
    end

    def create_post(content, user)
        get_db().execute("INSERT INTO posts (content, created, author_id) VALUES (?, ?, ?)", [content, Time.now.to_i, user])
    end

    def remove_post(post_id)
        get_db().execute("DELETE FROM posts WHERE id=?", post_id)
    end
end