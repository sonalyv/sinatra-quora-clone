enable :sessions

get '/' do
	if logged_in? 
		redirect '/index'
	else 
		erb :"static/login"
	end
end

get '/index' do
	# @posts = Question.paginate(page: params[:page], per_page: 5)
	erb :"static/index"
end

post '/signup' do 
	@user = User.new(params[:user])
	if @user.save
		login @user
		redirect '/'
	else
		flash[:error] = @user.errors.values.flatten.first
		redirect '/'
	end
end

post '/login' do
	@user = User.find_by(email: params[:user][:email])
	if @user.nil?
		flash[:error] = "No account found for this email. Retry, or Sign up for Quora."
		redirect '/'
	elsif @user.authenticate(params[:user][:password]) == false
		flash[:error] = "Incorrect password."
		redirect '/'
	else
		login @user
		redirect '/index'
	end
end

post '/logout' do
	session[:user_id] = nil
	redirect '/'
end

get '/user/:full_name' do
	full_name = params[:full_name].gsub("-", " ")
	@user = User.find_by(full_name: full_name)
	erb :'static/profile'
end

get '/question/:title' do
	question_title = params[:title].gsub("-", " ")
	@question = Question.find_by(title: question_title)
	erb :'static/view_question'
end

post '/question/new' do
	@question = Question.new(title: params[:question], user_id: current_user.id)
	if @question.title == ""
		flash[:error] = "Please enter a question."
		redirect '/index'
	elsif @question.save
		question_url = @question.title.gsub(" ", "-")
		redirect to "/question/#{question_url}"
	else
		redirect "/question/#{params[:question].gsub(" ", "-")}"
	end
end

post '/answer/new' do
	@question = Question.find_by(id: params[:question_id])
	@answer = Answer.new(answer: params[:answer], user_id: current_user.id, question_id: params[:question_id])
	question_url = Question.find_by(id: params[:question_id]).title.gsub(" ", "-")
	@user = User.find_by(id: @answer.user_id).full_name.gsub(" ", "-")
	if @question.answers.find_by(user_id: current_user.id) != nil
		flash[:error] = "You have already answered this question before."
		redirect "/question/#{question_url}"
	else
		if @answer.save
			redirect "/#{question_url}/answer/#{@user}"
		else
			flash[:error] = @answer.errors.values.flatten.first 
			redirect "/question/#{question_url}"
		end
	end
end

get '/:title/answer/:full_name' do
	@user = User.find_by(full_name: params[:full_name].gsub("-"," "))
	@question = Question.find_by(title: params[:title].gsub("-"," "))
	@answer = @question.answers.where(user_id: @user.id).first
	# @answer = Answer.find_by(user_id: @user.id)
	erb :'static/view_answer'
end

post '/questions/:question_id/vote' do
	@question = Question.find(params[:question_id])
	@vote = QuestionVote.find_or_initialize_by(question_id: params[:question_id], user_id: current_user.id)

	if @vote.new_record? 
		@vote.upvote = true
	else
		@vote.toggle(:upvote)
	end

	@vote.save

	if request.xhr?
		{ vote_count: @question.question_votes.where(upvote: true).count,
			voted: @vote.upvote
		}.to_json
	else
		redirect "/questions/#{@question.title.gsub(" ", "-")}"
	end
end

post '/answers/:answer_id/vote' do
	@answer = Answer.find(params[:answer_id])
	@vote = AnswerVote.find_or_initialize_by(answer_id: params[:answer_id], user_id: current_user.id)

	if @vote.new_record? 
		@vote.upvote = true
	else
		@vote.toggle(:upvote)
	end

	@vote.save

	if request.xhr?
		{ vote_count: @answer.answer_votes.where(upvote: true).count,
			voted: @vote.upvote
		}.to_json
	else
		redirect "/questions/#{@question.title.gsub(" ", "-")}"
	end
end

delete '/questions/:question_id' do
	Question.find(params[:question_id]).destroy
	flash[:alert] = "Your question has been deleted."

	redirect "/"
end