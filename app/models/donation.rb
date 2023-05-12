class Donation < ApplicationRecord

    CLIENT_ID = ENV['NB_CLIENT_ID']
    CLIENT_SECRET = ENV['NB_CLIENT_SECRET']
    REDIRECT_URI = Rails.env.production? ? "https://cors.acl.org.au/nb_oauth_callback/" : "http://localhost:3000/nb_oauth_callback/"
    SITE_PATH = 'https://acl.nationbuilder.com'

    def Donation.get_auth_page_url
        #site_path = 'https://acl.nationbuilder.com'
        #redirect_uri = 'http://localhost:3000/nb_oauth_callback/'
        client = OAuth2::Client.new(CLIENT_ID,CLIENT_SECRET,:site=>SITE_PATH)
        return client.auth_code.authorize_url(:redirect_url => REDIRECT_URI)
    end

    def Donation.get_client
        #site_path = 'https://acl.nationbuilder.com'
        client = OAuth2::Client.new(CLIENT_ID,CLIENT_SECRET,:site=>SITE_PATH)
        return client
    end

    def Donation.get_access_token(code)
        response = HTTParty.post("https://acl.nationbuilder.com/oauth/token",
            :body => {
                'grant_type'=>'authorization_code',
                'client_id'=>CLIENT_ID,
                'client_secret'=>CLIENT_SECRET,
                'redirect_uri'=>REDIRECT_URI, # change depending on ENV
                'code'=>code
            }.to_json,
            :headers => {
                'Content-Type'=>'application/json',
                'Accept'=>'application/json'
            })
        return response
    end

    def Donation.refresh_access_token
        response = HTTParty.post("https://acl.nationbuilder.com/oauth/token",
            :body => {
                'grant_type'=>'refresh_token',
                'client_id'=>CLIENT_ID,
                'client_secret'=>CLIENT_SECRET,
                'redirect_uri'=>REDIRECT_URI,
                'refresh_token'=>General.refresh_token
            }.to_json,
            :headers => {
                'Content-Type'=>'application/json',
                'Accept'=>'application/json'
            })
        if response.code == 200
            #ENV['NB_ACCESS_TOKEN'] = response['access_token']
            #ENV['NB_TOKEN_EXPIRES_AT'] = Time.now + response['expires_in'].seconds
            #ENV['NB_REFRESH_TOKEN'] = response['refresh_token']
            General.save_access_token(response['access_token'], response['expires_in'], response['refresh_token'])
        else
            puts response.code
            raise "Couldn't refresh token."
        end
    end

    def Donation.save_access_token(code)
        response = Donation.get_access_token(code)
        puts response.code
        if response.code == 200
            #ENV['NB_ACCESS_TOKEN'] = response['access_token']
            #ENV['NB_TOKEN_EXPIRES_AT'] = Time.now + response['expires_in'].seconds
            #ENV['NB_REFRESH_TOKEN'] = response['refresh_token']
            General.save_access_token(response['access_token'], response['expires_in'], response['refresh_token'])
        else
            raise "Unsuccessful access token."
        end
    end
end
