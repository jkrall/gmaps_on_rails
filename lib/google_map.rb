class GoogleMap
  include UnbackedDomId
  attr_accessor :dom_id,
                :markers,
                :controls,
                :center,
                :inject_on_load,
                :zoom,
                :min_zoom,
                :max_zoom,
                :api_key,
                :javascript_framework

  def initialize(options = {})
    self.dom_id = 'google_map'
    self.api_key = GOOGLE_APPLICATION_ID
    self.markers = []
    self.controls = [ :zoom, :overview, :scale, :type ]
    options.each_pair { |key, value| send("#{key}=", value) }
  end

  def to_html
    html = []

    html << "<script src='http://maps.google.com/maps?file=api&amp;v=2&amp;key=#{api_key}' type='text/javascript'></script>"

    html << "<script type=\"text/javascript\">\n/* <![CDATA[ */\n"
    html << to_js
    html << "/* ]]> */</script> "

    return html.join("\n")
  end

  def to_js
    js = []

    # Initialise the map variable so that it can externally accessed.
    js << "var #{dom_id};"
    js << "var #{dom_id}_markers = new Object();"

    js << center_on_markers_function_js

    js << "function initialize_google_map_#{dom_id}() {"
    js << "  if(GBrowserIsCompatible()) {"
    js << "    #{dom_id} = new GMap2(document.getElementById('#{dom_id}'));"

    js << '    ' + controls_js
    js << '    ' + markers_icons_js

    js << add_markers_js.gsub("\n", "    \n")

    js << '    ' + center_on_markers_js

    js << '    ' + inject_on_load.gsub("\n", "    \n") if inject_on_load

    js << "  }"
    js << "}"

    # Load & unload the map with the window
    case javascript_framework
    when :jquery
      js << "$(window).load(initialize_google_map_#{dom_id});"
      js << "$(window).unload(GUnload);"
    when :prototype
      js << "Event.observe(window, \"load\", initialize_google_map_#{dom_id});"
      js << "Event.observe(window, \"unload\", GUnload);"
    else
      js << "if (typeof window.onload != 'function') {"
      js << "  window.onload = initialize_google_map_#{dom_id};"
      js << "} else {"
      js << "  old_before_google_map_#{dom_id} = window.onload;"
      js << "  window.onload = function() {"
      js << "    old_before_google_map_#{dom_id}();"
      js << "    initialize_google_map_#{dom_id}();"
      js << "  }"
      js << "}"
      js << "if (typeof window.onunload != 'function') {"
      js << "  window.onunload = GUnload;"
      js << "} else {"
      js << "  old_before_onunload = window.onload;"
      js << "  window.onunload = function() {"
      js << "    old_before_onunload();"
      js << "    GUnload();"
      js << "  }"
      js << "}"
    end

    return js.join("\n")
  end

  def controls_js
    js = []

    controls.each do |control|
      case control
        when :large, :small, :overview
          c = "G#{control.to_s.capitalize}MapControl"
        when :scale
          c = "GScaleControl"
        when :type
          c = "GMapTypeControl"
        when :zoom
          c = "GSmallZoomControl"
      end
      js << "#{dom_id}.addControl(new #{c}());"
    end

    return js.join("\n")
  end

  def markers_icons_js
    icons = []

    for marker in markers
      if marker.icon and !icons.include?(marker.icon)
        icons << marker.icon
      end
    end

    js = []

    for icon in icons
      js << icon.to_js
    end

    return js.join("\n")
  end

  def clear_markers_js
    js = []
    js << "  for(marker in #{dom_id}_markers) {"
    js << "    GEvent.clearListeners(#{dom_id}_markers[marker], 'click');"
    js << "  }"
    js << "#{dom_id}.clearOverlays();"
    js << "#{dom_id}_markers = new Object();"
    return js.join("\n")
  end

  # Creates a JS function that removes all markers, and adds new ones
  def add_markers_js
    js = []
    for marker in markers
      js << '    ' + marker.to_js
      js << ''
    end
    return js.join("\n")
  end

  # Creates a JS function that centers the map on its markers.
  def center_on_markers_function_js
    js = []
    js << "function centerzoom_#{dom_id}(center, zoom) {"

    # Calculate the bounds of the markers
    js << "  if (!center || !zoom) {"
    js << "    var bounds = new GLatLngBounds();"
    js << "    for(marker in #{dom_id}_markers) {"
    js << "      bounds.extend(#{dom_id}_markers[marker].getLatLng());"
    js << "    }"
    js << "  }"
    js << "  if (!center) { center = bounds.getCenter(); }"
    js << "  if (!zoom) {"
    js << "    zoom = #{dom_id}.getBoundsZoomLevel(bounds);"
    js << "    if (zoom < #{min_zoom}) { zoom = #{min_zoom}; }" if min_zoom
    js << "    if (zoom > #{max_zoom}) { zoom = #{max_zoom}; }" if max_zoom
    js << "  }"

    js << "  #{dom_id}.checkResize();"
    js << "  #{dom_id}.setCenter(center, zoom);"
    js << "}"

    return js.join("\n")
  end

  def center_on_markers_js
    _center = self.center ? "new GLatLng(#{self.center[0]}, #{self.center[1]})" : "false"
    _zoom = self.zoom ? "#{self.zoom}" : "false"
    return "centerzoom_#{dom_id}(#{_center},#{_zoom});"
  end

  def div(width = '100%', height = '100%')
    styles = []
    styles << "width: #{width}" unless width.nil?
    styles << "height: #{height}" unless height.nil?
    style_attr = " style='#{styles.join('; ')}'" unless styles.empty?
    "<div id='#{dom_id}'#{style_attr}></div>"
  end
end
