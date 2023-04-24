#!/bin/bash

if [[ "$1" == "enable" ]]; then
  # enable debug mode
  if grep -q "SOGoUIxDebugEnabled = YES;" "/etc/sogo/sogo.conf"; then
    sed -i "s|//SOGoUIxDebugEnabled = YES;|SOGoUIxDebugEnabled = YES;|" "/etc/sogo/sogo.conf"
  else
    echo "SOGoUIxDebugEnabled = YES;" >> "/etc/sogo/sogo.conf"
  fi
  
  echo "Success: SOGoUIxDebugEnabled has been enabled"
elif [[ "$1" == "disable" ]]; then
  # disable debug mode
  if grep -q "SOGoUIxDebugEnabled = YES;" "/etc/sogo/sogo.conf"; then
    if ! grep -q "//SOGoUIxDebugEnabled = YES;" "/etc/sogo/sogo.conf"; then
      sed -i "s|SOGoUIxDebugEnabled = YES;|//SOGoUIxDebugEnabled = YES;|" "/etc/sogo/sogo.conf"
    fi
  fi

  echo "Success: SOGoUIxDebugEnabled has been disabled"
elif [[ "$1" == "set_theme" ]]; then
  # Get the sogo palettes from Redis
  PRIMARY=$(redis-cli -h redis HGET SOGO_THEME primary)
  if [ $? -ne 0 ]; then
    PRIMARY="green"
  fi
  ACCENT=$(redis-cli -h redis HGET SOGO_THEME accent)
  if [ $? -ne 0 ]; then
    ACCENT="green"
  fi
  BACKGROUND=$(redis-cli -h redis HGET SOGO_THEME background)
  if [ $? -ne 0 ]; then
    BACKGROUND="grey"
  fi

  # Read custom palettes
  if [ -f /etc/sogo/custom-palettes.js ]; then
    COLORS=$(cat /etc/sogo/custom-palettes.js)
  else
    COLORS=""
  fi

  # Write theme to /usr/lib/GNUstep/SOGo/WebServerResources/js/theme.js
  cat > /usr/lib/GNUstep/SOGo/WebServerResources/js/theme.js <<EOL
(function() {
  'use strict';

  angular.module('SOGo.Common')
    .config(configure)

  configure.\$inject = ['\$mdThemingProvider'];
  function configure(\$mdThemingProvider) {

$COLORS

    var primary = \$mdThemingProvider.extendPalette('$PRIMARY', {});
    var accent = \$mdThemingProvider.extendPalette('$ACCENT', {
      'A100': 'ffffff'
    });
    var background = \$mdThemingProvider.extendPalette('$BACKGROUND', {});

    \$mdThemingProvider.definePalette('primary-cow', primary);
    \$mdThemingProvider.definePalette('accent-cow', accent);
    \$mdThemingProvider.definePalette('background-cow', background);

    \$mdThemingProvider.theme('default')
      .primaryPalette('primary-cow', primarySettings)
      .accentPalette('accent-cow', accentSettings)
      .backgroundPalette('background-cow', backgroundSettings);
    \$mdThemingProvider.generateThemesOnDemand(false);
  }
})();
EOL

  echo "Success: Theme configuration written"
elif [[ "$1" == "set_logo" ]]; then
  # Get the image data from Redis and save it to a tmp file
  redis-cli -h redis GET MAIN_LOGO > /tmp/logo_base64.txt

  # Check if mime type is svg+xml
  mime_type=$(awk -F'[:;]' '{print $2}' /tmp/logo_base64.txt | sed 's/.*\///')
  if [ "$mime_type" != "svg+xml" ]; then
    echo "Error: Image format must be of type svg"
    exit 1
  fi

  # Decode base64 and save to file
  payload=$(cat /tmp/logo_base64.txt | sed 's/^data:[^;]*;//' | awk '{ sub(/^base64,/, ""); print $0 }')
  echo $payload | base64 -d | tee /usr/lib/GNUstep/SOGo/WebServerResources/img/sogo-full.svg > /dev/null

  # Remove temp file
  rm /tmp/logo_base64.txt
  echo "Success: Image has been set"
elif [[ "$1" == "set_favicon" ]]; then
  # Get the image data from Redis and save it to a tmp file
  redis-cli -h redis GET FAVICON > /tmp/favicon_base64.txt

  # Check if mime type is png or ico
  mime_type=$(awk -F'[:;]' '{print $2}' /tmp/favicon_base64.txt | sed 's/.*\///')
  if [[ "$mime_type" != "png" && "$mime_type" != "ico" ]]; then
    echo "Error: Image format must be of type png or ico"
    exit 1
  fi

  # Decode base64 and save to file
  payload=$(cat /tmp/favicon_base64.txt | sed 's/^data:[^;]*;//' | awk '{ sub(/^base64,/, ""); print $0 }')
  echo $payload | base64 -d | tee /usr/lib/GNUstep/SOGo/WebServerResources/img/sogo.ico > /dev/null

  # Remove temp file
  rm /tmp/favicon_base64.txt
  echo "Success: Image has been set"
fi