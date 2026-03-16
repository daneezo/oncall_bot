# config/routes.rb

Rails.application.routes.draw do

  # built-in Rails health check — returns 200 if app is running
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes versioned under /api/v1
  namespace :api do
    namespace :v1 do

      # POST /api/v1/incidents — receives a simulated PagerDuty alert
      # this is the core endpoint for DEV-19
      resources :incidents, only: [:create]

    end
  end

end