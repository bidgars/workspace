#!/bin/bash

# Send keystrokes to an application (replace 'AppName' with the actual app name)
osascript <<EOF
tell application "Omnissa Horizon Client"
    activate
end tell
#tell application "System Events"
#    keystroke "Hello World!"
#    key code 36 -- Simulates pressing Enter
#end tell
EOF

# Number of iterations (adjust as needed)
iterations=2592000

# Delay between keystrokes (in seconds)
shortdelay=0.005
longdelay=90

# Loop to send keystrokes
for ((i=1; i<=iterations; i++))
do
  # Send left arrow key
  osascript -e 'tell application "System Events" to key code 123'
  sleep $shortdelay

  # Send right arrow key
  osascript -e 'tell application "System Events" to key code 124'
  sleep $longdelay
done

