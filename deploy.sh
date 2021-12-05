set -e
TMP=/tmp/tldiff
rm -rf "$TMP"
mkdir "$TMP"
cp diff.js atom.xml diffs.js diff.html diff.css "$TMP"
git checkout --orphan gh-pages
mv "$TMP"/* .
git add diff.js atom.xml diffs.js diff.html diff.css -f
git commit -am "Deploy new layer"
git push --force -u origin gh-pages
git checkout master
