#!/bin/bash
# @(#) --dry-run

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
#!/usr/bin/python3

import os
import logging
import sys

import buildpy.v8


def _setup_logger(level):
    logger = logging.getLogger()
    hdl = logging.StreamHandler(sys.stderr)
    hdl.setFormatter(
        logging.Formatter(
            "%(levelname)s %(process)d %(thread)d %(asctime)s %(filename)s %(lineno)d %(funcName)s %(message)s",
            "%y%m%d%H%M%S",
        )
    )
    logger.addHandler(hdl)
    hdl.setLevel(getattr(logging, level))
    logger.setLevel(getattr(logging, level))
    return logger


os.environ["SHELL"] = "/bin/bash"
os.environ["SHELLOPTS"] = "pipefail:errexit:nounset:noclobber"
os.environ["PYTHON"] = sys.executable


dsl = buildpy.v8.DSL(sys.argv)
logger = _setup_logger(dsl.args.log)

file = dsl.file
phony = dsl.phony
sh = dsl.sh
rm = dsl.rm


phony("all", ["check"], desc="Default target")
phony("check", ["t1.done", "t2.done"], desc="Run tests")

@file(["t2.done"], ["t2"], desc="Test 2")
def _(j):
    sh("touch " + " ".join(j.ts))

@file(["t1.done"], ["t1"], desc="Test 1")
def _(j):
    sh("touch " + " ".join(j.ts))

@file(["t2", "t1"], ["u2", "u1"])
def _(j):
    sh("touch " + " ".join(j.ts))


if __name__ == '__main__':
    dsl.run()
EOF

cat <<EOF > expect.1
t1.done
	t1

check
	t1.done
	t2.done

all
	check

EOF

cat <<EOF > expect.2.sort
touch t1.done
touch t2 t1
touch t2.done
EOF

touch u1 u2

{
   "$PYTHON" build.py --use_hash False
   # HFS has only 1 s time resolution
   sleep 1.1
   touch t1
   "$PYTHON" build.py --use_hash False -n
} 1> actual.1 2> actual.2
LC_ALL=C sort actual.2 > actual.2.sort

git diff --color-words --no-index --word-diff expect.1 actual.1
git diff --color-words --no-index --word-diff expect.2.sort actual.2.sort
