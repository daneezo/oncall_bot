# app/controllers/application_controller.rb

class ApplicationController < ActionController::API

    # protect every endpoint automatically
    before_action :authenticate_api_key!
  
    private
  
    def authenticate_api_key!
      # extract token from Authorization header
      # expected format: "Bearer your_token_here"
      token = request.headers["Authorization"]&.split(" ")&.last
  
      unless token
        render json: { error: "Unauthorized - no token provided" }, status: :unauthorized
        return
      end
  
      @current_api_key = ApiKey.authenticate(token)
  
      unless @current_api_key
        render json: { error: "Unauthorized - invalid or inactive token" }, status: :unauthorized
      end
    end
  
  end