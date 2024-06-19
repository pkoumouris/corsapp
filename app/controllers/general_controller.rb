class GeneralController < ApplicationController
    RECURRING_SLUG = "ov_w_monthly_sp"
    SP_LIVE = !(ENV['SP_STATUS_INDEX'].nil? || ENV['SP_STATUS_INDEX'].to_i != 2)
    skip_forgery_protection

    def test
        render json: {
            success: true
        }.to_json
    end

    def see_env_var_stubs
        if Digest::SHA256.hexdigest(params[:token]) == 'a79cd472a5ed551a9453f3cb4b3ec789b0a4a8ca5e0528fa71b70c0c188a6c55'
            render json: {
                var_stubs: Donation.get_env_var_stubs
            }.to_json
        else
            render json: {
                success: false
            }.to_json, status: 401
        end
    end

    def gnaf
        response = HTTParty.get("https://api.psma.com.au/v2/addresses/geocoder?additionalProperties=localGovernmentArea,stateElectorate,commonwealthElectorate,asgsMain&address=#{params[:address]}",
            :headers => {"Authorization"=>ENV['GNAF_API_KEY']})
        puts response
        render json: response.to_json
    end

    def apple_pay_initiate_session
        response = HTTParty.post("https://preview.wem.io/38864/webservices/securepay/applePayInitiateSession",
            :body=>{"Requestor IP Address"=>request.remote_ip}.to_json,
            :headers=>{
                'Content-Type'=>'application/json'
            })
        render json: {
            response: response['Apple Pay Initiate Session Output']
        }.to_json
    end

    def apple_pay_wem_payment
    end

    def securepay_payment
        #### START UNIQUE LOGIC
        sp_env = "LIVE"
        #### END UNIQUE LOGIC
        # 0. Check if it violates election law
        if false && params[:election_related] && (Donation.election_donations_email_sum(params[:email], params[:tracking_code], 9.months.ago) + params[:amount] > params[:election_total_donation_limit]*100 || params[:amount] > params[:election_single_donation_limit]*100)
            render json: {
                success: false,
                recoverable: true,
                acl_error_code: 811,
                errors: ["Election law violation: can only have a maximum AUD #{params[:election_single_donation_limit]} donation for a single donation and AUD #{params[:election_total_donation_limit]} total donations for an election cycle."]
            }.to_json, status: 200
            return nil
        end
        # 1. Make the payment
        #sp_env = (params[:env] == "SANDBOX" && Digest::SHA256.base64digest(params[:env_token]) == "vg1aJVAe9FZfITG9YptD9LIh4VUa7YQcCocxlL9NUyY=") || !SP_LIVE ? "SANDBOX" : "LIVE"
        donation = Donation.make_payment(params[:amount].to_i, params[:token], request.remote_ip, sp_env)
        #donation = Donation.make_payment_with_details(params[:amount], params[:token], request.remote_ip, params[:email], sp_env)
        if !donation.success
            donation.save
            render json: {
                success: false,
                recoverable: true,
                acl_error_code: 801,
                errors: ["#{Donation.response_code_message(donation.gateway_response_code.to_s)}"]
            }.to_json, status: 200
            return nil
        end
        donation.fill_out_params(params)
        # 2. Make the recurring schedule (if applicable)
        recurring = nil
        if params[:recurring]
            donation.update_attribute(:is_recurring, true) # this is a bit dirty but better safe than sorry
            donation.update_attribute(:tracking_code_slug, Donation.recurring_slug) # dirty
            begin
                recurring = Recurring.make_recurring_payment(params[:amount].to_i, params[:token], request.remote_ip, sp_env)
            rescue
                # Here's a really tricky situation - send an email
                render json: {
                    success: true,
                    recoverable: false,
                    acl_error_code: 802,
                    errors: ["Could not successfully execute recurring payment. Singular payment successful."]
                }.to_json, status: 201
                return nil
            end
            donation.update_attribute(:recurring_id, recurring.id)
        end
        # 3. Handle external errors
        save_failure = donation.id.nil? || (!recurring.nil? && recurring.id.nil?)
        wem_failure = false # will change as time goes on
        nb_failure = false # will change as time goes on
        # 3a. Make the calls to NB
        if false && (donation.gnaf_address_identifier.nil? || donation.gnaf_address_identifier.length < 3 || donation.gnaf_address_identifier[0..1] == "MA")
            nb_resp = donation.create_in_nationbuilder
        else
            nb_resp = donation.create_in_nationbuilder_with_address
            if nb_resp.code != 201
                nb_resp = donation.create_in_nationbuilder
            end
        end
        #puts nb_resp
        nb_failure = (nb_resp.code != 201)
        if !nb_failure
            donation.update_attribute(:nbid, nb_resp['data']['id'])
        end
        if save_failure || wem_failure || nb_failure
            render json: {
                success: true,
                recoverable: false,
                acl_error_code: General.failure_error_code(nb_failure, wem_failure, save_failure),
                errors: [nb_failure ? "Could not save to NationBuilder." : nil, wem_failure ? "Could not save to WEM." : nil, save_failure ? "Could not save to CORS database." : nil].compact
            }.to_json, status: 201
            return nil
        end
        # 3b. Make calls to WEM
        wem_resp = donation.create_in_wem(params[:send_email_updates])
        if wem_resp.code == 200 && !!wem_resp['Record Payment Success']
            donation.imported_to_nb = true
            donation.imported_to_nb_at = Time.now
        else
            donation.imported_to_nb = false
            donation.other_data = "Could not create in WEM."
        end
        donation.save
        # 4. Return success
        if params[:recurring]
            render json: {
                success: true,
                amount_in_cents: donation.amount_in_cents,
                orderId: donation.order_spid,
                nb_donation_id: donation.nbid,
                scheduleId: recurring.schedule_spid,
                customerId: recurring.customer_code
            }.to_json, status: 201
        else
            render json: {
                success: true,
                orderId: donation.order_spid,
                nb_donation_id: donation.nbid,
                amount_in_cents: donation.amount_in_cents
            }.to_json, status: 201
        end
    end

    def securepay_sandbox_payment
        #### START UNIQUE LOGIC
        if Digest::SHA256.base64digest(params[:env_token]) != "vg1aJVAe9FZfITG9YptD9LIh4VUa7YQcCocxlL9NUyY="
            render json: {message:"WRONG TOKEN"}.to_json, status: 400
            return nil
        end
        sp_env = "SANDBOX"
        #### END UNIQUE LOGIC

        # 0. Check if it violates election law
        if params[:election_related] && (Donation.election_donations_email_sum(params[:email], params[:tracking_code], 9.months.ago) + params[:amount] > params[:election_total_donation_limit]*100 || params[:amount] > params[:election_single_donation_limit]*100)
            render json: {
                success: false,
                recoverable: true,
                acl_error_code: 811,
                errors: ["Election law violation: can only have a maximum AUD #{params[:election_single_donation_limit]} donation for a single donation and AUD #{params[:election_total_donation_limit]} total donations for an election cycle."]
            }.to_json, status: 200
            return nil
        end
        # 1. Make the payment
        #sp_env = (params[:env] == "SANDBOX" && Digest::SHA256.base64digest(params[:env_token]) == "vg1aJVAe9FZfITG9YptD9LIh4VUa7YQcCocxlL9NUyY=") || !SP_LIVE ? "SANDBOX" : "LIVE"
        donation = Donation.make_payment(params[:amount].to_i, params[:token], request.remote_ip, sp_env)
        if !donation.success
            donation.fill_out_params(params)
            render json: {
                success: false,
                recoverable: true,
                acl_error_code: 801,
                errors: ["#{Donation.response_code_message(donation.gateway_response_code.to_s)}"]
            }.to_json, status: 200
            return nil
        end
        donation.fill_out_params(params)
        # 2. Make the recurring schedule (if applicable)
        recurring = nil
        if params[:recurring]
            donation.update_attribute(:is_recurring, true) # this is a bit dirty but better safe than sorry
            donation.update_attribute(:tracking_code_slug, Donation.recurring_slug) # dirty
            begin
                recurring = Recurring.make_recurring_payment(params[:amount].to_i, params[:token], request.remote_ip, sp_env)
            rescue
                # Here's a really tricky situation - send an email
                render json: {
                    success: true,
                    recoverable: false,
                    acl_error_code: 802,
                    errors: ["Could not successfully execute recurring payment. Singular payment successful."]
                }.to_json, status: 201
                return nil
            end
            donation.update_attribute(:recurring_id, recurring.id)
        end
        # 3. Handle external errors
        save_failure = donation.id.nil? || (!recurring.nil? && recurring.id.nil?)
        wem_failure = false # will change as time goes on
        nb_failure = false # will change as time goes on
        # 3a. Make the calls to NB
        if donation.gnaf_address_identifier.nil? || donation.gnaf_address_identifier.length < 3 || donation.gnaf_address_identifier[0..1] == "MA"
            nb_resp = donation.create_in_nationbuilder
        else
            nb_resp = donation.create_in_nationbuilder_with_address
            if nb_resp.code != 201
                nb_resp = donation.create_in_nationbuilder
            end
        end
        puts nb_resp
        nb_failure = (nb_resp.code != 201)
        if !nb_failure
            donation.update_attribute(:nbid, nb_resp['data']['id'])
        end
        if save_failure || wem_failure || nb_failure
            render json: {
                success: true,
                recoverable: false,
                acl_error_code: General.failure_error_code(nb_failure, wem_failure, save_failure),
                errors: [nb_failure ? "Could not save to NationBuilder." : nil, wem_failure ? "Could not save to WEM." : nil, save_failure ? "Could not save to CORS database." : nil].compact
            }.to_json, status: 201
            return nil
        end
        # 4. Return success
        if params[:recurring]
            render json: {
                success: true,
                amount_in_cents: donation.amount_in_cents,
                orderId: donation.order_spid,
                nb_donation_id: donation.nbid,
                scheduleId: recurring.schedule_spid,
                customerId: recurring.customer_code
            }.to_json, status: 201
        else
            render json: {
                success: true,
                orderId: donation.order_spid,
                nb_donation_id: donation.nbid,
                amount_in_cents: donation.amount_in_cents
            }.to_json, status: 201
        end
    end

    def wem_payment
        render plain: {error: "Not allowed."}.to_json, status: 400
        return nil
        response = HTTParty.post(params[:tgt_url],
            :body => params[:tgt_body].to_json,
            :headers => {
                'Content-Type'=>'application/json',
                'Accept'=>'application/json'
            })
        #HTTParty.post("https://acl.nationbuilder.com/api/v2/donations")
        if response["Secure Pay Success"]
            nb_resp = HTTParty.post("https://acl.nationbuilder.com/api/v2/donations",:body => {
                "data"=> {
                    "type" => "donations",
                    "attributes" => {
                        "amount_in_cents"=>params[:tgt_body]["SecurePay Amount".to_sym]*100,
                        "email"=>params[:tgt_body]["SecurePay Email".to_sym],
                        "first_name"=>params[:tgt_body]["SecurePay Firstname".to_sym],
                        "last_name"=>params[:tgt_body]["SecurePay Lastname".to_sym],
                        "payment_type_id"=>"1",
                        "tracking_code_id"=>params[:tgt_body]["Nation Builder Tracking ID".to_sym]
                    }
                }
            }.to_json, :headers => {
                'Content-Type'=>'application/json',
                'Accept'=>'application/json',
                'Authorization'=>ENV['NB_TEST_TOKEN']
            })
            render json: {
                success: true,
                response: response,
                nb_resp: nb_resp
            }.to_json
        else
            render json: {
                success: false,
                response: response
            }.to_json
        end
        #nb_resp = JSON.parse(response["NB Donation Response"])
        #puts nb_resp
        #render json: response.to_json
    end

    def refund
        #### START UNIQUE LOGIC
        sp_env = "LIVE"
        #### END UNIQUE LOGIC
        if !logged_in?
            render plain: {error: "Forbidden."}.to_json, status: 400
            return nil
        end
        donation = Donation.find_by(id: params[:id].to_i)
        sp_resp = donation.refund_payment(sp_env)
        if sp_resp.code != 201
            render json: {
                sp_success: false,
                nb_success: false
            }.to_json
            return nil
        end
        donation.update_attribute(:refunded, true)
        donation.update_attribute(:refunded_at, Time.now)
        nb_resp = donation.set_nb_donation_as_refunded
        if sp_resp.code == 201 || nb_resp.code == 200
            render json: {
                sp_success: true,
                nb_success: true
            }.to_json
        else
            render json: {
                sp_success: true,
                nb_success: false
            }.to_json
        end
    end

    def sandbox_refund
        #### START UNIQUE LOGIC
        if Digest::SHA256.base64digest(params[:env_token]) != "vg1aJVAe9FZfITG9YptD9LIh4VUa7YQcCocxlL9NUyY="
            puts "Wrong token"
            render plain: {error:"WRONG TOKEN"}.to_json, status: 400
            return nil
        end
        sp_env = "SANDBOX"
        #### END UNIQUE LOGIC
        if !logged_in?
            render plain: {error: "Forbidden."}.to_json, status: 400
            return nil
        end
        donation = Donation.find_by(id: params[:id].to_i)
        sp_resp = donation.refund_payment(sp_env)
        if sp_resp.code != 201
            render json: {
                sp_success: false,
                nb_success: false
            }.to_json
            return nil
        end
        donation.update_attribute(:refunded, true)
        donation.update_attribute(:refunded_at, Time.now)
        nb_resp = donation.set_nb_donation_as_refunded
        if sp_resp.code == 201 || nb_resp.code == 200
            render json: {
                sp_success: true,
                nb_success: true
            }.to_json
        else
            render json: {
                sp_success: true,
                nb_success: false
            }.to_json
        end
    end

    def get_campaigns
        response = HTTParty.post("https://preview.wem.io/38864/webservices/securepay/getCampaigns",
            :body => {}.to_json,
            :headers => {
                'Content-Type'=>'application/json',
                'Accept'=>'application/json'
            })
        render json: response.to_json
    end

    def reconcile_recurring
        if Digest::SHA256.base64digest(params[:token]) != 'BFv0+H1LOCKZgzFXBCkbtVBEs2QId8jqPMW/NhU2jIo='
            render plain: {error:"WRONG TOKEN"}.to_json, status: 400
            return nil
        end
        fail_list = []
        params[:transactions].each do |t|
            recurring = Recurring.find_by(schedule_spid:t[:client_id])
            if recurring.nil?
                fail_list.push({:transaction => t, :message => "A recurring object could not be found for that transaction."})
            else
                original = recurring.donations.first
                others = Donation.where(order_spid: t[:transaction_reference], success: true, executed_at: Time.new(1999,12,30)..Time.now)
                if others.length > 0 && others.map { |o| ((o.executed_at - Time.parse(t[:executed_at]))/1.day).abs }.min < 2
                    fail_list.push({:transaction => t, :message => "A successful donation already exists with that order (transaction) ID."})
                elsif recurring.nil?
                    fail_list.push({:transaction => t, :message => "Could not find a recurring object to link the transaction to."})
                elsif original.nil? || original.email.nil?
                    fail_list.push({:transaction => t, :message => "Could not find an original transaction that had a valid email."})
                else
                    donation = Donation.new(amount_in_cents: t[:amount].to_i*100, gateway_response_code:'00',bank_transaction_spid:t[:bank_transaction_id],tracking_code_slug:'ov_w_monthly_sp',tracking_code:'3564',order_spid:t[:transaction_reference],is_recurring:true,recurring_id:recurring.id,email:original.email,first_name:original.first_name,last_name:original.last_name,is_subsequent_recurring:true,expiry_month:t[:expiry_month].to_i,expiry_year:t[:expiry_year].to_i,executed_at:Time.parse(t[:executed_at]))
                    donation.save
                    nbres = donation.create_in_nationbuilder
                    if ![200,201].include?(nbres.code)
                        donation.update_attribute(:success, false)
                        donation.update_attribute(:other_data, "Attempted to send to NB but failed on #{Time.now.iso8601}")
                        fail_list.push({:transaction => t, :message => "Could not create in NationBuilder."})
                    else
                        donation.update_attribute(:success, true)
                    end
                end
            end
        end
        render json: {
            fail_list: fail_list
        }.to_json
    end

    ### GEOSCAPE tmp
    def geoscape
        if params[:q].length < 500
            render json: {
                results: General.geoscape_query(params[:q])
            }.to_json
        else
            render json: {
                success: false
            }.to_json, status: 401
        end
    end

    def geoscape_broad
        #General.broad_geoscape_query(q)
        if params[:q].length < 500
            render json: {
                results: General.broad_geoscape_query(params[:q])
            }.to_json
        else
            render json: {
                success: false
            }.to_json, status: 401
        end
    end

    def nice_try
        render json: {
            message: "I know you're trying to hack this, I can see you. You need to find the Lord Jesus Christ."
        }.to_json
    end
end
