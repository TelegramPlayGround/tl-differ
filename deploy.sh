set -e
TMP=/tmp/tldiff
rm -rf "$TMP"
mkdir "$TMP"
cp app.js atom.xml diff.js index.html "$TMP"
git checkout --orphan gh-pages
mv "$TMP"/* .
git commit -am "Deploy new layer"
git push --force -u origin gh-pages
git checkout master
