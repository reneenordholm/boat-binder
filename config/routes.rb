Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  root "dashboard#index"

  resources :owners, controller: :accounts, except: %i[destroy]

  resources :vessels do
    resources :service_visits, only: %i[index new create show]
    resources :documents, only: %i[new create destroy]
    resources :binder_notes, only: %i[create edit update destroy]
    resources :batteries, controller: :asset_batteries, except: %i[index show]
  end

  resources :documents, only: %i[index new create destroy]
  resources :reminders, only: %i[index new create edit update]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
