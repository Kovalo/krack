module Krack
  class Router
    attr_reader :routes

    def initialize(&block)
      @routes = []
      instance_eval(&block) if block
    end

    def call(env)
      @routes.each do |verb, route, app|
        next unless verb == env["REQUEST_METHOD"]
        next unless match = env["PATH_INFO"].match(route)

        env["krack.params"] = Hash[match.names.zip(match.captures)]
        return app.dup.call(env)
      end
      not_found
    end
    
    def not_found
      [404, {"Content-Type" => "text/plain"}, ["Not found"]]
    end

    # Defines methods for each HTTP verb. These methods just call #map
    # with the corresponding verb argument.
    %w[get post put delete patch].each do |verb|
      define_method(verb) { |route, to| map(verb.upcase, route, to) }
    end

    def map(verb, route, to)
      # Converts route params to regex named groups, like so:
      # "/deals/:id" -> "/deals/(?<id>\w+)"
      route.gsub!(/:\w+/) { |param| "(?<#{param[1..-1]}>\\w+)" }

      # Allow optional trailing slash, add start/end tokens
      route = "\\A#{route}\\/?\\z"

      # App can be either a Rack class or an instance of such, e.g.
      # Endpoints::Deals::Near or lambda { |env| ... }
      # What goes into @routes is something that responds to #call
      app = to.respond_to?(:call) ? to : to.new

      @routes << [verb, Regexp.new(route), app]
    end
  end
end