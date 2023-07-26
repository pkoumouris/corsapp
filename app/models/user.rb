class User < ApplicationRecord
    has_secure_password

    #xcrypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base[0..31])
    #CAMMON_DEV_API_KEY = Rails.env.production? ? ENV['CM_DEV_API_KEY'] : xcrypt.decrypt_and_verify('0LGPirdUV8W+UHluknc3lwHinltEkUAIrhUTP3dXc13rDk2wGmPZI0r4BFDWtnby9PtET2HP3Ds71Ha4Ei/DzYNipwohSH4MijcVz8oW5OsXVHR1NYtaW2DLuUPCIJX+GNWjX7erseaKRfWD9gxkpvXneJyGbmZNb8sIMuZwaIK58vn4UFYIbC8+HNAG26wCEADJHLQYuVdeswU412vxzxqsuHhMjWSyM2XhU0qqt0O1nbl7O/xQ3XycCVnSpdF3P/slIHqaC9bbYUAPE6pgG7/W9kST0rtwuPgF--KuL3c0CVBzOejpEy--1chvUoxNttXEhVSQmWbTpQ==')
    #CAMMON_LIVE_API_KEY = Rails.env.production? ? ENV['CM_LIVE_API_KEY'] : xcrypt.decrypt_and_verify('T0x3ZG55NXdLYk9UNUNFcExKcVlzM3pJWmNGRU9WV3BkdU1mS2RDeDI4Q0N4MFM1ZVlJM1Y2VUcyNExmaUxoNXo1b1EwS1FiN2ZmUXRpVkZvNFRIUVZYc0M1aTRORXg4SFZrdVFtNDBNWnFLKzhTWUF2WGZ3UmxHeHlTZWtsL3VIdEJObmI4QTFxQ1poakpwUTltaEZBPT06eA==')

    def send_email(subject, to_arr, cc_arr, html)
        if to_arr.length > 25
            return nil # cannot exceed 25
        end
        xcrypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base[0..31])
        res = HTTParty.post("https://api.createsend.com/api/v3.2/transactional/classicEmail/send?clientID=#{Rails.env.production? ? "ba2383a86df105accc1562e64b4316af" : "a9eef8b7cb9a43b3c35055c5510d0d12"}",
            :headers => {
                'Accept'=>'*/*',
                'Connection'=>'close',
                'Content-Type'=>'application/json',
                'Authorization'=>'Basic '+(Rails.env.production? ? ENV['CM_DEV_API_KEY'] : xcrypt.decrypt_and_verify('0LGPirdUV8W+UHluknc3lwHinltEkUAIrhUTP3dXc13rDk2wGmPZI0r4BFDWtnby9PtET2HP3Ds71Ha4Ei/DzYNipwohSH4MijcVz8oW5OsXVHR1NYtaW2DLuUPCIJX+GNWjX7erseaKRfWD9gxkpvXneJyGbmZNb8sIMuZwaIK58vn4UFYIbC8+HNAG26wCEADJHLQYuVdeswU412vxzxqsuHhMjWSyM2XhU0qqt0O1nbl7O/xQ3XycCVnSpdF3P/slIHqaC9bbYUAPE6pgG7/W9kST0rtwuPgF--KuL3c0CVBzOejpEy--1chvUoxNttXEhVSQmWbTpQ=='))
            },
            :body => {
                'Subject'=>subject,
                'From'=>self.email,
                'ReplyTo'=>self.email,
                'To'=>to_arr,
                'CC'=>cc_arr,
                'BCC'=>nil,
                'Html'=>html,
                'Text'=>'',
                'Attachments'=>[],
                'TrackOpens'=>false,
                'TrackClicks'=>false,
                'InlineCSS'=>true,
                'ConsentToTrack'=>'Yes'
            }.to_json)
        return res
    end
end
