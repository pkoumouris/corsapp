class Recurring < ApplicationRecord

    has_many :donations

    SP_STATUSES = ['SP_SANDBOX_AUTH','SP_SANDBOX_APPLEPAY_AUTH','SP_LIVE_AUTH']
    SP_MC_STATUSES = ['SP_SANDBOX_MC','SP_SANDBOX_APPLEPAY_MC','SP_LIVE_MC']
    SP_LIVE = !(ENV['SP_STATUS_INDEX'].nil? || ENV['SP_STATUS_INDEX'].to_i != 2)
    SP_AUTH = ENV['SP_STATUS_INDEX'].nil? ? 'MG9heGI5aThQOXZRZFhUc24zbDU6MGFCc0dVM3gxYmMtVUlGX3ZEQkEySnpqcENQSGpvQ1A3b0k2amlzcA==' : ENV[SP_STATUSES[ENV['SP_STATUS_INDEX'].to_i]]
    SP_MERCHANT_CODE = ENV['SP_STATUS_INDEX'].nil? ? '5AR0055' : ENV[SP_MC_STATUSES[ENV['SP_STATUS_INDEX'].to_i]]

    def Recurring.create_payment_instrument(token, ip, sp_env) # SP env toggle
        customer_code = SecureRandom.alphanumeric
        response = HTTParty.post(sp_env == "LIVE" && SP_LIVE ? "https://payments.auspost.net.au/v2/customers/#{customer_code}/payment-instruments/token" : "https://payments-stest.npe.auspost.zone/v2/customers/#{customer_code}/payment-instruments/token",
        :headers => {
            'Content-Type'=>'application/json',
            'Authorization'=>'Bearer '+General.sp_access_token(sp_env),
            'token'=>token,
            'ip'=>ip
        })
        if ![200,201].include?(response.code)
            #raise "Unsuccessful creation of payment instrument"
            return response
        end
        recurring = Recurring.new(customer_code:customer_code,last_digits:response['last4'],expiry_month:response['expiryMonth'].to_i,expiry_year:response['expiryYear'].to_i,card_scheme:response['scheme'])
        return recurring
    end

    #def delete_payment_instrument
    #    response = HTTParty.delete(SP_LIVE ? "https://payments.auspost.net.au/v2/customers/#{self.customer_code}/payment-instruments/token" : "https://payments-stest.npe.auspost.zone/v2/customers/#{self.customer_code}/payment-instruments/token",
    #    :headers => {
    #       'Content-Type'=>'application/json',
    #       'Authorization'=>'Bearer '+General.sp_access_token(sp_env),
    #        'token'=>token,
    #        'ip'=>ip
    #    })
    #    return response
    #end

    def Recurring.make_recurring_payment(amount, token, ip, sp_env) # SP env toggle
        recurring = Recurring.create_payment_instrument(token, ip, sp_env)
        refnum = SecureRandom.alphanumeric
        response = HTTParty.post(sp_env == "LIVE" && SP_LIVE ? "https://payments.auspost.net.au/v2/payments/schedules/recurring" : "https://payments-stest.npe.auspost.zone/v2/payments/schedules/recurring",
        :body => {
            'ip'=>ip,
            'referenceNumber'=>refnum,
            'token'=>token,
            'merchantCode'=>SP_LIVE && sp_env == "LIVE" ? SP_MERCHANT_CODE : "5AR0055",
            'customerCode'=>recurring.customer_code,
            'amount'=>amount,
            'recurringTransaction'=>true,
            'scheduleDetails'=>{
                'paymentIntervalType'=>'MONTHLY',
                'startDate'=>1.month.from_now.iso8601[0..9]
            }
        }.to_json,
        :headers => {
            'Content-Type'=>'application/json',
            'Authorization'=>'Bearer '+General.sp_access_token(sp_env)
        })
        if ![200,201].include?(response.code)
            #raise "Make Recurring Payment failed"
            puts "Response code: #{response.code}"
            return response
        end
        recurring.active = true
        recurring.amount = amount
        recurring.schedule_spid = response['scheduleId']
        recurring.payment_interval_type = 'MONTHLY'
        recurring.save
        return recurring
    end
end
