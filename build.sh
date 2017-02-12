#!/bin/bash

push=0
branch=master

function abort_with_message() {
    echo $* > /dev/stderr
    exit 1
}

function print_help() {
    echo "Usage: ./build.sh [-h|--help] [--push] [--branch BRANCH]"
}

while [ $# -gt 0 ]; do
    key="$1"
    case $key in
        --push)
        push=1
        ;;
        --branch)
        branch="$2"
        shift
        ;;
        -h|--help)
        print_help
        exit 0
        ;;
    *)
        echo "Unknow argument founds." > /dev/stderr
        print_help
        exit 1
    ;;
    esac
    shift
done



which mkdocs && mkdocs --version > /dev/null

if [ $? -ne 0 ]; then
    abort_with_message "Cannot find mkdocs, please install it using 'pip install mkdocs'."
fi

export PYTHONPATH=$PYTHONPATH:$(pwd)

mkdocs build

if [ $? -ne 0 ]; then
    abort_with_message "Fail to build site, aborting process."
fi

site_url=$(python3 -c "import yaml; print(yaml.load(open('mkdocs.yml'))['site_url'])")
sed -i 's@$site_url\s*=.*@$site_url = "'"$site_url"'"}@g' build/templates/bootstrap/@layout.latte
repo_url=$(python3 -c "import yaml; print(yaml.load(open('mkdocs.yml'))['repo_url'])")
sed -i 's@$repo_url\s*=.*@$repo_url = "'"$repo_url"'"}@g' build/templates/bootstrap/@layout.latte
menu=$(grep -Pzo '(?s)(?<=<!-- helpers -->)(.*?)(?=</ul>)' site/index.html)
echo $menu | sed -E 's@</li>\s+@</li>\n@g' | sed -E 's@href="(.*?)"@href="'"$site_url"'/\1"@g' > build/templates/bootstrap/helpers-menu.latte

if [ $? -ne 0 ]; then
    abort_with_message "No menu found in site/index.html, aborting process."
fi

cd build

if [ ! -e repo ]; then
    git clone https://github.com/holt59/cakephp3-bootstrap-helpers.git repo
fi

cd repo && git fetch && git checkout $branch && cd ..

if [ ! -e apigen.phar ]; then
    echo "Fetching apigen.phar... "
    wget http://apigen.org/apigen.phar && chmod +x apigen.phar
    if [ $? -ne 0 ]; then
        abort_with_message "Unable to retrieve apigen.phar, aborting process."
    fi
fi

rm -rf api
php apigen.phar generate -s ./repo/src -d api  --debug

rm -rf ./site
mv ../site ./site
mv api site/api

if [ $push -eq 1 ]; then
    rm -rf gh-pages
    git clone --branch gh-pages https://github.com/holt59/cakephp3-bootstrap-helpers.git gh-pages
    cd gh-pages
    rm ./* -rf
    mv ../site/* ./
    git add * && git commit -a -m "Update documentation."
    git push --set-upstream origin gh-pages
fi