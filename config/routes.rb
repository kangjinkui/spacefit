Rails.application.routes.draw do
  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  # Area analysis API
  get "api/analyze", to: "analyze#index"

  # Frontend
  root "home#index"
end
