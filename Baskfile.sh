[ -f local.sh ] && . local.sh


task_update_gn() {
  [ -d chromium-buildtools ] || \
    git clone https://chromium.googlesource.com/chromium/buildtools chromium-buildtools

  cd chromium-buildtools
  git pull
  cd ..

  aria2c -x16 -o pkg/gn --allow-overwrite \
    "https://storage.googleapis.com/chromium-gn/`cat chromium-buildtools/linux64/gn.sha1`"
}


get_message() {
  git show -s --format=medium $1 | grep '^     '
}


get_full_commit() {
  curl -s https://chromium.googlesource.com/chromium/src/+/$1 | \
    pup 'th:contains("commit") + td:not(:contains("Commit")) text{}'
}


task_update_changelog() {
  start=e043d81e9185a2445fa3ec3fc34a4f69b58d4969

  [ -f pkg/debian/changelog ] && mv pkg/debian/changelog changelog.old
  changelog=`realpath pkg/debian/changelog`

  cd chromium-buildtools
  for commit in `git rev-list $start^.. linux64/gn.sha1`; do
    head=`get_message $commit | grep -Po '(?<=^      )\w+' | head -1`
    bask_log_info commit: $head
    echo "gn (1.`get_full_commit $head`) unstable; urgency=low" >> $changelog
    echo >> $changelog

    get_message $commit | sed 's/^      /    * /' >> $changelog

    echo >> $changelog
    echo " -- Ryan Gonzalez <rymg19@gmail.com>  `git show -s --format=%aD $commit`" \
        >> $changelog
    echo >> $changelog
  done
}


task_build() {
  cd pkg
  debuild -b
  cd ..
  mkdir -p deps
  mv gn*.deb gn*.changes gn*.build debs
}


task_push() {
  n=`echo debs/*.deb | wc -w`
  if [ "$n" != "1" ]; then
    bask_log_error 'Clean up your debs!'
    return 1
  fi

  if [ -z "$REPREPRO_BASE_DIR" ]; then
    bask_log_error "Set $REPREPRO_BASE_DIR in 'local.sh'."
    return 1
  fi

  if [ -z "$RELEASES" ]; then
    bask_log_error "Set $RELEASES in 'local.sh'."
    return 1
  fi

  export REPREPRO_BASE_DIR

  for release in $RELEASES; do
    bask_run reprepro -C $release includedeb $release debs/*.deb || return
  done
}


task_clean() {
  for path in `sed '/^$/d;/^local.sh$/d' < .gitignore`; do
    rm -rf $path
  done
}
