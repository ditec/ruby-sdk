require 'test_helper'
require 'socket'
require 'tempfile'

module PortaText
  module Test
    # Tests the Net::HTTP client mplementation.
    #
    # Author::    Marcelo Gornstein (mailto:marcelog@portatext.com)
    # Copyright:: Copyright (c) 2015 PortaText
    # License::   Apache-2.0
    class NetHttpClient < Minitest::Test
      def test_request_error
        uri = "http://127.0.0.1:65534"
        descriptor = PortaText::Command::Descriptor.new(
          uri, :post, {"h1" => "v1"}, "body"
        )
        client = PortaText::Client::HttpClient.new
        assert_raises PortaText::Exception::RequestError do
          client.execute descriptor
        end
      end

      def test_get
        run_method :get
      end

      def test_post
        run_method :post
      end

      def test_put
        run_method :put
      end

      def test_delete
        run_method :delete
      end

      def test_patch
        run_method :patch
      end

      private

      def run_method(method)
        port = rand(64_511) + 1_024
        recv_file = Tempfile.new "received#{port}"
        Process.fork do
          server = TCPServer.new port
          server.setsockopt :SOCKET, :REUSEADDR, 1
          server.listen 10
          client = server.accept
          buffer = ''
          loop do
            new_buff = client.recv 2_048
            buffer = buffer + new_buff
            break if /a body/ =~ buffer
          end
          recv_file.write buffer
          recv_file.close

          client.puts 'HTTP/1.1 742 OK'
          client.puts 'Connection: close'
          client.puts 'X-header1: value1'
          client.puts 'X-header2: value2'
          client.puts ''
          hash = {success: true}
          client.write hash.to_json
          sleep 0.1

          client.close
          server.close
          Process.exit! true
        end
        client = PortaText::Client::HttpClient.new
        sleep 0.1
        code, headers, body = client.execute PortaText::Command::Descriptor.new(
          "http://127.0.0.1:#{port}/some/endpoint",
          method,
          {
            'header1' => 'value1'
          },
          "a body\r\n"
        )
        assert code == 742
        assert headers == {
          'connection' => 'close',
          'x-header1' => 'value1',
          'x-header2' => 'value2'
        }
        assert body == '{"success":true}'
        content = File.readlines recv_file
        assert "#{method.upcase} /some/endpoint HTTP/1.1" == content[0].chop
        recv_file.delete
      end
    end
  end
end
