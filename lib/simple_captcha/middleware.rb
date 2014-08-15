# encoding: utf-8
module SimpleCaptcha
  class Middleware
    include SimpleCaptcha::ImageHelpers
    include SimpleCaptcha::ViewHelper

    DEFAULT_SEND_FILE_OPTIONS = {
      :type         => 'application/octet-stream'.freeze,
      :disposition  => 'attachment'.freeze,
    }.freeze

    def initialize(app, options={})
      @app = app
      self
    end

    def call(env) # :nodoc:
      if env["REQUEST_METHOD"] == "GET" && captcha_path?(env['PATH_INFO'])
        request = Rack::Request.new(env)
        if request.params.present? && request.params['code'].present?
          make_image(env)
        else
          refresh_code(env)
        end
      else
        @app.call(env)
      end
    end

    protected
      def make_image(env, headers = {}, status = 404)
        request = Rack::Request.new(env)
        code = request.params["code"]
        body = []

        if Utils::simple_captcha_value(code)
          #status, headers, body = @app.call(env)
          #status = 200
          #body = generate_simple_captcha_image(code)
          #headers['Content-Type'] = 'image/jpeg'

          send_data(generate_simple_captcha_image(code), :type => 'image/jpeg', :disposition => 'inline', :filename =>  'simple_captcha.jpg')
        else
          [status, headers, body]
        end
      end

      def captcha_path?(request_path)
        request_path.include?('/simple_captcha')
      end

      def send_file(path, options = {})
        raise MissingFile, "Cannot read file #{path}" unless File.file?(path) and File.readable?(path)

        options[:filename] ||= File.basename(path) unless options[:url_based_filename]

        status = options[:status] || 200
        headers = {"Content-Disposition" => "#{options[:disposition]}; filename='#{options[:filename]}'", "Content-Type" => options[:type], 'Content-Transfer-Encoding' => 'binary', 'Cache-Control' => 'private'}
        response_body = File.open(path, "rb")

        [status, headers, response_body]
      end

      def send_data(response_body, options = {})
        status = options[:status] || 200
        headers = {"Content-Disposition" => "#{options[:disposition]}; filename='#{options[:filename]}'", "Content-Type" => options[:type], 'Content-Transfer-Encoding' => 'binary', 'Cache-Control' => 'private'}

        [status, headers, [response_body]]
      end

      def refresh_code(env)
        request = Rack::Request.new(env)

        request.session.delete :captcha
        key = simple_captcha_key(nil, request)
        options = {}
        options[:field_value] = set_simple_captcha_data(key, options)
        url = simple_captcha_image_url(key, options)

        status = 200
        id = request.params['id']

        body = %Q{
                    $("##{id}").attr('src', '#{url}');
                    $("#captcha_key").attr('value', '#{key}');
                  }
        headers = {'Content-Type' => 'text/javascript; charset=utf-8', "Content-Disposition" => "inline; filename='captcha.js'", "Content-Length" => body.length.to_s}
        [status, headers, [body]]
      end
  end
end
