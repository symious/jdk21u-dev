#!/bin/bash
set -euo pipefail

export MANPATH="${MANPATH:-}"
source /opt/rh/devtoolset-8/enable

log() {
  echo "[INFO] $*"
}

err() {
  echo "[ERROR] $*" >&2
}

JEMALLOC_VERSION="${JEMALLOC_VERSION:-5.3.0}"
JEMALLOC_URL="${JEMALLOC_URL:-https://github.com/jemalloc/jemalloc/releases/download/${JEMALLOC_VERSION}/jemalloc-${JEMALLOC_VERSION}.tar.bz2}"

PATCHELF_VERSION="${PATCHELF_VERSION:-0.18.0}"
PATCHELF_URL="${PATCHELF_URL:-https://github.com/NixOS/patchelf/archive/refs/tags/${PATCHELF_VERSION}.tar.gz}"

JDK_BRANCH="${JDK_BRANCH:-21}"
GIT_TAG="${GIT_TAG:-master}"
GIT_URL="${GIT_URL:-gitlab@git.garena.com:shopee/data-infra}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"

JEMALLOC_PREFIX="${JEMALLOC_PREFIX:-/opt/jemalloc}"
PATCHELF_PREFIX="${PATCHELF_PREFIX:-/opt/patchelf}"

mkdir -p "${OUTPUT_DIR}"
rm -rf /tmp/jemalloc-src /tmp/patchelf-src /jdk /bootjdk
mkdir -p /tmp/jemalloc-src /tmp/patchelf-src /bootjdk

# ------------------------------------------------------------------------------
# Build jemalloc
# ------------------------------------------------------------------------------

log "Building jemalloc ${JEMALLOC_VERSION}"
rm -rf "${JEMALLOC_PREFIX}"
mkdir -p "${JEMALLOC_PREFIX}"

curl -fL "${JEMALLOC_URL}" | tar -xj -C /tmp/jemalloc-src --strip-components=1

pushd /tmp/jemalloc-src >/dev/null
./configure --prefix="${JEMALLOC_PREFIX}"
make -j"$(nproc)"
make install
popd >/dev/null

test -f "${JEMALLOC_PREFIX}/lib/libjemalloc.so.2" || {
  err "jemalloc build failed: libjemalloc.so.2 not found"
  exit 1
}

# ------------------------------------------------------------------------------
# Build patchelf
# ------------------------------------------------------------------------------

log "Building patchelf ${PATCHELF_VERSION}"
rm -rf "${PATCHELF_PREFIX}"
mkdir -p "${PATCHELF_PREFIX}"

curl -fL "${PATCHELF_URL}" | tar -xz -C /tmp/patchelf-src --strip-components=1

pushd /tmp/patchelf-src >/dev/null
if [ -f bootstrap.sh ]; then
  ./bootstrap.sh
fi
./configure --prefix="${PATCHELF_PREFIX}"
make -j"$(nproc)"
make install
popd >/dev/null

PATCHELF_BIN="${PATCHELF_PREFIX}/bin/patchelf"
test -x "${PATCHELF_BIN}" || {
  err "patchelf build failed"
  exit 1
}

# ------------------------------------------------------------------------------
# Boot JDK URL
# ------------------------------------------------------------------------------

case "${JDK_BRANCH}" in
  17)
    GA_URL="https://download.java.net/java/GA/jdk17/0d483333a00540d886896bac774ff48b/35/GPL/openjdk-17_linux-x64_bin.tar.gz"
    ;;
  21)
    GA_URL="https://download.java.net/java/GA/jdk21/fd2272bbf8e04c3dbaee13770090416c/35/GPL/openjdk-21_linux-x64_bin.tar.gz"
    ;;
  *)
    err "Unsupported JDK_BRANCH: ${JDK_BRANCH}"
    exit 1
    ;;
esac

log "JDK_BRANCH=${JDK_BRANCH}, GIT_TAG=${GIT_TAG}"
log "Boot JDK URL: ${GA_URL}"

# ------------------------------------------------------------------------------
# Resolve version args
# ------------------------------------------------------------------------------

USE_SDI_VERSION_ARGS=0
BUILD_ID=""

if [[ "${GIT_TAG}" =~ ^(17|21)\.sdi-([0-9]+(\.[0-9]+)*)$ ]]; then
  USE_SDI_VERSION_ARGS=1
  BUILD_ID="${BASH_REMATCH[2]}"
fi

log "USE_SDI_VERSION_ARGS=${USE_SDI_VERSION_ARGS}"
if [ -n "${BUILD_ID}" ]; then
  log "BUILD_ID=${BUILD_ID}"
fi

# ------------------------------------------------------------------------------
# Clone JDK source
# ------------------------------------------------------------------------------

REPO="${GIT_URL}/jdk${JDK_BRANCH}u-dev.git"
log "Cloning source from ${REPO}"

git clone "${REPO}" /jdk

pushd /jdk >/dev/null
git fetch --tags origin
git checkout -f "${GIT_TAG}"
git reset --hard "${GIT_TAG}"
popd >/dev/null

# ------------------------------------------------------------------------------
# Boot JDK
# ------------------------------------------------------------------------------

log "Downloading boot JDK"
curl -fL "${GA_URL}" | tar -xz -C /bootjdk --strip-components=1

# ------------------------------------------------------------------------------
# Configure / Build JDK
# ------------------------------------------------------------------------------

pushd /jdk >/dev/null

EXTRA_CFLAGS="-I${JEMALLOC_PREFIX}/include"
EXTRA_CXXFLAGS="-I${JEMALLOC_PREFIX}/include"
EXTRA_LDFLAGS="-L${JEMALLOC_PREFIX}/lib -Wl,-rpath,${JEMALLOC_PREFIX}/lib -ljemalloc"

CONFIGURE_ARGS=(
  --with-boot-jdk=/bootjdk
  --disable-warnings-as-errors
  --with-extra-cflags="${EXTRA_CFLAGS}"
  --with-extra-cxxflags="${EXTRA_CXXFLAGS}"
  --with-extra-ldflags="${EXTRA_LDFLAGS}"
)

if [ "${USE_SDI_VERSION_ARGS}" -eq 1 ]; then
  CONFIGURE_ARGS+=(
    --with-version-date="$(date +%Y-%m-%d)"
    --with-version-pre='sdi'
    --with-version-feature="${JDK_BRANCH}"
    --with-version-interim=0
    --with-version-update=0
    --with-version-patch=0
    --with-version-opt="${BUILD_ID}"
  )
fi

log "Running configure"
bash configure "${CONFIGURE_ARGS[@]}"

log "Running make images"
make images

# ------------------------------------------------------------------------------
# Post-process final JDK image
# ------------------------------------------------------------------------------

IMAGE_DIR="$(echo /jdk/build/*/images/jdk)"
if [ -z "${IMAGE_DIR}" ]; then
  err "JDK image dir not found under /jdk/build"
  exit 1
fi

LIB_DIR="${IMAGE_DIR}/lib"
JVM_SO="${IMAGE_DIR}/lib/server/libjvm.so"

if [ ! -f "${JVM_SO}" ]; then
  err "libjvm.so not found: ${JVM_SO}"
  exit 1
fi

log "Installing jemalloc into final JDK image"
mkdir -p "${LIB_DIR}"
cp -f "${JEMALLOC_PREFIX}/lib/libjemalloc.so.2" "${LIB_DIR}/"
ln -sf libjemalloc.so.2 "${LIB_DIR}/libjemalloc.so"

log "Patching RUNPATH on libjvm.so"
"${PATCHELF_BIN}" --set-rpath '$ORIGIN/..' "${JVM_SO}"

log "Verifying final libjvm.so"
readelf -d "${JVM_SO}" | egrep 'NEEDED|RPATH|RUNPATH' || true
ldd "${JVM_SO}" | grep jemalloc || true

# ------------------------------------------------------------------------------
# Package
# ------------------------------------------------------------------------------

SAFE_TAG="$(echo "${GIT_TAG}" | sed 's|/|-|g')"
PKG_DIR="jdk-${SAFE_TAG#jdk-}"
TAR_GZ_PREFIX="openjdk-${SAFE_TAG#jdk-}_linux-x64_bin"

pushd "$(dirname "${IMAGE_DIR}")" >/dev/null
rm -rf "${PKG_DIR}"
cp -r jdk "${PKG_DIR}"
tar czf "${OUTPUT_DIR}/${TAR_GZ_PREFIX}.tar.gz" "${PKG_DIR}"
popd >/dev/null

popd >/dev/null

log "Build complete: ${OUTPUT_DIR}/${TAR_GZ_PREFIX}.tar.gz"