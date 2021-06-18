#! /usr/bin/env bash

set -eu
shopt -s extglob

if (git grep 'localhost:4000' | egrep -v "(README|regenerate-site)"); then
  echo "ERROR: Your content has links to localhost:4000!" >&2
  exit 1
fi

if [ "x$(git status --porcelain)" != "x" ]; then
  echo -n "git repo has uncommited changes.  Continue anyway? (y/N) " >&2
  read -n 1 YESNO
  echo >&2
  if [ "x$YESNO" != xy ]; then
    exit 1
  fi
fi

case $(git rev-parse --abbrev-ref HEAD) in
  master )
    echo "On master branch.  Will push to sandstorm.io."
    HOST=sandstorm.io
    BRANCH=published
    ;;

  * )
    echo "On devel branch.  Will push to next.sandstorm.io."
    HOST=next.sandstorm.io
    BRANCH=published-next
    ;;
esac

echo "Regenerating site..."

rm -rf _pushsite
bundle exec jekyll build -d _pushsite

rm -rf _published
mkdir _published

(cd _published && git clone -b "$BRANCH" .. .)

# Note that these intentionally skip dotfiles.
rm -rf _published/*
cp -r _pushsite/* _published

COMMIT=$(git rev-parse HEAD)
(cd _published && git add . && git commit -am "Regenerated site from commit: $COMMIT")

echo
echo "Files changed:"
echo
(cd _published && git diff --name-only HEAD^)

echo
echo -n "Make these changes live? (y/N)"
read -n 1 YESNO
echo

if [ "x$YESNO" == "xy" ]; then
  (cd _published && git push)
  git push -u origin "$BRANCH:$BRANCH"
  CLOUDSDK_COMPUTE_ZONE=us-central1-a gcloud --project=sandstorm-io compute ssh alpha2 --command 'cd /var/www/sandstorm.io && pull-and-purge-cf-cache.sh'
else
  echo "Push CANCELED"
  echo "You can examine the canceled changes in: ./_published"
  echo "When you run this script again, that directory will be wiped and regenerated."
  exit 1
fi

