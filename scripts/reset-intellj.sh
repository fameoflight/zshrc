#!/bin/bash

# ./Library/Application Support/IntelliJIdea2016.2
# ./Library/Caches/IntelliJIdea2016.2
# ./Library/Logs/IntelliJIdea2016.2
# ./Library/Preferences/IntelliJIdea2016.2

echo "removeing evaluation key"
rm ~/Library/Preferences/IntelliJIdea2016.2/eval/idea162.evaluation.key

echo "resetting evalsprt in options.xml"
sed -i '/evlsprt/d' ~/Library/Preferences/IntelliJIdea2016.2/config/options/options.xml

echo "resetting evalsprt in prefs.xml"
sed -i '/evlsprt/d' ~/.java/.userPrefs/prefs.xml
