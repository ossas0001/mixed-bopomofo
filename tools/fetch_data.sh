#!/bin/zsh
# 從原始來源下載字庫到 vendor/（這個專案本身不附帶任何第三方資料）
set -e
cd "$(dirname "$0")/.."
mkdir -p vendor && cd vendor
MCB=https://raw.githubusercontent.com/openvanilla/McBopomofo/master
for f in BPMFBase.txt BPMFMappings.txt phrase.occ heterophony1.list heterophony2.list heterophony3.list; do
    [ -f $f ] || curl -fL --progress-bar -O $MCB/Source/Data/$f
done
[ -f McBopomofo-LICENSE.txt ] || curl -fsL $MCB/LICENSE.txt -o McBopomofo-LICENSE.txt
[ -f en_50k.txt ] || curl -fL --progress-bar -O https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/en/en_50k.txt
echo "字庫已下載到 vendor/"
