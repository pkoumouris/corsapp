Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
  get '/test', to: 'general#test'
  get '/gnaf', to: 'general#gnaf'
  post '/payment', to: 'general#securepay_payment'
  post '/sandbox/payment', to: 'general#securepay_sandbox_payment'
  get '/getcampaigns', to: 'general#get_campaigns'
  post '/applepay/initiatesession', to: 'general#apple_pay_initiate_session'
  get '/nb_oauth_callback', to: 'nboauths#redirect_code'
  get '/varstubs', to: 'general#see_env_var_stubs'

  post '/reconcile_recurring', to: 'general#reconcile_recurring'

  # api
  post '/api/sandbox/refund', to: 'general#sandbox_refund'
  post '/api/refund', to: 'general#refund'

  post '/api/refresh_access_token', to: 'sessions#refresh_access_token'

  # general pages
  get '/index', to: 'sessions#index'
  get '/donation/:order_spid', to: 'sessions#show_donation'

  # A message for the hackers
  get '/boaform/admin/formLogin', to: 'general#nice_try'
  get '/.env', to: 'general#nice_try'

  # Log in
  get '/login', to: 'sessions#new'
  post '/login', to: 'sessions#create'
  get '/test_pdf', to: 'sessions#test_pdf'

  # Geoscape
  get '/geoscape', to: 'general#geoscape'
  get '/broadgeoscape', to: 'general#geoscape_broad'

  post '/getnbat', to: 'sessions#get_access_token'

  # Comms preferences
  get '/commspreferences', to: 'sessions#comms_preferences'
  get '/emailcommspreferences', to: 'sessions#send_comms_preference_email'
  post '/emailcommspreferences', to: 'sessions#send_comms_preference_email_api'
  post '/commspreferences', to: 'sessions#update_comms_preferences_api'

  get '/sendunsubscribe', to: 'sessions#send_unsubscribe'
  post '/sendunsubscribe', to: 'sessions#send_unsubscribe_api'
  get '/unsubscribe', to: 'sessions#unsubscribe'
  post '/unsubscribe', to: 'sessions#unsubscribe_api'
end
