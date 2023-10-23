class SessionsController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:refresh_access_token, :get_access_token]

    PREFERENCE_SECRET = Rails.env == "production" ? ENV['PREFERENCE_SECRET'] : '8QKI4a57dDvKoM2v'
    CM_AUTH = Rails.env == "production" ? 'Basic '+ENV['CM_AUTH'] : ''
    CM_LIST_ID = Rails.env == "production" ? "819d4c49e69290315797754839ad14e1" : "42d1a271424b7a6a8650c810575c3fb1"
    CM_CLIENT_ID = Rails.env == "production" ? "ba2383a86df105accc1562e64b4316af" : "a9eef8b7cb9a43b3c35055c5510d0d12"
    SMART_EMAIL_ID = Rails.env == "production" ? "8fb85bc4-6ded-4b1c-b7da-4b83d7d983d0" : "ccc7f472-9810-4102-a351-8f43e92e4e4b"

    def new
        if logged_in?
            redirect_to root_url
        end
    end

    def create
        user = User.find_by(email: params[:session][:email].downcase)
        if !user.nil?
            if user.authenticate(params[:session][:password])
                log_in(user)
                redirect_to '/index'
            else
                flash[:danger] = "Failed to log in"
                redirect_to '/login'
            end
        else
            flash[:danger] = "Failed to log in"
            redirect_to '/login'
        end
    end

    def destroy
        if logged_in?
            log_out
            redirect_to root_url
        end
    end

    def index
        @start = nil
        @finish = nil
        if !params[:start].nil? && !params[:finish].nil?
            @start = Time.new(params[:start][0..3].to_i,params[:start][4..5].to_i,params[:start][6..7].to_i)
            @finish = Time.new(params[:finish][0..3].to_i,params[:finish][4..5].to_i,params[:finish][6..7].to_i)
            @donations = Donation.where(created_at: @start..(@finish+1.day))
            @load_more = false
        else
            n = params[:n].nil? ? 10 : params[:n]
            @donations = Donation.last(n).reverse
            @load_more = true
        end
    end

    def show_donation
        @donation = Donation.find_by(order_spid: params[:order_spid])
        if @donation.nil?
            flash[:danger] = "Donation not found."
            redirect_to '/index'
        end
        @test_token = General.test_token
    end

    def refresh_access_token
        if Digest::SHA256.base64digest(params[:token]) != "vg1aJVAe9FZfITG9YptD9LIh4VUa7YQcCocxlL9NUyY="
            render plain: {error: "Forbidden"}.to_json, status: 400
            return nil
        end
        General.refresh_access_token
        render json: {
            expires_at: General.find_by(name: "NB_EXPIRES_AT").value
        }.to_json
    end

    def get_access_token
        if Digest::SHA256.base64digest(params[:token]) != ENV['GET_ACCESS_TOKEN_HASH']
            render plain: {error: "Forbidden"}.to_json, status: 400
            return nil
        end
        render json: {
            access_token: General.access_token
        }.to_json
    end

    def test_pdf
        #html = "<h1>Hey!</h1><p>Here is a test</p>"
        #kit = PDFKit.new(html, :page_size => 'Letter')
        #send_data(kit.to_pdf, filename: SecureRandom.alphanumeric+'.pdf', type: 'application/pdf')
        #pdf = Prawn::Document.new(page_size: 'A4')
        #f = File.open('public/receipt.html','r')
        #s = f.read
        #PrawnHtml.append_html(pdf, '<div><h1>Red dot!</h1><img src="data:image/png;base64, iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==" alt="Red dot" /></div>')
        #send_data(pdf.render, filename: 'sample-'+SecureRandom.alphanumeric+'.pdf', type:'application/pdf')
    end

    def update_comms_preferences_api
        if Rails.env != "development" && Digest::SHA256.hexdigest(params[:email]+':'+PREFERENCE_SECRET) != params[:token]
            render json: {
                success: false
            }.to_json, status: 400
            return nil
        end
        results = []
        signup_id = General.get_signup_id_from_email(params[:email])
        existing_tags = General.get_tags_from_person(signup_id)
        new_tags = params[:preferences]
        if new_tags.map { |t| ['7216','5635','5637','5636','5632','5633','5634'].include?(t) }.uniq != [true]
            render json: {
                success: false,
                existing_tags: existing_tags,
                new_tags: new_tags
            }.to_json
            return nil
        end
        res1 = General.remove_tags_from_person(signup_id, existing_tags - new_tags)
        res2 = General.add_tags_to_person(signup_id, new_tags - existing_tags)
        render json: {
            success: [res1,res2].flatten.map { |c| [200,201].include?(c) }.uniq == [true]
        }.to_json
        #res = HTTParty.put("https://api.createsend.com/api/v3.3/subscribers/#{CM_LIST_ID}.json?email=#{params[:email]}",
        #    :headers => {
        #        'Authorization'=>CM_AUTH
        #    },
        #    :body => {
        #        'EmailAddress'=>params[:email],
        #        'CustomFields'=>[{
        #            'Key'=>'Tags',
        #            'Value'=>'',
        #            'Clear'=>true
        #        }],
        #        'ConsentToTrack'=>'Yes'
        #    }.to_json)
        #results.push(res.code)
        #res = HTTParty.put("https://api.createsend.com/api/v3.3/subscribers/#{CM_LIST_ID}.json?email=#{params[:email]}",
        #    :headers => {
        #        'Authorization'=>CM_AUTH
        #    },
        #    :body => {
        #        'EmailAddress'=>params[:email],
        #        'CustomFields'=>[{
        #            'Key'=>'Tags',
        #            'Value'=>'',
        #            'Clear'=>true
        #        }],
        #        'ConsentToTrack'=>'Yes'
        #    }.to_json)
        #results.push(res.code)
        #if params[:preferences].length > 0
        #    res = HTTParty.put("https://api.createsend.com/api/v3.3/subscribers/#{CM_LIST_ID}.json?email=#{params[:email]}",
        #        :headers => {
        #            'Authorization'=>CM_AUTH
        #        },
        #        :body => {
        #            'EmailAddress'=>params[:email],
        #            'CustomFields'=>params[:preferences].map { |p| {'Key'=>'Tags','Value'=>p} },
        #            'ConsentToTrack'=>'Yes'
        #        }.to_json)
        #    results.push(res.code)
        #end
        #res = HTTParty.post('https://aclportal.staging.wemapac.io/webservices/commspreferences/changePrefs',
        #    :headers => {
        #        'Content-Type'=>'application/json'
        #    },
        #    :body => {
        #        'Update Email'=>params[:email],
        #        'Update Token'=>params[:token],
        #        'Update Preferences'=>params[:preferences].map { |p| {'Preference Name' => p} }
        #    }.to_json)
        #puts "BODY"
        #puts({
        #        'Update Email'=>params[:email],
        #        'Update Token'=>params[:token],
        #        'Update Preferences'=>params[:preferences].map { |p| {'Preference Name' => p} }
        #    })
        #render json: {
        #    success: res.code == 200 && res['Update Success'],
        #    res_code: res.code
        #}.to_json
        #render json: {
        #    success: results.map { |r| r==200||r==201 }.uniq == [true]
        #}.to_json
    end

    def send_comms_preference_email_api
        @email = params[:email]
        token = Digest::SHA256.hexdigest(@email.downcase+':'+PREFERENCE_SECRET)
        @result = 202
        if Rails.env == "production"
            res = HTTParty.post("https://api.createsend.com/api/v3.2/transactional/smartemail/#{SMART_EMAIL_ID}/send",
                :headers=>{
                    'Authorization'=>CM_AUTH
                },
                :body=>{
                    'To'=>[@email],
                    'CC'=>nil,
                    'BCC'=>nil,
                    'Attachments'=>[],
                    'Data'=>{
                        'manageLink'=>"https://cors.acl.org.au/commspreferences?email=#{@email}&token=#{token}"
                    },
                    'AddRecipientsToList'=>false,
                    'ConsentToTrack'=>'Yes'
                }.to_json)
            @result = res.code
        end
        render json: {
            success: [200,201,202].include?(@result)
        }.to_json
    end

    def send_comms_preference_email
        @email = params[:email]
        #token = Digest::SHA256.hexdigest(@email.downcase+':'+PREFERENCE_SECRET)
        # 
        #res = HTTParty.post("https://api.createsend.com/api/v3.3/transactional/classicEmail/send?clientID=#{CM_CLIENT_ID}",
        #    :headers=>{
        #        'Authorization'=>CM_AUTH
        #    },
        #    :body => {
        #        'Subject' => 'Update your communication preferences',
        #        'From'=>'ACL National Office <natoffice@acl.org.au>',
        #       'ReplyTo'=>'natoffice@acl.org.au',
        #       'To'=>[email],
        #       'CC'=>nil,
        #       'BCC'=>nil,
        #        'Html'=>"<div style=\"text-align:center;\"><img src=\"https://www.acl.org.au/wp-content/uploads/2023/04/ACL_Logo_POS_RGB_final.png\" style=\"width:200px;\" /><p>Manage your email preferences for <b>#{email}</b> here:</p><a href=\"https://cors.acl.org.au/commspreferences?email=#{email}&token=#{token}\"><button style=\"background-color:#e75819;color:#fff;padding:20px;border-radius:4px;border:none;\">Manage preferences</button></a></div>",
        #        'Text'=>'',
        #        'Attachments'=>[],
        #        'TrackOpens'=>false,
        #        'TrackClicks'=>false,
        #        'InlineCSS'=>true,
        #        'ConsentToTrack'=>'Yes'
        #    }.to_json)
        #@result = 202
        #if Rails.env == "production"
        #    res = HTTParty.post("https://api.createsend.com/api/v3.2/transactional/smartemail/#{SMART_EMAIL_ID}/send",
        #        :headers=>{
        #            'Authorization'=>CM_AUTH
        #        },
        #        :body=>{
        #0           'To'=>[@email],
        #           'CC'=>nil,
        #            'BCC'=>nil,
        #            'Attachments'=>[],
        #            'Data'=>{
        #                'manageLink'=>"https://cors.acl.org.au/commspreferences?email=#{@email}&token=#{token}"
        #            },
        #            'AddRecipientsToList'=>false,
        #            'ConsentToTrack'=>'Yes'
        #        }.to_json)
        #    @result = res.code
        #end
    end

    def comms_preferences
        @email = params[:email]
        @token = params[:token]
        #res = HTTParty.post('https://aclportal.staging.wemapac.io/webservices/commspreferences/getInfo',
        #    :headers => {
        #        'Content-Type'=>'application/json'
        #    },
        #    :body => {
        #        'Email Lookup'=>@email,
        #        'Comms Token'=>@token
        #    }.to_json)
        if Rails.env != "development" && Digest::SHA256.hexdigest(@email.downcase+':'+PREFERENCE_SECRET) != @token
            redirect_to "/404?reason=failedauth&email=#{@email}&token#{@token}&digest=#{Digest::SHA256.hexdigest(@email.downcase+':'+PREFERENCE_SECRET)}"
            return nil
        end
        #res = HTTParty.get("https://api.createsend.com/api/v3.3/subscribers/#{CM_LIST_ID}.json?email=#{@email}&includetrackingpreference=true",
        #    :headers=>{
        #        'Authorization'=>CM_AUTH,
        #        'Accept'=>'*/*'
        #    })
        #if res.code != 200
        #    redirect_to '/500?reason=failed_auth'
        #    return nil
        #end
        signup_id = General.get_signup_id_from_email(@email)
        @tags = General.get_tags_from_person(signup_id)
        #@preferences = res['CustomFields'].map { |c| c['Value'] }
    end

    ## UNSUBSCRIBE
    def send_unsubscribe
        @email = params[:email]
        #@token = params[:token]
        #if Digest::SHA256.hexdigest(@email.downcase+':'+PREFERENCE_SECRET) != @token
        #    redirect_to "/404?reason=failedauth&email=#{@email}&token#{@token}&digest=#{Digest::SHA256.hexdigest(@email.downcase+':'+PREFERENCE_SECRET)}"
        #    return nil
        #end
        #@tags = General.get_tags_from_person(signup_id)
    end

    def send_unsubscribe_api
        @email = params[:email].to_s
        #@token = params[:token].to_s
        #if Digest::SHA256.hexdigest(@email.downcase+':'+PREFERENCE_SECRET) != @token
        #    redirect_to "/404?reason=failedauth&email=#{@email}&token#{@token}&digest=#{Digest::SHA256.hexdigest(@email.downcase+':'+PREFERENCE_SECRET)}"
        #    return nil
        #end
        #signup_id = General.get_signup_id_from_email(@email)
        token = Digest::SHA256.hexdigest(@email.downcase+':'+PREFERENCE_SECRET)
        if Rails.env == "production"
            res = HTTParty.post("https://api.createsend.com/api/v3.2/transactional/smartemail/#{SMART_EMAIL_ID}/send",
                :headers=>{
                    'Authorization'=>CM_AUTH
                },
                :body=>{
                    'To'=>[@email],
                    'CC'=>nil,
                    'BCC'=>nil,
                    'Attachments'=>[],
                    'Data'=>{
                        'manageLink'=>"https://cors.acl.org.au/unsubscribe?email=#{@email}&token=#{token}"
                    },
                    'AddRecipientsToList'=>false,
                    'ConsentToTrack'=>'Yes'
                }.to_json)
            @result = res.code
        end
        render json: {
            success: [200,201,202].include?(@result)
        }.to_json
    end

    def unsubscribe
        @email = params[:email]
        @token = params[:token]
        if Rails.env != "development" && Digest::SHA256.hexdigest(@email.downcase+':'+PREFERENCE_SECRET) != @token
            redirect_to "/404?reason=failedauth&email=#{@email}&token#{@token}&digest=#{Digest::SHA256.hexdigest(@email.downcase+':'+PREFERENCE_SECRET)}"
            return nil
        end
        if !@email.nil?
            signup_id = General.get_signup_id_from_email(@email)
            @unsubscribed = General.get_tags_from_person(signup_id).include?('7216')
        end
    end

    def unsubscribe_api
        @email = params[:email]
        @token = params[:token]
        if Rails.env != "development" && Digest::SHA256.hexdigest(@email.downcase+':'+PREFERENCE_SECRET) != @token
            render json: {success: false}.to_json, status: 400
            return nil
        end
        signup_id = General.get_signup_id_from_email(@email)
        if params[:unsubscribe]
            res = General.add_tags_to_person(signup_id, ['7216'])
            res.push(General.change_email_opt_in(signup_id, false))
        else
            res = General.remove_tags_from_person(signup_id, ['7216'])
            res.push(General.change_email_opt_in(signup_id, true))
        end
        render json: {
            success: res.map { |r| [200,201].include?(r) }.uniq[0]
        }.to_json
    end
end
