class App < Sinatra::Base

	enable:sessions

	def db()
		db = SQLite3::Database::new("./db/database.db")
		db.results_as_hash = true
		return db
	end

	def failure
		error = session[:failure]
		session[:failure] = nil
		return error
	end

	def get_likes(posts)
		db = db()
		posts.each do |post|
			likes = db.execute("SELECT * FROM users WHERE id IN (SELECT user_id FROM user_likes_post WHERE post_id=?)", post["id"])
			post["likes"] = likes
		end
		return posts
	end

	def get_name_of_user(user_id)
		name = db().execute("SELECT name FROM users WHERE id=?", user_id)[0]["name"]
		return name
	end

	def get_following(user_id)
		users = db().execute("SELECT * FROM users WHERE id IN (SELECT followed_id FROM user_follows_user WHERE following_id=?)", user_id)
		return users
	end

	def liked(user_id, post_id)
		existing = db().execute("SELECT * FROM user_likes_post WHERE user_id=? AND post_id=?", [user_id, post_id])
		!existing.empty?
	end

	def following(following, followed)
		existing = db().execute("SELECT * FROM user_follows_user WHERE following_id=? AND followed_id=?", [following, followed])
		!existing.empty?
	end

	def get_posts_of_following(user_id)
		posts = db().execute("SELECT * from posts WHERE author_id IN (
			SELECT followed_id FROM user_follows_user WHERE following_id=?
		) ORDER BY created DESC", user_id)
		posts = get_likes(posts)
		return posts
	end

	get '/following' do
		if session[:user_id]
			users = get_following(session[:user_id])
			slim(:users_list, locals:{users:users})
		else
			redirect("/")
		end
	end

	get '/all_users' do
		users = db().execute("SELECT name FROM users")
		slim(:users_list, locals: {users: users})
	end

	get '/logout' do
		session[:user_id] = nil
		redirect('/')
	end
	
	get '/liked' do
		if session[:user_id]
			posts = db().execute("SELECT * FROM posts WHERE id IN (SELECT post_id FROM user_likes_post WHERE user_id=?)", session[:user_id])
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
		db = db()
		user = db.execute("SELECT * FROM users WHERE name=?", params[:user])
		if !user.empty?
			posts = db.execute("SELECT * FROM posts WHERE author_id IN (SELECT id FROM users WHERE name=?) ORDER BY created DESC", params[:user])
			posts = get_likes(posts)
			slim(:user_feed, locals: {posts: posts, user_id: user[0]["id"], name: user[0]["name"]})
		else
			"User not found"
		end
	end

	get '/' do
		if session[:user_id]
			posts = get_posts_of_following(session[:user_id])
			slim(:home_page, locals: {posts: posts})
		else
			redirect('/login')
		end
	end
	
	post '/new_post' do
		if session[:user_id]
			db().execute("INSERT INTO posts (content, created, author_id) VALUES (?, ?, ?)", [params[:text], Time.now.to_i, session[:user_id]])
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
		db = db()
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
			db = db()
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

	post '/like_post/:post_id/:place' do
		liking_user_id = session[:user_id]
		post_id = params[:post_id]
		db = db()
		post_author = db.execute("SELECT name FROM users WHERE id IN (SELECT author_id FROM posts WHERE id=?)", post_id)[0][0]
		if !liked(liking_user_id, post_id)
			db.execute("INSERT INTO user_likes_post (user_id, post_id) VALUES (?, ?)", [liking_user_id, post_id])
		end
		if params[:place] == "home"
			redirect "/##{post_id}"
		else
			redirect "page/#{post_author}##{post_id}"
		end
	end

	post '/delete_post/:post_id/:name' do
		post_id = params[:post_id]
		db = db()
		author = db.execute("SELECT author_id FROM posts WHERE id=?", post_id)
		if !author.empty? && session[:user_id] == author[0]['author_id']
			db.execute("DELETE FROM posts WHERE id=?", post_id)
		end
		redirect "page/#{params[:name]}##{post_id}"
	end

	post '/unlike_post/:post_id/:place' do
		liking_user_id = session[:user_id]
		post_id = params[:post_id]
		db = db()
		post_author = db.execute("SELECT name FROM users WHERE id IN (SELECT author_id FROM posts WHERE id=?)", post_id)[0][0]
		if liked(liking_user_id, post_id)
			db.execute("DELETE FROM user_likes_post WHERE user_id=? AND post_id=?", [liking_user_id, post_id])
		end
		if params[:place] == "home"
			redirect "/##{post_id}"
		elsif params[:place] == "liked"
			redirect "/liked"
		else
			redirect "/page/#{post_author}##{post_id}"
		end
	end

	post '/follow_user/:user_id' do
		following_id = session[:user_id]
		followed_id = params[:user_id]
		db = db()
		existing = db.execute("SELECT * FROM user_follows_user WHERE following_id=? AND followed_id=?", [following_id, followed_id])
		if existing.empty?
			db.execute("INSERT INTO user_follows_user (following_id, followed_id) VALUES (?, ?)", [following_id, followed_id])
		end
		redirect back
	end

	post '/unfollow_user/:user_id' do
		following_id = session[:user_id]
		followed_id = params[:user_id]
		db = db()
		existing = db.execute("SELECT * FROM user_follows_user WHERE following_id=? AND followed_id=?", [following_id, followed_id])
		if !existing.empty?
			db.execute("DELETE FROM user_follows_user WHERE following_id=? AND followed_id=?", [following_id, followed_id])
		end
		redirect back
	end

end
