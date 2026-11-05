# Source this: `. scripts/env.sh`. Sets NUCLEUS_HOME (a Nucleus tree with a built
# compiler) and puts its build/ and an LLVM 19+ toolchain first on PATH.
# In the cloud the tree is ../nucleus (scripts/setup-cloud.sh); on the host, set
# NUCLEUS_HOME before sourcing.

_nd_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export NUCLEUS_HOME=${NUCLEUS_HOME:-$(dirname "$_nd_root")/nucleus}

# The cloud image's default llvm-config/clang are LLVM 18, too old for Nucleus.
for _nd_v in 21 20 19; do
    if command -v "llvm-config-$_nd_v" >/dev/null 2>&1; then
        PATH="$("llvm-config-$_nd_v" --bindir):$PATH"
        break
    fi
done
export PATH="$NUCLEUS_HOME/build:$PATH"
unset _nd_root _nd_v
