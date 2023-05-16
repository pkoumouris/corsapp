class General < ApplicationRecord
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

    def General.sp_has_expired?
        ea = General.find_by(name: "SP_EXPIRES_AT")
        return ea.nil? || Time.at(ea.value.to_i) < Time.now
    end
    
    def General.sp_access_token # if expired, it updates it
        if General.sp_has_expired?
            Donation.securepay_auth
        end
        sat = General.find_by(name: "SP_ACCESS_TOKEN")
        crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base[0..31])
        return sat.nil? ? nil : crypt.decrypt_and_verify(sat.value)
    end

    def General.failure_error_code(nb, wem, cors)
        803 + (nb ? 4 : 0) + (wem ? 2 : 0) + (cors ? 1 : 0)
    end
end
