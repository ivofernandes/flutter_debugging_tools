cd ../../example

flutter build web \
  --release \
  --dart2js-optimization O4 \
  --no-tree-shake-icons \
  --no-source-maps || { echo "❌ Flutter build failed"; exit 1; }
