#!/bin/bash
# @(#) smoke test

# set -xv
set -o nounset
set -o errexit
set -o pipefail
set -o noclobber

export IFS=$' \t\n'
export LANG=en_US.UTF-8
umask u=rwx,g=,o=


readonly tmp_dir="$(mktemp -d)"

finalize(){
   rm -fr "$tmp_dir"
}

trap finalize EXIT


cd "$tmp_dir"


cat <<EOF > build.py
#!/usr/bin/python

import os
import sys

import buildpy.v1


os.environ["SHELL"] = "/bin/bash"
os.environ["SHELLOPTS"] = "pipefail:errexit:nounset:noclobber"
os.environ["PYTHON"] = sys.executable


dsl = buildpy.v1.DSL()
file = dsl.file
phony = dsl.phony
sh = dsl.sh
rm = dsl.rm


def let():
    phony("all", [], desc="Default target")
let()


if __name__ == '__main__':
    dsl.main(sys.argv)
EOF


cat <<EOF > expect
EOF

"$PYTHON" build.py > actual

colordiff expect actual
