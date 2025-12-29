Rails.application.routes.draw do
  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  # Area analysis API
  get "analyze", to: "analyze#index"

  # Root path
  root to: proc { [200, {}, ["SpaceFit API - Use GET /analyze?address=<address>"]] }
end
