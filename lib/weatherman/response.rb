module Weatherman

  # = Response
  #
  # This is where we get access to the contents parsed by Nokogiri in a object-oriented way.
  # We also use this class to do the i18n stuff.
  #
  class Response
    attr_accessor :document_root

    def initialize(raw, language = nil)
      @document_root = Nokogiri::XML.parse(raw).xpath('rss/channel')
      @language = !!language
      load_language_yaml!(language) if @language
    end

    #
    # Returns a hash containing the actual weather condition details:
    #
    #  condition = response.condition
    #  condition['text'] => "Tornado"
    #  condition['code'] => 0
    #  condition['temp'] => 21
    #  condition['date'] => #<Date: -1/2,0,2299161>
    #
    def condition
      condition = item_attribute 'yweather:condition'
      condition = do_convertions(condition, [:code, :to_i], [:temp, :to_i], [:date, :to_date], :text)
      if i18n?
        internationalize!(condition)
      else
        condition
      end
    end

    # 
    # Wind's details:
    #
    #  wind = response.wind
    #  wind['chill'] => 21 
    #  wind['direction'] => 340 
    #  wind['chill'] => 9.66
    #
    def wind
      wind = attribute 'yweather:wind'
      do_convertions(wind, [:chill, :to_i], [:direction, :to_i], [:speed, :to_f]) 
    end

    #
    # Forecasts for the next 2 days.
    #
    #  forecast = response.forecasts.first
    #  forecast['low'] => 20
    #  forecast['high'] => 31
    #  forecast['text'] => "Tornado"
    #  forecast['code'] => 0
    #  forecast['day'] => "Sat"
    #
    def forecasts
      item_attribute('yweather:forecast').collect do |forecast|
        do_convertions(forecast, [:date, :to_date], [:low, :to_i], [:high, :to_i], [:code, :to_i], :day, :text)
      end
    end

    #
    # Location:
    #
    #  location = response.location
    #  location['country'] => "Brazil"
    #  location['region'] => "MG"
    #  location['city'] => Belo Horizonte
    #
    def location
      attribute 'yweather:location'
    end

    # Units:
    #
    #  units = response.units
    #  units['temperature']  => "C"
    #  units['distance']  => "km"
    #  units['pressure']  => "mb"
    #  units['speed']  => "km/h"
    #
    def units
      attribute 'yweather:units'
    end

    #
    # Astronomy:
    #
    #  astronomy = response.astronomy
    #  astronomy['sunrise'] => "6:01 am"
    #  astronomy['sunset'] => "7:20 pm"
    #
    def astronomy
      attribute 'yweather:astronomy' 
    end

    #
    # Latitude:
    #
    #  response.latitude => -49.90
    def latitude
      geo_attribute('lat').to_f
    end

    # 
    # Longitude;
    #
    #  response.longitude => -45.32
    #
    def longitude
      geo_attribute('long').to_f
    end

    #
    # A hash like object providing image info:
    #
    #  image = reponse.image
    #  image['width'] => 142
    #  image['height'] => 18
    #  image['title'] => "Yahoo! Weather"
    #  image['link'] => "http://weather.yahoo.com"
    #
    def image
      image = Weatherman::Image.new(attribute 'image')
      do_convertions(image, [:width, :to_i], [:height, :to_i], :title, :link, :url)
    end

    #
    # A short HTML snippet with a simple weather description.
    # 
    def description
      text_attribute 'description'
    end

    private
      def attribute(attr, root = document_root)
        elements = root.xpath(attr)
        elements.size == 1 ? elements.first : elements
      end

      def item_attribute(attr)
        item = document_root.xpath('item').first
        attribute(attr, item)
      end

      def geo_attribute(attr)
        geo = item_attribute('geo:' + attr)
        geo.children.first.text
      end

      def text_attribute(attr)
        item_attribute(attr).content        
      end

      def do_convertions(attributes, *pairs)
        pairs.inject({}) do |hash, (attr, method)|
          value = attributes[attr.to_s]
          hash[attr.to_s] = convert(value, method)
          hash
        end
      end

      def convert(value, method)
        if method == :to_date
          Date.parse(value)
        else
          method ? value.send(method) : value
        end
      end

      def load_language_yaml!(language)
        stream = File.read(File.join([I18N_YAML_DIR, language + '.yml']))
        @language_config = YAML.load(stream) 
      end

      def internationalize!(condition)
        condition['text'] = @language_config[condition['code']]
        condition
      end

      def i18n?
        @language
      end
  end
end