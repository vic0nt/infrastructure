#!/bin/sh

#"set -e" will cause bash to exit with an error on any simple command
#"set -o pipefail" will cause bash to exit with an error on any command in a pipeline as well
set -e
set -o pipefail

cd /opt/bundles-bamboo

cat > conduct_helper.py <<EOL
import json

def getInstancesToStop(conductrInfo, newBundleDigest):
    jsonStringArr = '{"nodes": ' + conductrInfo + '}'
    parsedString = json.loads(jsonStringArr)
    nodesList = parsedString['nodes']
    # Filter python objects with list comprehensions
    filteredList = [x for x in nodesList if x['attributes']['system'] == 'mortgage-portal' and x['bundleDigest'] != newBundleDigest]
    mappedList = [elem['bundleId'] for elem in filteredList]
    output = ",".join([str(item) for item in mappedList])
    return output

def getInstanceToRun(conductrInfo, newBundleDigest):
    jsonStringArr = '{"nodes": ' + conductrInfo + '}'
    parsedString = json.loads(jsonStringArr)
    nodesList = parsedString['nodes']
    filteredList = [x for x in nodesList if x['attributes']['system'] == 'mortgage-portal' and x['bundleDigest'] == newBundleDigest]
    mappedList = [elem['bundleId'] for elem in filteredList]
    return mappedList[0]
EOL

#get the name of most recent file in current dir with mask
artifactName=$(ls -t mortgage-portal*.zip | head -1)

echo "Conduct load $artifactName"
conduct load --ip $(hostname -i) $artifactName
printf "\n"

buildDigest=$(python -c "import re; result = re.search(r'-([^-]+).zip', '${artifactName}'); print(result.group(1))")
conductrInfo=$(curl -s $(hostname -i):9005/v2/bundles)
instancesToStop=$(python -c "import conduct_helper; print(conduct_helper.getInstancesToStop('${conductrInfo}', '${buildDigest}'))")
instanceToRun=$(python -c "import conduct_helper; print(conduct_helper.getInstanceToRun('${conductrInfo}', '${buildDigest}'))")

printf "\n"
echo "Deploy variables:"
echo "artifactName: $artifactName"
echo "buildDigest: $buildDigest"
echo "instancesToStop: $instancesToStop"
echo "instanceToRun: $instanceToRun"
echo "conductrInfo: $conductrInfo"
printf "\n"

instancesToStopParsed=$(echo $instancesToStop | tr "," "\n")
echo "Conduct stop $instancesToStopParsed"
for inst in $instancesToStopParsed
do
    conduct stop --ip $(hostname -i) $inst
done

printf "\n"
echo "Conduct run $instanceToRun"
conduct run --ip $(hostname -i) $instanceToRun

printf "\n"
echo "Conduct unload $instancesToStopParsed"
for inst in $instancesToStopParsed
do
    conduct unload --ip $(hostname -i) $inst
done