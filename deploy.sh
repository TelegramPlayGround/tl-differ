#!/bin/bash
set -e
set -x
IFS="
"
TZ="Asia/Kolkata"
TMP=/tmp/tldiff
rm -rf "$TMP"
mkdir "$TMP"
cp diff.js atom.xml diffs.js diff.html diff.css "$TMP"
current_date=$(date -R)

mv "$TMP"/* .
ls
git config --global user.email "johnprestonmail@gmail.com"
git config --global user.name "GitHub Action <John Preston>"
wget "https://github.com/TelegramPlayGround/tg-api-spec-s/raw/data/tdesktop.tl" -O schemes/latest.tl

git add schemes/ diff.js atom.xml diffs.js diff.html index.html diff.css -Af
# the below lines were copied from
# https://github.com/LonamiWebs/Telethon/blob/master/update-docs.sh
git commit -am "${current_date} TLDiffer: Deploy new layer"

curpath=$(pwd)

git clone https://github.com/pyrogram/pyrogram /tmp/docgen/
cd /tmp/docgen/
sudo apt install -y pandoc latexmk
make clean
make venv
pip install --upgrade pip
pip install tox sphinx_tabs
make api
make docs
mv /tmp/docgen/docs/build/html /tmp/pydocs
cd ${curpath}
rm -rf pyrogram
mv /tmp/pydocs pyrogram

git config --global user.name "GitHub Action <Dan>"
git config --global user.email "14043624+delivrance@users.noreply.github.com"
git add . -A
git commit -m "${current_date} DocGen: Update documentation"
rm -rf /tmp/docgen

git clone https://github.com/TelegramPlayGround/Telethon /tmp/docgen/
cd /tmp/docgen/
git checkout rotcev
python setup.py install
python setup.py gen docs
rm -rf /tmp/docs
mv docs/ /tmp/docs
pip install sphinx_rtd_theme sphinx_tabs
cd readthedocs
make html
rm -rf /tmp/telethonrtd
mv _build/html /tmp/telethonrtd
cd ${curpath}
rm -rf telethon
mv /tmp/telethonrtd telethon
cd telethon
mv /tmp/docs advanced
cd advanced
git config --global user.email "totufals@hotmail.com"
git config --global user.name "GitHub Action <Lonami Exo>"
git add constructors/ types/ methods/ index.html js/search.js css/ img/
cd ..
git add . -A
git commit -m "${current_date} DocGen: Update TeLethoN documentation"
rm -rf /tmp/docgen

git push -u origin gh-pages
