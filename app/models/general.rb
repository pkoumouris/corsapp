class General < ApplicationRecord
    xcrypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base[0..31])
    CLIENT_ID = Rails.env.production? ? ENV['NB_CLIENT_ID'] : xcrypt.decrypt_and_verify('SXN8u9vl0davLbNR4axO6/9BI+zvakizdFm7Ori3vT9ppGLKBTZbemrjGrGarvXSObKyxrs=--cgiPU7DgeAO+hztT--MKD/LgFOrtNdZsY1rPngpQ==')
    CLIENT_SECRET = Rails.env.production? ? ENV['NB_CLIENT_SECRET'] : xcrypt.decrypt_and_verify('tYpic0T4w9Wv/fP9Dvubjzj0qKCFPJ7nVRER0eEmGmQ8ki+sg1zECV+mc3e19LTUwSe/yxk=--5zbRz+cHjO1XLQtS--cLeCgMYQHjK38V7cLpyxlA==')
    TEST_TOKEN = Rails.env.production? ? "" : xcrypt.decrypt_and_verify('Q56f7Pn7gHvpGWSaKoTHnXtQVW2dZNHR8cQ=--3A46FpVdAg1tMMPd--T5ow8BuoeF6Tjpdln5sohA==')

    def General.save_access_token(access_token, expires_in, refresh_token)
        if General.find_by(name: "NB_ACCESS_TOKEN").nil?
            General.new(name: "NB_ACCESS_TOKEN").save
        end
        if General.find_by(name: "NB_EXPIRES_AT").nil?
            General.new(name: "NB_EXPIRES_AT").save
        end
        if General.find_by(name: "NB_REFRESH_TOKEN").nil?
            General.new(name: "NB_REFRESH_TOKEN").save
        end

        crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base[0..31])
        General.find_by(name: "NB_ACCESS_TOKEN").update_attribute(:value, crypt.encrypt_and_sign(access_token))
        General.find_by(name: "NB_EXPIRES_AT").update_attribute(:value, (Time.now + expires_in.seconds).to_s)
        General.find_by(name: "NB_REFRESH_TOKEN").update_attribute(:value, crypt.encrypt_and_sign(refresh_token))
    end

    def General.access_token
        crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base[0..31])
        rec = General.find_by(name: "NB_ACCESS_TOKEN")
        if rec.nil?
            return nil
        else
            return crypt.decrypt_and_verify(rec.value)
        end
    end

    def General.refresh_token
        crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base[0..31])
        rec = General.find_by(name: "NB_REFRESH_TOKEN")
        if rec.nil?
            return nil
        else
            return crypt.decrypt_and_verify(rec.value)
        end
    end
    
    def General.refresh_access_token
        refresh_token = General.refresh_token
        if refresh_token.nil?
            return nil
        end
        nb_resp = HTTParty.post("https://acl.nationbuilder.com/oauth/token",:body => {
                "grant_type"=>"refresh_token",
                "client_id"=>CLIENT_ID, # NEED TO BE ABSTRACTED OUT
                "client_secret"=>CLIENT_SECRET, # NEED TO BE ABSTRACTED OUT
                "refresh_token"=>refresh_token
            }.to_json, :headers => {
                'Content-Type'=>'application/json',
                'Accept'=>'*/*'
            })
        if nb_resp.code == 200
            General.save_access_token(nb_resp['access_token'], nb_resp['expires_in'], nb_resp['refresh_token'])
        else
            raise "Could not refresh token"
        end
    end

    def General.test_token
        TEST_TOKEN
    end

    ######## NB PEOPLE
    def General.find_nb_person_by_email(email)
        resp = HTTParty.get("https://acl.nationbuilder.com/api/v1/people/match?email=#{email}",
            :headers => {
                'Authorization'=>'Bearer '+General.access_token,
                'Accept'=>'*/*',
                'Connection'=>'keep-alive'
            })
        #return resp
        return resp.code == 200 ? resp['person']['id'] : nil
    end

    #def General.create_nb_person(first_name, last_name, email)

    #end

    ######## SECUREPAY

    def General.save_sp_access_token(access_token, expires_in)
        if General.find_by(name: "SP_ACCESS_TOKEN").nil?
            General.new(name: "SP_ACCESS_TOKEN").save
        end
        if General.find_by(name: "SP_EXPIRES_AT").nil?
            General.new(name: "SP_EXPIRES_AT").save
        end

        crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base[0..31])
        puts "Access token is: "+access_token
        General.find_by(name: "SP_ACCESS_TOKEN").update_attribute(:value, crypt.encrypt_and_sign(access_token))
        General.find_by(name: "SP_EXPIRES_AT").update_attribute(:value, (Time.now + expires_in.seconds).to_i.to_s)
    end

    def General.save_sandbox_sp_access_token(access_token, expires_in)
        if General.find_by(name: "SP_SANDBOX_ACCESS_TOKEN").nil?
            General.new(name:"SP_SANDBOX_ACCESS_TOKEN").save
        end
        if General.find_by(name:"SP_SANDBOX_EXPIRES_AT").nil?
            General.new(name:"SP_SANDBOX_EXPIRES_AT").save
        end
        crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base[0..31])
        General.find_by(name:"SP_SANDBOX_ACCESS_TOKEN").update_attribute(:value, crypt.encrypt_and_sign(access_token))
        General.find_by(name: "SP_SANDBOX_EXPIRES_AT").update_attribute(:value, (Time.now + expires_in.seconds).to_i.to_s)
    end

    def General.sp_has_expired?(sp_env)
        ea = General.find_by(name: sp_env == "LIVE" ? "SP_EXPIRES_AT" : "SP_SANDBOX_EXPIRES_AT")
        return ea.nil? || Time.at(ea.value.to_i) < Time.now
    end
    
    def General.sp_access_token(sp_env) # if expired, it updates it
        if General.sp_has_expired?(sp_env)
            Donation.securepay_auth(sp_env)
        end
        sat = General.find_by(name: sp_env == "LIVE" ? "SP_ACCESS_TOKEN" : "SP_SANDBOX_ACCESS_TOKEN")
        crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base[0..31])
        return sat.nil? ? nil : crypt.decrypt_and_verify(sat.value)
    end

    def General.failure_error_code(nb, wem, cors)
        803 + (nb ? 4 : 0) + (wem ? 2 : 0) + (cors ? 1 : 0)
    end

    ################# GEOSCAPE #####################
    def General.geoscape_address_query(query)
        response = HTTParty.get("https://api.psma.com.au/v2/addresses/geocoder?additionalProperties=localGovernmentArea,stateElectorate,commonwealthElectorate,asgsMain&address=#{query}",
            :headers => {"Authorization"=>ENV['GNAF_API_KEY']})
        if response.code != 200 || response['features'].length == 0
            return nil
        end
        return {
            addressId: response['features'][0]['properties']['addressId'],
            formattedAddress: response['features'][0]['properties']['formattedAddress']
        }
    end

    def General.geoscape_address_from_gnaf_id(gnaf_id)
        response = HTTParty.get("https://api.psma.com.au/v2/addresses/address/#{gnaf_id}",
            :headers => {"Authorization"=>ENV['GNAF_API_KEY']})
        if response.code != 200 || response['properties'].nil?
            return nil
        end
        return response['properties']['formattedAddress']
    end

    ####### GNAF
    def General.geoscape_query(q)
        response = HTTParty.get("https://api.psma.com.au/v2/addresses/geocoder?additionalProperties=localGovernmentArea,stateElectorate,commonwealthElectorate,asgsMain&address=#{q}",
            :headers => {
                'Authorization' => ENV['GEOSCAPE_API_KEY']
            })
        if response.code == 200# && !response['features'].nil? && response['features'].length > 0 && !response['features'][0]['properties'].nil? && !response['features'][0]['properties']['commonwealthElectorate'].nil?
            return response['features'].map { |r| {
                'formattedAddress': r['properties']['formattedAddress'],
                'commonwealthElectorate': r['properties']['commonwealthElectorate']['commElectoralName']
            } }
        else
            return nil
        end
    end

    def General.broad_geoscape_query(q)
        response = HTTParty.get("https://api.psma.com.au/v2/addresses/geocoder?additionalProperties=localGovernmentArea,stateElectorate,commonwealthElectorate,asgsMain&address=#{q}",
            :headers => {
                'Authorization' => ENV['GEOSCAPE_API_KEY']
            })
        if response.code == 200# && !response['features'].nil? && response['features'].length > 0 && !response['features'][0]['properties'].nil? && !response['features'][0]['properties']['commonwealthElectorate'].nil?
            return response['features'].map { |r| {
                'formattedAddress': r['properties']['formattedAddress'],
                'gnafId': r['properties']['addressId'],
                'lat': r['geometry']['coordinates'][1],
                'long': r['geometry']['coordinates'][0]
            } }
        else
            return nil
        end
    end

    ### NB for preferences
    def General.test_token
        return ''
    end

    def General.get_signup_id_from_email(email)
        response = HTTParty.get("https://acl.nationbuilder.com/api/v2/signups?filter[with_email_address]=#{email}",
            :headers => {
                'Authorization' => 'Bearer '+General.test_token#access_token
            })
        return response.code == 200 ? response['data'][0]['id'] : nil
    end

    def General.get_tags_from_person(signup_id)
        response = HTTParty.get("https://acl.nationbuilder.com/api/v2/signup_taggings?filter[signup_id]=#{signup_id}",
            :headers => {
                'Authorization' => 'Bearer '+General.test_token#access_token
            })
        return response.code == 200 ? response['data'].map { |d| d['attributes']['tag_id'] } : nil
    end

    def General.add_tags_to_person(signup_id, tag_ids)
        responses = []
        tag_ids.each do |tag_id|
            responses.push(HTTParty.post("https://acl.nationbuilder.com/api/v2/signup_taggings",
                :headers => {
                    'Content-Type'=>'application/json',
                    'Accept'=>'*/*',
                    'Authorization' => 'Bearer '+General.test_token#access_token
                },
                :body => {
                    'data'=>{
                        'type'=>'signup_taggings',
                        'attributes'=>{
                            'signup_id'=>signup_id.to_s,
                            'tag_id'=>tag_id
                        }
                    }
                }.to_json))
        end
        return responses.map { |r| r.code }
    end

    def General.remove_tags_from_person(signup_id, tag_ids)
        responses = []
        tag_ids.each do |tag_id|
            tagging_res = HTTParty.get("https://acl.nationbuilder.com/api/v2/signup_taggings?filter[tag_id]=#{tag_id}&filter[signup_id]=#{signup_id}",
                :headers => {
                    'Authorization' => 'Bearer '+General.test_token#access_token
                })
            if tagging_res.code == 200
                puts tagging_res['data'][0]['id']
                responses.push(HTTParty.delete("https://acl.nationbuilder.com/api/v2/signup_taggings/#{tagging_res['data'][0]['id']}",
                    :headers => {
                        'Content-Type'=>'application/json',
                        'Accept'=>'*/*',
                        'Authorization' => 'Bearer '+General.test_token#access_token
                    }))
            else
                responses.push(400)
            end
        end
        return responses.map { |r| r.code }
    end
end
