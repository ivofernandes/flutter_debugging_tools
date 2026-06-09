#!/usr/bin/env bash
cd ../.. || exit 1
# echo the current time
echo "Current time: $(date +"%Y-%m-%d %H:%M:%S")"
# Output total lines of Dart code across all Dart files
echo "#################### Total lines of Dart code inside lib ################"
cd lib || exit 1
find . -name "*.dart" -type f -exec wc -l {} + | grep total
cd .. || exit 1

# Output total lines in example
echo "#################### Total lines of Dart code inside example ################"
cd example || exit 1
find . -name "*.dart" -type f -exec wc -l {} + | grep total
cd .. || exit 1

# Output total lines in test
echo "#################### Total lines of Dart code inside test ################"
cd test || exit 1
find . -name "*.dart" -type f -exec wc -l {} + | grep total