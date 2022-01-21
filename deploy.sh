#!/bin/bash
set -e
set -x
IFS="
"
TMP=/tmp/tldiff
rm -rf "$TMP"
mkdir "$TMP"
cp diff.js atom.xml diffs.js diff.html diff.css "$TMP"
# git branch -D gh-pages
git checkout --orphan gh-pages
mv "$TMP"/* .
ls
git config --global user.email "johnprestonmail@gmail.com"
git config --global user.name "GitHub Action <John Preston>"
cimmot="64d108c6160716bdf999e98f78a8d50117ba88a0"
wget "https://github.com/SpEcHiDe/telegram-bot-api-spec/raw/${cimmot}/mtproto.tl" -O schemes/${cimmot}.tl
rm README.md deploy.sh get_all_tl.py
git add schemes/ diff.js atom.xml diffs.js diff.html diff.css README.md deploy.sh get_all_tl.py -Af
# the below lines were copied from
# https://github.com/LonamiWebs/Telethon/blob/master/update-docs.sh
git commit -am "TLDiffer: Deploy new layer"

curpath=$(pwd)

git clone https://github.com/TelegramPlayGround/pyrogram /tmp/docgen/
cd /tmp/docgen/
python setup.py install
python setup.py generate --api
python setup.py generate --docs
cd docs
sudo apt install -y pandoc latexmk
pip install -r requirements.txt
pip install sphinx_tabs
make html
mv build/html /tmp/pydocs
cd ${curpath}
mkdir -p pyrogram
cd pyrogram
mv /tmp/pydocs/* .
touch ../.nojekyll  # https://github.blog/2009-12-29-bypassing-jekyll-on-github-pages/
git add ../.nojekyll
git config --global user.name "GitHub Action <Dan>"
git config --global user.email "14043624+delivrance@users.noreply.github.com"
git add . -A
git commit -m "DocGen: Update documentation"
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
mkdir -p telethon/advanced
cd telethon/advanced
rm -rf $(ls /tmp/docs)
mv /tmp/docs/* .
git config --global user.email "totufals@hotmail.com"
git config --global user.name "GitHub Action <Lonami Exo>"
git add constructors/ types/ methods/ index.html js/search.js css/ img/
git commit -m "DocGen: Update TL documentation"
cd ..
mv /tmp/telethonrtd/* .
git add . -A
git commit -m "DocGen: Update RTD"
rm -rf /tmp/docgen

git push --force -u origin gh-pages
git checkout master
