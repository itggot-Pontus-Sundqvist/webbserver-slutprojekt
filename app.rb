class App < Sinatra::Base

	enable:sessions

	def failure
		error = session[:failure]
		session[:failure] = nil
		return error
	end

	def get_likes(posts)
		db = SQLite3::Database::new("./db/database.db")
		db.results_as_hash = true
		posts.each do |post|
			likes = db.execute("SELECT * FROM users WHERE id IN (SELECT user_id FROM user_likes_post WHERE post_id=?)", post["id"])
			post["likes"] = likes
		end
		return posts
	end

	def get_name_of_user(user_id)
		db = SQLite3::Database::new("./db/database.db")
		db.results_as_hash = true
		name = db.execute("SELECT name FROM users WHERE id=?", user_id)[0]["name"]
		return name
	end

	get '/following' do
		if session[:user_id]
			db = SQLite3::Database::new("./db/database.db")
			db.results_as_hash = true
			users = db.execute("SELECT * FROM users WHERE id IN (SELECT followed_id FROM user_follows_user WHERE following_id=?)", session[:user_id])
			slim(:follow_list, locals:{users:users})
		else
			redirect("/")
		end
	end

	get '/logout' do
		session[:user_id] = nil
		redirect('/')
	end
	
	get '/liked' do
		if session[:user_id]
			db = SQLite3::Database::new("./db/database.db")
			db.results_as_hash = true
			posts = db.execute("SELECT * FROM posts WHERE id IN (SELECT post_id FROM user_likes_post WHERE user_id=?)", session[:user_id])
			posts = get_likes(posts)
			posts.each do |post| 
				post["author"] = get_name_of_user(post["author_id"])
			end
			slim(:liked_list, locals:{posts:posts})
		else
			redirect("/")
		end
	end

	get '/page/:user' do
		db = SQLite3::Database::new("./db/database.db")
		db.results_as_hash = true
		posts = db.execute("SELECT * FROM posts WHERE author_id IN (SELECT id FROM users WHERE name=?) ORDER BY created DESC", params[:user])
		posts = get_likes(posts)
		if !posts.empty?
			slim(:user_feed, locals: {posts: posts, user_id: posts[0]["author_id"]})
		else
			"User not found"
		end
	end
	
	get '/' do
		if session[:user_id]
			slim(:home_page, locals: {name: get_name_of_user(session[:user_id])})
		else
			redirect('/login')
		end
	end
	
	post '/new_post' do
		if session[:user_id]
			db = SQLite3::Database::new("./db/database.db")
			db.execute("INSERT INTO posts (content, created, author_id) VALUES (?, ?, ?)", [params[:text], Time.now.to_i, session[:user_id]])
			redirect('/')
		else
			redirect('/login')
		end
	end

	get '/login' do
		slim(:login_page)
	end

	post '/login' do
		name = params[:name]
		password = params[:password]
		db = SQLite3::Database::new("./db/database.db")
		real_password = db.execute("SELECT password FROM users WHERE name=?", name)
		if real_password != [] && BCrypt::Password.new(real_password[0][0]) == password
			session[:user_id] = db.execute("SELECT id FROM users WHERE name=?", name)[0][0]
			redirect('/')
		else
			session[:failure] = "Login failed"
			redirect('/login')
		end
	end

	get '/new_user' do
		slim(:new_user)
	end

	post '/new_user' do
		new_name = params[:name]
		new_password = params[:password]
		confirmed_password = params[:confirmed_password]
		if new_password == confirmed_password
			db = SQLite3::Database::new("./db/database.db")	
			taken_name = db.execute("SELECT * FROM users WHERE name IS ?", new_name)
			if taken_name == []
				hashed_password = BCrypt::Password.create(new_password)
				db.execute("INSERT INTO users (name, password) VALUES (?,?)", [new_name, hashed_password])
				redirect('/')
			else
				session[:failure] = "Username is already taken."
				redirect('/new_user')
			end
		else
			session[:failure] = "Passwords didn't match. Please try again."
			redirect('/new_user')
		end
	end

	def liked(user_id, post_id)
		db = SQLite3::Database::new("./db/database.db")
		existing = db.execute("SELECT * FROM user_likes_post WHERE user_id=? AND post_id=?", [user_id, post_id])
		!existing.empty?
	end

	def following(following, followed)
		db = SQLite3::Database::new("./db/database.db")
		existing = db.execute("SELECT * FROM user_follows_user WHERE following_id=? AND followed_id=?", [following, followed])
		!existing.empty?
	end

	post '/like_post/:post_id' do
		liking_user_id = session[:user_id]
		post_id = params[:post_id]
		db = SQLite3::Database::new("./db/database.db")
		post_author = db.execute("SELECT name FROM users WHERE id IN (SELECT author_id FROM posts WHERE id=?)", post_id)[0][0]
		if !liked(liking_user_id, post_id)
			db.execute("INSERT INTO user_likes_post (user_id, post_id) VALUES (?, ?)", [liking_user_id, post_id])
		end
		redirect "page/#{post_author}##{post_id}"
	end

	post '/unlike_post/:post_id' do
		liking_user_id = session[:user_id]
		post_id = params[:post_id]
		db = SQLite3::Database::new("./db/database.db")
		post_author = db.execute("SELECT name FROM users WHERE id IN (SELECT author_id FROM posts WHERE id=?)", post_id)[0][0]
		if liked(liking_user_id, post_id)
			db.execute("DELETE FROM user_likes_post WHERE user_id=? AND post_id=?", [liking_user_id, post_id])
		end
		redirect "page/#{post_author}##{post_id}"
	end

	post '/follow_user/:user_id' do
		following_id = session[:user_id]
		followed_id = params[:user_id]
		db = SQLite3::Database::new("./db/database.db")
		existing = db.execute("SELECT * FROM user_follows_user WHERE following_id=? AND followed_id=?", [following_id, followed_id])
		if existing.empty?
			db.execute("INSERT INTO user_follows_user (following_id, followed_id) VALUES (?, ?)", [following_id, followed_id])
		end
		redirect back
	end

	post '/unfollow_user/:user_id' do
		following_id = session[:user_id]
		followed_id = params[:user_id]
		db = SQLite3::Database::new("./db/database.db")
		existing = db.execute("SELECT * FROM user_follows_user WHERE following_id=? AND followed_id=?", [following_id, followed_id])
		if !existing.empty?
			db.execute("DELETE FROM user_follows_user WHERE following_id=? AND followed_id=?", [following_id, followed_id])
		end
		redirect back
	end

end
