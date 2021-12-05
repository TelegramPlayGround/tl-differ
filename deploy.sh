#!/bin/bash
set -e
TMP=/tmp/tldiff
rm -rf "$TMP"
mkdir "$TMP"
cp diff.js atom.xml diffs.js diff.html diff.css "$TMP"
git checkout --orphan gh-pages
mv "$TMP"/* .
git add diff.js atom.xml diffs.js diff.html diff.css -f
# the below lines were copied from
# https://github.com/LonamiWebs/Telethon/blob/master/update-docs.sh
git commit -am "TLDiffer: Deploy new layer"
curpath=$(pwd)
git clone https://github.com/LonamiWebs/Telethon /tmp/docgen/
cd /tmp/docgen/
rm telethon_generator/data/api.tl
wget "https://raw.githubusercontent.com/SpEcHiDe/Telethon/f2a366c70e21ca02ea612e3f82fd1b6462bb8005/telethon_generator/data/api.tl" -O telethon_generator/data/api.tl
python setup.py gen docs
rm -rf /tmp/docs
mv docs/ /tmp/docs
cd ${curpath}
mkdir -p docs
cd docs
# there's probably better ways but we know none has spaces
rm -rf $(ls /tmp/docs)
mv /tmp/docs/* .
git add constructors/ types/ methods/ index.html js/search.js css/ img/
git commit --amend -m "DocGen: Update documentation"
git push --force -u origin gh-pages
git checkout master
