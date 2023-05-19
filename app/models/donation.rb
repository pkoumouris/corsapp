class Donation < ApplicationRecord

    belongs_to :recurring, optional: true

    xcrypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base[0..31])
    CLIENT_ID = Rails.env.production? ? ENV['NB_CLIENT_ID'] : xcrypt.decrypt_and_verify('SXN8u9vl0davLbNR4axO6/9BI+zvakizdFm7Ori3vT9ppGLKBTZbemrjGrGarvXSObKyxrs=--cgiPU7DgeAO+hztT--MKD/LgFOrtNdZsY1rPngpQ==')
    CLIENT_SECRET = Rails.env.production? ? ENV['NB_CLIENT_SECRET'] : xcrypt.decrypt_and_verify('tYpic0T4w9Wv/fP9Dvubjzj0qKCFPJ7nVRER0eEmGmQ8ki+sg1zECV+mc3e19LTUwSe/yxk=--5zbRz+cHjO1XLQtS--cLeCgMYQHjK38V7cLpyxlA==')
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

    def Donation.election_donations_email_sum(email, tracking_code, time_start)
        Donation.where(email: email, tracking_code: tracking_code, created_at: time_start..Time.now).map { |d| d.amount_in_cents }.sum
    end

    ###################### NationBuilder #####################
    def create_in_nationbuilder
        attrs = self.fill_in_tracking_code_id.nil? ? {
            "amount_in_cents"=>self.amount_in_cents,
            "email"=>self.email,
            "first_name"=>self.first_name,
            "last_name"=>self.last_name,
            "payment_type_id"=>"1"
        } : {
            "amount_in_cents"=>self.amount_in_cents,
            "email"=>self.email,
            "first_name"=>self.first_name,
            "last_name"=>self.last_name,
            "payment_type_id"=>"1",
            "donation_tracking_code_id"=>self.tracking_code
        }
        nb_resp = HTTParty.post("https://acl.nationbuilder.com/api/v2/donations",:body => {
                "data"=> {
                    "type" => "donations",
                    "attributes" => attrs
                }
            }.to_json, :headers => {
                'Content-Type'=>'application/json',
                'Accept'=>'application/json',
                'Authorization'=>'Bearer '+General.access_token
            })
        return nb_resp
    end

    def Donation.get_tracking_code_id(tracking_code_slug)
        resp = HTTParty.get("https://acl.nationbuilder.com/api/v2/donation_tracking_codes?filter[slug]=#{tracking_code_slug}",
            :headers=>{
                'Accept'=>'application/json',
                'Authorization'=>'Bearer '+General.access_token
            })
        if resp.code == 200
            return resp['data'][0]['id']
        else
            return nil
        end
    end

    def fill_in_tracking_code_id
        if !self.tracking_code.nil? || self.tracking_code_slug.nil?
            return nil
        end

        id = Donation.get_tracking_code_id(self.tracking_code_slug)
        if id.nil?
            return nil
        end
        self.update_attribute(:tracking_code, id)
        return true
    end

    ###################### SecurePay #########################
    SP_STATUSES = ['SP_SANDBOX_AUTH','SP_SANDBOX_APPLEPAY_AUTH','SP_LIVE_AUTH']
    SP_MC_STATUSES = ['SP_SANDBOX_MC','SP_SANDBOX_APPLEPAY_MC','SP_LIVE_MC']
    SP_LIVE = !(ENV['SP_STATUS_INDEX'].nil? || ENV['SP_STATUS_INDEX'].to_i != 2)
    SP_AUTH = ENV['SP_STATUS_INDEX'].nil? ? 'MG9heGI5aThQOXZRZFhUc24zbDU6MGFCc0dVM3gxYmMtVUlGX3ZEQkEySnpqcENQSGpvQ1A3b0k2amlzcA==' : ENV[SP_STATUSES[ENV['SP_STATUS_INDEX'].to_i]]
    SP_MERCHANT_CODE = ENV['SP_STATUS_INDEX'].nil? ? '5AR0055' : ENV[SP_MC_STATUSES[ENV['SP_STATUS_INDEX'].to_i]]

    def Donation.securepay_auth ## what is this vv is this correct link??
        response = HTTParty.post(SP_LIVE ? "https://payments.auspost.net.au/oauth/token" : "https://welcome.api2.sandbox.auspost.com.au/oauth/token",
            :body => {
                'grant_type'=>'client_credentials',
                'audience'=>'https://api.payments.auspost.com.au'
            }.to_json,
            :headers => {
                'Content-Type'=>'application/x-www-form-urlencoded',
                'Accept'=>'application/json',
                'Authorization'=>'Basic '+SP_AUTH
            })
        if response.code == 200
            General.save_sp_access_token(response['access_token'], response['expires_in'])
            return response
        else
            puts response.code
            puts SP_AUTH
            raise "Unsuccessful access token for SecurePay."
        end
    end

    def Donation.make_payment(amount, token, ip)
        order_id = SecureRandom.uuid
        idem_key = SecureRandom.uuid
        puts "Merchant code: "+SP_MERCHANT_CODE
        response = HTTParty.post(SP_LIVE ? "https://payments.auspost.net.au/v2/payments" : "https://payments-stest.npe.auspost.zone/v2/payments",
            :body => {
                'amount'=>amount,
                'merchantCode'=>SP_MERCHANT_CODE,
                'token'=>token,
                'ip'=>ip,
                'orderId'=>order_id
            }.to_json,
            :headers => {
                'Content-Type'=>'application/json',
                'Idempotency-Key'=>idem_key,
                'Authorization'=>'Bearer '+General.sp_access_token
            })
        if response.code != 200 && response.code != 201
            puts "The following response code was found: " + response.code.to_s
            puts response
            raise "Not successful"
        end
        if ['00','11','77','16'].include?(response['gatewayResponseCode'])
            donation = Donation.new(amount_in_cents: amount, gateway_response_code: '00', success: true, currency: 'AUD', recurring: false, order_spid: response['orderId'], bank_transaction_spid: response['bankTransactionId'])
            return donation
        end
        donation = Donation.new(amount_in_cents: amount, gateway_response_code: response['gatewayResponseCode'], success: false, currency: 'AUD', recurring: false, order_spid: response['orderId'], bank_transaction_spid: response['bankTransactionId'])
        return donation
    end

    def fill_out_params(params)
        begin
            self.email = params[:email]
            self.amount_in_cents = params[:amount]
            self.first_name = params[:first_name]
            self.last_name = params[:last_name]
            self.address = params[:address]
            self.gnaf_address_identifier = params[:gnaf_address_id]
            self.phone_number = params[:phone_number]
            self.send_email_updates = params[:send_email_updates]
            self.recurring = params[:recurring]
            self.tracking_code_slug = params[:tracking_code]
            self.save
        rescue
            return nil
        end
    end

    def Donation.response_code_message(response_code)
        {
            '00'=>'Approved or completed successfully.',
            '01'=>'Refer to card issuer.',
            '02'=>'Refer to card issuers special conditions',
            '03'=>'Invalid merchant.',
            '04'=>'Pick-up card.',
            '05'=>'Do not honour.',
            '06'=>'Error',
            '07'=>'Pick-up card, special condition',
            '08'=>'Honor with identification.',
            '09'=>'Request in progress',
            '10'=>'Approved for partial amount',
            '11'=>'Approved VIP',
            '12'=>'Invalid transaction.',
            '13'=>'Invalid amount',
            '14'=>'Invalid card number (no such number).',
            '15'=>'No such issuer',
            '16'=>'Approved, update Track 3',
            '17'=>'Customer cancellation.',
            '18'=>'Customer dispute',
            '19'=>'Re-enter transaction',
            '20'=>'Invalid response',
            '21'=>'No action taken',
            '22'=>'Suspected malfunction.',
            '23'=>'Unacceptable transaction fee',
            '24'=>'File update not supported by receiver',
            '25'=>'Unable to locate record on file',
            '26'=>'Duplicate file update record, old record replaced',
            '27'=>'File update field edit error',
            '28'=>'File update file locked out',
            '29'=>'File update not successful, contact acquirer',
            '30'=>'Format error',
            '31'=>'Bank not supported by switch',
            '32'=>'Completed partially',
            '33'=>'Expired card',
            '34'=>'Suspected fraud.',
            '35'=>'Card acceptor contact acquirer',
            '36'=>'Restricted card',
            '37'=>'Card acceptor call acquirer security',
            '38'=>'Allowable PIN tries exceeded',
            '39'=>'No credit account',
            '40'=>'Request function not supported',
            '41'=>'Lost card',
            '42'=>'No universal account.',
            '43'=>'Stolen card, pick up',
            '44'=>'No investment account',
            '51'=>'Not sufficient funds',
            '52'=>'No cheque account',
            '53'=>'No savings account',
            '54'=>'Expired card.',
            '55'=>'Incorrect PIN',
            '56'=>'No card record',
            '57'=>'Transaction not permitted to cardholder',
            '58'=>'Transaction not permitted to terminal',
            '59'=>'Suspected fraud','60'=>'Card acceptor contact acquirer',
            '61'=>'Exceeds withdrawal amount limits.',
            '62'=>'Restricted card',
            '63'=>'Security violation',
            '64'=>'Original amount incorrect',
            '65'=>'Exceeds withdrawal frequency limit',
            '66'=>'Card acceptor call acquirers security department',
            '67'=>'Hard capture (requires that card be picked up at ATM)',
            '68'=>'Response received too late',
            '75'=>'Allowable number of PIN tries exceeded',
            '79'=>'Reserved for private use.',
            '90'=>'Cutoff is in process.',
            '91'=>'Issuer or switch is inoperative.',
            '92'=>'Financial institution or intermediate network facility cannot be found for routing',
            '93'=>'Transaction cannot be completed. Violation of law',
            '94'=>'Duplicate transmission',
            '95'=>'Reconcile error',
            '96'=>'System malfunction',
            '97'=>'Advises that reconciliation totals have been reset',
            '98'=>'MAC error',
            '99'=>'Reserved for national use'
        }[response_code]
    end
end
