class App < Sinatra::Base

	enable:sessions

	def failure
		error = session[:failure]
		session[:failure] = nil
		return error
	end

	get '/page/:user' do
		db = SQLite3::Database::new("./db/database.db")
		db.results_as_hash = true
		posts = db.execute("SELECT content FROM posts WHERE author_id IN (SELECT id FROM users WHERE name=?) ORDER BY created DESC LIMIT 10", params[:user])
		slim(:user_feed, locals: {posts: posts})
	end
	
	get '/' do
		if session[:user_id]
			slim(:home_page)
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

end
