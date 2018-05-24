require_relative './db/db_module'

class App < Sinatra::Base

	enable:sessions
	include DB

	# Get the last error stored in `session[:failure]`
	def failure
		error = session[:failure]
		session[:failure] = nil
		return error
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
		users = all_users()
		slim(:users_list, locals: {users: users})
	end

	get '/logout' do
		session[:user_id] = nil
		redirect('/')
	end

	get '/liked' do
		if session[:user_id]
			posts = get_posts_liked_by(session[:user_id])
			slim(:liked_list, locals:{posts:posts})
		else
			redirect("/")
		end
	end

	get '/page/:user' do
		username = params[:user]
		if user_exists(username)
			posts = get_posts_authored_by(username)
			slim(:user_feed, locals: {posts: posts, user_id: get_user_id(username), name: username})
		else
			"User not found"
		end
	end

	get '/' do
		if session[:user_id]
			posts = get_posts_of_users_followed_by(session[:user_id])
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
		if password_is_correct(name, password)
			session[:user_id] = get_user_id(name)
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
			if user_exists(new_name)
				session[:failure] = "Username is already taken."
				redirect('/new_user')
			else
				create_user(new_name, new_password)
				redirect('/')
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
		if !liked(liking_user_id, post_id)
			add_like(liking_user_id, post_id)
		end

		if params[:place] == "home"
			redirect "/##{post_id}"
		else
			author = get_author_of_post(post_id)
			redirect "page/#{author}##{post_id}"
		end
	end

	post '/unlike_post/:post_id/:place' do
		liking_user_id = session[:user_id]
		post_id = params[:post_id]
		db = db()
		if liked(liking_user_id, post_id)
			remove_like(liking_user_id, post_id)
		end

		if params[:place] == "home"
			redirect "/##{post_id}"
		elsif params[:place] == "liked"
			redirect "/liked"
		else
			author = get_author_of_post(post_id)
			redirect "/page/#{author}##{post_id}"
		end
	end

	post '/delete_post/:post_id/:name' do
		post_id = params[:post_id]
		db = db()
		if is_author(session[:user_id], post_id)
			db().execute("DELETE FROM posts WHERE id=?", post_id)
		end
		redirect "page/#{params[:name]}##{post_id}"
	end

	post '/follow_user/:user_id' do
		following_id = session[:user_id]
		followed_id = params[:user_id]
		if !following(following_id, followed_id)
			add_follow(following_id, followed_id)
		end
		redirect back
	end

	post '/unfollow_user/:user_id' do
		following_id = session[:user_id]
		followed_id = params[:user_id]
		if following(following_id, followed_id)
			remove_follow(following_id, followed_id)
		end
		redirect back
	end
end
