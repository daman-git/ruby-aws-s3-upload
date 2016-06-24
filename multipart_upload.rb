require 'aws-sdk-core'
require 'aws-sdk-resources'
require 'net/http'
require 'nokogiri'
 
############## SERVER SIDE CODE ###########
class Server
    @@s3 =  Aws::S3::Client.new(
        region: 'us-west-2'
    )
    @@upload = {
            client: @@s3,
            bucket: 'test-daman',
            key: 'dummy/master',
    }
    @@presigner  = Aws::S3::Presigner.new({client:@@s3})
 
    class << self
        def get_create_multipart_upload_url()
            upload_url = @@presigner.presigned_url(:create_multipart_upload, bucket:@@upload[:bucket], key:@@upload[:key])
            upload_url
        end
 
        def get_part_upload_url(create_multipart_upload_response, part_num)
            response = Nokogiri::XML(create_multipart_upload_response.body)
            response.remove_namespaces!
            upload_id = response.xpath('//UploadId')[0].content
            puts upload_id
            part_url  = @@presigner.presigned_url(:upload_part,bucket:@@upload[:bucket], key:@@upload[:key],
                    upload_id: upload_id, part_number: part_num)
            part_url
        end
 
        def complete_multipart_upload_url(create_multipart_upload_response)
            response = Nokogiri::XML(create_multipart_upload_response.body)
            response.remove_namespaces!
            upload_id = response.xpath('//UploadId')[0].content
            puts upload_id
 
            input_opts = {
                    bucket:     @@upload[:bucket] ,
                    key:        @@upload[:key]  ,
                    upload_id:  upload_id       ,
                  } 
 
            parts_resp = @@s3.list_parts(input_opts)
            input_opts = input_opts.merge(
                    :multipart_upload => {
                        :parts =>
                          parts_resp.parts.map do |part|
                          { :part_number => part.part_number,
                            :etag        => part.etag }
                          end
                        }  
                    ) 
 
            last_response = @@s3.complete_multipart_upload(input_opts)
            puts last_response
        end
     
        def download()
            s3_resource = Aws::S3::Resource.new(region:'us-west-2')
            obj = s3_resource.bucket(@@upload[:bucket]).object(@@upload[:key])
            puts obj.get.body.read
        end
    end
end
 
 
############## CLIENT SIDE CODE ###########
# Initiate multipart upload
mul_upload_uri=Server.get_create_multipart_upload_url
mul_upload_url=URI.parse(mul_upload_uri)
mul_upload_response=Net::HTTP.start(mul_upload_url.host) { |http| http.send_request("POST", mul_upload_url.request_uri, "", {"content-type" => ""}) }
 
# Upload part 1
part1=File.read('/Users/daman/S3/part1.txt')
part_upload_uri=Server.get_part_upload_url(mul_upload_response, 1)
part_upload_url=URI.parse(part_upload_uri)
part_upload_response=Net::HTTP.start(part_upload_url.host) { |http| http.send_request("PUT", part_upload_url.request_uri, part1, {"content-type" => "text/plain"}) }
puts part_upload_response.code
 
# Upload part 2
part2=File.read('/Users/daman/S3/part2.txt')
part_upload_uri=Server.get_part_upload_url(mul_upload_response, 2)
part_upload_url=URI.parse(part_upload_uri)
part_upload_response=Net::HTTP.start(part_upload_url.host) { |http| http.send_request("PUT", part_upload_url.request_uri, part2, {"content-type" => "text/plain"}) }
puts part_upload_response.code
 
# Complete mutipart upload
Server.complete_multipart_upload_url(mul_upload_response)
 
# Read back uploaded file to verify
Server.download
