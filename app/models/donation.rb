class Donation < ApplicationRecord

    belongs_to :recurring, optional: true

    xcrypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base[0..31])
    CLIENT_ID = Rails.env.production? ? ENV['NB_CLIENT_ID'] : xcrypt.decrypt_and_verify('SXN8u9vl0davLbNR4axO6/9BI+zvakizdFm7Ori3vT9ppGLKBTZbemrjGrGarvXSObKyxrs=--cgiPU7DgeAO+hztT--MKD/LgFOrtNdZsY1rPngpQ==')
    CLIENT_SECRET = Rails.env.production? ? ENV['NB_CLIENT_SECRET'] : xcrypt.decrypt_and_verify('tYpic0T4w9Wv/fP9Dvubjzj0qKCFPJ7nVRER0eEmGmQ8ki+sg1zECV+mc3e19LTUwSe/yxk=--5zbRz+cHjO1XLQtS--cLeCgMYQHjK38V7cLpyxlA==')
    GNAF_API_KEY = Rails.env.production? ? ENV['GNAF_API_KEY'] : xcrypt.decrypt_and_verify('DzPxfwqMGdAJBZf/giRZ4T1Mh/+/+dMoZtwzghLnACHDsUXWwomtWpj2--xz/qcV5RyUAp65aO--/n5DGBlEJPp5P1MaBRjSoA==')
    REDIRECT_URI = Rails.env.production? ? "https://cors.acl.org.au/nb_oauth_callback/" : "http://localhost:3000/nb_oauth_callback/"
    SITE_PATH = 'https://acl.nationbuilder.com'
    RECURRING_SLUG = "ov_w_monthly_sp"
    RECURRING_ID = "3564"
    RECURRING_TAG_ID = "2556"

    WEM_DONATION_URL = Rails.env.production? ? "https://aclportal.live.wemapac.io/webservices/securepay/recordPayment" : "https://aclportal.staging.wemapac.io/webservices/securepay/recordPayment"
    #WEM_DONATION_URL = "https://preview.wem.io/38864/webservices/securepay/recordPayment"#"https://aclportal.staging.wemapac.io/webservices/securepay/recordPayment"
    WEM_DONATION_TOKEN = Rails.env.production? ? ENV['WEM_DONATION_TOKEN'] : xcrypt.decrypt_and_verify('dVtlxJuuVfXjwJODrdhU6pv5Rvth71FNO30PYLsIf+bC9kJ/4issjJvh--yJBG4mmU5xtaWidl--z9xjASJbJ1L1KAp5jLGdhg==')
    
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

    ########################### WEM ##########################
    def create_in_wem(send_email_updates)
        puts WEM_DONATION_TOKEN
        puts WEM_DONATION_URL
        response = HTTParty.post(WEM_DONATION_URL,
            :headers => {"Content-Type" => "application/json"},
            :body => {
                'Donation Amount'=>self.amount_in_cents,
                'Donation Tracking Code'=>self.tracking_code_slug,
                'Email Address'=>self.email,
                'Donor First Name'=>self.first_name,
                'Donor Last Name'=>self.last_name,
                'Donor Address'=>self.address,
                'Donor GNAF ID'=>self.gnaf_address_identifier,
                'SP Response Code'=>self.gateway_response_code,
                'SP Order ID'=>self.order_spid,
                'SP Bank Transaction ID'=>self.bank_transaction_spid,
                'Donation Server Token'=>WEM_DONATION_TOKEN,
                'Donor Mobile Phone'=>self.phone_number,
                'Recurring Transaction'=>self.is_recurring,
                'SP Recurring ID'=>self.recurring.nil? ? nil : self.recurring.schedule_spid,
                'Donation Designation'=>'General Giving',
                'Page Slug'=>self.page_slug,
                'Include Email Updates'=>!!send_email_updates
        }.to_json)
        return response
    end

    ###################### NationBuilder #####################
    def Donation.gnaf_to_billing_address(gnaf_id) ## Test this!
        response = HTTParty.get("https://api.psma.com.au/v2/addresses/address/#{gnaf_id}",
            :headers => {"Authorization"=>GNAF_API_KEY}) #ENV['GNAF_API_KEY']
        if response.code != 200 || response['properties'].nil?
            return response
        end
        return {
            "city"=>response['properties']['localityName'],
            "zip"=>response['properties']['postcode'],
            "state"=>response['properties']['stateTerritory'],
            "country_code"=>"AU",
            "lat"=>response['geometry']['coordinates'][1].to_s,
            "lng"=>response['geometry']['coordinates'][0].to_s,
            "street_number"=>response['properties']['streetNumber1'],
            "street_type"=>response['properties']['streetType'],
            "street_name"=>response['properties']['streetName'],
            "unit_number"=>response['properties']['complexUnitNumber']
        }
    end

    def update_nb_with_tracking_code
        if self.tracking_code.nil?
            return nil
        end
        nb_resp = HTTParty.put("https://acl.nationbuilder.com/api/v2/donations/#{self.nbid}",:body => {
            "data"=>{
                "type"=>"donations",
                "id"=>self.nbid,
                "attributes"=>{
                    "donation_tracking_code_id"=>self.tracking_code
                }
            }
        }.to_json,:headers => {
            'Content-Type'=>'application/json',
            'Accept'=>'application/json',
            'Authorization'=>'Bearer '+General.access_token
        })
    end

    def create_in_nationbuilder_with_address
        if self.gnaf_address_identifier.nil? || self.gnaf_address_identifier.length < 2 || self.gnaf_address_identifier[0..1] == "MA"
            #addr_attrs = {"city"=>"","zip"=>"","state"=>"","country_code"=>"AU","lat"=>"","lng"=>"","street_number"=>"","street_type"=>"","street_name"=>"","unit_number"=>""}
            return self.create_in_nationbuilder
        else
            addr_attrs = Donation.gnaf_to_billing_address(self.gnaf_address_identifier)
        end
        puts addr_attrs
        attrs = self.fill_in_tracking_code_id.nil? ? {
            "amount_in_cents"=>self.amount_in_cents,
            "email"=>self.email,
            "first_name"=>self.first_name,
            "last_name"=>self.last_name,
            "payment_type_id"=>"2",
            "donation_tracking_code_id"=>self.tracking_code.nil? ? "3493" : self.tracking_code,
            "note"=>self.order_spid
        } : {
            "amount_in_cents"=>self.amount_in_cents,
            "email"=>self.email,
            "first_name"=>self.first_name,
            "last_name"=>self.last_name,
            "payment_type_id"=>"2",
            "donation_tracking_code_id"=>self.tracking_code,
            "note"=>self.order_spid
        }
        nb_resp = HTTParty.post("https://acl.nationbuilder.com/api/v2/donations",:body => {
                "data"=> {
                    "type" => "donations",
                    "attributes" => attrs,
                    "relationships"=>{
                        "billing_address"=>{
                            "data"=>{
                                "type"=>"billing_address",
                                "temp-id"=>"tempid-1234",
                                "method"=>"create"
                            }
                        }
                    }
                },
                "included"=>[
                    {
                        "type"=>"billing_address",
                        "temp-id"=>"tempid-1234",
                        "attributes"=>addr_attrs
                    }
                ]
            }.to_json, :headers => {
                'Content-Type'=>'application/json',
                'Accept'=>'application/json',
                'Authorization'=>'Bearer '+General.access_token
            })
        if (nb_resp.code == 201 || nb_resp.code == 200) && !nb_resp['data'].nil?
            self.update_attribute(:nbid,nb_resp['data']['id'])
            self.update_attribute(:signup_nbid,nb_resp['data']['attributes']['signup_id'])
            self.update_signup
        end
        return nb_resp
    end

    def create_in_nationbuilder
        attrs = self.fill_in_tracking_code_id.nil? ? {
            "amount_in_cents"=>self.amount_in_cents,
            "email"=>self.email,
            "first_name"=>self.first_name,
            "last_name"=>self.last_name,
            "payment_type_id"=>"2",
            "donation_tracking_code_id"=>self.tracking_code.nil? ? "3493" : self.tracking_code,
            "note"=>self.order_spid
        } : {
            "amount_in_cents"=>self.amount_in_cents,
            "email"=>self.email,
            "first_name"=>self.first_name,
            "last_name"=>self.last_name,
            "payment_type_id"=>"2",
            "donation_tracking_code_id"=>self.tracking_code,
            "note"=>self.order_spid
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
        if self.is_recurring
            begin
                puts "Here in the add_tag part"
                suid = nb_resp['data']['relationships']['recruiter']['links']['related'].split('/').last
                resp2 = Donation.add_tag_to_person(suid, RECURRING_TAG_ID)
                if !resp2.nil?
                    self.update_attribute(:other_data, resp2.code.to_s)
                end
            rescue
                puts "Aw schucks, couldn't add the tag"
            end
        end
        if (nb_resp.code == 201 || nb_resp.code == 200) && !nb_resp['data'].nil?
            self.update_attribute(:nbid,nb_resp['data']['id'])
            self.update_attribute(:signup_nbid,nb_resp['data']['attributes']['signup_id'])
            self.update_signup
        end
        return nb_resp
    end

    def Donation.get_tracking_code_id(tracking_code_slug)
        resp = HTTParty.get("https://acl.nationbuilder.com/api/v2/donation_tracking_codes?filter[slug]=#{tracking_code_slug}",
            :headers=>{
                'Accept'=>'application/json',
                'Authorization'=>'Bearer '+General.access_token
            })
        if resp.code == 200
            return resp['data'].length == 0 ? nil : resp['data'][0]['id']
        else
            return nil
        end
    end

    def update_signup
        resp = HTTParty.patch("https://acl.nationbuilder.com/api/v2/signups/#{self.signup_nbid}",
            :body=>{
                'data'=>{
                    'id'=>self.signup_nbid,
                    'type'=>'signups',
                    'attributes'=>{
                        'email_opt_in'=>!!self.send_email_updates
                    }
                }
            }.to_json,
            :headers=>{
                'Content-Type'=>'application/json',
                'Accept'=>'application/json',
                'Authorization'=>'Bearer '+General.access_token
            })
        return resp.code == 200 || resp.code == 201
    end

    def fill_in_tracking_code_id
        if !self.tracking_code.nil? || self.tracking_code_slug.nil?
            return nil
        end
        if self.is_recurring
            id = RECURRING_ID
        else
            id = Donation.get_tracking_code_id(self.tracking_code_slug)
            if id.nil?
                return nil
            end
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

    def Donation.securepay_auth(sp_env) # SP env toggle
        response = HTTParty.post(sp_env == "LIVE" ? "https://welcome.api2.auspost.com.au/oauth/token" : "https://welcome.api2.sandbox.auspost.com.au/oauth/token",
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
            if sp_env == "LIVE"
                General.save_sp_access_token(response['access_token'], response['expires_in'])
            else
                General.save_sandbox_sp_access_token(response['access_token'], response['expires_in'])
            end
            return response
        else
            puts response.code
            puts SP_AUTH
            raise "Unsuccessful access token for SecurePay."
        end
    end

    # In test
    def Donation.make_payment_with_details(amount, token, ip, email, sp_env)
        order_id = SecureRandom.uuid
        idem_key = SecureRandom.uuid
        response = HTTParty.post(SP_LIVE && sp_env == "LIVE" ? "https://payments.auspost.net.au/v2/payments" : "https://payments-stest.npe.auspost.zone/v2/payments",
            :body => {
                'amount'=>amount,
                'merchantCode'=>SP_LIVE && sp_env == "LIVE" ? SP_MERCHANT_CODE : "5AR0055",
                'token'=>token,
                'ip'=>ip,
                'orderId'=>order_id,
                'fraudCheckDetails'=>{
                    'fraudCheckType'=>'FRAUD_GUARD',
                    'customerDetails'=>{
                        'emailAddress'=>email
                    }
                }
            }.to_json,
            :headers => {
                'Content-Type'=>'application/json',
                'Idempotency-Key'=>idem_key,
                'Authorization'=>'Bearer '+General.sp_access_token(sp_env)
            })
        if response.code != 200 && response.code != 201
            puts "The following response code was found: " + response.code.to_s
            puts response
            raise "Not successful"
        end
        if ['00','08','11','77','16'].include?(response['gatewayResponseCode'])
            donation = Donation.new(amount_in_cents: amount, gateway_response_code: '00', success: true, currency: 'AUD', order_spid: response['orderId'], bank_transaction_spid: response['bankTransactionId'], test: sp_env != "LIVE")
            return donation
        end
        donation = Donation.new(amount_in_cents: amount, gateway_response_code: response['gatewayResponseCode'], success: false, currency: 'AUD', order_spid: response['orderId'], bank_transaction_spid: response['bankTransactionId'], test: sp_env != "LIVE")
        return donation
    end

    def Donation.make_payment(amount, token, ip, sp_env) # SP env toggle
        order_id = SecureRandom.uuid
        idem_key = SecureRandom.uuid
        #puts "Merchant code: "+SP_MERCHANT_CODE
        response = HTTParty.post(SP_LIVE && sp_env == "LIVE" ? "https://payments.auspost.net.au/v2/payments" : "https://payments-stest.npe.auspost.zone/v2/payments",
            :body => {
                'amount'=>amount,
                'merchantCode'=>SP_LIVE && sp_env == "LIVE" ? SP_MERCHANT_CODE : "5AR0055",
                'token'=>token,
                'ip'=>ip,
                'orderId'=>order_id
            }.to_json,
            :headers => {
                'Content-Type'=>'application/json',
                'Idempotency-Key'=>idem_key,
                'Authorization'=>'Bearer '+General.sp_access_token(sp_env)
            })
        if response.code != 200 && response.code != 201
            puts "The following response code was found: " + response.code.to_s
            puts response
            raise "Not successful"
        end
        if ['00','08','11','77','16'].include?(response['gatewayResponseCode'])
            donation = Donation.new(amount_in_cents: amount, gateway_response_code: '00', success: true, currency: 'AUD', order_spid: response['orderId'], bank_transaction_spid: response['bankTransactionId'], test: sp_env != "LIVE")
            return donation
        end
        donation = Donation.new(amount_in_cents: amount, gateway_response_code: response['gatewayResponseCode'], success: false, currency: 'AUD', order_spid: response['orderId'], bank_transaction_spid: response['bankTransactionId'], test: sp_env != "LIVE")
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
            self.is_recurring = params[:recurring]
            self.tracking_code_slug = self.is_recurring ? RECURRING_SLUG : params[:tracking_code]
            self.is_subsequent_recurring = false
            self.executed_at = Time.now
            self.save
        rescue
            return nil
        end
    end

    def Donation.recurring_slug
        RECURRING_SLUG
    end

    def refund_payment(sp_env)
        sp_resp = HTTParty.post(SP_LIVE && sp_env == "LIVE" ? "https://payments.auspost.net.au/v2/orders/#{self.order_spid}/refunds" : "https://payments-stest.npe.auspost.zone/v2/orders/#{self.order_spid}/refunds",
            :body => {
                'amount'=>self.amount_in_cents,
                'merchantCode'=>SP_LIVE && sp_env == "LIVE" ? SP_MERCHANT_CODE : "5AR0055",
                'ip'=>self.origin_ip.nil? ? "127.0.0.1" : self.origin_ip
            }.to_json,
            :headers => {
                'Content-Type'=>'application/json',
                'Authorization'=>'Bearer '+General.sp_access_token(sp_env)
            })
        return sp_resp
    end

    def set_nb_donation_as_refunded
        attrs = {
            "canceled_at" => Time.now.in_time_zone("GMT").rfc3339
            #"first_name" => "Yetanother"
        }
        nb_resp = HTTParty.patch("https://acl.nationbuilder.com/api/v2/donations/#{self.nbid.to_s}",:body => {
            "data"=> {
                "id" => self.nbid.to_s,
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

    #def update_nb_user_address
    #end

    def Donation.get_env_var_stubs
        return {
            nb_client_id: CLIENT_ID[0..4],
            nb_client_secret: CLIENT_SECRET[0..4],
            sp_status: SP_STATUSES[ENV['SP_STATUS_INDEX'].to_i],
            sp_live: SP_LIVE,
            sp_auth: SP_AUTH[0..4],
            sp_merchant_code: SP_MERCHANT_CODE,
            nb_access_token: General.access_token[0..6],
            nb_refresh_token: General.refresh_token[0..6],
            nb_access_token_expiry: Time.at(General.find_by(name:"NB_EXPIRES_AT").value.to_i).in_time_zone('Australia/Melbourne').rfc2822
        }
    end

    def Donation.add_tag_to_person(person_id, tag_id)
        response = HTTParty.post("https://acl.nationbuilder.com/api/v2/signup_taggings",
            :body => {
                'data'=>{
                    'type'=>'signup_taggings',
                    'attributes'=>{
                        'signup_id'=>person_id,
                        'tag_id'=>tag_id
                    }
                }
            }.to_json,
            :headers => {
                'Content-Type'=>'application/json',
                'Accept'=>'application/json',
                'Authorization'=>'Bearer '+General.access_token
            })
        puts "Add tag to person response code: #{response.code.to_s}"
        puts "Add tag to person ID: #{response.code == 201 ? response['data']['id'] : nil}"
        return response
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

    #### ANCILLARY METHODS
    def rectify_payment_method_type
        response = HTTParty.put("https://acl.nationbuilder.com/api/v1/donations/#{self.nbid}",
            :body => {
                'donation'=>{
                    'payment_type'=>'Credit/Debit Card'
                }
            }.to_json,
            :headers => {
                'Content-Type'=>'application/json',
                'Accept'=>'application/json',
                'Authorization'=>'Bearer '+General.access_token
            })
        return response
    end

    def delete_in_nationbuilder
        response = HTTParty.delete("https://acl.nationbuilder.com/api/v2/donations/#{self.nbid}",
            :headers => {
                'Content-Type'=>'application/json',
                'Accept'=>'application/json',
                'Authorization'=>'Bearer '+General.access_token
            })
        return response
    end
end
