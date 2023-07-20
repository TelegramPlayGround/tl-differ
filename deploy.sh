#!/bin/bash
set +ex
IFS="
"
TZ="Asia/Kolkata"
US="https://github.com/telegramdesktop/tdesktop/raw/dev/Telegram/mtproto/scheme/api.tl"
TMP=/tmp/tldiff
rm -rf "$TMP"
mkdir "$TMP"
cp diff.js atom.xml diffs.js diff.html diff.css "$TMP"
current_date=$(date -R)

mv "$TMP"/* .
ls

rm -rf tdesktop/ deploy.sh > /dev/null 2>&1
git add tdesktop/ deploy.sh -A > /dev/null 2>&1

git config --global user.email "johnprestonmail@gmail.com"
git config --global user.name "GitHub Action <John Preston>"
wget $US -O schemes/latest.tl

git add schemes/ diff.js atom.xml diffs.js diff.html index.html diff.css -Af
# the below lines were copied from
# https://github.com/LonamiWebs/Telethon/blob/master/update-docs.sh
git commit -am "${current_date} TLDiffer: Deploy new layer" > /dev/null 2>&1

curpath=$(pwd)

git clone https://github.com/LonamiWebs/Telethon /tmp/docgen/
cd /tmp/docgen/
git checkout v1
cd telethon_generator/data
rm api.tl
wget $US -O api.tl
cd ../..

python setup.py install
python setup.py gen docs

rm -rf /tmp/docs
mv docs/ /tmp/docs

rm -rf /tmp/docgen/
cd $curpath
rm -rf TL/
mv /tmp/docs TL
cd TL
git config --global user.email "totufals@hotmail.com"
git config --global user.name "GitHub Action <Lonami Exo>"
git add constructors/ types/ methods/ index.html js/search.js css/ img/
cd ..

rm -rf telethon pyrogram > /dev/null 2>&1
git add . -A
git status
git commit -m "${current_date} DocGen: Update documentation" > /dev/null 2>&1

git push -u origin gh-pages
