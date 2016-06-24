require 'aws-sdk-core'
require 'aws-sdk-resources'
require 'net/http'
 
############## SERVER SIDE CODE ###########
class Server
    @@s3 =  Aws::S3::Client.new(region: 'us-west-2')
    @@presigner = Aws::S3::Presigner.new({client:@@s3})
    @@upload = {
            bucket: 'test-daman',
            key: 'dummy/test_file'
         }
    class << self
        def get_upload_uri()
            upload_uri = @@presigner.presigned_url(:put_object, bucket:@@upload[:bucket], key:@@upload[:key], expires_in:600)
            upload_uri
        end
        def download()
            # Test method to check contents of S3 file
            s3_resource = Aws::S3::Resource.new(region:'us-west-2')
            obj = s3_resource.bucket(@@upload[:bucket]).object(@@upload[:key])
            puts obj.get.body.read
        end
    end
end
 
############## CLIENT SIDE CODE ###########
class Client
    class << self
        def upload_file(file_content)
            upload_url=URI.parse(Server.get_upload_uri())
            puts upload_url
            response = Net::HTTP.start(upload_url.host) { |http| http.send_request("PUT", upload_url.request_uri, file_content,
                {"content-type" => "text/plain" }) }
            puts response.code
            puts response.body
        end
    end
end
 
#Upload file
file_content="Hello World!"
Client.upload_file(file_content)
 
#Download file to check contents
Server.download
